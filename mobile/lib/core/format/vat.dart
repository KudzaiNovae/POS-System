/// VAT (Value Added Tax) classes used across Zimbabwe.
///
/// ZIMRA currently enforces:
///   STANDARD: 15%  — most goods & services
///   ZERO:      0%  — exports, basic foods, specified medical supplies
///   EXEMPT:   n/a — financial services, education, residential rent
///
/// A fourth class LUXURY (25%) applies to a narrow list (tobacco, alcohol —
/// actually excise + VAT). We model it as data; the tenant sets per-product.
enum VatClass {
  standard,
  zero,
  exempt,
  luxury;

  /// Rate in basis points so we can do integer math (no FP rounding).
  /// 15.00% = 1500 bps.
  int get bps => switch (this) {
        VatClass.standard => 1500,
        VatClass.luxury => 2500,
        VatClass.zero => 0,
        VatClass.exempt => 0,
      };

  String get label => switch (this) {
        VatClass.standard => 'STANDARD (15%)',
        VatClass.zero => 'ZERO (0%)',
        VatClass.exempt => 'EXEMPT',
        VatClass.luxury => 'LUXURY (25%)',
      };

  String get code => switch (this) {
        VatClass.standard => 'S',
        VatClass.zero => 'Z',
        VatClass.exempt => 'E',
        VatClass.luxury => 'L',
      };

  static VatClass fromName(String? s) => switch (s?.toUpperCase()) {
        'STANDARD' => VatClass.standard,
        'ZERO' => VatClass.zero,
        'EXEMPT' => VatClass.exempt,
        'LUXURY' => VatClass.luxury,
        _ => VatClass.standard,
      };
}

/// Pure functions. No dependency on Hive / services — unit-testable.
class VatEngine {
  /// VAT on an inclusive line total. Returns net + vat in cents.
  /// Most SSA shops quote prices VAT-inclusive so we default to that here.
  static ({int net, int vat}) splitInclusive(int grossCents, VatClass cls) {
    if (cls == VatClass.exempt || cls == VatClass.zero) {
      return (net: grossCents, vat: 0);
    }
    // gross = net * (1 + bps/10000); net = gross * 10000 / (10000 + bps)
    final denom = 10000 + cls.bps;
    final net = (grossCents * 10000) ~/ denom;
    final vat = grossCents - net;
    return (net: net, vat: vat);
  }

  /// If a shop chooses to quote exclusive prices, compute the add-on.
  static ({int gross, int vat}) applyExclusive(int netCents, VatClass cls) {
    if (cls == VatClass.exempt || cls == VatClass.zero) {
      return (gross: netCents, vat: 0);
    }
    final vat = (netCents * cls.bps) ~/ 10000;
    return (gross: netCents + vat, vat: vat);
  }
}
