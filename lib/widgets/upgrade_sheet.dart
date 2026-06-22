import 'package:flutter/material.dart';
import '../core/routes/routes_name.dart';
import '../util/color.dart';
import '../util/common/app_responsive.dart';

/// Shared "Upgrade to Premium" bottom sheet shown whenever a Free user hits a
/// plan limit (locked feature, count cap, history window, export, etc.).
/// Centralised so every lock looks and behaves the same.
class UpgradeSheet {
  UpgradeSheet._();

  /// Shows the upgrade prompt. [title] and [message] describe the specific lock.
  /// The "Upgrade" button routes to the licensing screen.
  static Future<void> show(
    BuildContext context, {
    String title = 'Premium feature',
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
                  child: Text('Maybe later',
                      style:
                          TextStyle(fontSize: AppResponsive.buttonFontSize(context))),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .pushNamed(RouteNames.restaurantLicensing);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Upgrade',
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
