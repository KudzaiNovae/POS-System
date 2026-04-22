package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "invoices")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Invoice {
    @Id
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(unique = true)
    private String number;

    @Column(nullable = false)
    private String kind = "INVOICE"; // INVOICE | QUOTE | PROFORMA | CREDIT_NOTE

    @Column(name = "parent_invoice_id")
    private UUID parentInvoiceId;

    @Column(name = "customer_id")
    private UUID customerId;

    @Column(name = "customer_name")
    private String customerName;

    @Column(name = "customer_tin")
    private String customerTin;

    @Column(name = "customer_email")
    private String customerEmail;

    @Column(name = "customer_address", columnDefinition = "text")
    private String customerAddress;

    @Column(nullable = false)
    private String status = "DRAFT"; // DRAFT|SENT|PARTIAL|PAID|OVERDUE|VOIDED

    @Column(name = "issue_date", nullable = false)
    private LocalDate issueDate;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(nullable = false)
    private String currency = "USD";

    @Column(name = "subtotal_cents", nullable = false)
    private Long subtotalCents = 0L;

    @Column(name = "vat_cents", nullable = false)
    private Long vatCents = 0L;

    @Column(name = "discount_cents", nullable = false)
    private Long discountCents = 0L;

    @Column(name = "total_cents", nullable = false)
    private Long totalCents = 0L;

    @Column(name = "paid_cents", nullable = false)
    private Long paidCents = 0L;

    @Column(name = "balance_cents", nullable = false)
    private Long balanceCents = 0L;

    @Column(columnDefinition = "text")
    private String notes;

    @Column(columnDefinition = "text")
    private String terms;

    @Column(name = "fiscal_receipt_no")
    private String fiscalReceiptNo;

    @Column(name = "fiscal_status")
    private String fiscalStatus;

    @Column(name = "client_created_at", nullable = false)
    private Instant clientCreatedAt;

    @CreationTimestamp
    @Column(name = "server_received_at", updatable = false)
    private Instant serverReceivedAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
