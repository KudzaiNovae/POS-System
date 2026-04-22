package com.tillpro.api.subscriptions;

import com.tillpro.api.domain.Subscription;
import com.tillpro.api.repo.SubscriptionRepository;
import com.tillpro.api.security.TenantContext;
import com.tillpro.api.web.ApiException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Minimal subscription management. In production, EcoCash and OneMoney
 * USSD/push, Stripe, and card acquirer integrations live here. For the MVP
 * scaffold we expose a "mock checkout" endpoint that immediately upgrades
 * the tenant so we can test feature gating end-to-end.
 */
@RestController
@RequestMapping("/api/v1/subscriptions")
public class SubscriptionController {

    private static final Set<String> SUPPORTED_PROVIDERS = Set.of(
            "ecocash", "onemoney", "mpesa", "mtn_momo", "flutterwave", "stripe");
    private static final Set<Subscription.Tier> UPGRADABLE_TIERS = new HashSet<>(Arrays.asList(
            Subscription.Tier.STARTER, Subscription.Tier.PRO, Subscription.Tier.BUSINESS));

    private final SubscriptionRepository repo;

    public SubscriptionController(SubscriptionRepository repo) { this.repo = repo; }

    @GetMapping("/me")
    public Map<String, Object> me() {
        Subscription s = repo.findByTenantId(TenantContext.requireTenantId())
                .orElseThrow(() -> ApiException.notFound("No subscription."));
        return Map.of(
                "tier", s.getTier().name(),
                "status", s.getStatus().name(),
                "currentPeriodEnd", s.getCurrentPeriodEnd().toString(),
                "provider", s.getProvider() == null ? "" : s.getProvider()
        );
    }

    @PostMapping("/checkout")
        public Map<String, Object> checkout(@Valid @RequestBody CheckoutRequest req) {
        UUID tenantId = TenantContext.requireTenantId();
        Subscription s = repo.findByTenantId(tenantId)
                .orElseThrow(() -> ApiException.notFound("No subscription."));
                Subscription.Tier tier = parseTier(req.tier());
                if (!UPGRADABLE_TIERS.contains(tier)) {
                        throw ApiException.validation("Checkout is only available for paid tiers.");
                }
                String provider = normalizeProvider(req.provider());

                String checkoutId = UUID.randomUUID().toString();
                // Production integrations will replace this immediate activation path.
                // For now we still validate the request and persist a clear checkout ref.
                s.setTier(tier);
        s.setStatus(Subscription.Status.ACTIVE);
                s.setProvider(provider);
                s.setExternalRef(checkoutId);
        s.setCurrentPeriodEnd(Instant.now().plus(30, ChronoUnit.DAYS));
        repo.save(s);
                return Map.of(
                                "status", s.getStatus().name(),
                                "tier", s.getTier().name(),
                                "provider", s.getProvider(),
                                "checkoutId", checkoutId,
                                "currentPeriodEnd", s.getCurrentPeriodEnd().toString());
    }

    @PostMapping("/webhook/{provider}")
    public Map<String, String> webhook(@PathVariable String provider,
                                       @RequestBody Map<String, Object> payload) {
                String normalizedProvider = normalizeProvider(provider);
                return Map.of("ack", "ok", "provider", normalizedProvider);
    }

        public record CheckoutRequest(
                        @NotBlank String tier,
                        @NotBlank String provider,
                        @NotBlank String phone) {}

        private Subscription.Tier parseTier(String tier) {
                try {
                        return Subscription.Tier.valueOf(tier.toUpperCase());
                } catch (IllegalArgumentException ex) {
                        throw ApiException.validation("Unsupported tier: " + tier);
                }
        }

        private String normalizeProvider(String provider) {
                if (provider == null || provider.isBlank()) {
                        throw ApiException.validation("Provider is required.");
                }
                String normalized = provider.trim().toLowerCase();
                if (!SUPPORTED_PROVIDERS.contains(normalized)) {
                        throw ApiException.validation("Unsupported payment provider: " + provider);
                }
                return normalized;
        }
}
