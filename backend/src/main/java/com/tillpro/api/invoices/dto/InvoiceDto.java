package com.tillpro.api.invoices.dto;

import com.tillpro.api.domain.Invoice;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record InvoiceDto(
        @NotNull UUID id,
        String number,
        String kind,              // INVOICE | QUOTE | PROFORMA | CREDIT_NOTE
        UUID parentInvoiceId,
        UUID customerId,
        String customerName,
        String customerTin,
        String customerEmail,
        String customerAddress,
        String status,
        @NotNull LocalDate issueDate,
        LocalDate dueDate,
        String currency,
        Long subtotalCents,
        Long vatCents,
        Long discountCents,
        Long totalCents,
        Long paidCents,
        Long balanceCents,
        String notes,
        String terms,
        String fiscalReceiptNo,
        String fiscalStatus,
        @NotNull Instant clientCreatedAt,
        @NotEmpty @Valid List<InvoiceItemDto> items,
        List<InvoicePaymentDto> payments
) {
    public static InvoiceDto from(Invoice inv, List<InvoiceItemDto> items,
                                  List<InvoicePaymentDto> payments) {
        return new InvoiceDto(
                inv.getId(), inv.getNumber(), inv.getKind(), inv.getParentInvoiceId(),
                inv.getCustomerId(), inv.getCustomerName(), inv.getCustomerTin(),
                inv.getCustomerEmail(), inv.getCustomerAddress(),
                inv.getStatus(), inv.getIssueDate(), inv.getDueDate(), inv.getCurrency(),
                inv.getSubtotalCents(), inv.getVatCents(), inv.getDiscountCents(),
                inv.getTotalCents(), inv.getPaidCents(), inv.getBalanceCents(),
                inv.getNotes(), inv.getTerms(),
                inv.getFiscalReceiptNo(), inv.getFiscalStatus(),
                inv.getClientCreatedAt(), items, payments);
    }
}
