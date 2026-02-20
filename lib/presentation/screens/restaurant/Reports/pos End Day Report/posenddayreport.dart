import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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

class Posenddayreport extends StatefulWidget {
  const Posenddayreport({super.key});

  @override
  State<Posenddayreport> createState() => _PosenddayreportState();
}

class _PosenddayreportState extends State<Posenddayreport> {
  DateTime? _selectedDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports() async {
    setState(() => _isLoading = true);
    await eodStore.loadEODReports();
    setState(() => _isLoading = false);
  }

  List<EndOfDayReport> _getFilteredReports() {
    if (_selectedDate == null) {
      return eodStore.eodReports;
    }

    return eodStore.eodReports.where((report) {
      return report.date.year == _selectedDate!.year &&
          report.date.month == _selectedDate!.month &&
          report.date.day == _selectedDate!.day;
    }).toList();
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
        setState(() {
          _selectedDate = picked;
        });
      }
    });
  }

  Future<void> _exportReport() async {
    final filteredReports = _getFilteredReports();

    if (filteredReports.isEmpty) {
      NotificationService.instance.showError('No data to export');
      return;
    }

    final headers = [
      'Opening Date',
      'Closing Date',
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

      for (var payment in report.paymentSummaries) {
        if (payment.paymentType.toLowerCase() == 'cash') {
          cashAmount = payment.totalAmount;
        } else if (payment.paymentType.toLowerCase() == 'card') {
          cardAmount = payment.totalAmount;
        } else if (payment.paymentType.toLowerCase() == 'online' ||
            payment.paymentType.toLowerCase() == 'upi') {
          onlineAmount = payment.totalAmount;
        }
      }

      return [
        ReportExportService.formatDateTime(report.date),
        ReportExportService.formatDateTime(report.date.add(Duration(hours: 8))),
        ReportExportService.formatCurrency(report.openingBalance),
        ReportExportService.formatCurrency(report.closingBalance),
        ReportExportService.formatCurrency(report.cashReconciliation.actualCash),
        ReportExportService.formatCurrency(cashAmount),
        ReportExportService.formatCurrency(cardAmount),
        ReportExportService.formatCurrency(onlineAmount),
      ];
    }).toList();

    final totalOpening = filteredReports.fold<double>(0, (sum, r) => sum + r.openingBalance);
    final totalClosing = filteredReports.fold<double>(0, (sum, r) => sum + r.closingBalance);

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
                      color: AppColors.primary.withValues(alpha: 0.1 * AppColors.primary.a),
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
                        onPressed: _loadAllReports,
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
                            setState(() {
                              _selectedDate = null;
                            });
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

            // Observer for reactive updates
            Observer(
              builder: (_) {
                if (_isLoading || eodStore.isLoading) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                final filteredReports = _getFilteredReports();

                if (filteredReports.isEmpty) {
                  return _buildEmptyState(context);
                }

                return Column(
                  children: [
                    _buildSummaryCards(context, filteredReports, isTablet, isDesktop),
                    SizedBox(height: 16),
                    _buildExportButton(context, isTablet, isDesktop),
                    SizedBox(height: 16),
                    _buildReportsTable(context, filteredReports, isTablet),
                  ],
                );
              },
            ),
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

  Widget _buildSummaryCards(BuildContext context, List<EndOfDayReport> reports, bool isTablet, bool isDesktop) {
    double totalOpeningBalance = 0.0;
    double totalClosingBalance = 0.0;

    for (var report in reports) {
      totalOpeningBalance += report.openingBalance;
      totalClosingBalance += report.closingBalance;
    }

    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Reports',
            reports.length.toString(),
            Icons.event_note,
            AppColors.primary,
            isTablet,
            isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Opening Balance',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalOpeningBalance)}',
            Icons.account_balance_wallet,
            Colors.blue,
            isTablet,
            isDesktop,
          ),
        ),
        SizedBox(width: isDesktop ? 24 : 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Closing Balance',
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalClosingBalance)}',
            Icons.monetization_on,
            Colors.green,
            isTablet,
            isDesktop,
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color iconColor,
    bool isTablet,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
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
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: isDesktop ? 16 : (isTablet ? 14 : 11),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : (isTablet ? 8 : 5)),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isDesktop ? 28 : (isTablet ? 22 : 14),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: isDesktop ? 32 : (isTablet ? 24 : 20),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
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

  Widget _buildReportsTable(BuildContext context, List<EndOfDayReport> reports, bool isTablet) {
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
                DataColumn(label: Text('Opening Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Closing Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary))),
                DataColumn(label: Text('Opening', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Closing', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Actual Cash', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Cash', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Card', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
                DataColumn(label: Text('Online', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: headerFontSize, color: AppColors.textPrimary)), numeric: true),
              ],
              rows: reports.map((report) {
                final dateFormatter = DateFormat('dd/MM/yyyy');
                final timeFormatter = DateFormat('HH:mm');

                double cashAmount = 0.0;
                double cardAmount = 0.0;
                double onlineAmount = 0.0;

                for (var payment in report.paymentSummaries) {
                  if (payment.paymentType.toLowerCase() == 'cash') {
                    cashAmount = payment.totalAmount;
                  } else if (payment.paymentType.toLowerCase() == 'card') {
                    cardAmount = payment.totalAmount;
                  } else if (payment.paymentType.toLowerCase() == 'online' ||
                      payment.paymentType.toLowerCase() == 'upi') {
                    onlineAmount = payment.totalAmount;
                  }
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '${dateFormatter.format(report.date)}\n${timeFormatter.format(report.date)}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${dateFormatter.format(report.date)}\n${timeFormatter.format(report.date.add(Duration(hours: 8)))}',
                        style: GoogleFonts.poppins(fontSize: cellFontSize, color: AppColors.textPrimary),
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