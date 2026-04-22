package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "z_reports",
       uniqueConstraints = @UniqueConstraint(columnNames = {"tenant_id", "business_date"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ZReport {
    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(name = "business_date", nullable = false)
    private LocalDate businessDate;

    @Column(name = "sales_count", nullable = false)
    private Integer salesCount;

    @Column(name = "gross_cents", nullable = false)
    private Long grossCents;

    @Column(name = "net_cents", nullable = false)
    private Long netCents;

    @Column(name = "vat_cents", nullable = false)
    private Long vatCents;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "by_payment", nullable = false, columnDefinition = "jsonb")
    private String byPayment;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "by_vat_class", nullable = false, columnDefinition = "jsonb")
    private String byVatClass;

    @CreationTimestamp
    @Column(name = "closed_at", updatable = false)
    private Instant closedAt;
}
