import '../db/local_db.dart';

/// Client-side feature gating that mirrors the backend TierPolicy.
/// If you change limits here, update `backend/.../TierPolicy.java` too.
class FeatureGate {
  static String get tier => LocalDb.tier;

  static int get productLimit => switch (tier) {
        'FREE' => 50,
        'STARTER' => 500,
        _ => 1 << 30,
      };

  static int get deviceLimit => switch (tier) {
        'FREE' => 1,
        'STARTER' => 2,
        'PRO' => 5,
        _ => 10,
      };

  static int get historyDays => switch (tier) {
        'FREE' => 7,
        'STARTER' => 90,
        _ => 3650,
      };

  static bool get canExportCsv => tier != 'FREE';
  static bool get canViewMultiBranch => tier == 'BUSINESS';
  static bool get canUseLowStockAlerts => tier == 'PRO' || tier == 'BUSINESS';

  /// Whether the app should allow a new product to be added locally.
  /// We mirror the server: the real enforcement is at /sync/push, but we
  /// pre-empt it here to avoid creating products the server will reject.
  static bool canAddProduct(int currentCount) =>
      currentCount + 1 <= productLimit;
}
