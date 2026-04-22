package com.tillpro.api.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "tenants")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Tenant {
    @Id
    @GeneratedValue
    @Column(columnDefinition = "uuid")
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(name = "trade_name")
    private String tradeName;

    private String address;

    @Column(name = "country_code", nullable = false, length = 2)
    private String countryCode;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(nullable = false)
    private String timezone;

    // --- ZIMRA fiscal identity ---
    private String tin;

    @Column(name = "vat_number")
    private String vatNumber;

    @Column(name = "fiscal_device_id")
    private String fiscalDeviceId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}
