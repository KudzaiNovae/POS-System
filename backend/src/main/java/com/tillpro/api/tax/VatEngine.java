package com.tillpro.api.tax;

/**
 * Pure VAT math. Uses long cents and integer division so server output
 * matches the Flutter client's VatEngine bit-for-bit.
 */
public final class VatEngine {
    private VatEngine() {}

    public record Split(long netCents, long vatCents) {}

    public static Split splitInclusive(long grossCents, VatClass cls) {
        if (cls == VatClass.EXEMPT || cls == VatClass.ZERO) {
            return new Split(grossCents, 0);
        }
        long denom = 10_000L + cls.bps();
        long net = Math.floorDiv(grossCents * 10_000L, denom);
        long vat = grossCents - net;
        return new Split(net, vat);
    }

    public static Split applyExclusive(long netCents, VatClass cls) {
        if (cls == VatClass.EXEMPT || cls == VatClass.ZERO) {
            return new Split(netCents, 0);
        }
        long vat = Math.floorDiv(netCents * cls.bps(), 10_000L);
        return new Split(netCents + vat, vat);
    }
}
