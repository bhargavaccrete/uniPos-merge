import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_date_range_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_period_filter_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
import '../../../../widget/componets/common/report_summary_card.dart';
import '../../../../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../tabbar/orderDetails.dart';
import '../../../../../util/restaurant/refund_state.dart';
import 'package:billberrylite/util/restaurant/report_history_window.dart';

class RefundDetails extends StatefulWidget {
  const RefundDetails({super.key});

  @override
  State<RefundDetails> createState() => _RefundDetailsState();
}

class _RefundDetailsState extends State<RefundDetails> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: reportAppBar(
        title: 'Refund Details',
        subtitle: 'View refunds across different periods',
      ),
      body: Column(
        children: [
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          ReportPeriodFilterBar(
            selected: _selectedPeriod,
            onSelected: (p) => setState(() => _selectedPeriod = p),
            featureNoun: 'refunds',
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.small),
          Expanded(child: RefundDataView(period: _selectedPeriod)),
        ],
      ),
    );
  }
}

class RefundDataView extends StatefulWidget {
  final ReportPeriod period;
  const RefundDataView({super.key, required this.period});

  @override
  State<RefundDataView> createState() => _RefundDataViewState();
}

class _RefundDataViewState extends State<RefundDataView> {
  List<PastOrderModel> _refundedOrders = [];
  double _totalRefundAmount = 0.0;
  int _totalRefundCount = 0;
  String _mostCommonReason = '-';
  bool _isLoading = true;
  bool _isDataLoaded = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadAndFilter();
  }

  @override
  void didUpdateWidget(covariant RefundDataView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _startDate = null;
      _endDate = null;
      _filterFromMemory();
    }
  }

  Future<void> _loadAndFilter() async {
    if (!_isDataLoaded) {
      setState(() => _isLoading = true);
      await pastOrderStore.loadPastOrders();
      _isDataLoaded = true;
    }
    _filterFromMemory();
  }

  /// Single-pass filter with pre-computed boundaries — matches total sales pattern.
  void _filterFromMemory() {
    final now = DateTime.now();
    final results = <PastOrderModel>[];
    double refundTotal = 0.0;
    final reasonCounts = <String, int>{};

    // Pre-compute date boundaries
    final isCustom = widget.period == ReportPeriod.custom;
    final hasCustomRange = isCustom && _startDate != null && _endDate != null;

    late final DateTime startBound;
    late final DateTime endBound;

    if (!isCustom) {
      // Same helper the filter's history lock uses - they cannot disagree.
      startBound = reportPeriodStartBound(widget.period, now);
      endBound = reportPeriodEndBound(widget.period, now);
    } else if (hasCustomRange) {
      startBound = _startDate!;
      endBound = _endDate!.add(const Duration(days: 1));
    }

    // Plan data-scope: clamp the visible history window (reports.history_limit_days).
    final cutoff = ReportHistoryWindow.cutoff;

    // Single pass: date filter + status filter + accumulate totals + reason counts
    for (final order in pastOrderStore.pastOrders) {
      final status = order.orderStatus ?? '';
      final hasRefund = RefundInfo.hasRefund(order);
      final isRefundStatus = status == 'FULLY_REFUNDED' || status == 'PARTIALLY_REFUNDED';
      final isRefundedVoided = status == 'VOIDED' && hasRefund;
      if (!isRefundStatus && !isRefundedVoided) continue;
      if (order.refundedAt == null) continue;
      if (cutoff != null && order.refundedAt!.isBefore(cutoff)) continue;
      if (isCustom && !hasCustomRange) continue;

      if (order.refundedAt!.isBefore(startBound) || !order.refundedAt!.isBefore(endBound)) {
        continue;
      }

      results.add(order);
      refundTotal += order.refundAmount ?? 0.0;

      // Track reason counts for most-common computation
      if (order.refundReason != null && order.refundReason!.isNotEmpty) {
        final lines = order.refundReason!.split('\n');
        final reason = lines.isNotEmpty ? lines.last.trim() : '';
        if (reason.isNotEmpty) {
          reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
        }
      }
    }

    // Sort by refund date descending
    results.sort((a, b) =>
        (b.refundedAt ?? DateTime(2000)).compareTo(a.refundedAt ?? DateTime(2000)));

    // Compute most common reason
    String topReason = '-';
    if (reasonCounts.isNotEmpty) {
      var best = reasonCounts.entries.first;
      for (final entry in reasonCounts.entries) {
        if (entry.value > best.value) best = entry;
      }
      topReason = best.key;
    }

    setState(() {
      _refundedOrders = results;
      _totalRefundCount = results.length;
      _totalRefundAmount = refundTotal;
      _mostCommonReason = topReason;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _exportReport() async {
    if (_refundedOrders.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    // Prepare headers
    final headers = [
      'Date & Time',
      'Bill #',
      'Customer',
      'Payment Method',
      'Order Type',
      'Refund Amount',
      'Refunded By',
      'Reason'
    ];

    // Prepare data rows
    final data = _refundedOrders.map((order) {
      String reason = '';
      if (order.refundReason != null && order.refundReason!.isNotEmpty) {
        final lines = order.refundReason!.split('\n');
        reason = lines.isNotEmpty ? lines.last.trim() : '';
      }

      return [
        ReportExportService.formatDateTime(order.refundedAt),
        order.billNumber?.toString() ?? order.id.substring(0, 8),
        order.customerName ?? 'Guest',
        order.paymentmode ?? 'N/A',
        order.orderType ?? 'N/A',
        ReportExportService.formatCurrency(order.refundAmount ?? 0.0),
        order.refundedBy ?? '—',
        reason,
      ];
    }).toList();

    // Prepare summary
    final periodName = _getPeriodDisplayName();
    final summary = {
      'Report Period': periodName,
      'Total Refunds': _totalRefundCount.toString(),
      'Total Refund Amount': ReportExportService.formatCurrency(_totalRefundAmount),
      'Most Common Reason': _mostCommonReason,
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    // Show export dialog
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'refund_details_${widget.period.name.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'Refund Details - $periodName',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  String _getPeriodDisplayName() {
    if (widget.period != ReportPeriod.custom) return widget.period.label;
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }
    return 'Custom Period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const ReportLoading();

    if (widget.period == ReportPeriod.custom) {
      return _buildCustomDateSelector();
    }

    return _buildReportUI();
  }

  Widget _buildCustomDateSelector() {
    return ReportBody(
      child: Column(
        children: [
          ReportDateRangeCard(
            initialStart: _startDate,
            initialEnd: _endDate,
            onApply: (start, end) {
              setState(() {
                _startDate = start;
                _endDate = end;
              });
              _loadAndFilter();
            },
          ),
          if (_startDate != null && _endDate != null) ...[
            AppResponsive.verticalSpace(context),
            if (_refundedOrders.isNotEmpty)
              _buildReportContent()
            else
              const ReportEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Refunds',
                message: 'No refunds found for the selected date range',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportUI() {
    if (_refundedOrders.isEmpty) {
      return const ReportEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Refunds',
        message: 'No refunds found for this period',
      );
    }

    return ReportBody(child: _buildReportContent());
  }

  Widget _buildReportContent() {
    return Column(
      children: [
        _buildSummaryCards(),
        AppResponsive.verticalSpace(context),
        ReportExportButton(onPressed: _exportReport),
        AppResponsive.verticalSpace(context),
        _buildDataTable(),
        ReportPagination(
          currentPage: _currentPage,
          rowsPerPage: _rowsPerPage,
          totalCount: _refundedOrders.length,
          onPageChanged: (page) => setState(() => _currentPage = page),
          unit: 'refunds',
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        ReportSummaryRow(cards: [
          ReportSummaryCard(
            title: 'Total Refunds',
            value: _totalRefundCount.toString(),
            icon: Icons.receipt_long,
            color: AppColors.primary,
          ),
          ReportSummaryCard(
            title: 'Total Amount',
            value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalRefundAmount)}',
            icon: Icons.monetization_on,
            color: Colors.red,
          ),
        ]),
        AppResponsive.verticalSpace(context),
        ReportSummaryCard(
          title: 'Common Reason',
          value: _mostCommonReason,
          icon: Icons.info_outline,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    final cellFontSize = AppResponsive.smallFontSize(context);
    final pageOrders = ReportPagination.pageSlice(_refundedOrders, _currentPage, _rowsPerPage);

    return ReportTable(
      columns: [
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Order ID'),
        ReportTable.column(context, 'Customer'),
        ReportTable.column(context, 'Payment'),
        ReportTable.column(context, 'Type'),
        ReportTable.column(context, 'Amount', numeric: true),
        ReportTable.column(context, 'Refunded By'),
        ReportTable.column(context, 'Reason'),
      ],
      rows: pageOrders.map((order) {
                String reason = '-';
                if (order.refundReason != null && order.refundReason!.isNotEmpty) {
                  final lines = order.refundReason!.split('\n');
                  reason = lines.isNotEmpty ? lines.last.trim() : '-';
                }

                return DataRow(
                  onSelectChanged: (selected) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Orderdetails(Order: order),
                      ),
                    );
                  },
                  cells: [
                    DataCell(Text(order.refundedAt != null ? DateFormat('dd-MM-yy\nHH:mm').format(order.refundedAt!) : 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(Text('#${order.id?.substring(0, 8) ?? 'N/A'}...', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
                    DataCell(Text(order.customerName ?? '-', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(order.paymentmode ?? 'N/A', style: GoogleFonts.poppins(fontSize: AppResponsive.captionFontSize(context), color: AppColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    DataCell(Text(order.orderType ?? 'N/A', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textSecondary))),
                    DataCell(Text('${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(order.refundAmount ?? 0.0)}', style: GoogleFonts.poppins(fontSize: cellFontSize, color: Colors.red.shade600, fontWeight: FontWeight.w600))),
                    DataCell(Text(order.refundedBy ?? '—', style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary))),
                    DataCell(
                      Container(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Text(reason, style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis, maxLines: 2),
                      ),
                    ),
                  ],
                );
      }).toList(),
    );
  }
}