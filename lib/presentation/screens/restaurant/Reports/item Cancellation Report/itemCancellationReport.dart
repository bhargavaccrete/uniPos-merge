import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:unipos/data/repositories/restaurant/item_cancellation_repository.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import '../../../../widget/componets/common/primary_app_bar.dart';
import '../../../../widget/componets/common/report_summary_card.dart';

enum CancelPeriod { Today, ThisWeek, Month, Custom }

/// Report of individual items cancelled from already-placed orders, with reason.
class ItemCancellationReport extends StatefulWidget {
  const ItemCancellationReport({super.key});

  @override
  State<ItemCancellationReport> createState() => _ItemCancellationReportState();
}

class _ItemCancellationReportState extends State<ItemCancellationReport> {
  CancelPeriod _period = CancelPeriod.Today;
  DateTime? _startDate;
  DateTime? _endDate;

  List<ItemCancellationModel> _all = [];
  List<ItemCancellationModel> _filtered = [];
  bool _loaded = false;

  int _totalCount = 0;
  int _totalQty = 0;
  double _totalAmount = 0;
  String _topReason = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _all = locator<ItemCancellationRepository>().getAll();
    _loaded = true;
    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    switch (_period) {
      case CancelPeriod.Today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case CancelPeriod.ThisWeek:
        final ws = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(ws.year, ws.month, ws.day);
        end = start.add(const Duration(days: 7));
        break;
      case CancelPeriod.Month:
        start = DateTime(now.year, now.month);
        end = DateTime(now.year, now.month + 1);
        break;
      case CancelPeriod.Custom:
        if (_startDate != null && _endDate != null) {
          start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
              .add(const Duration(days: 1));
        }
        break;
    }

    final results = (start == null || end == null)
        ? <ItemCancellationModel>[]
        : _all
            .where((r) => !r.timestamp.isBefore(start!) && r.timestamp.isBefore(end!))
            .toList();

    final reasonCounts = <String, int>{};
    int qty = 0;
    double amount = 0;
    for (final r in results) {
      qty += r.quantity;
      amount += r.amount;
      final reason = r.reason.trim();
      if (reason.isNotEmpty && reason != 'No reason given') {
        reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
      }
    }
    String top = '—';
    if (reasonCounts.isNotEmpty) {
      top = reasonCounts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    setState(() {
      _filtered = results;
      _totalCount = results.length;
      _totalQty = qty;
      _totalAmount = amount;
      _topReason = top;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Item Cancellation Report',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
            Text('Items cancelled from placed orders, with reason',
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Period chips
          Container(
            width: double.infinity,
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('Today', CancelPeriod.Today),
                  _chip('This Week', CancelPeriod.ThisWeek),
                  _chip('Month', CancelPeriod.Month),
                  _chip('Custom', CancelPeriod.Custom),
                ],
              ),
            ),
          ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_period == CancelPeriod.Custom) _customRange(),
                        Row(
                          children: [
                            Expanded(child: ReportSummaryCard(title: 'Cancellations', value: '$_totalCount', icon: Icons.remove_circle_outline, color: Colors.red)),
                            AppResponsive.horizontalSpace(context),
                            Expanded(child: ReportSummaryCard(title: 'Items Qty', value: '$_totalQty', icon: Icons.numbers, color: Colors.orange)),
                            AppResponsive.horizontalSpace(context),
                            Expanded(child: ReportSummaryCard(title: 'Amount', value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalAmount)}', icon: Icons.attach_money, color: AppColors.primary)),
                          ],
                        ),
                        if (_filtered.isNotEmpty && _topReason != '—') ...[
                          const SizedBox(height: 12),
                          ReportSummaryCard(title: 'Top Reason', value: _topReason, icon: Icons.report_problem_outlined, color: Colors.red),
                        ],
                        const SizedBox(height: 16),
                        if (_filtered.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.download, size: 20),
                              label: Text('Export Report',
                                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _export,
                            ),
                          ),
                        const SizedBox(height: 16),
                        _filtered.isEmpty ? _empty() : _table(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, CancelPeriod p) {
    final selected = _period == p;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : AppColors.white,
          foregroundColor: selected ? AppColors.white : AppColors.textPrimary,
          elevation: selected ? 2 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
          ),
        ),
        onPressed: () {
          setState(() => _period = p);
          _applyFilter();
        },
        child: Text(label,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _customRange() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _dateField('From', _startDate, (d) => setState(() => _startDate = d))),
          const SizedBox(width: 12),
          Expanded(child: _dateField('To', _endDate, (d) => setState(() => _endDate = d))),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: (_startDate != null && _endDate != null) ? _applyFilter : null,
            child: Text('Apply', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, ValueChanged<DateTime> onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          date != null ? DateFormat('dd/MM/yyyy').format(date) : label,
          style: GoogleFonts.poppins(
              fontSize: 13,
              color: date != null ? AppColors.textPrimary : AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('No item cancellations',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('No items were cancelled in this period',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _table() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: AppResponsive.tableColumnSpacing(context),
            headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
            columns: [
              _col('Date'),
              _col('Item'),
              _col('Qty'),
              _col('Amount'),
              _col('Reason'),
              _col('Staff'),
            ],
            rows: _filtered.map((r) {
              final name = r.variantName != null && r.variantName!.isNotEmpty
                  ? '${r.itemName} (${r.variantName})'
                  : r.itemName;
              return DataRow(cells: [
                DataCell(Text(DateFormat('dd/MM hh:mm a').format(r.timestamp),
                    style: GoogleFonts.poppins(fontSize: 12))),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                )),
                DataCell(Text('${r.quantity}', style: GoogleFonts.poppins(fontSize: 13))),
                DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(r.amount)}',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
                DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(r.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13)),
                )),
                DataCell(Text(r.staffName ?? '—', style: GoogleFonts.poppins(fontSize: 13))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
        label: Text(label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Future<void> _export() async {
    if (_filtered.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }
    final headers = ['Date & Time', 'Item', 'Qty', 'Amount', 'Reason', 'Staff', 'KOT'];
    final data = _filtered
        .map((r) => [
              ReportExportService.formatDateTime(r.timestamp),
              r.variantName != null && r.variantName!.isNotEmpty
                  ? '${r.itemName} (${r.variantName})'
                  : r.itemName,
              r.quantity.toString(),
              ReportExportService.formatCurrency(r.amount),
              r.reason,
              r.staffName ?? '—',
              r.kotNumber?.toString() ?? '—',
            ])
        .toList();
    final summary = {
      'Total Cancellations': _totalCount.toString(),
      'Total Items Qty': _totalQty.toString(),
      'Total Amount': ReportExportService.formatCurrency(_totalAmount),
      'Top Reason': _topReason,
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'item_cancellations_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Item Cancellation Report',
      headers: headers,
      data: data,
      summary: summary,
    );
  }
}
