package com.tillpro.api.sales.dto;

import com.tillpro.api.domain.SaleItem;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record SaleItemDto(
        @NotNull UUID id,
        @NotNull UUID productId,
        @NotNull String nameSnapshot,
        @NotNull BigDecimal qty,
        @NotNull Long unitPriceCents,
        @NotNull Long lineTotalCents,
        String vatClass,
        Long netCents,
        Long vatCents
) {
    public static SaleItemDto from(SaleItem i) {
        return new SaleItemDto(
                i.getId(), i.getProductId(), i.getNameSnapshot(),
                i.getQty(), i.getUnitPriceCents(), i.getLineTotalCents(),
                i.getVatClass(), i.getNetCents(), i.getVatCents());
    }
}
