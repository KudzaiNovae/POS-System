package com.tillpro.api.fiscal;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tillpro.api.domain.*;
import com.tillpro.api.repo.*;
import com.tillpro.api.tax.VatClass;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * ZIMRA-compliant fiscal layer.
 *
 * Responsibilities:
 *  1. Compute per-line net/VAT on every sale.
 *  2. Assign a strictly sequential fiscal_receipt_no per tenant.
 *  3. Generate the QR verification payload that the receipt footer encodes.
 *  4. Enqueue an FDMS submission record for the background poller to deliver
 *     to ZIMRA's FDMS API (real endpoint, URLs, and signing vary per
 *     fiscal-device certification). Offline-safe by design.
 *
 * Design note: we DO NOT call ZIMRA synchronously from the POS path. A till
 * must always close a sale. Fiscalisation is eventually-consistent and the
 * sale carries a fiscal_status that transitions PENDING → ACCEPTED.
 */
@Service
public class FiscalService {

    private final FiscalCounterRepository counters;
    private final FdmsSubmissionRepository submissions;
    private final TenantRepository tenants;
    private final SaleItemRepository items;
    private final ObjectMapper json;

    public FiscalService(FiscalCounterRepository counters,
                         FdmsSubmissionRepository submissions,
                         TenantRepository tenants,
                         SaleItemRepository items,
                         ObjectMapper json) {
        this.counters = counters;
        this.submissions = submissions;
        this.tenants = tenants;
        this.items = items;
        this.json = json;
    }

    /**
     * Called by SalesService after persisting a sale + its items, before the
     * transaction commits. Mutates the sale with fiscal fields. Caller saves.
     */
    @Transactional
    public void fiscalise(Sale sale, List<SaleItem> lines) {
        Tenant tenant = tenants.findById(sale.getTenantId()).orElseThrow();

        // 1) per-line VAT breakdown ------------------------------------------
        long totalNet = 0, totalVat = 0;
        Map<String, Long> byClass = new LinkedHashMap<>();
        for (SaleItem li : lines) {
            VatClass cls = VatClass.valueOf(
                    li.getVatClass() == null ? "STANDARD" : li.getVatClass());
            // gross = line_total_cents (we treat shop prices as VAT-inclusive)
            var split = com.tillpro.api.tax.VatEngine
                    .splitInclusive(li.getLineTotalCents(), cls);
            li.setNetCents(split.netCents());
            li.setVatCents(split.vatCents());
            totalNet += split.netCents();
            totalVat += split.vatCents();
            byClass.merge(cls.code(), split.vatCents(), Long::sum);
        }
        sale.setSubtotalCents(totalNet);
        sale.setVatCents(totalVat);

        // 2) sequential receipt number ---------------------------------------
        FiscalCounter c = counters.findByTenantId(sale.getTenantId())
                .orElseGet(() -> counters.save(FiscalCounter.builder()
                        .tenantId(sale.getTenantId()).nextValue(1L).build()));
        long seq = c.getNextValue();
        c.setNextValue(seq + 1);
        counters.save(c);

        String receiptNo = formatReceiptNo(tenant, seq);
        sale.setFiscalReceiptNo(receiptNo);

        // 3) QR payload ------------------------------------------------------
        String qr = buildQrPayload(tenant, sale, receiptNo);
        sale.setFiscalQrPayload(qr);
        sale.setFiscalStatus("PENDING");

        // 4) enqueue FDMS submission ----------------------------------------
        try {
            Map<String, Object> payload = Map.of(
                "version", "1.0",
                "deviceId", nvl(tenant.getFiscalDeviceId()),
                "tenant", Map.of(
                        "tin", nvl(tenant.getTin()),
                        "vatNumber", nvl(tenant.getVatNumber()),
                        "tradeName", nvl(tenant.getTradeName()),
                        "address", nvl(tenant.getAddress())),
                "receipt", Map.of(
                        "number", receiptNo,
                        "id", sale.getId().toString(),
                        "issuedAt", sale.getClientCreatedAt().toString(),
                        "paymentMethod", sale.getPaymentMethod(),
                        "subtotalCents", sale.getSubtotalCents(),
                        "vatCents", sale.getVatCents(),
                        "totalCents", sale.getTotalCents(),
                        "customerTin", nvl(sale.getCustomerTin()),
                        "customerName", nvl(sale.getCustomerName()),
                        "vatByClass", byClass),
                "lines", lines.stream().map(li -> Map.of(
                        "name", li.getNameSnapshot(),
                        "qty", li.getQty(),
                        "unitPriceCents", li.getUnitPriceCents(),
                        "lineTotalCents", li.getLineTotalCents(),
                        "netCents", li.getNetCents(),
                        "vatCents", li.getVatCents(),
                        "vatClass", li.getVatClass()
                )).toList()
            );

            FdmsSubmission sub = FdmsSubmission.builder()
                    .tenantId(sale.getTenantId())
                    .saleId(sale.getId())
                    .payloadJson(json.writeValueAsString(payload))
                    .status("PENDING")
                    .attempts(0)
                    .nextAttemptAt(Instant.now())
                    .build();
            submissions.save(sub);
        } catch (Exception e) {
            // Never fail a sale because of a fiscalisation issue. Log-and-go.
            sale.setFiscalStatus("OFFLINE");
        }
    }

    /** Format: TIN-YYYYMMDD-NNNNNN. Human-readable, sortable, tenant-scoped. */
    private String formatReceiptNo(Tenant t, long seq) {
        String date = LocalDate.now(ZoneId.of(t.getTimezone()))
                .format(DateTimeFormatter.BASIC_ISO_DATE);
        String base = (t.getTin() == null || t.getTin().isBlank())
                ? t.getId().toString().substring(0, 8).toUpperCase()
                : t.getTin();
        return "%s-%s-%06d".formatted(base, date, seq);
    }

    /**
     * QR payload contains the fields ZIMRA asks a verifier to see:
     *   TIN | VAT# | receipt# | datetime | totalCents | vatCents | hash
     * The hash is a SHA-256 over the canonical string, truncated to 16 chars
     * for compact printing. Real FDMS flow replaces hash with ZIMRA's issued
     * verification code after ACCEPTED.
     */
    private String buildQrPayload(Tenant t, Sale s, String receiptNo) {
        String canon = String.join("|",
                nvl(t.getTin()), nvl(t.getVatNumber()),
                receiptNo, s.getClientCreatedAt().toString(),
                String.valueOf(s.getTotalCents()), String.valueOf(s.getVatCents()));
        String hash = sha256Hex(canon).substring(0, 16);
        return canon + "|" + hash;
    }

    private static String nvl(String s) { return s == null ? "" : s; }

    private static String sha256Hex(String in) {
        try {
            MessageDigest d = MessageDigest.getInstance("SHA-256");
            byte[] out = d.digest(in.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(out.length * 2);
            for (byte b : out) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) { throw new RuntimeException(e); }
    }
}
