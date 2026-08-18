import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/sales_totals_report_view.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_step_bar.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';
import 'package:billberrylite/util/color.dart';

/// Sales totals for a single month.
///
/// Point-in-time like the daily report, so it keeps its own month picker and
/// shares [SalesTotalsReportView] for the body.
class MonthlySalesReportScreen extends StatefulWidget {
  const MonthlySalesReportScreen({super.key});

  @override
  State<MonthlySalesReportScreen> createState() =>
      _MonthlySalesReportScreenState();
}

class _MonthlySalesReportScreenState extends State<MonthlySalesReportScreen> {
  final ReportService _reportService = ReportService();

  DateTime _selectedMonth = DateTime.now();
  Map<String, dynamic>? _reportData;
  List<Map<String, dynamic>> _items = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    // Same window the totals cover. `DateTime(y, m + 1)` rolls the year over
    // correctly for December.
    final start = DateTime(_selectedMonth.year, _selectedMonth.month);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    final totalsFuture = _reportService.getMonthlySalesReport(
        _selectedMonth.year, _selectedMonth.month);
    final itemsFuture =
        _reportService.getVariantWiseSalesReport(startDate: start, endDate: end);

    final data = await totalsFuture;
    final items = await itemsFuture;
    if (!mounted) return;
    setState(() {
      _reportData = data;
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _pickMonth() async {
    // Flutter has no month picker; the day is discarded on selection.
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      // Clamped to the plan's history window, like every other report picker.
      firstDate: ReportDateStepBar.pickerFirstDate(),
      lastDate: DateTime.now(),
      helpText: 'Select any day in the month',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    await _loadReport();
  }

  /// `DateTime(y, m + n)` normalises out-of-range months, so stepping past
  /// December or before January rolls the year without special-casing.
  Future<void> _step(int months) async {
    setState(() => _selectedMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + months));
    await _loadReport();
  }

  /// The current month is the newest worth showing.
  bool get _canStepForward {
    final now = DateTime.now();
    return _selectedMonth.isBefore(DateTime(now.year, now.month));
  }

  bool get _canStepBack {
    final cutoff = ReportHistoryWindow.cutoff;
    if (cutoff == null) return true;
    // The previous month is reachable if any part of it is inside the window.
    final previousMonthEnd =
        DateTime(_selectedMonth.year, _selectedMonth.month);
    return previousMonthEnd.isAfter(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Monthly Sales',
        subtitle: DateFormat('MMMM yyyy').format(_selectedMonth),
      ),
      body: Column(
        children: [
          ReportDateStepBar(
            value: _selectedMonth,
            label: DateFormat('MMMM yyyy').format(_selectedMonth),
            onPrevious: _canStepBack ? () => _step(-1) : null,
            onNext: _canStepForward ? () => _step(1) : null,
            onPick: _pickMonth,
          ),
          Expanded(
            child: SalesTotalsReportView(
              isLoading: _isLoading,
              data: _reportData,
              items: _items,
              periodLabel: DateFormat('MMMM yyyy').format(_selectedMonth),
              reportTitle: 'Monthly Sales',
              exportFileName: 'monthly_sales',
            ),
          ),
        ],
      ),
    );
  }
}
