import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/screens/retail/reports/sales_totals_report_view.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_step_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

/// Sales totals for a single day.
///
/// Point-in-time, so it keeps its own date picker rather than the period bar —
/// see [SalesTotalsReportView] for why.
class DailySalesReportScreen extends StatefulWidget {
  const DailySalesReportScreen({super.key});

  @override
  State<DailySalesReportScreen> createState() => _DailySalesReportScreenState();
}

class _DailySalesReportScreenState extends State<DailySalesReportScreen> {
  final ReportService _reportService = ReportService();

  DateTime _selectedDate = DateTime.now();
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

    // Same window the totals cover: midnight to midnight, end exclusive.
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));

    final totalsFuture = _reportService.getDailySalesReport(_selectedDate);
    final itemsFuture = _reportService.getVariantWiseSalesReport(
      startDate: start,
      endDate: end,
    );

    final data = await totalsFuture;
    final items = await itemsFuture;
    if (!mounted) return;
    setState(() {
      _reportData = data;
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // Clamped to the plan's history window, like every other report picker.
      firstDate: ReportDateStepBar.pickerFirstDate(),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    await _loadReport();
  }

  Future<void> _step(int days) async {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    await _loadReport();
  }

  /// Today is the newest day worth showing, so forward stops there rather than
  /// letting the report run into an empty future.
  bool get _canStepForward {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return selected.isBefore(today);
  }

  bool get _canStepBack {
    final cutoff = ReportHistoryWindow.cutoff;
    if (cutoff == null) return true;
    return _selectedDate.subtract(const Duration(days: 1)).isAfter(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Daily Sales',
        subtitle: DateFormat('dd MMM yyyy').format(_selectedDate),
      ),
      body: Column(
        children: [
          ReportDateStepBar(
            value: _selectedDate,
            label: DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
            onPrevious: _canStepBack ? () => _step(-1) : null,
            onNext: _canStepForward ? () => _step(1) : null,
            onPick: _pickDate,
          ),
          Expanded(
            child: SalesTotalsReportView(
              isLoading: _isLoading,
              data: _reportData,
              items: _items,
              periodLabel: DateFormat(
                'EEEE, dd MMMM yyyy',
              ).format(_selectedDate),
              reportTitle: 'Daily Sales',
              exportFileName: 'daily_sales',
            ),
          ),
        ],
      ),
    );
  }
}
