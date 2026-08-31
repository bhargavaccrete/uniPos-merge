import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = true;

  final ReportService _reportService = ReportService();

  // Report data — all aggregation now happens in ReportService; this screen
  // only renders what it is handed.
  int _saleCount = 0;
  int _lineCount = 0;
  double _totalTaxableAmount = 0;
  double _totalGstAmount = 0;
  double _totalCgstAmount = 0;
  double _totalSgstAmount = 0;
  Map<double, _GstRateSummary> _gstByRate = {};
  Map<String, _ProductGstSummary> _gstByProduct = {};
  Map<String, _CategoryGstSummary> _gstByCategory = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      // Exclusive end — the service's window rule. The old `±1 day` fudge on
      // both sides silently pulled in neighbouring days.
      final start = DateTime(
        _dateRange.start.year,
        _dateRange.start.month,
        _dateRange.start.day,
      );
      final end = DateTime(
        _dateRange.end.year,
        _dateRange.end.month,
        _dateRange.end.day,
      ).add(const Duration(days: 1));

      final data = await _reportService.getGstSummaryReport(
        startDate: start,
        endDate: end,
      );
      if (!mounted) return;

      _saleCount = data['saleCount'] as int;
      _lineCount = data['lineCount'] as int;
      _totalTaxableAmount = data['totalTaxableAmount'] as double;
      _totalGstAmount = data['totalGstAmount'] as double;
      _totalCgstAmount = data['totalCgstAmount'] as double;
      _totalSgstAmount = data['totalSgstAmount'] as double;

      _gstByRate = {
        for (final row in (data['byRate'] as List).cast<Map<String, dynamic>>())
          row['rate'] as double: _GstRateSummary.fromMap(row),
      };
      _gstByProduct = {
        for (final row
            in (data['byProduct'] as List).cast<Map<String, dynamic>>())
          row['productId'] as String: _ProductGstSummary.fromMap(row),
      };
      _gstByCategory = {
        for (final row
            in (data['byCategory'] as List).cast<Map<String, dynamic>>())
          row['categoryName'] as String: _CategoryGstSummary.fromMap(row),
      };
    } catch (e) {
      debugPrint('Error loading GST report: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF4CAF50)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'GST Reports',
        // Tabs read on the primary fill, matching every other AppBar.
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'By Rate'),
            Tab(text: 'By Product'),
            Tab(text: 'By Category'),
          ],
        ),
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxContentWidth(context),
        child: Column(
          children: [
            if (!TaxFeature.enabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFFFF8E1),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFFB28900),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tax is currently disabled for new sales. This report reflects '
                        'historical data collected while tax was active.',
                        style: TextStyle(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: Color(0xFF7A5C00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Date Range Selector
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                              style: TextStyle(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF6B6B6B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSummaryTab(),
                        _buildByRateTab(),
                        _buildByProductTab(),
                        _buildByCategoryTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Total Sales', '$_saleCount'),
                const SizedBox(height: 12),
                _buildSummaryRow('Total Items Sold', '$_lineCount'),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total Taxable Amount',
                  '${CurrencyHelper.currentSymbol}${_totalTaxableAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  'Total CGST',
                  '${CurrencyHelper.currentSymbol}${_totalCgstAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  'Total SGST',
                  '${CurrencyHelper.currentSymbol}${_totalSgstAmount.toStringAsFixed(2)}',
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total GST Collected',
                  '${CurrencyHelper.currentSymbol}${_totalGstAmount.toStringAsFixed(2)}',
                  isBold: true,
                  fontSize: AppResponsive.subheadingFontSize(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // GST Rate Distribution
          Text(
            'GST Distribution by Rate',
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              children: _gstByRate.entries.map((entry) {
                final summary = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${entry.key.toInt()}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${CurrencyHelper.currentSymbol}${summary.totalGst.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${summary.itemCount} items',
                              style: TextStyle(
                                fontSize: AppResponsive.captionFontSize(
                                  context,
                                ),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildByRateTab() {
    final sortedRates = _gstByRate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRates.length,
      itemBuilder: (context, index) {
        final entry = sortedRates[index];
        final summary = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GST ${entry.key.toInt()}%',
                      style: TextStyle(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.itemCount} items',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'Taxable Amount',
                '${CurrencyHelper.currentSymbol}${summary.taxableAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'CGST (${(entry.key / 2).toStringAsFixed(1)}%)',
                '${CurrencyHelper.currentSymbol}${summary.cgst.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'SGST (${(entry.key / 2).toStringAsFixed(1)}%)',
                '${CurrencyHelper.currentSymbol}${summary.sgst.toStringAsFixed(2)}',
              ),
              const Divider(height: 16),
              _buildDetailRow(
                'Total GST',
                '${CurrencyHelper.currentSymbol}${summary.totalGst.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByProductTab() {
    final sortedProducts = _gstByProduct.values.toList()
      ..sort((a, b) => b.totalGst.compareTo(a.totalGst));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedProducts.length,
      itemBuilder: (context, index) {
        final summary = sortedProducts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.productName,
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    'Qty: ${summary.quantity}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxable: ${CurrencyHelper.currentSymbol}${summary.taxableAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GST Rate: ${summary.avgGstRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GST: ${CurrencyHelper.currentSymbol}${summary.totalGst.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByCategoryTab() {
    final sortedCategories = _gstByCategory.values.toList()
      ..sort((a, b) => b.totalGst.compareTo(a.totalGst));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final summary = sortedCategories[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.categoryName,
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${summary.gstRate.toInt()}%',
                      style: TextStyle(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailRow('Items Sold', '${summary.itemCount}'),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Taxable Amount',
                '${CurrencyHelper.currentSymbol}${summary.taxableAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _buildDetailRow('CGST', '${CurrencyHelper.currentSymbol}${summary.cgst.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('SGST', '${CurrencyHelper.currentSymbol}${summary.sgst.toStringAsFixed(2)}'),
              const Divider(height: 16),
              _buildDetailRow(
                'Total GST',
                '${CurrencyHelper.currentSymbol}${summary.totalGst.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double? fontSize,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            color: isBold ? const Color(0xFF1A1A1A) : Colors.grey[600],
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: isBold ? const Color(0xFF4CAF50) : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

// Helper classes for summaries
// Read-only views over ReportService.getGstSummaryReport. They used to do the
// accumulating themselves; now they only carry the result.

class _GstRateSummary {
  final double rate;
  final int itemCount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double totalGst;

  const _GstRateSummary({
    required this.rate,
    required this.itemCount,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.totalGst,
  });

  factory _GstRateSummary.fromMap(Map<String, dynamic> map) => _GstRateSummary(
    rate: (map['rate'] as num).toDouble(),
    itemCount: (map['itemCount'] as num).toInt(),
    taxableAmount: (map['taxableAmount'] as num).toDouble(),
    cgst: (map['cgst'] as num).toDouble(),
    sgst: (map['sgst'] as num).toDouble(),
    totalGst: (map['totalGst'] as num).toDouble(),
  );
}

class _ProductGstSummary {
  final String productId;
  final String productName;
  final int quantity;
  final double taxableAmount;
  final double totalGst;
  final double avgGstRate;

  const _ProductGstSummary({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.taxableAmount,
    required this.totalGst,
    required this.avgGstRate,
  });

  factory _ProductGstSummary.fromMap(Map<String, dynamic> map) =>
      _ProductGstSummary(
        productId: map['productId'] as String,
        productName: map['productName'] as String,
        quantity: (map['quantity'] as num).toInt(),
        taxableAmount: (map['taxableAmount'] as num).toDouble(),
        totalGst: (map['totalGst'] as num).toDouble(),
        avgGstRate: (map['avgGstRate'] as num).toDouble(),
      );
}

class _CategoryGstSummary {
  final String categoryName;
  final double gstRate;
  final int itemCount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double totalGst;

  const _CategoryGstSummary({
    required this.categoryName,
    required this.gstRate,
    required this.itemCount,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.totalGst,
  });

  factory _CategoryGstSummary.fromMap(Map<String, dynamic> map) =>
      _CategoryGstSummary(
        categoryName: map['categoryName'] as String,
        gstRate: (map['gstRate'] as num).toDouble(),
        itemCount: (map['itemCount'] as num).toInt(),
        taxableAmount: (map['taxableAmount'] as num).toDouble(),
        cgst: (map['cgst'] as num).toDouble(),
        sgst: (map['sgst'] as num).toDouble(),
        totalGst: (map['totalGst'] as num).toDouble(),
      );
}
