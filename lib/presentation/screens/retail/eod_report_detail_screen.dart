import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';

/// EOD Report Detail Screen - Shows detailed view of a single EOD report
class EODReportDetailScreen extends StatelessWidget {
  final EndOfDayReport report;

  const EODReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, EEEE');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'EOD Report Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 4),
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

            const SizedBox(height: 20),

            // Opening/Closing Balance
            _buildSection(
              context,
              'Balance Summary',
              Icons.account_balance_wallet,
              Colors.teal,
              [
                _buildRow(context, 'Opening Balance', 'Rs. ${report.openingBalance.toStringAsFixed(2)}'),
                _buildRow(context, 'Closing Balance', 'Rs. ${report.closingBalance.toStringAsFixed(2)}'),
              ],
            ),

            const SizedBox(height: 16),

            // Sales Summary
            _buildSection(
              context,
              'Sales Summary',
              Icons.shopping_cart,
              Colors.green,
              [
                _buildRow(context, 'Total Sales', 'Rs. ${report.totalSales.toStringAsFixed(2)}', isBold: true),
                _buildRow(context, 'Total Transactions', '${report.totalOrderCount}'),
                if (report.totalDiscount > 0)
                  _buildRow(context, 'Discount', 'Rs. ${report.totalDiscount.toStringAsFixed(2)}', color: Colors.red),
                if (report.totalRefunds > 0)
                  _buildRow(context, 'Refunds', 'Rs. ${report.totalRefunds.toStringAsFixed(2)}', color: Colors.orange),
              ],
            ),

            const SizedBox(height: 16),

            // Payment Breakdown
            if (report.paymentSummaries.isNotEmpty) ...[
              _buildSection(
                context,
                'Payment Breakdown',
                Icons.payment,
                Colors.blue,
                report.paymentSummaries.map((payment) {
                  return _buildRow(context, 
                    '${payment.paymentType} (${payment.transactionCount} txns)',
                    'Rs. ${payment.totalAmount.toStringAsFixed(2)}',
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Tax Summary
            if (report.taxSummaries.isNotEmpty) ...[
              _buildSection(
                context,
                'Tax Summary',
                Icons.receipt_long,
                Colors.purple,
                [
                  ...report.taxSummaries.map((tax) {
                    return _buildRow(context, 
                      tax.taxName,
                      'Rs. ${tax.taxAmount.toStringAsFixed(2)}',
                    );
                  }),
                  const Divider(),
                  _buildRow(context, 'Total Tax', 'Rs. ${report.totalTax.toStringAsFixed(2)}', isBold: true),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Expenses
            if (report.totalExpenses > 0) ...[
              _buildSection(
                context,
                'Expenses',
                Icons.money_off,
                Colors.red,
                [
                  _buildRow(context, 'Total Expenses', 'Rs. ${report.totalExpenses.toStringAsFixed(2)}'),
                  _buildRow(context, 'Cash Expenses', 'Rs. ${report.cashExpenses.toStringAsFixed(2)}', color: Colors.red[700]!),
                  if (report.totalExpenses > report.cashExpenses)
                    _buildRow(context, 
                      'Non-Cash Expenses',
                      'Rs. ${(report.totalExpenses - report.cashExpenses).toStringAsFixed(2)}',
                      color: Colors.grey,
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
                    _buildRow(context, 'Cash', 'Rs. ${report.cashCollections.toStringAsFixed(2)}'),
                  if (report.cardCollections > 0)
                    _buildRow(context, 'Card', 'Rs. ${report.cardCollections.toStringAsFixed(2)}'),
                  if (report.upiCollections > 0)
                    _buildRow(context, 'UPI', 'Rs. ${report.upiCollections.toStringAsFixed(2)}'),
                  const Divider(),
                  _buildRow(context, 'Total Collected', 'Rs. ${report.totalCollections.toStringAsFixed(2)}', isBold: true),
                ],
              ),
              const SizedBox(height: 16),
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
                  _buildRow(context, 'Revenue (excl. tax)',
                      'Rs. ${(report.totalSales - report.totalTax).toStringAsFixed(2)}'),
                  _buildRow(context, 'Cost of Goods', 'Rs. ${report.totalCost.toStringAsFixed(2)}'),
                  const Divider(),
                  _buildRow(context, 
                    'Gross Profit',
                    'Rs. ${report.grossProfit.toStringAsFixed(2)}',
                    isBold: true,
                    color: report.grossProfit >= 0 ? Colors.green[700]! : Colors.red[700]!,
                  ),
                  _buildRow(context, 'Margin', '${report.profitMargin.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 16),
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
                  _buildRow(context, 'Customers with Due', '${report.customersWithDue}'),
                  _buildRow(context, 
                    'Total Outstanding',
                    'Rs. ${report.totalOutstanding.toStringAsFixed(2)}',
                    isBold: true,
                    color: Colors.brown[700]!,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Cash Reconciliation
            _buildCashReconciliation(context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(Icons.account_balance, color: statusColor, size: 20),
                    const SizedBox(width: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRow(context, 'Expected Cash', 'Rs. ${reconciliation.systemExpectedCash.toStringAsFixed(2)}'),
                _buildRow(context, 'Actual Cash', 'Rs. ${reconciliation.actualCash.toStringAsFixed(2)}'),
                const Divider(),
                _buildRow(context, 
                  'Difference',
                  '${reconciliation.difference >= 0 ? '+' : ''}Rs. ${reconciliation.difference.toStringAsFixed(2)}',
                  isBold: true,
                  color: reconciliation.difference == 0
                      ? Colors.green
                      : reconciliation.difference > 0
                          ? Colors.blue
                          : Colors.orange,
                ),
                if (reconciliation.remarks != null && reconciliation.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(height: 4),
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