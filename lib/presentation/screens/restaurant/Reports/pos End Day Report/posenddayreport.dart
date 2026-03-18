import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/common/report_export_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/common/app_responsive.dart';
import '../../../../widget/componets/common/report_summary_card.dart';

class Posenddayreport extends StatefulWidget {
  const Posenddayreport({super.key});

  @override
  State<Posenddayreport> createState() => _PosenddayreportState();
}

class _PosenddayreportState extends State<Posenddayreport> {
  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isDataLoaded = false;

  // Pre-computed state
  List<EndOfDayReport> _filteredReports = [];
  double _totalOpeningBalance = 0.0;
  double _totalClosingBalance = 0.0;

  // Pagination
  int _currentPage = 0;
  static const int _rowsPerPage = 50;

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports({bool forceReload = false}) async {
    if (_isDataLoaded && !forceReload) {
      _filterReports();
      return;
    }
    setState(() => _isLoading = true);
    await eodStore.loadEODReports();
    _isDataLoaded = true;
    _filterReports();
  }

  void _filterReports() {
    final results = <EndOfDayReport>[];
    double openingSum = 0.0;
    double closingSum = 0.0;

    for (final report in eodStore.eodReports) {
      if (_selectedDate != null) {
        if (report.date.year != _selectedDate!.year ||
            report.date.month != _selectedDate!.month ||
            report.date.day != _selectedDate!.day) {
          continue;
        }
      }
      results.add(report);
      openingSum += report.openingBalance;
      closingSum += report.closingBalance;
    }

    setState(() {
      _filteredReports = results;
      _totalOpeningBalance = openingSum;
      _totalClosingBalance = closingSum;
      _currentPage = 0;
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) {
    return showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    ).then((picked) {
      if (picked != null) {
        _selectedDate = picked;
        _filterReports();
      }
    });
  }

  Future<void> _exportReport() async {
    final filteredReports = _filteredReports;

    if (filteredReports.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Date',
      'Total Sales',
      'Opening Balance',
      'Closing Balance',
      'Actual Cash',
      'Cash Payment',
      'Card Payment',
      'Online Payment',
    ];

    final data = filteredReports.map((report) {
      double cashAmount = 0.0;
      double cardAmount = 0.0;
      double onlineAmount = 0.0;

      // FIX 2: Use += to accumulate; = would discard earlier entries of the same type.
      for (var payment in report.paymentSummaries) {
        if (payment.paymentType.toLowerCase() == 'cash') {
          cashAmount += payment.totalAmount;
        } else if (payment.paymentType.toLowerCase() == 'card') {
          cardAmount += payment.totalAmount;
        } else if (payment.paymentType.toLowerCase() == 'online' ||
            payment.paymentType.toLowerCase() == 'upi') {
          onlineAmount += payment.totalAmount;
        }
      }

      return [
        // FIX 1: Model has no closingDate — replaced with report date and totalSales.
        ReportExportService.formatDateTime(report.date),
        ReportExportService.formatCurrency(report.totalSales),
        ReportExportService.formatCurrency(report.openingBalance),
        ReportExportService.formatCurrency(report.closingBalance),
        ReportExportService.formatCurrency(report.cashReconciliation.actualCash),
        ReportExportService.formatCurrency(cashAmount),
        ReportExportService.formatCurrency(cardAmount),
        ReportExportService.formatCurrency(onlineAmount),
      ];
    }).toList();

    final totalOpening = _totalOpeningBalance;
    final totalClosing = _totalClosingBalance;

    String periodDisplay = _selectedDate != null
        ? DateFormat('dd MMM yyyy').format(_selectedDate!)
        : 'All Dates';

    final summary = {
      'Report Period': periodDisplay,
      'Total Reports': filteredReports.length.toString(),
      'Total Opening Balance': ReportExportService.formatCurrency(totalOpening),
      'Total Closing Balance': ReportExportService.formatCurrency(totalClosing),
      'Generated': ReportExportService.formatDateTime(DateTime.now()),
    };

    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'eod_reports_${_selectedDate != null ? DateFormat('yyyyMMdd').format(_selectedDate!) : 'all'}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      reportTitle: 'End of Day Reports - $periodDisplay',
      headers: headers,
      data: data,
      summary: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Modern Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back, color: AppColors.white, size: 24),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End of Day Reports',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.headingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'View daily closing reports',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 8.0, tablet: 10.0)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event_available,
                      size: AppResponsive.iconSize(context),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AppResponsive.verticalSpace(context, size: SpacingSize.small),

          Expanded(
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1200;

    return SingleChildScrollView(
      padding: AppResponsive.padding(context),
      child: AppResponsive.constrainedContent(
        context: context,
        child: Column(
          children: [
            // Date Filter Card
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter by Date',
                              style: GoogleFonts.poppins(
                                fontSize: isDesktop ? 18 : (isTablet ? 16 : 15),
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select a date to filter reports or view all',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _loadAllReports(forceReload: true),
                        icon: Icon(Icons.refresh),
                        color: AppColors.primary,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: EdgeInsets.all(isTablet ? 14 : 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDate != null
                                      ? DateFormat('dd MMM, yyyy').format(_selectedDate!)
                                      : 'All Dates',
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 14 : 13,
                                    color: _selectedDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                                Icon(Icons.calendar_today, size: isTablet ? 20 : 18, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            _selectedDate = null;
                            _filterReports();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceLight,
                            foregroundColor: AppColors.textSecondary,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 12,
                              vertical: isTablet ? 14 : 12,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: AppColors.divider),
                            ),
                          ),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_filteredReports.isEmpty)
              _buildEmptyState(context)
            else ...[
              _buildSummaryCards(context),
              SizedBox(height: 16),
              _buildExportButton(context, isTablet, isDesktop),
              SizedBox(height: 16),
              _buildReportsTable(context, isTablet),
              if (_filteredReports.length > _rowsPerPage) ...[
                SizedBox(height: 16),
                _buildPaginationControls(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 40.0, desktop: 60.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.getValue(context, mobile: 20.0, tablet: 24.0)),
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available,
                size: AppResponsive.getValue(context, mobile: 56.0, tablet: 64.0),
                color: AppColors.textSecondary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            Text(
              'No EOD Reports',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.small),
            Text(
              _selectedDate != null
                  ? 'No End of Day Report found for selected date'
                  : 'Complete End Day process to see reports here',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ReportSummaryCard(
              title: 'Reports',
              value: _filteredReports.length.toString(),
              icon: Icons.event_note,
              color: AppColors.primary,
            ),
          ),
          AppResponsive.horizontalSpace(context),
          Expanded(
            child: ReportSummaryCard(
              title: 'Opening Bal.',
              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalOpeningBalance)}',
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
            ),
          ),
          AppResponsive.horizontalSpace(context),
          Expanded(
            child: ReportSummaryCard(
              title: 'Closing Bal.',
              value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalClosingBalance)}',
              icon: Icons.monetization_on,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, bool isTablet, bool isDesktop) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportReport,
        icon: Icon(Icons.file_download_outlined, size: isDesktop ? 22 : (isTablet ? 20 : 18)),
        label: Text(
          'Export to Excel',
          style: GoogleFonts.poppins(
            fontSize: isDesktop ? 17 : (isTablet ? 16 : 15),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 18 : (isTablet ? 16 : 14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_filteredReports.length / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          icon: Icon(Icons.chevron_left),
          color: AppColors.primary,
        ),
        Text(
          'Page ${_currentPage + 1} of $totalPages',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
          icon: Icon(Icons.chevron_right),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildReportsTable(BuildContext context, bool isTablet) {
    final screenWidth = AppResponsive.screenWidth(context);
    final cellFontSize = AppResponsive.smallFontSize(context);
    final headerFontSize = AppResponsive.bodyFontSize(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth - AppResponsive.getValue(context, mobile: 32.0, tablet: 40.0),
            ),
            child: DataTable(
              columnSpacing: AppResponsive.getValue(context, mobile: 12.0, tablet: 20.0),
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
              headingRowHeight: AppResponsive.tableHeadingHeight(context),
              dataRowMinHeight: AppResponsive.tableRowMinHeight(context),
              dataRowMaxHeight: AppResponsive.tableRowMaxHeight(context),
              columns: [
                // FIX 1: 'Closing Date' was fabricated (date + 8 hours); replaced with 'Total Sales'.
                DataColumn(label: Text('Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Total Sales', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Opening', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Closing', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Actual Cash', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Cash', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Card', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Online', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
              ],
              rows: _filteredReports.skip(_currentPage * _rowsPerPage).take(_rowsPerPage).map((report) {
                final dateFormatter = DateFormat('dd/MM/yyyy');
                final timeFormatter = DateFormat('HH:mm');

                double cashAmount = 0.0;
                double cardAmount = 0.0;
                double onlineAmount = 0.0;

                // FIX 2: Use += to accumulate all entries of the same payment type.
                for (var payment in report.paymentSummaries) {
                  if (payment.paymentType.toLowerCase() == 'cash') {
                    cashAmount += payment.totalAmount;
                  } else if (payment.paymentType.toLowerCase() == 'card') {
                    cardAmount += payment.totalAmount;
                  } else if (payment.paymentType.toLowerCase() == 'online' ||
                      payment.paymentType.toLowerCase() == 'upi') {
                    onlineAmount += payment.totalAmount;
                  }
                }

                return DataRow(
                  cells: [
                    // FIX 1: Show report date; 'Closing Date' col replaced with 'Total Sales'.
                    DataCell(
                      Text(
                        '${dateFormatter.format(report.date)}\n${timeFormatter.format(report.date)}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(report.totalSales)}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(report.openingBalance)}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(report.closingBalance)}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(report.cashReconciliation.actualCash)}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(cashAmount)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(cardAmount)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.getValue(context, mobile: 8.0, desktop: 12.0),
                          vertical: AppResponsive.getValue(context, mobile: 4.0, desktop: 6.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(onlineAmount)}',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}