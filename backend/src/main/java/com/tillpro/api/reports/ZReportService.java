package com.tillpro.api.reports;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tillpro.api.domain.Sale;
import com.tillpro.api.domain.SaleItem;
import com.tillpro.api.domain.Tenant;
import com.tillpro.api.domain.ZReport;
import com.tillpro.api.repo.SaleItemRepository;
import com.tillpro.api.repo.SaleRepository;
import com.tillpro.api.repo.TenantRepository;
import com.tillpro.api.repo.ZReportRepository;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;

/**
 * Z-Report = "fiscal close" of a business day. Required by ZIMRA-conformant
 * deployments and used by every shop owner to reconcile cash drawer + EcoCash
 * settlements. We aggregate from sales (not from the till session) so the
 * report survives reboots, multi-device usage, and replays.
 */
@Service
public class ZReportService {

    private final SaleRepository sales;
    private final SaleItemRepository items;
    private final TenantRepository tenants;
    private final ZReportRepository reports;
    private final ObjectMapper json;

    public ZReportService(SaleRepository sales, SaleItemRepository items,
                          TenantRepository tenants, ZReportRepository reports,
                          ObjectMapper json) {
        this.sales = sales;
        this.items = items;
        this.tenants = tenants;
        this.reports = reports;
        this.json = json;
    }

    /**
     * Close (or re-close) a business day. Idempotent — replaces any prior
     * report for the same date so an owner can re-run after late sync.
     */
    @Transactional
    public ZReport close(UUID tenantId, LocalDate date) {
        Tenant t = tenants.findById(tenantId)
                .orElseThrow(() -> ApiException.notFound("Tenant not found."));
        ZoneId zone = ZoneId.of(t.getTimezone() == null ? "Africa/Harare" : t.getTimezone());

        var startUtc = ZonedDateTime.of(date.atStartOfDay(), zone).toInstant();
        var endUtc   = ZonedDateTime.of(date.plusDays(1).atStartOfDay(), zone).toInstant();

        List<Sale> dailySales = sales.findByTenantIdAndClientCreatedAtBetween(
                tenantId, startUtc, endUtc).stream()
                .filter(s -> "COMPLETED".equals(s.getStatus()))
                .toList();

        long gross = 0L, net = 0L, vat = 0L;
        Map<String, Long> byPayment = new LinkedHashMap<>();
        Map<String, Long> byVatClass = new LinkedHashMap<>();

        for (Sale s : dailySales) {
            gross += s.getTotalCents();
            net   += s.getSubtotalCents() == null ? 0 : s.getSubtotalCents();
            vat   += s.getVatCents() == null ? 0 : s.getVatCents();
            byPayment.merge(
                    s.getPaymentMethod() == null ? "UNKNOWN" : s.getPaymentMethod(),
                    s.getTotalCents(), Long::sum);
        }

        List<UUID> saleIds = dailySales.stream().map(Sale::getId).toList();
        if (!saleIds.isEmpty()) {
            for (SaleItem li : items.findBySaleIdIn(saleIds)) {
                String cls = li.getVatClass() == null ? "STANDARD" : li.getVatClass();
                long v = li.getVatCents() == null ? 0L : li.getVatCents();
                byVatClass.merge(cls, v, Long::sum);
            }
        }

        ZReport existing = reports.findByTenantIdAndBusinessDate(tenantId, date)
                .orElse(null);
        ZReport z = existing == null
                ? ZReport.builder().tenantId(tenantId).businessDate(date).build()
                : existing;

        z.setSalesCount(dailySales.size());
        z.setGrossCents(gross);
        z.setNetCents(net);
        z.setVatCents(vat);
        z.setByPayment(toJson(byPayment));
        z.setByVatClass(toJson(byVatClass));

        return reports.save(z);
    }

    @Transactional(readOnly = true)
    public List<ZReport> recent(UUID tenantId) {
        return reports.findTop30ByTenantIdOrderByBusinessDateDesc(tenantId);
    }

    @Transactional(readOnly = true)
    public ZReport get(UUID tenantId, LocalDate date) {
        return reports.findByTenantIdAndBusinessDate(tenantId, date)
                .orElseThrow(() -> ApiException.notFound("No Z-Report for that date."));
    }

    private String toJson(Object o) {
        try { return json.writeValueAsString(o); }
        catch (JsonProcessingException e) { return "{}"; }
    }
}
