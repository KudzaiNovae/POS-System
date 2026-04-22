package com.tillpro.api.invoices.dto;

import com.tillpro.api.domain.InvoicePayment;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.Instant;
import java.util.UUID;

public record InvoicePaymentDto(
        UUID id,
        @NotNull @Positive Long amountCents,
        @NotBlank String method,
        String reference,
        Instant paidAt
) {
    public static InvoicePaymentDto from(InvoicePayment p) {
        return new InvoicePaymentDto(
                p.getId(), p.getAmountCents(), p.getMethod(),
                p.getReference(), p.getPaidAt());
    }
}
