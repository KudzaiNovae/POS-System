package com.tillpro.api.auth;

import com.tillpro.api.auth.dto.*;
import com.tillpro.api.domain.*;
import com.tillpro.api.repo.SubscriptionRepository;
import com.tillpro.api.repo.TenantRepository;
import com.tillpro.api.repo.UserRepository;
import com.tillpro.api.security.JwtService;
import com.tillpro.api.web.ApiException;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
public class AuthService {
    private final TenantRepository tenants;
    private final UserRepository users;
    private final SubscriptionRepository subs;
    private final PasswordEncoder encoder;
    private final JwtService jwt;

    public AuthService(TenantRepository tenants, UserRepository users,
                       SubscriptionRepository subs, PasswordEncoder encoder,
                       JwtService jwt) {
        this.tenants = tenants;
        this.users = users;
        this.subs = subs;
        this.encoder = encoder;
        this.jwt = jwt;
    }

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        if (users.existsByEmail(req.ownerEmail())) {
            throw ApiException.validation("Email already registered.");
        }

        Tenant tenant = Tenant.builder()
                .name(req.businessName())
                .countryCode(req.countryCode().toUpperCase())
                .currency(req.currency().toUpperCase())
                .timezone(defaultTimezoneFor(req.countryCode()))
                .build();
        tenant = tenants.save(tenant);

        User user = User.builder()
                .tenantId(tenant.getId())
                .email(req.ownerEmail().toLowerCase().trim())
                .phone(req.ownerPhone())
                .passwordHash(encoder.encode(req.password()))
                .role(User.Role.OWNER)
                .build();
        user = users.save(user);

        Subscription sub = Subscription.builder()
                .tenantId(tenant.getId())
                .tier(Subscription.Tier.FREE)
                .status(Subscription.Status.TRIALING)
                .currentPeriodEnd(Instant.now().plus(14, ChronoUnit.DAYS))
                .build();
        subs.save(sub);

        return buildAuth(user, tenant, sub);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest req) {
        User user = users.findByEmail(req.email().toLowerCase().trim())
                .orElseThrow(() -> ApiException.unauth("Invalid credentials."));
        if (!encoder.matches(req.password(), user.getPasswordHash())) {
            throw ApiException.unauth("Invalid credentials.");
        }
        Tenant tenant = tenants.findById(user.getTenantId()).orElseThrow();
        Subscription sub = subs.findByTenantId(tenant.getId()).orElseThrow();
        return buildAuth(user, tenant, sub);
    }

    @Transactional(readOnly = true)
    public AuthResponse refresh(RefreshRequest req) {
        try {
            Claims c = jwt.parse(req.refreshToken());
            if (!"refresh".equals(c.get("typ", String.class))) {
                throw ApiException.unauth("Invalid token type.");
            }
            UUID userId = UUID.fromString(c.getSubject());
            User user = users.findById(userId).orElseThrow(() -> ApiException.unauth("User not found."));
            Tenant tenant = tenants.findById(user.getTenantId()).orElseThrow();
            Subscription sub = subs.findByTenantId(tenant.getId()).orElseThrow();
            return buildAuth(user, tenant, sub);
        } catch (JwtException ex) {
            throw ApiException.unauth("Invalid refresh token.");
        }
    }

    private AuthResponse buildAuth(User user, Tenant tenant, Subscription sub) {
        String access = jwt.issueAccess(user.getId(), tenant.getId(),
                sub.getTier().name(), user.getRole().name());
        String refresh = jwt.issueRefresh(user.getId(), tenant.getId());
        return new AuthResponse(
                tenant.getId(), user.getId(),
                sub.getTier().name(), user.getRole().name(),
                access, refresh, jwt.getExpirationSeconds());
    }

    private String defaultTimezoneFor(String countryCode) {
        return switch (countryCode.toUpperCase()) {
            case "KE", "TZ", "UG", "RW" -> "Africa/Nairobi";
            case "NG", "GH", "CM"        -> "Africa/Lagos";
            case "ZW"                    -> "Africa/Harare";
            case "ZA", "BW"              -> "Africa/Johannesburg";
            default                      -> "UTC";
        };
    }
}
