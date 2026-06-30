import 'package:flutter/widgets.dart';
import 'entitlement_keys.dart';
import 'plan_enforcement.dart';
import '../../widgets/upgrade_sheet.dart';

/// UI-layer entitlement guards. Where the old model HID denied features, the new
/// model SHOWS them and blocks on interaction with an "upgrade / contact Bill
/// Berry" sheet. Call these at a tap / action entry, before navigating or
/// mutating. Role-based visibility (RestaurantSession.canAccess) is unaffected —
/// these only cover plan ENTITLEMENT, and store-level checks remain as backup.
class PlanGuard {
  PlanGuard._();

  /// True if [key] is granted. Otherwise shows the "not in your plan" blocker
  /// and returns false. Use: `if (!PlanGuard.allowedOr(context, key)) return;`
  static bool allowedOr(BuildContext context, String key, {String? featureName}) {
    if (PlanEnforce.allows(key)) return true;
    UpgradeSheet.showLocked(context, featureName: featureName);
    return false;
  }

  /// True if one more record fits under [maxKey] given [count]. Otherwise shows
  /// the "plan limit reached" blocker and returns false. [unit] labels the cap
  /// (e.g. 'items', 'customers', 'users', 'bills per day').
  static bool withinLimitOr(
    BuildContext context,
    String maxKey,
    int count, {
    required String unit,
  }) {
    if (PlanEnforce.withinLimit(maxKey, count)) return true;
    final max = PlanEnforce.limit(maxKey) ?? 0;
    UpgradeSheet.showLimit(context, max: max, unit: unit);
    return false;
  }
}
