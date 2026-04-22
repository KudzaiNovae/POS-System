package com.tillpro.api.tax;

/**
 * ZIMRA VAT classes. Basis-points keep integer math deterministic so
 * server-computed VAT matches the client receipt to the cent.
 */
public enum VatClass {
    STANDARD(1500, "S", "15%"),
    ZERO    (   0, "Z", "0%"),
    EXEMPT  (   0, "E", "Exempt"),
    LUXURY  (2500, "L", "25%");

    private final int bps;
    private final String code;
    private final String label;

    VatClass(int bps, String code, String label) {
        this.bps = bps;
        this.code = code;
        this.label = label;
    }

    public int bps()     { return bps; }
    public String code() { return code; }
    public String label(){ return label; }
}
