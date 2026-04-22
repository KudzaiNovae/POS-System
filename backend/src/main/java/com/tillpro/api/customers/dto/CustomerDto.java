package com.tillpro.api.customers.dto;

import com.tillpro.api.domain.Customer;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.util.UUID;

public record CustomerDto(
        @NotNull UUID id,
        @NotBlank String name,
        String phone,
        String email,
        String tin,
        Long balanceCents,
        Instant createdAt,
        Instant updatedAt
) {
    public static CustomerDto from(Customer c) {
        return new CustomerDto(
                c.getId(), c.getName(), c.getPhone(), c.getEmail(),
                c.getTin(), c.getBalanceCents(),
                c.getCreatedAt(), c.getUpdatedAt());
    }
}
