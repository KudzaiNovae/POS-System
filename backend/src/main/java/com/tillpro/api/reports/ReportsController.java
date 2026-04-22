package com.tillpro.api.reports;

import com.tillpro.api.repo.ProductRepository;
import com.tillpro.api.repo.SaleItemRepository;
import com.tillpro.api.repo.SaleRepository;
import com.tillpro.api.security.TenantContext;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;

@RestController
@RequestMapping("/api/v1/reports")
public class ReportsController {

    private final SaleRepository sales;
    private final SaleItemRepository items;
    private final ProductRepository products;

    public ReportsController(SaleRepository sales, SaleItemRepository items, ProductRepository products) {
        this.sales = sales;
        this.items = items;
        this.products = products;
    }

    @GetMapping("/dashboard")
    public Map<String, Object> dashboard(
            @RequestParam(required = false, defaultValue = "today") String range) {
        UUID tenantId = TenantContext.requireTenantId();
        Instant to = Instant.now();
        Instant from = switch (range) {
            case "7d"  -> to.minus(7, ChronoUnit.DAYS);
            case "30d" -> to.minus(30, ChronoUnit.DAYS);
            default    -> to.truncatedTo(ChronoUnit.DAYS);
        };

        long count = sales.countSince(tenantId, from);
        long revenue = sales.sumRevenueBetween(tenantId, from, to);
        var top = items.topProducts(tenantId, from, to).stream().limit(5).toList();

        var lowStock = products.findByTenantIdAndDeletedFalse(tenantId).stream()
                .filter(p -> p.getStockQty().compareTo(p.getReorderLevel()) <= 0
                          && p.getReorderLevel().compareTo(BigDecimal.ZERO) > 0)
                .limit(20)
                .map(p -> Map.of(
                        "productId", p.getId(),
                        "name", p.getName(),
                        "stockQty", p.getStockQty(),
                        "reorderLevel", p.getReorderLevel()))
                .toList();

        return Map.of(
                "salesCount", count,
                "revenueCents", revenue,
                "topProducts", top,
                "lowStock", lowStock,
                "range", range,
                "from", from.toString(),
                "to", to.toString()
        );
    }
}
