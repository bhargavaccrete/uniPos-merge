import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/common/short_ref.dart';

/// The headers, rows and summary of one exported credit report.
///
/// A record rather than `ReportExportData`, which lives in the report scaffold
/// — a presentation file this layer must not depend on.
typedef CreditExport = ({
  List<String> headers,
  List<List<dynamic>> rows,
  Map<String, dynamic> summary,
});

/// Builds the three Credit Reports exports.
///
/// Pure — no Hive, no DI, no BuildContext — so the exported shape can be tested
/// without standing up a screen. It is also what keeps the file honest: each
/// builder is handed the very list and totals the tab is displaying, so an
/// export can never cover a different period, or a different set of rows, than
/// the screen it was taken from.
class CreditReportExport {
  CreditReportExport._();

  // ==================== Credit Sales ====================

  static const List<String> creditSalesHeaders = [
    'Invoice',
    'Sale ID',
    'Date',
    'Customer ID',
    'Status',
    'Total',
    'Paid',
    'Due',
  ];

  /// [totalCreditSales] and the row count are the same two figures the tab's
  /// summary band shows — passed in rather than recomputed, so the two can
  /// never drift.
  static CreditExport creditSales({
    required List<SaleModel> sales,
    required double totalCreditSales,
    required String period,
  }) {
    return (
      headers: creditSalesHeaders,
      rows: sales.map((sale) {
        final at = DateTime.tryParse(sale.date);
        return <dynamic>[
          // The screen's short form AND the full key: one to match a row on
          // screen, the other to trace it back to the record.
          sale.displayNumber,
          sale.saleId,
          at == null ? sale.date : ReportExportService.formatDateTime(at),
          sale.customerId ?? '',
          sale.statusDisplayText,
          ReportExportService.formatCurrency(sale.totalAmount),
          ReportExportService.formatCurrency(sale.paidAmount),
          ReportExportService.formatCurrency(sale.dueAmount),
        ];
      }).toList(),
      summary: {
        'Report Period': period,
        'Transactions': sales.length,
        'Total Credit Sales':
            ReportExportService.formatCurrency(totalCreditSales),
      },
    );
  }

  // ==================== Collections ====================

  static const List<String> collectionsHeaders = [
    'Date',
    'Type',
    'Mode',
    'Customer ID',
    'Sale ID',
    'Reference',
    'Note',
    'Amount',
  ];

  /// A row's kind, spelled out.
  ///
  /// On screen a write-off is marked by its icon and a return adjustment only
  /// by an upper-cased mode string. A spreadsheet has neither, and this is the
  /// difference between a row that is money and one that is not — the same
  /// distinction `CreditPaymentRepository.bucketCollections` counts on.
  static String rowType(CreditPaymentModel payment) {
    if (payment.isDebtWriteOff) return 'Write-off';
    if (payment.isReturnAdjustment) return 'Return adjustment';
    return 'Collection';
  }

  /// [buckets] is the map the summary cards render
  /// (`CreditPaymentRepository.bucketCollections`), so the file's totals are
  /// literally the ones on screen. "Other" appears only when it carries
  /// something, exactly as the card does.
  static CreditExport collections({
    required List<CreditPaymentModel> payments,
    required Map<String, double> buckets,
    required String period,
  }) {
    final other = buckets[CreditPaymentRepository.otherMode] ?? 0;

    return (
      headers: collectionsHeaders,
      rows: payments.map((p) {
        final at = DateTime.tryParse(p.date);
        return <dynamic>[
          at == null ? p.date : ReportExportService.formatDateTime(at),
          rowType(p),
          p.paymentModeDisplayText,
          p.customerId,
          p.saleId,
          p.referenceId ?? '',
          p.note ?? '',
          ReportExportService.formatCurrency(p.amount),
        ];
      }).toList(),
      summary: {
        'Report Period': period,
        // ROWS, not collections: write-offs and return adjustments are listed
        // here but excluded from every money figure below.
        'Rows': payments.length,
        'Cash': ReportExportService.formatCurrency(buckets['cash'] ?? 0),
        'UPI': ReportExportService.formatCurrency(buckets['upi'] ?? 0),
        'Card': ReportExportService.formatCurrency(buckets['card'] ?? 0),
        if (other > 0) 'Other': ReportExportService.formatCurrency(other),
        'Total Collections':
            ReportExportService.formatCurrency(buckets['total'] ?? 0),
      },
    );
  }

  // ==================== Outstanding ====================

  static const List<String> outstandingHeaders = [
    'Customer',
    'Phone',
    'Customer ID',
    'Outstanding',
    'Share of Total',
  ];

  /// Outstanding is a CURRENT balance, so the file is stamped with the moment
  /// it was taken rather than a period — there is no period to state.
  ///
  /// [asAt] is injectable for tests; production passes `DateTime.now()`.
  static CreditExport outstanding({
    required List<Customer> customers,
    required double totalOutstanding,
    required DateTime asAt,
  }) {
    return (
      headers: outstandingHeaders,
      rows: customers.map((c) {
        // The same share the card's progress bar draws.
        final share = totalOutstanding > 0
            ? (c.creditBalance / totalOutstanding * 100)
            : 0.0;
        return <dynamic>[
          c.name ?? '',
          c.phone ?? '',
          c.customerId,
          ReportExportService.formatCurrency(c.creditBalance),
          '${share.toStringAsFixed(1)}%',
        ];
      }).toList(),
      summary: {
        'As At': ReportExportService.formatDateTime(asAt),
        'Customers': customers.length,
        'Total Outstanding':
            ReportExportService.formatCurrency(totalOutstanding),
      },
    );
  }
}
