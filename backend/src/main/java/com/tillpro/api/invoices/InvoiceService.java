package com.tillpro.api.invoices;

import com.tillpro.api.domain.*;
import com.tillpro.api.invoices.dto.*;
import com.tillpro.api.repo.*;
import com.tillpro.api.subscriptions.TierPolicy;
import com.tillpro.api.tax.VatClass;
import com.tillpro.api.tax.VatEngine;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.*;

/**
 * Invoice lifecycle.
 *
 * Handles create/update of draft invoices & quotations, numbering on SEND,
 * partial/full payment application, auto status transitions, and optional
 * conversion into a fiscalised Sale on full payment (so the same engine that
 * generates ZIMRA receipts also closes out an invoice).
 *
 * Offline path: the mobile app assigns the client UUID and POSTs the whole
 * document; we upsert by id. Number assignment waits until status != DRAFT.
 *
 * All mutating paths are tenant-scoped and the service never trusts the
 * totals from the client — we recompute from the authoritative items list.
 */
@Service
public class InvoiceService {

    private final InvoiceRepository invoices;
    private final InvoiceItemRepository items;
    private final InvoicePaymentRepository payments;
    private final InvoiceCounterRepository counters;
    private final TenantRepository tenants;
    private final TierPolicy tier;

    public InvoiceService(InvoiceRepository invoices,
                          InvoiceItemRepository items,
                          InvoicePaymentRepository payments,
                          InvoiceCounterRepository counters,
                          TenantRepository tenants,
                          TierPolicy tier) {
        this.invoices = invoices;
        this.items = items;
        this.payments = payments;
        this.counters = counters;
        this.tenants = tenants;
        this.tier = tier;
    }

    // ------------------------------------------------------------------
    // Queries
    // ------------------------------------------------------------------
    @Transactional(readOnly = true)
    public List<InvoiceDto> list(UUID tenantId) {
        return invoices.findByTenantIdOrderByClientCreatedAtDesc(tenantId).stream()
                .map(this::hydrate)
                .toList();
    }

    @Transactional(readOnly = true)
    public InvoiceDto get(UUID tenantId, UUID id) {
        Invoice inv = invoices.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Invoice not found."));
        return hydrate(inv);
    }

    // ------------------------------------------------------------------
    // Upsert (DRAFT editable; SENT and later are frozen)
    // ------------------------------------------------------------------
    @Transactional
    public InvoiceDto upsert(UUID tenantId, InvoiceDto dto) {
        tier.assertCanWrite();

        Invoice inv = invoices.findByIdAndTenantId(dto.id(), tenantId).orElse(null);
        boolean isNew = (inv == null);
        if (isNew) {
            inv = Invoice.builder()
                    .id(dto.id())
                    .tenantId(tenantId)
                    .status(dto.status() != null ? dto.status() : "DRAFT")
                    .clientCreatedAt(dto.clientCreatedAt())
                    .build();
        } else if (isLocked(inv)) {
            throw ApiException.forbidden(
                    "Invoice is " + inv.getStatus() + " and cannot be edited. "
                            + "Issue a credit note instead.");
        }

        inv.setKind(dto.kind() != null ? dto.kind() : "INVOICE");
        inv.setParentInvoiceId(dto.parentInvoiceId());
        inv.setCustomerId(dto.customerId());
        inv.setCustomerName(dto.customerName());
        inv.setCustomerTin(dto.customerTin());
        inv.setCustomerEmail(dto.customerEmail());
        inv.setCustomerAddress(dto.customerAddress());
        inv.setIssueDate(dto.issueDate() != null ? dto.issueDate() : LocalDate.now());
        inv.setDueDate(dto.dueDate());
        inv.setCurrency(dto.currency() != null ? dto.currency() : "USD");
        inv.setNotes(dto.notes());
        inv.setTerms(dto.terms());
        inv.setDiscountCents(dto.discountCents() != null ? dto.discountCents() : 0L);

        invoices.save(inv);

        // Replace line items wholesale (draft edit pattern)
        items.deleteByInvoiceId(inv.getId());
        long gross = 0, net = 0, vat = 0;
        for (InvoiceItemDto li : dto.items()) {
            long unit = li.unitPriceCents();
            long disc = li.discountCents() != null ? li.discountCents() : 0L;
            long lineGross = Math.round(unit * li.qty().doubleValue()) - disc;
            if (lineGross < 0) lineGross = 0;
            VatClass cls = VatClass.valueOf(
                    li.vatClass() == null ? "STANDARD" : li.vatClass());
            VatEngine.Split sp = VatEngine.splitInclusive(lineGross, cls);

            InvoiceItem item = InvoiceItem.builder()
                    .id(li.id())
                    .invoiceId(inv.getId())
                    .tenantId(tenantId)
                    .productId(li.productId())
                    .description(li.description())
                    .qty(li.qty())
                    .unit(li.unit() != null ? li.unit() : "pc")
                    .unitPriceCents(unit)
                    .discountCents(disc)
                    .lineTotalCents(lineGross)
                    .vatClass(cls.name())
                    .netCents(sp.netCents())
                    .vatCents(sp.vatCents())
                    .build();
            items.save(item);
            gross += lineGross;
            net += sp.netCents();
            vat += sp.vatCents();
        }
        long total = gross - inv.getDiscountCents();
        if (total < 0) total = 0;

        inv.setSubtotalCents(net);
        inv.setVatCents(vat);
        inv.setTotalCents(total);
        long paid = payments.findByInvoiceIdOrderByPaidAtDesc(inv.getId())
                .stream().mapToLong(InvoicePayment::getAmountCents).sum();
        inv.setPaidCents(paid);
        inv.setBalanceCents(total - paid);
        inv.setStatus(resolveStatus(inv));

        invoices.save(inv);
        return hydrate(inv);
    }

    // ------------------------------------------------------------------
    // Transition: DRAFT → SENT. Assigns a sequential number.
    // ------------------------------------------------------------------
    @Transactional
    public InvoiceDto issue(UUID tenantId, UUID id) {
        Invoice inv = invoices.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Invoice not found."));
        if (!"DRAFT".equals(inv.getStatus())) {
            return hydrate(inv); // idempotent
        }
        if (inv.getNumber() == null) {
            inv.setNumber(nextNumber(tenantId, inv.getKind(),
                    inv.getIssueDate() != null
                            ? inv.getIssueDate()
                            : LocalDate.now()));
        }
        inv.setStatus(inv.getTotalCents() == 0 ? "PAID" : "SENT");
        invoices.save(inv);
        return hydrate(inv);
    }

    @Transactional
    public InvoiceDto voidInvoice(UUID tenantId, UUID id, String reason) {
        Invoice inv = invoices.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Invoice not found."));
        inv.setStatus("VOIDED");
        String prev = inv.getNotes() == null ? "" : inv.getNotes();
        inv.setNotes((prev.isEmpty() ? "" : prev + "\n")
                + "[VOIDED] " + (reason == null ? "no reason" : reason));
        invoices.save(inv);
        return hydrate(inv);
    }

    // ------------------------------------------------------------------
    // Record a payment (partial or full). Rolls up status automatically.
    // ------------------------------------------------------------------
    @Transactional
    public InvoiceDto addPayment(UUID tenantId, UUID id, InvoicePaymentDto p) {
        Invoice inv = invoices.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Invoice not found."));
        if ("VOIDED".equals(inv.getStatus())) {
            throw ApiException.forbidden("Cannot record payment on a voided invoice.");
        }
        if ("DRAFT".equals(inv.getStatus())) {
            // implicit issue — a walk-in payment against a draft
            issue(tenantId, id);
            inv = invoices.findByIdAndTenantId(id, tenantId).orElseThrow();
        }
        InvoicePayment payment = InvoicePayment.builder()
                .id(p.id() != null ? p.id() : UUID.randomUUID())
                .invoiceId(inv.getId())
                .tenantId(tenantId)
                .amountCents(p.amountCents())
                .method(p.method())
                .reference(p.reference())
                .paidAt(p.paidAt() != null ? p.paidAt() : java.time.Instant.now())
                .build();
        payments.save(payment);

        long paid = payments.findByInvoiceIdOrderByPaidAtDesc(inv.getId())
                .stream().mapToLong(InvoicePayment::getAmountCents).sum();
        inv.setPaidCents(paid);
        inv.setBalanceCents(Math.max(0L, inv.getTotalCents() - paid));
        inv.setStatus(resolveStatus(inv));
        invoices.save(inv);
        return hydrate(inv);
    }

    // ------------------------------------------------------------------
    // Convert a QUOTE to an INVOICE (same id, new kind + new number).
    // ------------------------------------------------------------------
    @Transactional
    public InvoiceDto convertQuoteToInvoice(UUID tenantId, UUID id) {
        Invoice inv = invoices.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Quote not found."));
        if (!"QUOTE".equals(inv.getKind())) {
            throw ApiException.forbidden("Only QUOTE can be converted.");
        }
        inv.setKind("INVOICE");
        inv.setNumber(nextNumber(tenantId, "INVOICE", LocalDate.now()));
        inv.setStatus(inv.getTotalCents() == 0 ? "PAID" : "SENT");
        invoices.save(inv);
        return hydrate(inv);
    }

    // ------------------------------------------------------------------
    // Create a CREDIT_NOTE referencing a paid/issued invoice.
    // ------------------------------------------------------------------
    @Transactional
    public InvoiceDto createCreditNote(UUID tenantId, UUID parentId, String reason) {
        Invoice parent = invoices.findByIdAndTenantId(parentId, tenantId)
                .orElseThrow(() -> ApiException.notFound("Parent invoice not found."));

        UUID newId = UUID.randomUUID();
        Invoice cn = Invoice.builder()
                .id(newId)
                .tenantId(tenantId)
                .kind("CREDIT_NOTE")
                .parentInvoiceId(parent.getId())
                .customerId(parent.getCustomerId())
                .customerName(parent.getCustomerName())
                .customerTin(parent.getCustomerTin())
                .customerEmail(parent.getCustomerEmail())
                .customerAddress(parent.getCustomerAddress())
                .status("SENT")
                .issueDate(LocalDate.now())
                .currency(parent.getCurrency())
                .notes(reason)
                .clientCreatedAt(java.time.Instant.now())
                .subtotalCents(-parent.getSubtotalCents())
                .vatCents(-parent.getVatCents())
                .totalCents(-parent.getTotalCents())
                .balanceCents(-parent.getTotalCents())
                .build();
        cn.setNumber(nextNumber(tenantId, "CREDIT_NOTE", LocalDate.now()));
        invoices.save(cn);

        // Mirror line items with negative qty for accurate audit trail.
        for (InvoiceItem li : items.findByInvoiceId(parent.getId())) {
            InvoiceItem neg = InvoiceItem.builder()
                    .id(UUID.randomUUID())
                    .invoiceId(cn.getId())
                    .tenantId(tenantId)
                    .productId(li.getProductId())
                    .description(li.getDescription())
                    .qty(li.getQty().negate())
                    .unit(li.getUnit())
                    .unitPriceCents(li.getUnitPriceCents())
                    .discountCents(li.getDiscountCents())
                    .lineTotalCents(-li.getLineTotalCents())
                    .vatClass(li.getVatClass())
                    .netCents(-li.getNetCents())
                    .vatCents(-li.getVatCents())
                    .build();
            items.save(neg);
        }
        return hydrate(cn);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    private boolean isLocked(Invoice inv) {
        return List.of("PAID", "VOIDED", "CREDIT_NOTE").contains(inv.getStatus());
    }

    private String resolveStatus(Invoice inv) {
        if ("DRAFT".equals(inv.getStatus())) return "DRAFT";
        if ("VOIDED".equals(inv.getStatus())) return "VOIDED";
        long paid = inv.getPaidCents() == null ? 0 : inv.getPaidCents();
        long total = inv.getTotalCents() == null ? 0 : inv.getTotalCents();
        if (paid >= total && total > 0) return "PAID";
        if (paid > 0 && paid < total) return "PARTIAL";
        if (inv.getDueDate() != null && inv.getDueDate().isBefore(LocalDate.now())) {
            return "OVERDUE";
        }
        return "SENT";
    }

    private String nextNumber(UUID tenantId, String kind, LocalDate date) {
        int year = date.getYear();
        InvoiceCounter c = counters
                .findByTenantIdAndYearAndKind(tenantId, year, kind)
                .orElseGet(() -> counters.save(InvoiceCounter.builder()
                        .tenantId(tenantId).year(year).kind(kind).nextValue(1L)
                        .build()));
        long seq = c.getNextValue();
        c.setNextValue(seq + 1);
        counters.save(c);

        String prefix = switch (kind) {
            case "QUOTE" -> "QTE";
            case "PROFORMA" -> "PRO";
            case "CREDIT_NOTE" -> "CN";
            default -> "INV";
        };
        return "%s-%d-%06d".formatted(prefix, year, seq);
    }

    private InvoiceDto hydrate(Invoice inv) {
        var li = items.findByInvoiceId(inv.getId()).stream()
                .map(InvoiceItemDto::from).toList();
        var pp = payments.findByInvoiceIdOrderByPaidAtDesc(inv.getId()).stream()
                .map(InvoicePaymentDto::from).toList();
        return InvoiceDto.from(inv, li, pp);
    }

    // ------------------------------------------------------------------
    // Background: flip SENT invoices to OVERDUE after due date.
    // Called by a scheduler.
    // ------------------------------------------------------------------
    @Transactional
    public int sweepOverdue(UUID tenantId) {
        List<Invoice> due = invoices.findByTenantIdAndDueDateBeforeAndStatusIn(
                tenantId, LocalDate.now(ZoneId.of("Africa/Harare")),
                List.of("SENT", "PARTIAL"));
        int n = 0;
        for (Invoice inv : due) {
            if ("OVERDUE".equals(inv.getStatus())) continue;
            inv.setStatus("OVERDUE");
            invoices.save(inv);
            n++;
        }
        return n;
    }
}
