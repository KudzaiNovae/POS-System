import 'package:intl/intl.dart';

import '../db/local_db.dart';

/// Currency formatting driven by the tenant's currency code stored in meta.
///
/// In Zimbabwe shops dual-price in USD and ZWG. We render USD as "US$" so it
/// is unambiguously distinguishable from the historical ZWL "$" and the new
/// ZWG notation — which matters because owners reconcile tills in both.
class Money {
  /// Format an amount using the tenant's currency code.
  static String format(num amount) {
    final code = LocalDb.currency;
    final f = NumberFormat.currency(
      symbol: _symbolFor(code),
      decimalDigits: _decimalsFor(code),
    );
    return f.format(amount);
  }

  /// Convenience for the most common call-site: `Money.cents(priceCents)`.
  static String cents(int cents) => format(cents / 100.0);

  /// Display symbol — ISO code by default, with a few locally-recognised
  /// overrides for currencies used in Zimbabwe.
  static String _symbolFor(String code) => switch (code) {
        'USD' => r'US$ ',
        'ZWG' => 'ZWG ',
        'ZAR' => 'R ',
        _ => '$code ',
      };

  static int _decimalsFor(String code) {
    // Zero-decimal currencies per ISO 4217. KES/UGX/RWF are technically
    // 2-decimal but in practice shops price in whole units.
    const zeroDecimal = {
      'UGX', 'RWF', 'KES', 'TZS', 'BIF', 'DJF', 'GNF', 'XOF', 'XAF',
      'JPY', 'KRW', 'CLP', 'VND', 'ISK',
    };
    return zeroDecimal.contains(code) ? 0 : 2;
  }
}
