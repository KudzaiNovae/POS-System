package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "products",
       uniqueConstraints = @UniqueConstraint(columnNames = {"tenant_id", "sku"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Product {
    @Id
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    private String sku;

    @Column(nullable = false)
    private String name;

    private String barcode;

    @Column(name = "price_cents", nullable = false)
    private Long priceCents;

    @Column(name = "cost_cents", nullable = false)
    private Long costCents = 0L;

    @Column(name = "stock_qty", nullable = false, precision = 14, scale = 3)
    private BigDecimal stockQty = BigDecimal.ZERO;

    @Column(name = "reorder_level", nullable = false, precision = 14, scale = 3)
    private BigDecimal reorderLevel = BigDecimal.ZERO;

    @Column(nullable = false)
    private String unit = "pc";

    @Column(name = "vat_class", nullable = false)
    private String vatClass = "STANDARD";

    @Column(nullable = false)
    private Boolean deleted = false;

    @Version
    private Long version;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
