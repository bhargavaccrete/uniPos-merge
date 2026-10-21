import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

/// The selected day or month, with arrows to step and a tap to pick.
///
/// For *point-in-time* reports — Daily and Monthly Sales — which can't use
/// [ReportPeriodFilterBar] without becoming each other ("Daily Sales / This
/// Month" would be the Monthly report). They still deserve a visible control
/// in the same place, rather than hiding the only way to change period behind
/// an AppBar icon.
///
/// Stepping is the point: reading yesterday, then the day before, is two taps
/// instead of two dialogs.
class ReportDateStepBar extends StatelessWidget {
  /// Currently shown period.
  final DateTime value;

  /// Formatted [value] — the caller owns the wording ("Mon, 17 Aug 2026" for a
  /// day, "August 2026" for a month).
  final String label;

  /// Step back one unit. Null disables the arrow.
  final VoidCallback? onPrevious;

  /// Step forward one unit. Null disables the arrow — pass null at the newest
  /// period so the report can't run off into the future.
  final VoidCallback? onNext;

  /// Opens the picker. The bar itself is the tap target.
  final VoidCallback onPick;

  const ReportDateStepBar({
    super.key,
    required this.value,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final radius = AppResponsive.borderRadius(context);

    return Container(
      width: double.infinity,
      color: AppColors.white,
      // Same white band and padding as ReportFilterBar, so a report with this
      // bar and a report with the period bar line up.
      padding: AppResponsive.horizontalPadding(
        context,
      ).copyWith(top: 12, bottom: 12),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous',
            onPressed: onPrevious,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: onPick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: AppResponsive.smallIconSize(context),
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  /// Earliest date the picker may offer, clamped to the plan's history window
  /// the same way [ReportDateRangeCard] does.
  static DateTime pickerFirstDate() =>
      ReportHistoryWindow.cutoff ?? DateTime(2020);
}

/// Rectangular, radius-10 step button — never a circular icon button.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = AppResponsive.borderRadius(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? AppColors.surfaceLight : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onPressed,
          // 8px of padding around a 20px icon gave a 36×36 target — under the
          // 48dp minimum, on the primary navigation control of the Daily and
          // Monthly reports. The icon keeps its size; only the box it sits in
          // grows to meet the minimum.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  size: AppResponsive.iconSize(context),
                  color: enabled ? AppColors.primary : AppColors.divider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
