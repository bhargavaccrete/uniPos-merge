import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/domain/services/retail/eod_history_export.dart';
import 'package:billberrylite/domain/services/retail/eod_settlement_print.dart';

/// EOD Report Detail Screen - Shows detailed view of a single EOD report
class EODReportDetailScreen extends StatelessWidget {
  final EndOfDayReport report;

  const EODReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, EEEE');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'EOD Report Details',
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: 'Reprint settlement',
            onPressed: _reprint,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export',
            onPressed: () => _export(context),
          ),
        ],
      ),
      // Every amount here goes through formatMoney; MoneyScope is the single
      // subscription that re-renders them when the store's currency or decimal
      // precision changes. These two screens were the last holdouts still
      // hard-coding the symbol and two decimals.
      body: MoneyScope(
        child: AppResponsive.constrainedContent(
          context: context,
          alignment: Alignment.topCenter,
          maxWidth: AppResponsive.maxCardWidth(context),
          child: SingleChildScrollView(
            padding: AppResponsive.cardPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Container(
                  padding: AppResponsive.cardPadding(context),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EOD Report',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        dateFormat.format(report.date),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.headingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Opening/Closing Balance
                _buildSection(
                  context,
                  'Balance Summary',
                  Icons.account_balance_wallet,
                  Colors.teal,
                  [
                    _buildRow(
                      context,
                      'Opening Balance',
                      formatMoney(report.openingBalance),
                    ),
                    _buildRow(
                      context,
                      'Closing Balance',
                      formatMoney(report.closingBalance),
                    ),
                  ],
                ),

                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Sales Summary
                _buildSection(
                  context,
                  'Sales Summary',
                  Icons.shopping_cart,
                  Colors.green,
                  [
                    _buildRow(
                      context,
                      'Total Sales',
                      formatMoney(report.totalSales),
                      isBold: true,
                    ),
                    _buildRow(
                      context,
                      'Total Transactions',
                      '${report.totalOrderCount}',
                    ),
                    if (report.totalDiscount > 0)
                      _buildRow(
                        context,
                        'Discount',
                        formatMoney(report.totalDiscount),
                        color: Colors.red,
                      ),
                    if (report.totalRefunds > 0)
                      _buildRow(
                        context,
                        'Refunds',
                        formatMoney(report.totalRefunds),
                        color: Colors.orange,
                      ),
                  ],
                ),

                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Payment Breakdown
                if (report.paymentSummaries.isNotEmpty) ...[
                  _buildSection(
                    context,
                    'Payment Breakdown',
                    Icons.payment,
                    Colors.blue,
                    report.paymentSummaries.map((payment) {
                      return _buildRow(
                        context,
                        '${payment.paymentType} (${payment.transactionCount} txns)',
                        formatMoney(payment.totalAmount),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Tax Summary
                if (_taxRows(report).isNotEmpty) ...[
                  _buildSection(
                    context,
                    'Tax Summary',
                    Icons.receipt_long,
                    Colors.purple,
                    [
                      ..._taxRows(report).map((tax) {
                        return _buildRow(
                          context,
                          tax.label,
                          formatMoney(tax.amount),
                        );
                      }),
                      const Divider(),
                      _buildRow(
                        context,
                        'Total Tax',
                        formatMoney(report.totalTax),
                        isBold: true,
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Expenses
                if (report.totalExpenses > 0) ...[
                  _buildSection(
                    context,
                    'Expenses',
                    Icons.money_off,
                    Colors.red,
                    [
                      _buildRow(
                        context,
                        'Total Expenses',
                        formatMoney(report.totalExpenses),
                      ),
                      _buildRow(
                        context,
                        'Cash Expenses',
                        formatMoney(report.cashExpenses),
                        color: Colors.red[700]!,
                      ),
                      if (report.totalExpenses > report.cashExpenses)
                        _buildRow(
                          context,
                          'Non-Cash Expenses',
                          formatMoney(
                            (report.totalExpenses - report.cashExpenses),
                          ),
                          color: Colors.grey,
                        ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Credit Collections — repayments against credit sold on EARLIER
                // days. Deliberately separate from Sales: this money is not revenue
                // for today, but the cash leg still lands in today's drawer.
                if (report.totalCollections > 0) ...[
                  _buildSection(
                    context,
                    'Credit Collections',
                    Icons.account_balance_wallet,
                    Colors.teal,
                    [
                      if (report.cashCollections > 0)
                        _buildRow(
                          context,
                          'Cash',
                          formatMoney(report.cashCollections),
                        ),
                      if (report.cardCollections > 0)
                        _buildRow(
                          context,
                          'Card',
                          formatMoney(report.cardCollections),
                        ),
                      if (report.upiCollections > 0)
                        _buildRow(
                          context,
                          'UPI',
                          formatMoney(report.upiCollections),
                        ),
                      const Divider(),
                      _buildRow(
                        context,
                        'Total Collected',
                        formatMoney(report.totalCollections),
                        isBold: true,
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Profit — revenue here is EX-TAX, so the margin is real margin and
                // not inflated by the GST that has to be handed over.
                if (report.totalCost != 0 || report.grossProfit != 0) ...[
                  _buildSection(
                    context,
                    'Profit',
                    Icons.trending_up,
                    report.grossProfit >= 0 ? Colors.green : Colors.red,
                    [
                      _buildRow(
                        context,
                        'Revenue (excl. tax)',
                        formatMoney((report.totalSales - report.totalTax)),
                      ),
                      _buildRow(
                        context,
                        'Cost of Goods',
                        formatMoney(report.totalCost),
                      ),
                      const Divider(),
                      _buildRow(
                        context,
                        'Gross Profit',
                        formatMoney(report.grossProfit),
                        isBold: true,
                        color: report.grossProfit >= 0
                            ? Colors.green[700]!
                            : Colors.red[700]!,
                      ),
                      _buildRow(
                        context,
                        'Margin',
                        '${report.profitMargin.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Customer Outstanding — a position at close, not a movement during
                // the day, so it is not part of any total above.
                if (report.totalOutstanding > 0) ...[
                  _buildSection(
                    context,
                    'Customer Outstanding',
                    Icons.people_alt,
                    Colors.brown,
                    [
                      _buildRow(
                        context,
                        'Customers with Due',
                        '${report.customersWithDue}',
                      ),
                      _buildRow(
                        context,
                        'Total Outstanding',
                        formatMoney(report.totalOutstanding),
                        isBold: true,
                        color: Colors.brown[700]!,
                      ),
                    ],
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                ],

                // Cash Reconciliation
                _buildCashReconciliation(context),

                SizedBox(height: AppResponsive.extraLargeSpacing(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tax rows to print, by country — see
  /// [EodHistoryExport.taxRowsFor], which owns the rule so this screen and the
  /// file exported from it can never name the tax differently.
  List<({String label, double amount})> _taxRows(EndOfDayReport report) =>
      EodHistoryExport.taxRowsFor(report);

  /// Reprints the settlement slip for THIS stored close.
  ///
  /// The close flow prints one and it is gone; this is the second copy.
  Future<void> _reprint() async {
    final outcome = await EodSettlementPrint.reprint(report);
    switch (outcome) {
      case EodReprintOutcome.printed:
        NotificationService.instance.showSuccess('Settlement printed');
      case EodReprintOutcome.noPrinter:
        NotificationService.instance.showError(
          'No printer paired. Add one in Printer Settings.',
        );
      case EodReprintOutcome.sendFailed:
        NotificationService.instance.showError(
          'Could not reach the printer. Check it and try again.',
        );
    }
  }

  Future<void> _export(BuildContext context) async {
    final export = EodHistoryExport.detail(report);
    await ReportExportService.showExportDialog(
      context: context,
      fileName: 'eod_close',
      reportTitle: 'End of Day Report',
      headers: export.headers,
      data: export.rows,
      summary: export.summary,
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.cardPadding(context),
            child: Row(
              children: [
                Icon(icon, color: color, size: AppResponsive.iconSize(context)),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: AppResponsive.cardPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: color ?? Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashReconciliation(BuildContext context) {
    final reconciliation = report.cashReconciliation;
    final isBalanced = reconciliation.reconciliationStatus == 'Balanced';
    final isOverage = reconciliation.reconciliationStatus == 'Overage';

    Color statusColor;
    Color borderColor;
    Color bgColor;
    Color badgeBgColor;
    Color badgeTextColor;

    if (isBalanced) {
      statusColor = Colors.green;
      borderColor = Colors.green.shade200;
      bgColor = Colors.green.shade50;
      badgeBgColor = Colors.green.shade100;
      badgeTextColor = Colors.green.shade800;
    } else if (isOverage) {
      statusColor = Colors.blue;
      borderColor = Colors.blue.shade200;
      bgColor = Colors.blue.shade50;
      badgeBgColor = Colors.blue.shade100;
      badgeTextColor = Colors.blue.shade800;
    } else {
      statusColor = Colors.orange;
      borderColor = Colors.orange.shade200;
      bgColor = Colors.orange.shade50;
      badgeBgColor = Colors.orange.shade100;
      badgeTextColor = Colors.orange.shade800;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppResponsive.cardPadding(context),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance,
                      color: statusColor,
                      size: AppResponsive.iconSize(context),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Text(
                      'Cash Reconciliation',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
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
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                  ),
                  child: Text(
                    reconciliation.reconciliationStatus,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppResponsive.cardPadding(context),
            child: Column(
              children: [
                _buildRow(
                  context,
                  'Expected Cash',
                  formatMoney(reconciliation.systemExpectedCash),
                ),
                _buildRow(
                  context,
                  'Actual Cash',
                  formatMoney(reconciliation.actualCash),
                ),
                const Divider(),
                _buildRow(
                  context,
                  'Difference',
                  '${reconciliation.difference >= 0 ? '+' : ''}${formatMoney(reconciliation.difference)}',
                  isBold: true,
                  color: reconciliation.difference == 0
                      ? Colors.green
                      : reconciliation.difference > 0
                      ? Colors.blue
                      : Colors.orange,
                ),
                if (reconciliation.remarks != null &&
                    reconciliation.remarks!.isNotEmpty) ...[
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      AppResponsive.mediumSpacing(context),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remarks',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          reconciliation.remarks!,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
