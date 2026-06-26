import '../di/service_locator.dart';
import 'feature_catalog.dart';

/// The plan gate — the third access check, beside [RestaurantSession.canAccess]
/// (role) and [LicenseStore.isLicensed] (license validity). Reads the live,
/// server-driven plan from the active license and answers Free/Premium questions.
///
/// Read any getter inside an [Observer] to react when the server flips the plan.
class PlanGate {
  PlanGate._();

  /// True when the active license is Premium, or a trial (trials get Premium).
  static bool get isPremium {
    final info = licenseStore.licenseInfo;
    if (info == null) return false;
    if (info.isTrial) return true;
    return info.planName.trim().toLowerCase() == 'premium';
  }

  static bool get isFree => !isPremium;

  /// G1 — whole-feature lock. Returns true if [feature] is usable on this plan.
  static bool allows(String feature) =>
      isPremium || !FeatureCatalog.premiumOnly.contains(feature);

  /// G2 — count cap for [key]; null = unlimited (Premium, or an uncapped key).
  static int? limitFor(String key) =>
      isPremium ? null : FeatureCatalog.freeLimits[key];

  /// True if one more item can be added given [currentCount].
  static bool canAddMore(String key, int currentCount) {
    final limit = limitFor(key);
    return limit == null || currentCount < limit;
  }

  /// G3 — history window in days; null = unlimited.
  static int? get historyWindowDays =>
      isPremium ? null : FeatureCatalog.freeHistoryWindowDays;

  /// G3 — earliest date visible on this plan; null = no limit.
  static DateTime? get historyCutoff {
    final days = historyWindowDays;
    return days == null ? null : DateTime.now().subtract(Duration(days: days));
  }

  /// G4 — export (Excel / PDF / CSV) allowed when the 'export' feature is on.
  static bool get canExport => allows('export');

  /// G5 — show the "Powered by Bill Berry Lite" watermark unless 'removeWatermark' is on.
  static bool get showWatermark => !allows('removeWatermark');

  /// Plan label for UI: 'Trial' | 'Premium' | 'Free'.
  static String get planLabel {
    if (licenseStore.licenseInfo?.isTrial ?? false) return 'Trial';
    return isPremium ? 'Premium' : 'Free';
  }
}
