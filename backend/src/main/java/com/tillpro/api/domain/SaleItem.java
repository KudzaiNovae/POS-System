package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "sale_items")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SaleItem {
    @Id
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "sale_id", nullable = false)
    private UUID saleId;

    @Column(name = "product_id", nullable = false)
    private UUID productId;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(name = "name_snapshot", nullable = false)
    private String nameSnapshot;

    @Column(nullable = false, precision = 14, scale = 3)
    private BigDecimal qty;

    @Column(name = "unit_price_cents", nullable = false)
    private Long unitPriceCents;

    @Column(name = "line_total_cents", nullable = false)
    private Long lineTotalCents;

    @Column(name = "vat_class", nullable = false)
    private String vatClass = "STANDARD";

    @Column(name = "net_cents", nullable = false)
    private Long netCents = 0L;

    @Column(name = "vat_cents", nullable = false)
    private Long vatCents = 0L;
}
