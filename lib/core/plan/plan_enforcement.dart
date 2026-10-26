import '../di/service_locator.dart';
import '../../domain/store/restaurant/license_store.dart';
import '../config/app_config.dart';
import 'entitlements.dart';

/// Single source of truth for entitlement enforcement, used by BOTH the UI
/// (hide/disable) and the business logic (validate before execution).
///
/// Strict / deny-by-default: with a real manifest a key resolves to its granted
/// value (missing ⇒ off/0). Escape hatches: license bypass (web/dev), and
/// retail mode — retail has no licensing/entitlement system of its own, so it
/// must never be denied by restaurant's deny-by-default catalog when shared
/// stores (e.g. CategoryStore) call through here.
/// Keep all enforcement going through here so UI and logic can never diverge.
class PlanEnforce {
  PlanEnforce._();

  // Restaurant is unaffected: AppConfig.isRetail is false, so this reduces to
  // `licenseBypassed` exactly as before. Retail enforces ONLY once it has been
  // licensed — until the backend sends a manifest, retail stays fully open.
  //
  // The `licenseInfo == null` clause is a FAIL-CLOSED guard, not a nicety.
  // A lock-out (`_lockOutKeepingStatus` on EXPIRED/SUSPENDED) clears the
  // manifest but deliberately KEEPS licenseInfo. Without this clause an empty
  // manifest read as "retail has no licensing yet" and re-opened the entire
  // app — a revoke would have GRANTED access instead of removing it. So:
  //   never licensed  → licenseInfo null  → bypass (today's open behaviour)
  //   licensed, locked→ licenseInfo kept  → enforce → guard shows the lock screen
  static bool get _bypassed =>
      locator<LicenseStore>().licenseBypassed ||
      (AppConfig.isRetail &&
          !Entitlements.instance.hasManifest &&
          locator<LicenseStore>().licenseInfo == null);

  /// This store's own business type as the manifest enum: 1 Restaurant,
  /// 2 Retail. (There is no "Both" store — 3 only appears on features/plans.)
  static int get storeBusinessTypeCode => AppConfig.isRetail ? 2 : 1;

  /// Business-type relevance filter (fail-open). A feature is relevant unless
  /// the manifest EXPLICITLY tags it for a different business type:
  ///   - not sent / key absent (null) → true  (old manifests, untagged keys)
  ///   - 3 (Both)                     → true
  ///   - else                         → must equal this store's type
  /// Only an explicit mismatch withholds a feature, so this never regresses
  /// existing behaviour; it activates as the server tags features.
  static bool businessTypeAllows(String key) {
    final ft = Entitlements.instance.featureBusinessType(key);
    if (ft == null || ft == 3) return true;
    return ft == storeBusinessTypeCode;
  }

  /// Action / module / submodule permission (add/edit/delete/export/view/create…).
  /// Granted only when the plan grants it AND it applies to this business type.
  static bool allows(String key) =>
      _bypassed || (Entitlements.instance.can(key) && businessTypeAllows(key));

  /// True if ANY of [keys] is granted (and business-type-relevant). For a screen
  /// fronting several sub-keys (e.g. Sales Comparison, whose periods each carry
  /// their own key).
  static bool allowsAny(Iterable<String> keys) =>
      _bypassed ||
      keys.any((k) => Entitlements.instance.can(k) && businessTypeAllows(k));

  /// True if ONE more record fits under [maxKey] given the current [count].
  /// A limit of **0 or absent means NO cap** (unlimited) — availability is
  /// governed by the module/action flag, not the limit. The limit only caps
  /// when it is a positive number. This prevents a missing cap on a granted
  /// module (e.g. billing without per_day_max) from blocking the whole feature.
  static bool withinLimit(String maxKey, int count) {
    if (_bypassed) return true;
    final max = Entitlements.instance.limit(maxKey);
    if (max <= 0) return true; // 0/absent ⇒ unlimited
    return count < max;
  }

  /// Remaining slots under [maxKey]; null = unlimited (bypass, or 0/absent cap).
  static int? remaining(String maxKey, int count) {
    if (_bypassed) return null;
    final max = Entitlements.instance.limit(maxKey);
    if (max <= 0) return null;
    final left = max - count;
    return left < 0 ? 0 : left;
  }

  /// The numeric cap for [maxKey] (for messages); null = unlimited (bypass).
  static int? limit(String maxKey) =>
      _bypassed ? null : Entitlements.instance.limit(maxKey);

  /// Report history window in days; null = unlimited (bypass or 'all').
  static int? windowDays(String key) =>
      _bypassed ? null : Entitlements.instance.windowDays(key);

  /// Earliest date visible under a window-days scope; null = no limit.
  static DateTime? windowCutoff(String key) {
    final days = windowDays(key);
    return days == null ? null : DateTime.now().subtract(Duration(days: days));
  }

  /// Row cap for a report scope; null = unlimited (bypass or 0/unset).
  static int? maxRows(String key) {
    if (_bypassed) return null;
    final v = Entitlements.instance.limit(key);
    return v > 0 ? v : null;
  }
}
