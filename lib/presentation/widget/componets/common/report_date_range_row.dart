import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A compact From/To date pair for a report's **header band**.
///
/// Renders the same white full-width band as `ReportFilterBar`, so a report
/// scoped by an explicit range lines up with one scoped by period. Each field
/// opens its date picker directly — never a chooser sheet in between.
///
/// Not to be confused with `ReportDateRangeCard`, which is the taller card with
/// an explicit **Apply** step shown inside a report *body* when its Custom
/// period is active. Use this one when the range is the report's standing
/// scope and every change should apply immediately.
///
/// [firstDate] defaults to 2020 rather than the plan's history cutoff: the
/// screens using this bar (shift ledger, staff performance, cash-drawer audit
/// trail) are operational records, not reporting windows. Pass
/// `ReportHistoryWindow.cutoff` explicitly if a report does need gating.
class ReportDateRangeRow extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromPicked;
  final ValueChanged<DateTime> onToPicked;

  /// Earliest selectable date. Defaults to `DateTime(2020)`.
  final DateTime? firstDate;

  /// Band padding. Defaults to the standard `ReportFilterBar` band; pass a
  /// trimmed one when this sits directly against another band.
  final EdgeInsetsGeometry? padding;

  final String fromLabel;
  final String toLabel;

  const ReportDateRangeRow({
    super.key,
    required this.from,
    required this.to,
    required this.onFromPicked,
    required this.onToPicked,
    this.firstDate,
    this.padding,
    this.fromLabel = 'From',
    this.toLabel = 'To',
  });

  Future<void> _pick(BuildContext context, {required bool isStart}) async {
    final lower = firstDate ?? DateTime(2020);
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? from : to) ?? DateTime.now(),
      // Picking an end date can't reach behind the start date, so an invalid
      // range is unreachable rather than merely rejected afterwards.
      firstDate: isStart ? lower : (from ?? lower),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    if (!isStart && from != null && picked.isBefore(from!)) {
      NotificationService.instance.showError(
        'End date cannot be before start date',
      );
      return;
    }
    isStart ? onFromPicked(picked) : onToPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding:
          padding ??
          AppResponsive.horizontalPadding(
            context,
          ).copyWith(top: 12, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _field(
              context,
              label: fromLabel,
              value: from,
              onTap: () => _pick(context, isStart: true),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: _field(
              context,
              label: toLabel,
              value: to,
              onTap: () => _pick(context, isStart: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final set = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.smallSpacing(context) + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          // Radius 10 like every other report control.
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: set ? AppColors.primary : AppColors.divider,
            width: set ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: AppResponsive.smallIconSize(context),
              color: set ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                set ? DateFormat('dd MMM yyyy').format(value) : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: set ? FontWeight.w600 : FontWeight.w400,
                  color: set ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
