import 'package:flutter/material.dart';
import '../core/routes/routes_name.dart';
import '../util/color.dart';
import '../util/common/app_responsive.dart';

/// Shared "upgrade required" blocker shown whenever the active plan does not
/// include a feature, or a plan limit is reached. Centralised so every block
/// looks and behaves the same. Upgrades are sales-driven, so the primary action
/// is "Contact Bill Berry" (→ Need Help screen with phone/email/WhatsApp).
class UpgradeSheet {
  UpgradeSheet._();

  /// Generic blocker. [title] and [message] describe the specific lock.
  static Future<void> show(
    BuildContext context, {
    String title = 'Upgrade required',
    required String message,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => _UpgradeSheetBody(title: title, message: message),
    );
  }

  /// Feature not included in the current plan.
  static Future<void> showLocked(BuildContext context, {String? featureName}) {
    final what = (featureName == null || featureName.trim().isEmpty)
        ? 'This feature'
        : featureName.trim();
    return show(
      context,
      title: 'Not in your plan',
      message:
          "$what isn't included in your current plan.\nPlease contact Bill Berry to upgrade your plan.",
    );
  }

  /// A plan count/usage limit has been reached.
  static Future<void> showLimit(
    BuildContext context, {
    required int max,
    required String unit,
  }) {
    return show(
      context,
      title: 'Plan limit reached',
      message:
          "You've reached your plan limit of $max $unit.\nPlease contact Bill Berry to upgrade your plan.",
    );
  }
}

class _UpgradeSheetBody extends StatelessWidget {
  const _UpgradeSheetBody({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.largeSpacing(context) +
            MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: AppColors.accent,
                    size: AppResponsive.largeIconSize(context)),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            message,
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Close',
                      style:
                          TextStyle(fontSize: AppResponsive.buttonFontSize(context))),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .pushNamed(RouteNames.restaurantNeedHelp);
                  },
                  icon: Icon(Icons.support_agent_rounded,
                      size: AppResponsive.iconSize(context)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  label: Text('Contact Bill Berry',
                      style: TextStyle(
                          fontSize: AppResponsive.buttonFontSize(context),
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
