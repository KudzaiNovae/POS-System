package com.tillpro.api.fiscal;

import com.tillpro.api.domain.FdmsSubmission;
import com.tillpro.api.domain.Sale;
import com.tillpro.api.repo.FdmsSubmissionRepository;
import com.tillpro.api.repo.SaleRepository;
import com.tillpro.api.security.TenantContext;
import com.tillpro.api.web.ApiException;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Read-only endpoints the mobile app uses to:
 *   - check a sale's ZIMRA fiscalisation status (for the receipt footer),
 *   - see the FDMS delivery queue (owner/manager audit view).
 *
 * Write paths for fiscalisation are NOT exposed — a sale is fiscalised
 * automatically by SalesService and delivered by the FdmsSubmitter poller.
 */
@RestController
@RequestMapping("/api/v1/fiscal")
public class FiscalController {

    private final SaleRepository sales;
    private final FdmsSubmissionRepository submissions;

    public FiscalController(SaleRepository sales, FdmsSubmissionRepository submissions) {
        this.sales = sales;
        this.submissions = submissions;
    }

    /** Summary of fiscal state for a single sale — cheap enough to poll. */
    @GetMapping("/status/{saleId}")
    public Map<String, Object> status(@PathVariable UUID saleId) {
        UUID tenantId = TenantContext.requireTenantId();
        Sale s = sales.findById(saleId)
                .filter(x -> x.getTenantId().equals(tenantId))
                .orElseThrow(() -> ApiException.notFound("Sale not found."));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("saleId", s.getId());
        out.put("fiscalReceiptNo", s.getFiscalReceiptNo());
        out.put("fiscalStatus", s.getFiscalStatus());
        out.put("fiscalReference", s.getFiscalReference());
        out.put("fiscalQrPayload", s.getFiscalQrPayload());
        out.put("totalCents", s.getTotalCents());
        out.put("vatCents", s.getVatCents());
        out.put("subtotalCents", s.getSubtotalCents());
        return out;
    }

    /** Submission queue / history for the current tenant. */
    @GetMapping("/submissions")
    public List<Map<String, Object>> submissions(
            @RequestParam(required = false) String status) {
        UUID tenantId = TenantContext.requireTenantId();
        if (!isManagerOrOwner()) {
            throw ApiException.forbidden("Only owners/managers can view FDMS queue.");
        }
        List<FdmsSubmission> all = submissions.findByTenantIdOrderByCreatedAtDesc(tenantId);
        return all.stream()
                .filter(s -> status == null || status.equalsIgnoreCase(s.getStatus()))
                .limit(200)
                .map(s -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", s.getId());
                    m.put("saleId", s.getSaleId());
                    m.put("status", s.getStatus());
                    m.put("attempts", s.getAttempts());
                    m.put("lastError", s.getLastError());
                    m.put("nextAttemptAt", s.getNextAttemptAt());
                    m.put("createdAt", s.getCreatedAt());
                    return m;
                })
                .collect(Collectors.toList());
    }

    /** Lightweight counter of submissions per status — for the settings card. */
    @GetMapping("/submissions/summary")
    public Map<String, Long> submissionsSummary() {
        UUID tenantId = TenantContext.requireTenantId();
        return submissions.findByTenantIdOrderByCreatedAtDesc(tenantId).stream()
                .collect(Collectors.groupingBy(FdmsSubmission::getStatus, Collectors.counting()));
    }

    private static boolean isManagerOrOwner() {
        String role = TenantContext.getRole();
        return "OWNER".equals(role) || "MANAGER".equals(role);
    }
}
