package com.tillpro.api.sales.dto;

import com.tillpro.api.domain.Sale;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record SaleDto(
        @NotNull UUID id,
        UUID cashierId,
        UUID customerId,
        @NotNull Long totalCents,
        Long subtotalCents,
        Long vatCents,
        Long taxCents,
        @NotNull String paymentMethod,
        String paymentRef,
        String status,
        String customerTin,
        String customerName,
        String fiscalReceiptNo,
        String fiscalStatus,
        String fiscalReference,
        String fiscalQrPayload,
        @NotNull Instant clientCreatedAt,
        @NotEmpty @Valid List<SaleItemDto> items
) {
    public static SaleDto from(Sale s, List<SaleItemDto> items) {
        return new SaleDto(
                s.getId(), s.getCashierId(), s.getCustomerId(),
                s.getTotalCents(), s.getSubtotalCents(), s.getVatCents(), s.getTaxCents(),
                s.getPaymentMethod(), s.getPaymentRef(), s.getStatus(),
                s.getCustomerTin(), s.getCustomerName(),
                s.getFiscalReceiptNo(), s.getFiscalStatus(),
                s.getFiscalReference(), s.getFiscalQrPayload(),
                s.getClientCreatedAt(), items);
    }
}
