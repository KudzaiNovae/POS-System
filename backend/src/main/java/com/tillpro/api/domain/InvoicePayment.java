package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "invoice_payments")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class InvoicePayment {
    @Id
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(name = "paid_at", nullable = false)
    private Instant paidAt;

    @Column(name = "amount_cents", nullable = false)
    private Long amountCents;

    @Column(nullable = false)
    private String method; // CASH|ECOCASH|ONEMONEY|INNBUCKS|ZIPIT|CARD|BANK_TRANSFER

    @Column
    private String reference;

    @Column(name = "recorded_by")
    private UUID recordedBy;
}
