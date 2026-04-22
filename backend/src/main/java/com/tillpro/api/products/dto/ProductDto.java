package com.tillpro.api.products.dto;

import com.tillpro.api.domain.Product;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record ProductDto(
        @NotNull UUID id,
        String sku,
        @NotBlank String name,
        String barcode,
        @NotNull @PositiveOrZero Long priceCents,
        Long costCents,
        BigDecimal stockQty,
        BigDecimal reorderLevel,
        String unit,
        String vatClass,
        Boolean deleted,
        Long version,
        Instant updatedAt
) {
    public static ProductDto from(Product p) {
        return new ProductDto(
                p.getId(), p.getSku(), p.getName(), p.getBarcode(),
                p.getPriceCents(), p.getCostCents(),
                p.getStockQty(), p.getReorderLevel(),
                p.getUnit(), p.getVatClass(), p.getDeleted(),
                p.getVersion(), p.getUpdatedAt());
    }
}
