package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "invoice_counters")
@IdClass(InvoiceCounter.Key.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class InvoiceCounter {
    @Id
    @Column(name = "tenant_id", columnDefinition = "uuid")
    private UUID tenantId;

    @Id
    private Integer year;

    @Id
    private String kind;

    @Column(name = "next_value", nullable = false)
    private Long nextValue = 1L;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Key implements Serializable {
        private UUID tenantId;
        private Integer year;
        private String kind;

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key k)) return false;
            return Objects.equals(tenantId, k.tenantId)
                    && Objects.equals(year, k.year)
                    && Objects.equals(kind, k.kind);
        }

        @Override
        public int hashCode() { return Objects.hash(tenantId, year, kind); }
    }
}
