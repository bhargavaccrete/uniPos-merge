import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_body.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_export_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_pagination.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_table.dart';
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
  double _totalDiscount = 0.0;

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
    double discountSum = 0.0;

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
      discountSum += report.totalDiscount;
    }

    setState(() {
      _filteredReports = results;
      _totalOpeningBalance = openingSum;
      _totalClosingBalance = closingSum;
      _totalDiscount = discountSum;
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
      'Discount',
      'Opening Balance',
      'Closing Balance',
      'Actual Cash',
      'Difference',
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
        ReportExportService.formatCurrency(report.totalDiscount),
        ReportExportService.formatCurrency(report.openingBalance),
        ReportExportService.formatCurrency(report.closingBalance),
        ReportExportService.formatCurrency(report.cashReconciliation.actualCash),
        ReportExportService.formatCurrency(report.cashReconciliation.difference),
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
      'Total Discount': ReportExportService.formatCurrency(_totalDiscount),
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
      appBar: reportAppBar(
        title: 'End of Day Reports',
        subtitle: 'View daily closing reports',
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final isDesktop = AppResponsive.isDesktop(context);

    return ReportBody(
      child: Column(
        children: [
            // Date Filter Card
            ReportCard(
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
              const Padding(padding: EdgeInsets.all(50), child: ReportLoading())
            else if (_filteredReports.isEmpty)
              const ReportEmptyState(
                icon: Icons.event_available,
                title: 'No EOD Reports',
                message: 'No End of Day Report found for selected date',
              )
            else ...[
              _buildSummaryCards(context),
              AppResponsive.verticalSpace(context),
              ReportExportButton(onPressed: _exportReport),
              AppResponsive.verticalSpace(context),
              _buildReportsTable(context, isTablet),
              ReportPagination(
                currentPage: _currentPage,
                rowsPerPage: _rowsPerPage,
                totalCount: _filteredReports.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                unit: 'reports',
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return ReportSummaryRow(cards: [
      ReportSummaryCard(
        title: 'Reports',
        value: _filteredReports.length.toString(),
        icon: Icons.event_note,
        color: AppColors.primary,
      ),
      ReportSummaryCard(
        title: 'Opening Bal.',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalOpeningBalance)}',
        icon: Icons.account_balance_wallet,
        color: Colors.blue,
      ),
      ReportSummaryCard(
        title: 'Closing Bal.',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalClosingBalance)}',
        icon: Icons.monetization_on,
        color: Colors.green,
      ),
      ReportSummaryCard(
        title: 'Discount',
        value: '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_totalDiscount)}',
        icon: Icons.percent_rounded,
        color: Colors.orange,
      ),
    ]);
  }

  Widget _buildReportsTable(BuildContext context, bool isTablet) {
    final cellFontSize = AppResponsive.smallFontSize(context);

    return ReportTable(
      columns: [
        // 'Closing Date' was fabricated (date + 8 hours); replaced with 'Total Sales'.
        ReportTable.column(context, 'Date'),
        ReportTable.column(context, 'Total Sales', numeric: true),
        ReportTable.column(context, 'Opening', numeric: true),
        ReportTable.column(context, 'Closing', numeric: true),
        ReportTable.column(context, 'Actual Cash', numeric: true),
        ReportTable.column(context, 'Difference', numeric: true),
        ReportTable.column(context, 'Cash', numeric: true),
        ReportTable.column(context, 'Card', numeric: true),
        ReportTable.column(context, 'Online', numeric: true),
      ],
      rows: ReportPagination.pageSlice(_filteredReports, _currentPage, _rowsPerPage).map((report) {
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
                    // Difference (discrepancy)
                    DataCell(
                      () {
                        final diff = report.cashReconciliation.difference;
                        final isShortage = diff < -0.01;
                        final isOverage = diff > 0.01;
                        final color = isShortage ? Colors.red.shade700 : (isOverage ? Colors.green.shade700 : AppColors.textPrimary);
                        final prefix = isOverage ? '+' : '';
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppResponsive.getValue(context, mobile: 6.0, desktop: 10.0),
                            vertical: AppResponsive.getValue(context, mobile: 3.0, desktop: 5.0),
                          ),
                          decoration: BoxDecoration(
                            color: isShortage
                                ? Colors.red.withValues(alpha: 0.1)
                                : (isOverage ? Colors.green.withValues(alpha: 0.1) : Colors.transparent),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$prefix${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(diff.abs())}',
                            style: GoogleFonts.poppins(fontSize: cellFontSize, color: color, fontWeight: FontWeight.w600),
                          ),
                        );
                      }(),
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
    );
  }
}