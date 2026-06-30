import '../di/service_locator.dart';
import '../../domain/store/restaurant/license_store.dart';
import 'entitlements.dart';

/// Single source of truth for entitlement enforcement, used by BOTH the UI
/// (hide/disable) and the business logic (validate before execution).
///
/// Strict / deny-by-default: with a real manifest a key resolves to its granted
/// value (missing ⇒ off/0). The only escape hatch is license bypass (web/dev).
/// Keep all enforcement going through here so UI and logic can never diverge.
class PlanEnforce {
  PlanEnforce._();

  static bool get _bypassed => locator<LicenseStore>().licenseBypassed;

  /// Action / module / submodule permission (add/edit/delete/export/view/create…).
  static bool allows(String key) => _bypassed || Entitlements.instance.can(key);

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
