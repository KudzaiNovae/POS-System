package com.tillpro.api.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank String businessName,
        @NotBlank @Size(min = 2, max = 2) String countryCode,
        @NotBlank @Size(min = 3, max = 3) String currency,
        @Email @NotBlank String ownerEmail,
        String ownerPhone,
        @NotBlank @Size(min = 8) String password
) {}
