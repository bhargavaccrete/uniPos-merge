import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/domain/services/common/attendance_report_calc.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_step_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'attendance_export_dialog.dart';
import 'staff_attendance_detail_screen.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceModel> _records = [];
  bool _isLoading = true;

  Future<void> _printReport() async {
    final storeName =
        await StoreSettingsService().getStoreName() ?? 'Restaurant';
    final monthName = _monthName(_selectedMonth.month);
    final year = _selectedMonth.year;

    final font =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    final boldFont =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));

    final fallbackFonts = <pw.Font>[];
    for (final path in const [
      'assets/fonts/NotoSansGujarati-Regular.ttf',
      'assets/fonts/NotoSansDevanagari-Regular.ttf',
    ]) {
      try {
        final data = await rootBundle.load(path);
        fallbackFonts.add(pw.Font.ttf(data));
      } catch (e) {
        debugPrint('Error loading fallback font $path: $e');
      }
    }

    final allStaff = _staffNames;
    final periodEnd =
        (_selectedMonth.year == DateTime.now().year &&
            _selectedMonth.month == DateTime.now().month)
        ? DateTime.now()
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final workingDays = _workingDaysInPeriod(_selectedMonth, periodEnd);

    await Printing.layoutPdf(
      name: 'Attendance_Report_${monthName}_$year',
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(
              base: font,
              bold: boldFont,
              fontFallback: fallbackFonts,
            ),
            header: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      storeName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'Monthly Attendance Report - $monthName $year',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              );
            },
            build: (pw.Context context) {
              return [
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerRight,
                  },
                  headers: [
                    'Staff Name',
                    'Days Present',
                    'Days Absent',
                    'Total Hours Worked',
                  ],
                  data: allStaff.map((name) {
                    final presentDays = _presentDays(name);
                    final absentDays = (workingDays - presentDays).clamp(
                      0,
                      workingDays,
                    );
                    final totalMins = _totalMinutes(name);

                    final h = totalMins ~/ 60;
                    final m = totalMins % 60;
                    final formattedHours = '${h}h ${m}m';

                    return [
                      name,
                      presentDays.toString(),
                      absentDays.toString(),
                      formattedHours,
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Generated by Bill Berry Lite',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ];
            },
          ),
        );
        return doc.save();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Normalize to first day of month
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT MONTH',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _load();
    }
  }

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (next.isBefore(DateTime.now()) ||
        (next.year == DateTime.now().year &&
            next.month == DateTime.now().month)) {
      setState(() {
        _selectedMonth = next;
      });
      _load();
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final startOfMonth = _selectedMonth;
    final endOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final result = await attendanceStore.getRecordsBetweenDates(
      startOfMonth,
      endOfMonth,
    );

    setState(() {
      _records = result;
      _isLoading = false;
    });
  }

  // ── Calculations: ONE shared helper (AttendanceReportCalc) for the cards,
  // the staff list, Print and both exports — Restaurant and Retail alike.

  String _staffKey(StaffModel s) => '${s.firstName} ${s.lastName}'.trim();

  /// Role by name over ALL staff, first match wins (the old `firstOrNull`).
  Map<String, String> get _staffRoles {
    final roles = <String, String>{};
    for (final s in staffStore.staff) {
      roles.putIfAbsent(_staffKey(s), () => s.isCashier);
    }
    return roles;
  }

  AttendanceReportCalc _calcFor(
    List<AttendanceModel> records,
    DateTime from,
    DateTime periodEnd,
  ) =>
      AttendanceReportCalc(
        records: records,
        from: from,
        periodEnd: periodEnd,
        // Active staff are listed even with no records, so absences show.
        activeStaffNames:
            staffStore.staff.where((s) => s.isActive).map(_staffKey),
        staffRoles: _staffRoles,
      );

  /// The month on screen.
  AttendanceReportCalc get _calc => _calcFor(
        _records,
        _selectedMonth,
        AttendanceReportCalc.monthPeriodEnd(_selectedMonth, DateTime.now()),
      );

  int _workingDaysInPeriod(DateTime start, DateTime end) =>
      AttendanceReportCalc.workingDaysBetween(start, end);

  List<String> get _staffNames => _calc.staffNames;

  int _presentDays(String name) => _calc.presentDays(name);

  int _totalMinutes(String name) => _calc.totalMinutes(name);

  String _fmtMins(int mins) => AttendanceReportCalc.fmtMins(mins);

  String _monthName(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[m - 1];
  }

  /// Period + layout first (the month on screen is the default), then the
  /// standard Excel / PDF dialog. A custom range re-reads attendance for
  /// exactly those dates with the same loader the screen uses.
  Future<void> _doExport(BuildContext context) async {
    final choice = await AttendanceExportDialog.show(
      context,
      month: _selectedMonth,
    );
    if (choice == null || !context.mounted) return;

    final List<AttendanceModel> records;
    final DateTime periodEnd;
    final String periodKey;
    final String periodLabel;
    final String fileTag;
    if (choice.isMonth) {
      records = _records;
      periodEnd = AttendanceReportCalc.monthPeriodEnd(
        _selectedMonth,
        DateTime.now(),
      );
      periodKey = 'Month';
      periodLabel =
          '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}';
      fileTag = '${_monthName(_selectedMonth.month)}_${_selectedMonth.year}';
    } else {
      final to = choice.to;
      records = await attendanceStore.getRecordsBetweenDates(
        choice.from,
        DateTime(to.year, to.month, to.day, 23, 59, 59),
      );
      if (!context.mounted) return;
      periodEnd = to;
      periodKey = 'Period';
      final fmt = DateFormat('dd MMM yyyy');
      periodLabel = '${fmt.format(choice.from)} – ${fmt.format(to)}';
      fileTag = '${DateFormat('yyyyMMdd').format(choice.from)}-'
          '${DateFormat('yyyyMMdd').format(to)}';
    }

    final calc = _calcFor(records, choice.from, periodEnd);
    final title = choice.isMonth
        ? 'Monthly Attendance — $periodLabel'
        : 'Attendance — $periodLabel';

    if (choice.dayWise) {
      final rows = calc.dayRows();
      await ReportExportService.showExportDialog(
        context: context,
        fileName: 'attendance_daywise_$fileTag',
        reportTitle: '$title (Day-wise)',
        headers: AttendanceReportCalc.dayHeaders,
        data: rows,
        summary: calc.dayBlock(periodLabel, rows),
      );
    } else {
      await ReportExportService.showExportDialog(
        context: context,
        fileName: 'attendance_$fileTag',
        reportTitle: title,
        headers: AttendanceReportCalc.summaryHeaders,
        data: calc.summaryRows(),
        summary: calc.summaryBlock(periodKey, periodLabel),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allStaff = _staffNames;

    final isCurrentMonth =
        _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;

    final periodEnd = isCurrentMonth
        ? DateTime.now()
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final workingDays = _workingDaysInPeriod(_selectedMonth, periodEnd);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Monthly Attendance',
        subtitle:
            '${allStaff.length} staff  •  $workingDays working day${workingDays == 1 ? '' : 's'}',
        // Export moved to the shared full-width button; Print stays here as a
        // genuinely screen-specific control.
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printReport,
            tooltip: 'Print',
          ),
        ],
      ),
      body: Column(
        children: [
          // Point-in-time report: the kit's step bar, not a period filter —
          // "Monthly Attendance / This Week" would be a different report.
          ReportDateStepBar(
            value: _selectedMonth,
            label: '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
            onPrevious: _prevMonth,
            // Null at the newest month so the report can't run into the future.
            onNext: isCurrentMonth ? null : _nextMonth,
            onPick: _pickMonth,
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(child: _buildContent(context, allStaff, workingDays)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<String> allStaff,
    int workingDays,
  ) {
    if (_isLoading) return const ReportLoading();
    if (allStaff.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.badge_outlined,
        title: 'No staff data found',
        message: 'Attendance appears here once staff clock in for this month',
      );
    }

    return ReportBody(
      child: Column(
        children: [
          _buildSummaryCards(context, allStaff, workingDays),
          AppResponsive.verticalSpace(context),
          ReportExportButton(onPressed: () => _doExport(context)),
          AppResponsive.verticalSpace(context),
          _buildStaffList(context, allStaff, workingDays),
        ],
      ),
    );
  }

  /// Two rows of two, as in totalsales/refunddetails — four cards abreast
  /// leaves each ~78px on a 360px phone and ellipsises every title.
  Widget _buildSummaryCards(
    BuildContext context,
    List<String> allStaff,
    int workingDays,
  ) {
    var totalPresent = 0;
    var totalMins = 0;
    for (final name in allStaff) {
      totalPresent += _presentDays(name);
      totalMins += _totalMinutes(name);
    }

    return Column(
      children: [
        ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Staff',
              value: '${allStaff.length}',
              icon: Icons.people_outline,
              color: AppColors.primary,
            ),
            ReportSummaryCard(
              title: 'Working Days',
              value: '$workingDays',
              icon: Icons.event_available_outlined,
              color: Colors.blue,
            ),
          ],
        ),
        AppResponsive.verticalSpace(context),
        ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Days Present',
              value: '$totalPresent',
              icon: Icons.how_to_reg_outlined,
              color: AppColors.success,
            ),
            ReportSummaryCard(
              title: 'Total Hours',
              value: _fmtMins(totalMins),
              icon: Icons.timer_outlined,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  /// A plain Column, not a ListView: ReportBody already scrolls and supplies
  /// the padding + width cap, so a nested scrollable would fight it.
  Widget _buildStaffList(
    BuildContext context,
    List<String> allStaff,
    int workingDays,
  ) {
    return Column(
      children: [
        for (var i = 0; i < allStaff.length; i++) ...[
          if (i > 0) SizedBox(height: AppResponsive.smallSpacing(context)),
          _staffCard(context, allStaff[i], workingDays),
        ],
      ],
    );
  }

  Widget _staffCard(BuildContext context, String name, int workingDays) {
    final presentDays = _presentDays(name);
    final absentDays = (workingDays - presentDays).clamp(0, workingDays);
    final totalMins = _totalMinutes(name);

    // Role from staff store or first record (shared rule).
    final role = _calc.roleOf(name);

    final staffRecords = _records.where((r) => r.staffName == name).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StaffAttendanceDetailScreen(
              staffName: name,
              staffRole: role,
              from: _selectedMonth,
              to: DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                0,
                23,
                59,
                59,
              ),
              initialRecords: staffRecords,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: AppResponsive.getValue<double>(
                context,
                mobile: 44,
                tablet: 48,
                desktop: 52,
              ),
              height: AppResponsive.getValue<double>(
                context,
                mobile: 44,
                tablet: 48,
                desktop: 52,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            // Name + role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    role,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Row(
                    children: [
                      _miniChip(
                        context,
                        '${presentDays}P',
                        Colors.green.shade600,
                      ),
                      SizedBox(
                        width: AppResponsive.smallSpacing(context) * 0.5,
                      ),
                      _miniChip(
                        context,
                        '${absentDays}A',
                        absentDays > 0
                            ? Colors.red.shade400
                            : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Hours + arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total Hours',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtMins(totalMins),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: AppResponsive.smallIconSize(context),
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(BuildContext context, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.smallSpacing(context),
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
