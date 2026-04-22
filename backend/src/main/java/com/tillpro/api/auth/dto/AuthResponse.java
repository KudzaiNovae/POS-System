package com.tillpro.api.auth.dto;

import java.util.UUID;

public record AuthResponse(
        UUID tenantId,
        UUID userId,
        String tier,
        String role,
        String token,
        String refreshToken,
        long expiresIn
) {}
