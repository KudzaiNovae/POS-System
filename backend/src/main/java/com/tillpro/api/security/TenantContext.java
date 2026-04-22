package com.tillpro.api.security;

import java.util.UUID;

/**
 * Holds the current request's tenant id so services/repositories can filter
 * queries without plumbing it through every method signature. Set by the
 * JWT filter, cleared after the request completes.
 */
public final class TenantContext {
    private static final ThreadLocal<UUID> TENANT = new ThreadLocal<>();
    private static final ThreadLocal<UUID> USER = new ThreadLocal<>();
    private static final ThreadLocal<String> TIER = new ThreadLocal<>();
    private static final ThreadLocal<String> ROLE = new ThreadLocal<>();

    private TenantContext() {}

    public static void set(UUID tenantId, UUID userId, String tier, String role) {
        TENANT.set(tenantId);
        USER.set(userId);
        TIER.set(tier);
        ROLE.set(role);
    }

    public static UUID getTenantId() { return TENANT.get(); }
    public static UUID getUserId()   { return USER.get(); }
    public static String getTier()   { return TIER.get(); }
    public static String getRole()   { return ROLE.get(); }

    public static UUID requireTenantId() {
        UUID t = TENANT.get();
        if (t == null) throw new IllegalStateException("No tenant in context");
        return t;
    }

    public static void clear() {
        TENANT.remove();
        USER.remove();
        TIER.remove();
        ROLE.remove();
    }
}
