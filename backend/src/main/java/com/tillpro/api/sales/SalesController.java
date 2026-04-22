package com.tillpro.api.sales;

import com.tillpro.api.sales.dto.SaleDto;
import com.tillpro.api.security.TenantContext;
import com.tillpro.api.web.ApiException;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/sales")
public class SalesController {

    private final SalesService svc;

    public SalesController(SalesService svc) { this.svc = svc; }

    @PostMapping
    public SaleDto record(@Valid @RequestBody SaleDto dto) {
        return svc.record(TenantContext.requireTenantId(), dto);
    }

    @PostMapping("/{id}/void")
    public void voidSale(@PathVariable UUID id) {
        if (!"OWNER".equals(TenantContext.getRole())
                && !"MANAGER".equals(TenantContext.getRole())) {
            throw ApiException.forbidden("Only owners/managers can void sales.");
        }
        svc.voidSale(TenantContext.requireTenantId(), id);
    }

    @GetMapping
    public List<SaleDto> list(
            @RequestParam(required = false) Instant from,
            @RequestParam(required = false) Instant to) {
        Instant f = from != null ? from : Instant.now().minus(30, ChronoUnit.DAYS);
        Instant t = to != null ? to : Instant.now();
        return svc.between(TenantContext.requireTenantId(), f, t);
    }

    @GetMapping("/{id}")
    public SaleDto get(@PathVariable UUID id) {
        return svc.get(TenantContext.requireTenantId(), id);
    }
}
