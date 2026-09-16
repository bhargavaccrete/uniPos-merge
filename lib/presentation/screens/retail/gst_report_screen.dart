import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/config/tax_feature.dart';
import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_notice.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';

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

  // Resolved once. The country cannot change while this screen is open, and
  // these would otherwise hit the repository once per row of every list.
  //
  // PRESENTATION ONLY — the figures below are identical in every country; this
  // decides what they are called and whether the CGST/SGST halves, which are an
  // Indian intra-state concept, may be shown at all.
  late final String _taxName = TaxLabelRule.name;
  late final bool _splitsTax = TaxLabelRule.splitsIntoComponents;
  late final ({String first, String second})? _taxComponents =
      TaxLabelRule.components;

  // Report data — all aggregation now happens in ReportService; this screen
  // only renders what it is handed.
  int _saleCount = 0;

  /// Signed UNITS sold, not rows. `lineCount` counted a credit note's lines as
  /// +1 while every money figure beside it was netted, so a fully-credited
  /// period read "Total Items Sold: 20" against zero tax.
  double _totalQuantity = 0;

  /// Sales dropped because their date could not be read — and therefore missing
  /// from the tax totals above. Computed all along; never shown until now.
  int _skippedRows = 0;
  double _totalTaxableAmount = 0;
  double _totalGstAmount = 0;
  double _totalCgstAmount = 0;
  double _totalSgstAmount = 0;
  Map<double, _GstRateSummary> _gstByRate = {};
  Map<String, _ProductGstSummary> _gstByProduct = {};
  Map<double, _CategoryGstSummary> _gstByCategory = {};

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
      _totalQuantity = (data['totalQuantity'] as num).toDouble();
      _skippedRows = (data['skippedRows'] as num?)?.toInt() ?? 0;
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
      // Keyed on the RATE. Keyed on `categoryName`, two bands whose names
      // format alike would collide here and one would be silently dropped.
      _gstByCategory = {
        for (final row
            in (data['byCategory'] as List).cast<Map<String, dynamic>>())
          (row['gstRate'] as num).toDouble(): _CategoryGstSummary.fromMap(row),
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
            colorScheme: const ColorScheme.light(primary: AppColors.success),
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
        title: TaxLabelRule.reportTitle,
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
      // MoneyScope: one subscription for the surface, so every figure
      // re-renders when currency or decimal precision changes.
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxContentWidth(context),
          child: Column(
            children: [
              if (!TaxFeature.enabled)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                  color: const Color(0xFFFFF8E1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: AppResponsive.smallIconSize(context),
                        color: Color(0xFFB28900),
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Expanded(
                        child: Text(
                          'Tax is currently disabled for new sales. This report reflects '
                          'historical data collected while tax was active.',
                          style: GoogleFonts.poppins(
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
                padding: AppResponsive.cardPadding(context),
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
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.smallBorderRadius(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: AppResponsive.smallIconSize(context),
                                color: AppColors.success,
                              ),
                              SizedBox(
                                width: AppResponsive.mediumSpacing(context),
                              ),
                              Text(
                                '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_skippedRows > 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppResponsive.cardPadding(context).left,
                    0,
                    AppResponsive.cardPadding(context).left,
                    AppResponsive.largeSpacing(context),
                  ),
                  child: ReportNotice(
                    message:
                        '$_skippedRows sale${_skippedRows == 1 ? '' : 's'} '
                        'could not be dated and ${_skippedRows == 1 ? 'is' : 'are'} '
                        'excluded from every figure below.',
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
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: AppResponsive.cardPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Summary Card
          Container(
            padding: AppResponsive.padding(context),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Total Sales', '$_saleCount'),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildSummaryRow('Total Units Sold', formatQty(_totalQuantity)),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total Taxable Amount',
                  formatMoney(_totalTaxableAmount),
                ),
                // Outside India there are no components — VAT and US sales tax
                // are one figure, and the stored halves mean nothing.
                if (_splitsTax && _taxComponents != null) ...[
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _buildSummaryRow(
                    'Total ${_taxComponents.first}',
                    formatMoney(_totalCgstAmount),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  _buildSummaryRow(
                    'Total ${_taxComponents.second}',
                    formatMoney(_totalSgstAmount),
                  ),
                ],
                const Divider(height: 24),
                _buildSummaryRow(
                  'Total $_taxName Collected',
                  formatMoney(_totalGstAmount),
                  isBold: true,
                  fontSize: AppResponsive.subheadingFontSize(context),
                ),
              ],
            ),
          ),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),

          // GST Rate Distribution
          Text(
            '$_taxName Distribution by Rate',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Container(
            padding: AppResponsive.cardPadding(context),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: _gstByRate.entries.map((entry) {
                final summary = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: AppResponsive.mediumSpacing(context),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          GstService.formatGstRate(entry.key),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatMoney(summary.totalGst),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${summary.itemCount} lines',
                              style: GoogleFonts.poppins(
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
    // No sort: `ReportService` returns the rates ascending and the map above
    // preserves that order. One decision, one place.
    final sortedRates = _gstByRate.entries.toList();

    return ListView.builder(
      padding: AppResponsive.cardPadding(context),
      itemCount: sortedRates.length,
      itemBuilder: (context, index) {
        final entry = sortedRates[index];
        final summary = entry.value;
        return Container(
          margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
          padding: AppResponsive.cardPadding(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
            border: Border.all(color: AppColors.divider),
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
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_taxName ${GstService.formatGstRate(entry.key)}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    // LINES, not units: this counts sale rows, netted by sign.
                    '${summary.itemCount} lines',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'Taxable Amount',
                formatMoney(summary.taxableAmount),
              ),
              if (_splitsTax && _taxComponents != null) ...[
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _buildDetailRow(
                  '${_taxComponents.first} (${(entry.key / 2).toStringAsFixed(1)}%)',
                  formatMoney(summary.cgst),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _buildDetailRow(
                  '${_taxComponents.second} (${(entry.key / 2).toStringAsFixed(1)}%)',
                  formatMoney(summary.sgst),
                ),
              ],
              const Divider(height: 16),
              _buildDetailRow(
                'Total $_taxName',
                formatMoney(summary.totalGst),
                isBold: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildByProductTab() {
    // Ordered by the service: most tax first, product id as the tie-break.
    final sortedProducts = _gstByProduct.values.toList();

    return ListView.builder(
      padding: AppResponsive.cardPadding(context),
      itemCount: sortedProducts.length,
      itemBuilder: (context, index) {
        final summary = sortedProducts[index];
        return Container(
          margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
          padding: AppResponsive.cardPadding(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.productName,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    // `formatQty`, not the raw double: 2.5 kg used to be
                    // truncated to "2", and a product sold only in half-kilos
                    // read "Qty: 0".
                    'Qty: ${formatQty(summary.quantity)}',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxable: ${formatMoney(summary.taxableAmount)}',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$_taxName Rate: ${summary.avgGstRate.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
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
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_taxName: ${formatMoney(summary.totalGst)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
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
    // Ordered by the service: most tax first, rate as the tie-break.
    final sortedCategories = _gstByCategory.values.toList();

    return ListView.builder(
      padding: AppResponsive.cardPadding(context),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final summary = sortedCategories[index];
        return Container(
          margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
          padding: AppResponsive.cardPadding(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.categoryName,
                      style: GoogleFonts.poppins(
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
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      GstService.formatGstRate(summary.gstRate),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildDetailRow('Sale Lines', '${summary.itemCount}'),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              _buildDetailRow(
                'Taxable Amount',
                formatMoney(summary.taxableAmount),
              ),
              if (_splitsTax && _taxComponents != null) ...[
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _buildDetailRow(
                  _taxComponents.first,
                  formatMoney(summary.cgst),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _buildDetailRow(
                  _taxComponents.second,
                  formatMoney(summary.sgst),
                ),
              ],
              const Divider(height: 16),
              _buildDetailRow(
                'Total $_taxName',
                formatMoney(summary.totalGst),
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
          style: GoogleFonts.poppins(
            fontSize: fontSize ?? AppResponsive.bodyFontSize(context),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: fontSize ?? AppResponsive.bodyFontSize(context),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
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
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: isBold ? AppColors.textPrimary : Colors.grey[600],
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: isBold ? AppColors.success : AppColors.textPrimary,
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

  /// A `double` — retail sells by weight. Read back `as int` this truncated
  /// 2.5 to 2 and 0.5 to 0.
  final double quantity;
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
        quantity: (map['quantity'] as num).toDouble(),
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
