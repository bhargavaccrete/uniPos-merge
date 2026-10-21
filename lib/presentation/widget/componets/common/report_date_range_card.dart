import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

/// The "Select Date Range" card shown when a report's Custom period is active.
///
/// The picker's `firstDate` is clamped to the plan's history window, so a range
/// can't be chosen past the cutoff and then come back silently truncated.
class ReportDateRangeCard extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final void Function(DateTime start, DateTime end) onApply;

  const ReportDateRangeCard({
    super.key,
    this.initialStart,
    this.initialEnd,
    required this.onApply,
  });

  @override
  State<ReportDateRangeCard> createState() => _ReportDateRangeCardState();
}

class _ReportDateRangeCardState extends State<ReportDateRangeCard> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: ReportHistoryWindow.cutoff ?? DateTime(2020),
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

    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      } else {
        if (_start != null && picked.isBefore(_start!)) {
          NotificationService.instance.showError('End date cannot be before start date');
          return;
        }
        _end = picked;
      }
    });
  }

  String _format(DateTime? date) =>
      date == null ? 'Select Date' : DateFormat('dd MMM, yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    final ready = _start != null && _end != null;

    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date Range',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          AppResponsive.verticalSpace(context),
          Row(
            children: [
              Expanded(child: _dateButton('Start Date', _format(_start), () => _pick(true))),
              AppResponsive.horizontalSpace(context),
              Expanded(child: _dateButton('End Date', _format(_end), () => _pick(false))),
            ],
          ),
          AppResponsive.verticalSpace(context),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ready ? () => widget.onApply(_start!, _end!) : null,
              icon: Icon(Icons.filter_list, size: AppResponsive.smallIconSize(context)),
              label: Text(
                'Apply Filter',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.buttonFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.divider,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue(context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, String value, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0)),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: value == 'Select Date'
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today,
                    size: AppResponsive.smallIconSize(context), color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
