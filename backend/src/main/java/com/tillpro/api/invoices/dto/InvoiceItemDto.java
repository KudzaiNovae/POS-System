package com.tillpro.api.invoices.dto;

import com.tillpro.api.domain.InvoiceItem;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record InvoiceItemDto(
        @NotNull UUID id,
        UUID productId,
        @NotBlank String description,
        @NotNull BigDecimal qty,
        String unit,
        @NotNull Long unitPriceCents,
        Long discountCents,
        Long lineTotalCents,
        String vatClass,
        Long netCents,
        Long vatCents
) {
    public static InvoiceItemDto from(InvoiceItem i) {
        return new InvoiceItemDto(
                i.getId(), i.getProductId(), i.getDescription(),
                i.getQty(), i.getUnit(),
                i.getUnitPriceCents(), i.getDiscountCents(), i.getLineTotalCents(),
                i.getVatClass(), i.getNetCents(), i.getVatCents());
    }
}
