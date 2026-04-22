package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "fiscal_counters")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class FiscalCounter {
    @Id
    @Column(name = "tenant_id", columnDefinition = "uuid")
    private UUID tenantId;

    @Column(name = "next_value", nullable = false)
    private Long nextValue = 1L;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
