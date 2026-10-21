import 'package:intl/intl.dart';

import 'package:billberrylite/core/config/tax_label_rule.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/common/short_ref.dart';

/// The headers, rows and summary of one exported EOD file.
///
/// A record rather than `ReportExportData`, which lives in the report scaffold
/// — a presentation file this layer must not depend on.
typedef EodExport = ({
  List<String> headers,
  List<List<dynamic>> rows,
  Map<String, dynamic> summary,
});

/// Builds the two End of Day History exports: the list of closes, and one
/// close in full.
///
/// Pure — no Hive, no DI, no BuildContext — so the exported shape is testable
/// without a screen, and each builder is handed exactly the records the screen
/// is showing rather than re-querying them.
class EodHistoryExport {
  EodHistoryExport._();

  // ==================== The list of closes ====================

  static const List<String> listHeaders = [
    'Date',
    'Time',
    'Session',
    'Status',
    'Total Sales',
    'Transactions',
    'Expected Cash',
    'Actual Cash',
    'Difference',
  ];

  /// One row per close, in the order the screen lists them.
  ///
  /// Date and Time are separate columns on purpose: two closes on one day are
  /// the case EOD-3 exists for, and a spreadsheet sorts and groups them far
  /// better as two fields than as one string.
  static EodExport list({
    required List<EndOfDayReport> reports,
    required String period,
  }) {
    return (
      headers: listHeaders,
      rows: reports.map((r) {
        final session = r.sessionId;
        return <dynamic>[
          ReportExportService.formatDate(r.date),
          DateFormat('hh:mm a').format(r.date),
          session == null || session.isEmpty ? '' : shortRef(session),
          r.cashReconciliation.reconciliationStatus,
          ReportExportService.formatCurrency(r.totalSales),
          r.totalOrderCount,
          ReportExportService.formatCurrency(
              r.cashReconciliation.systemExpectedCash),
          ReportExportService.formatCurrency(r.cashReconciliation.actualCash),
          ReportExportService.formatCurrency(r.cashReconciliation.difference),
        ];
      }).toList(),
      summary: {
        'Report Period': period,
        'Closes': reports.length,
        // Aggregates over EXACTLY the rows above — no re-query, no re-filter.
        // The list screen shows no summary band of its own, so these are
        // export-only; they are sums of the columns beside them, not new
        // business figures.
        'Total Sales': ReportExportService.formatCurrency(
            reports.fold<double>(0, (s, r) => s + r.totalSales)),
        'Balanced': _countStatus(reports, 'Balanced'),
        'Shortage': _countStatus(reports, 'Shortage'),
        'Overage': _countStatus(reports, 'Overage'),
      },
    );
  }

  static int _countStatus(List<EndOfDayReport> reports, String status) =>
      reports
          .where((r) => r.cashReconciliation.reconciliationStatus == status)
          .length;

  // ==================== One close, in full ====================

  static const List<String> detailHeaders = ['Section', 'Item', 'Amount'];

  /// The whole close as Section / Item / Amount rows — the same sections the
  /// detail screen renders, in the same order, including the country-aware tax
  /// treatment so the file says exactly what the screen says.
  static EodExport detail(EndOfDayReport report) {
    final rows = <List<dynamic>>[];
    void add(String section, String item, Object amount) =>
        rows.add(<dynamic>[section, item, amount]);

    String money(double v) => ReportExportService.formatCurrency(v);

    add('Close', 'Date', ReportExportService.formatDateTime(report.date));
    final session = report.sessionId;
    if (session != null && session.isNotEmpty) {
      add('Close', 'Session', shortRef(session));
    }

    add('Cash Summary', 'Opening Balance', money(report.openingBalance));
    add('Cash Summary', 'Closing Balance', money(report.closingBalance));

    add('Sales', 'Total Sales', money(report.totalSales));
    add('Sales', 'Transactions', report.totalOrderCount);
    if (report.totalDiscount > 0) {
      add('Sales', 'Total Discount', money(report.totalDiscount));
    }
    if (report.totalRefunds > 0) {
      add('Sales', 'Refunds', money(report.totalRefunds));
    }

    for (final payment in report.paymentSummaries) {
      add('Payments', payment.paymentType, money(payment.totalAmount));
    }

    // Country-aware, exactly as the detail screen renders it: India keeps the
    // stored CGST/SGST breakdown, everywhere else gets one row named for this
    // country's tax, taken from the authoritative total.
    for (final tax in taxRowsFor(report)) {
      add('Tax', tax.label, money(tax.amount));
    }
    if (taxRowsFor(report).isNotEmpty) {
      add('Tax', 'Total Tax', money(report.totalTax));
    }

    if (report.totalExpenses > 0) {
      add('Expenses', 'Total Expenses', money(report.totalExpenses));
      add('Expenses', 'Cash Expenses', money(report.cashExpenses));
      if (report.totalExpenses > report.cashExpenses) {
        add('Expenses', 'Non-Cash Expenses',
            money(report.totalExpenses - report.cashExpenses));
      }
    }

    if (report.totalCollections > 0) {
      add('Credit Collections', 'Cash', money(report.cashCollections));
      add('Credit Collections', 'Card', money(report.cardCollections));
      add('Credit Collections', 'UPI', money(report.upiCollections));
      add('Credit Collections', 'Total', money(report.totalCollections));
    }

    if (report.totalCost > 0 || report.grossProfit != 0) {
      add('Profit', 'Net Sales (ex-tax)',
          money(report.totalSales - report.totalTax));
      add('Profit', 'Cost of Goods', money(report.totalCost));
      add('Profit', 'Gross Profit', money(report.grossProfit));
    }

    if (report.customersWithDue > 0 || report.totalOutstanding > 0) {
      add('Outstanding', 'Customers with Due', report.customersWithDue);
      add('Outstanding', 'Total Outstanding', money(report.totalOutstanding));
    }

    final recon = report.cashReconciliation;
    add('Reconciliation', 'Expected Cash', money(recon.systemExpectedCash));
    add('Reconciliation', 'Actual Cash', money(recon.actualCash));
    add('Reconciliation', 'Difference', money(recon.difference));
    add('Reconciliation', 'Status', recon.reconciliationStatus);

    return (
      headers: detailHeaders,
      rows: rows,
      summary: {
        'Close': ReportExportService.formatDateTime(report.date),
        'Total Sales': money(report.totalSales),
        'Status': recon.reconciliationStatus,
      },
    );
  }

  /// The tax rows to print for [report], by country.
  ///
  /// Shared with `EODReportDetailScreen` so a file and the screen it was taken
  /// from can never name the tax differently. Reading the country at BUILD time
  /// is what makes historical records right without touching them: a close
  /// saved before the country fix still holds rows named CGST and SGST, and a
  /// non-India shop simply never renders or exports them.
  static List<({String label, double amount})> taxRowsFor(
      EndOfDayReport report) {
    if (TaxLabelRule.splitsIntoComponents) {
      return report.taxSummaries
          .map((t) => (label: t.taxName, amount: t.taxAmount))
          .toList();
    }
    if (report.totalTax == 0 && report.taxSummaries.isEmpty) {
      return const [];
    }
    return [(label: TaxLabelRule.name, amount: report.totalTax)];
  }
}
