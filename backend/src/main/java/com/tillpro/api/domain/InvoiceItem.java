package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "invoice_items")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class InvoiceItem {
    @Id
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    // Nullable: services / custom work with no catalog entry.
    @Column(name = "product_id")
    private UUID productId;

    @Column(nullable = false, length = 400)
    private String description;

    @Column(nullable = false, precision = 14, scale = 3)
    private BigDecimal qty;

    @Column(nullable = false)
    private String unit = "pc";

    @Column(name = "unit_price_cents", nullable = false)
    private Long unitPriceCents;

    @Column(name = "discount_cents", nullable = false)
    private Long discountCents = 0L;

    @Column(name = "line_total_cents", nullable = false)
    private Long lineTotalCents;

    @Column(name = "vat_class", nullable = false)
    private String vatClass = "STANDARD";

    @Column(name = "net_cents", nullable = false)
    private Long netCents = 0L;

    @Column(name = "vat_cents", nullable = false)
    private Long vatCents = 0L;
}
