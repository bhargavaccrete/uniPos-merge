import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/common/attendance_report_calc.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// What the user chose in [AttendanceExportDialog].
class AttendanceExportChoice {
  /// First day (midnight).
  final DateTime from;

  /// Last day, inclusive (midnight).
  final DateTime to;

  /// True for the month on screen (the default, original export).
  final bool isMonth;

  /// Day-wise register instead of one row per staff.
  final bool dayWise;

  const AttendanceExportChoice({
    required this.from,
    required this.to,
    required this.isMonth,
    required this.dayWise,
  });
}

/// Period + type for the Attendance export. The Excel / PDF choice that
/// follows is the app's standard export dialog.
///
/// Period: the month on screen (default) or a custom range of up to
/// [maxRangeDays] days that may cross months; the end can't be in the future.
class AttendanceExportDialog extends StatefulWidget {
  static const int maxRangeDays = 93;

  /// First day of the month on screen.
  final DateTime month;

  /// Injectable "today" for tests.
  final DateTime? now;

  const AttendanceExportDialog({super.key, required this.month, this.now});

  /// Days in an inclusive range.
  static int rangeDays(DateTime from, DateTime to) =>
      AttendanceReportCalc.workingDaysBetween(from, to);

  /// Null when the range is usable, else why not.
  static String? rangeError(DateTime from, DateTime to, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(to.year, to.month, to.day).isAfter(today)) {
      return 'The end date can’t be in the future.';
    }
    if (rangeDays(from, to) > maxRangeDays) {
      return 'Choose $maxRangeDays days or fewer.';
    }
    return null;
  }

  static Future<AttendanceExportChoice?> show(
    BuildContext context, {
    required DateTime month,
  }) =>
      showDialog<AttendanceExportChoice>(
        context: context,
        builder: (_) => AttendanceExportDialog(month: month),
      );

  @override
  State<AttendanceExportDialog> createState() => _AttendanceExportDialogState();
}

enum _Period { month, custom }

class _AttendanceExportDialogState extends State<AttendanceExportDialog> {
  _Period _period = _Period.month;
  bool _dayWise = false;
  DateTimeRange? _range;

  DateTime get _now => widget.now ?? DateTime.now();

  DateTime get _monthEnd => AttendanceReportCalc.monthPeriodEnd(
        widget.month,
        _now,
      );

  String get _monthLabel => DateFormat('MMMM yyyy').format(widget.month);

  String? get _error {
    if (_period == _Period.month) return null;
    final r = _range;
    if (r == null) return 'Pick the dates to export.';
    return AttendanceExportDialog.rangeError(r.start, r.end, _now);
  }

  int get _days => _period == _Period.month
      ? AttendanceReportCalc.workingDaysBetween(widget.month, _monthEnd)
      : (_range == null
          ? 0
          : AttendanceExportDialog.rangeDays(_range!.start, _range!.end));

  Future<void> _pickRange() async {
    final today = DateTime(_now.year, _now.month, _now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: _range ??
          DateTimeRange(
            start: widget.month,
            end: _monthEnd.isAfter(today) ? today : _monthEnd,
          ),
      helpText: 'SELECT EXPORT PERIOD',
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _period = _Period.custom;
      });
    }
  }

  void _continue() {
    if (_error != null) return;
    final DateTime from;
    final DateTime to;
    if (_period == _Period.month) {
      from = widget.month;
      to = _monthEnd;
    } else {
      from = _range!.start;
      to = _range!.end;
    }
    Navigator.pop(
      context,
      AttendanceExportChoice(
        from: DateTime(from.year, from.month, from.day),
        to: DateTime(to.year, to.month, to.day),
        isMonth: _period == _Period.month,
        dayWise: _dayWise,
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 2),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _option<T>(T value, String title, VoidCallback onTap,
      {Widget? below}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<T>(value: value, activeColor: AppColors.primary),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (below != null)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: below,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final error = _error;
    final rangeText = _range == null
        ? 'Choose dates'
        : '${fmt.format(_range!.start)} – ${fmt.format(_range!.end)}';

    return AppDialogShell(
      title: 'Export Attendance',
      subtitle: 'Choose the period and the layout',
      accent: AppColors.primary,
      icon: Icons.file_download_outlined,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Period'),
          RadioGroup<_Period>(
            groupValue: _period,
            onChanged: (p) => setState(() => _period = p ?? _period),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _option(
                  _Period.month,
                  '$_monthLabel (on screen)',
                  () => setState(() => _period = _Period.month),
                ),
                _option(
                  _Period.custom,
                  'Custom range (up to ${AttendanceExportDialog.maxRangeDays} days)',
                  () => setState(() => _period = _Period.custom),
                  below: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(
                      rangeText,
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _label('Layout'),
          RadioGroup<bool>(
            groupValue: _dayWise,
            onChanged: (v) => setState(() => _dayWise = v ?? _dayWise),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _option(
                  false,
                  'Summary per staff',
                  () => setState(() => _dayWise = false),
                ),
                _option(
                  true,
                  'Day-wise detail (shifts and absent days)',
                  () => setState(() => _dayWise = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              error ?? 'Exporting $_days day${_days == 1 ? '' : 's'}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: error == null ? AppColors.primary : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
      actions: [
        appDialogCancelButton(context),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        appDialogPrimaryButton(label: 'Continue', onPressed: _continue),
      ],
    );
  }
}
