package com.tillpro.api.analytics;

import com.tillpro.api.security.TenantContext;
import com.tillpro.api.subscriptions.TierPolicy;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/analytics")
public class AnalyticsController {

    private final AnalyticsService svc;
    private final TierPolicy tier;

    public AnalyticsController(AnalyticsService svc, TierPolicy tier) {
        this.svc = svc;
        this.tier = tier;
    }

    /**
     * Full dashboard payload. `days` selects the window (1..365). Advanced
     * insights (reorder predictions, basket co-purchase) are feature-gated
     * to PRO/BUSINESS tiers via TierPolicy.
     */
    @GetMapping("/dashboard")
    public Map<String, Object> dashboard(
            @RequestParam(required = false, defaultValue = "30") int days) {
        Map<String, Object> out = svc.dashboard(TenantContext.requireTenantId(), days);
        if (!tier.hasAdvancedAnalytics()) {
            // Downgrade: strip premium panels so free-tier merchants see an
            // upgrade hint instead of the insight.
            out.remove("reorderPredictions");
            out.remove("basketCoPurchase");
            out.put("advancedAnalyticsLocked", true);
        }
        return out;
    }
}
