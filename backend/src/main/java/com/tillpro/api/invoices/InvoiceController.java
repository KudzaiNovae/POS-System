package com.tillpro.api.invoices;

import com.tillpro.api.invoices.dto.InvoiceDto;
import com.tillpro.api.invoices.dto.InvoicePaymentDto;
import com.tillpro.api.security.TenantContext;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/invoices")
public class InvoiceController {

    private final InvoiceService svc;

    public InvoiceController(InvoiceService svc) { this.svc = svc; }

    @GetMapping
    public List<InvoiceDto> list() {
        return svc.list(TenantContext.requireTenantId());
    }

    @GetMapping("/{id}")
    public InvoiceDto get(@PathVariable UUID id) {
        return svc.get(TenantContext.requireTenantId(), id);
    }

    /** Upsert — draft create or edit. Server recomputes totals. */
    @PostMapping
    public InvoiceDto upsert(@Valid @RequestBody InvoiceDto dto) {
        return svc.upsert(TenantContext.requireTenantId(), dto);
    }

    /** DRAFT → SENT, assigns an invoice number. */
    @PostMapping("/{id}/issue")
    public InvoiceDto issue(@PathVariable UUID id) {
        return svc.issue(TenantContext.requireTenantId(), id);
    }

    /** Record a payment against the invoice. */
    @PostMapping("/{id}/payments")
    public InvoiceDto addPayment(@PathVariable UUID id,
                                 @Valid @RequestBody InvoicePaymentDto p) {
        return svc.addPayment(TenantContext.requireTenantId(), id, p);
    }

    @PostMapping("/{id}/void")
    public InvoiceDto voidInvoice(@PathVariable UUID id,
                                  @RequestBody(required = false) Map<String, String> body) {
        String reason = body == null ? null : body.get("reason");
        return svc.voidInvoice(TenantContext.requireTenantId(), id, reason);
    }

    @PostMapping("/{id}/convert")
    public InvoiceDto convert(@PathVariable UUID id) {
        return svc.convertQuoteToInvoice(TenantContext.requireTenantId(), id);
    }

    @PostMapping("/{id}/credit-note")
    public InvoiceDto creditNote(@PathVariable UUID id,
                                 @RequestBody(required = false) Map<String, String> body) {
        String reason = body == null ? null : body.get("reason");
        return svc.createCreditNote(TenantContext.requireTenantId(), id, reason);
    }

    /** Sweep SENT/PARTIAL invoices past their due date into OVERDUE. */
    @PostMapping("/sweep-overdue")
    public Map<String, Object> sweepOverdue() {
        int n = svc.sweepOverdue(TenantContext.requireTenantId());
        return Map.of("updated", n);
    }
}
