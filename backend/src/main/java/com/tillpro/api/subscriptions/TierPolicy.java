package com.tillpro.api.subscriptions;

import com.tillpro.api.domain.Subscription;
import com.tillpro.api.repo.SubscriptionRepository;
import com.tillpro.api.security.TenantContext;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Component;

import java.time.temporal.ChronoUnit;

/**
 * Centralized feature-gating. Every tier limit lives here so the mobile
 * client can mirror it against `subscription.tier` from the JWT.
 */
@Component
public class TierPolicy {

    private final SubscriptionRepository subs;

    public TierPolicy(SubscriptionRepository subs) { this.subs = subs; }

    public int productLimit(Subscription.Tier t) {
        return switch (t) {
            case FREE -> 50;
            case STARTER -> 500;
            case PRO, BUSINESS -> Integer.MAX_VALUE;
        };
    }

    public int deviceLimit(Subscription.Tier t) {
        return switch (t) {
            case FREE -> 1;
            case STARTER -> 2;
            case PRO -> 5;
            case BUSINESS -> 10;
        };
    }

    public long historyDays(Subscription.Tier t) {
        return switch (t) {
            case FREE -> 7;
            case STARTER -> 90;
            case PRO, BUSINESS -> 3650; // ~10 years
        };
    }

    /** Advanced analytics (reorder predictions, basket co-purchase) are PRO+ only. */
    public boolean hasAdvancedAnalytics() {
        Subscription.Tier t = current().getTier();
        return t == Subscription.Tier.PRO || t == Subscription.Tier.BUSINESS;
    }

    public void assertProductCount(long countAfter) {
        Subscription s = current();
        int limit = productLimit(s.getTier());
        if (countAfter > limit) {
            throw ApiException.tierLimit(
                    "Plan %s is limited to %d products. Upgrade to add more."
                            .formatted(s.getTier(), limit));
        }
    }

    public void assertCanWrite() {
        Subscription s = current();
        if (s.getStatus() == Subscription.Status.CANCELED) {
            throw ApiException.paymentRequired("Subscription canceled. Please reactivate.");
        }
        // PAST_DUE gets a 7-day grace
        if (s.getStatus() == Subscription.Status.PAST_DUE
                && s.getUpdatedAt() != null
                && s.getUpdatedAt().isBefore(
                     java.time.Instant.now().minus(7, ChronoUnit.DAYS))) {
            throw ApiException.paymentRequired("Payment overdue. Please update billing.");
        }
    }

    public Subscription current() {
        return subs.findByTenantId(TenantContext.requireTenantId())
                .orElseThrow(() -> ApiException.notFound("No subscription on file."));
    }
}
