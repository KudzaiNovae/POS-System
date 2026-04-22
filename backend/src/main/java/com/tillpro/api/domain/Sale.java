package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "sales")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Sale {
    @Id
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(name = "cashier_id")
    private UUID cashierId;

    @Column(name = "customer_id")
    private UUID customerId;

    @Column(name = "subtotal_cents", nullable = false)
    private Long subtotalCents = 0L;

    @Column(name = "vat_cents", nullable = false)
    private Long vatCents = 0L;

    @Column(name = "tax_cents", nullable = false)
    private Long taxCents = 0L;

    @Column(name = "total_cents", nullable = false)
    private Long totalCents;

    @Column(name = "payment_method", nullable = false)
    private String paymentMethod;

    @Column(name = "payment_ref")
    private String paymentRef;

    @Column(nullable = false)
    private String status = "COMPLETED";

    // --- ZIMRA fiscal fields ---
    @Column(name = "fiscal_receipt_no", unique = true)
    private String fiscalReceiptNo;

    @Column(name = "fiscal_status", nullable = false)
    private String fiscalStatus = "PENDING";

    @Column(name = "fiscal_reference")
    private String fiscalReference;

    @Column(name = "fiscal_qr_payload", columnDefinition = "text")
    private String fiscalQrPayload;

    @Column(name = "customer_tin")
    private String customerTin;

    @Column(name = "customer_name")
    private String customerName;

    @Column(name = "client_created_at", nullable = false)
    private Instant clientCreatedAt;

    @CreationTimestamp
    @Column(name = "server_received_at", updatable = false)
    private Instant serverReceivedAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
