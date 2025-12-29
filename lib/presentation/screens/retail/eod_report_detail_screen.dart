import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';

/// EOD Report Detail Screen - Shows detailed view of a single EOD report
class EODReportDetailScreen extends StatelessWidget {
  final EndOfDayReport report;

  const EODReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, EEEE');

    return Scaffold(
      appBar: AppBar(
        title: Text('EOD Report Details', style: GoogleFonts.poppins()),
      ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(report.date),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
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
              'Balance Summary',
              Icons.account_balance_wallet,
              Colors.teal,
              [
                _buildRow('Opening Balance', 'Rs. ${report.openingBalance.toStringAsFixed(2)}'),
                _buildRow('Closing Balance', 'Rs. ${report.closingBalance.toStringAsFixed(2)}'),
              ],
            ),

            const SizedBox(height: 16),

            // Sales Summary
            _buildSection(
              'Sales Summary',
              Icons.shopping_cart,
              Colors.green,
              [
                _buildRow('Total Sales', 'Rs. ${report.totalSales.toStringAsFixed(2)}', isBold: true),
                _buildRow('Total Transactions', '${report.totalOrderCount}'),
                if (report.totalDiscount > 0)
                  _buildRow('Discount', 'Rs. ${report.totalDiscount.toStringAsFixed(2)}', color: Colors.red),
                if (report.totalRefunds > 0)
                  _buildRow('Refunds', 'Rs. ${report.totalRefunds.toStringAsFixed(2)}', color: Colors.orange),
              ],
            ),

            const SizedBox(height: 16),

            // Payment Breakdown
            if (report.paymentSummaries.isNotEmpty) ...[
              _buildSection(
                'Payment Breakdown',
                Icons.payment,
                Colors.blue,
                report.paymentSummaries.map((payment) {
                  return _buildRow(
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
                'Tax Summary',
                Icons.receipt_long,
                Colors.purple,
                [
                  ...report.taxSummaries.map((tax) {
                    return _buildRow(
                      tax.taxName,
                      'Rs. ${tax.taxAmount.toStringAsFixed(2)}',
                    );
                  }),
                  const Divider(),
                  _buildRow('Total Tax', 'Rs. ${report.totalTax.toStringAsFixed(2)}', isBold: true),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Expenses
            if (report.totalExpenses > 0) ...[
              _buildSection(
                'Expenses',
                Icons.money_off,
                Colors.red,
                [
                  _buildRow('Total Expenses', 'Rs. ${report.totalExpenses.toStringAsFixed(2)}'),
                  _buildRow('Cash Expenses', 'Rs. ${report.cashExpenses.toStringAsFixed(2)}', color: Colors.red[700]!),
                  if (report.totalExpenses > report.cashExpenses)
                    _buildRow(
                      'Non-Cash Expenses',
                      'Rs. ${(report.totalExpenses - report.cashExpenses).toStringAsFixed(2)}',
                      color: Colors.grey,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Cash Reconciliation
            _buildCashReconciliation(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
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
                    fontSize: 16,
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

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: color ?? Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashReconciliation() {
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
                        fontSize: 16,
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
                      fontSize: 12,
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
                _buildRow('Expected Cash', 'Rs. ${reconciliation.systemExpectedCash.toStringAsFixed(2)}'),
                _buildRow('Actual Cash', 'Rs. ${reconciliation.actualCash.toStringAsFixed(2)}'),
                const Divider(),
                _buildRow(
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reconciliation.remarks!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
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