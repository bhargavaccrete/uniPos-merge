import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/repositories/retail/credit_payment_repository.dart';
import 'package:billberrylite/domain/services/retail/credit_report_export.dart';

/// CREDIT REPORTS EXPORT — the shape of the three files.
///
/// Pure: the builders take the very list and totals the tab is displaying, so
/// these tests need no Hive and no DI. That is also the point of the design —
/// an export cannot cover a different period, or a different set of rows, than
/// the screen it was taken from, because it is handed that screen's data.
void main() {
  final day = DateTime(2026, 4, 15, 10, 30);

  SaleModel sale(
    String id, {
    double total = 500,
    double paid = 0,
    String? customerId = 'C-1',
    String? rawDate,
    String? invoiceNumber,
  }) {
    final iso = rawDate ?? day.toIso8601String();
    return SaleModel(
      saleId: id,
      invoiceNumber: invoiceNumber,
      totalItems: 1,
      subtotal: total,
      discountAmount: 0,
      taxAmount: 0,
      totalAmount: total,
      paymentType: 'credit',
      customerId: customerId,
      date: iso,
      createdAt: iso,
      updatedAt: iso,
      totalTaxableAmount: total,
      totalGstAmount: 0,
      grandTotal: total,
      paidAmount: paid,
      dueAmount: total - paid,
    );
  }

  CreditPaymentModel payment(
    String id, {
    double amount = 100,
    String mode = 'cash',
    bool isWriteOff = false,
    String? note,
    String? referenceId,
    String? rawDate,
  }) {
    final iso = rawDate ?? day.toIso8601String();
    return CreditPaymentModel(
      paymentId: id,
      customerId: 'C-1',
      saleId: 'S-1',
      amount: amount,
      paymentMode: mode,
      date: iso,
      createdAt: iso,
      balanceBefore: 0,
      balanceAfter: 0,
      note: note,
      referenceId: referenceId,
      isWriteOff: isWriteOff,
    );
  }

  Customer customer(String id, {required double balance, String? phone}) =>
      Customer(
        customerId: id,
        name: 'Name $id',
        phone: phone,
        creditBalance: balance,
        createdAt: day.toIso8601String(),
      );

  // ── Credit Sales ─────────────────────────────────────────────────────────

  group('credit sales export', () {
    test('one row per sale, in the order given', () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('S-1'), sale('S-2'), sale('S-3')],
        totalCreditSales: 1500,
        period: 'All time',
      );

      expect(export.rows, hasLength(3));
      // The builder must not re-sort — the screen's order IS the file's order.
      expect(export.rows.map((r) => r[1]), ['S-1', 'S-2', 'S-3']);
    });

    test('carries both the invoice number and the full key', () async {
      final export = CreditReportExport.creditSales(
        sales: [
          sale('abcdef-123456-7890-abcd', invoiceNumber: 'INV-00042'),
        ],
        totalCreditSales: 500,
        period: 'All time',
      );

      final row = export.rows.single;
      // One to match what the customer was handed…
      expect(row[0], 'INV-00042');
      // …the other to trace it back to the record. The two are deliberately
      // different: the number repeats each financial year, the key never does.
      expect(row[1], 'abcdef-123456-7890-abcd');
    });

    test('a sale predating invoice numbering falls back to a short reference',
        () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('abcdef-123456-7890-abcd')],
        totalCreditSales: 500,
        period: 'All time',
      );

      final row = export.rows.single;
      expect(row[0], 'ABCDEF-123456');
      expect(row[1], 'abcdef-123456-7890-abcd');
    });

    test('money columns are formatted, and paid + due reconcile to total',
        () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('S-1', total: 500, paid: 200)],
        totalCreditSales: 500,
        period: 'All time',
      );

      final row = export.rows.single;
      expect(row[5], contains('500'));
      expect(row[6], contains('200'));
      expect(row[7], contains('300'));
    });

    test('a missing customer id exports as blank, not "null"', () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('S-1', customerId: null)],
        totalCreditSales: 500,
        period: 'All time',
      );

      expect(export.rows.single[3], '');
    });

    test('an unreadable date falls back to the raw stored value', () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('S-1', rawDate: 'not-a-date')],
        totalCreditSales: 500,
        period: 'All time',
      );

      expect(export.rows.single[2], 'not-a-date');
    });

    test('the summary carries the period and the two figures on screen',
        () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('S-1'), sale('S-2')],
        totalCreditSales: 1000,
        period: '01 Apr 2026 - 30 Apr 2026',
      );

      expect(export.summary['Report Period'], '01 Apr 2026 - 30 Apr 2026');
      expect(export.summary['Transactions'], 2);
      expect(export.summary['Total Credit Sales'], contains('1'));
    });

    test('an empty period still produces headers and a summary', () async {
      final export = CreditReportExport.creditSales(
        sales: const [],
        totalCreditSales: 0,
        period: 'All time',
      );

      expect(export.rows, isEmpty);
      expect(export.headers, CreditReportExport.creditSalesHeaders);
      expect(export.summary['Transactions'], 0);
    });

    test('every row has one cell per header', () async {
      final export = CreditReportExport.creditSales(
        sales: [sale('S-1'), sale('S-2')],
        totalCreditSales: 1000,
        period: 'All time',
      );

      for (final row in export.rows) {
        expect(row, hasLength(export.headers.length));
      }
    });
  });

  // ── Collections ──────────────────────────────────────────────────────────

  group('collections export', () {
    test('the Type column names what a spreadsheet cannot otherwise see',
        () async {
      final rows = [
        payment('P-1'),
        payment('P-2', isWriteOff: true),
        payment('P-3', mode: CreditPaymentModel.returnAdjustmentMode),
      ];
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: CreditPaymentRepository.bucketCollections(rows),
        period: 'All time',
      );

      expect(export.rows.map((r) => r[1]),
          ['Collection', 'Write-off', 'Return adjustment']);
    });

    test('write-offs and return adjustments are LISTED but not counted',
        () async {
      final rows = [
        payment('P-1', amount: 500),
        payment('P-2', amount: 900, isWriteOff: true),
        payment('P-3',
            amount: 300, mode: CreditPaymentModel.returnAdjustmentMode),
      ];
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: CreditPaymentRepository.bucketCollections(rows),
        period: 'All time',
      );

      expect(export.summary['Rows'], 3, reason: 'all three appear in the file');
      expect(export.summary['Total Collections'], contains('500'));
    });

    test('the Other line appears only when that bucket carries something',
        () async {
      final plain = [payment('P-1', amount: 100)];
      final withOther = [
        payment('P-1', amount: 100),
        payment('P-2', amount: 250, mode: 'cheque'),
      ];

      final a = CreditReportExport.collections(
        payments: plain,
        buckets: CreditPaymentRepository.bucketCollections(plain),
        period: 'All time',
      );
      final b = CreditReportExport.collections(
        payments: withOther,
        buckets: CreditPaymentRepository.bucketCollections(withOther),
        period: 'All time',
      );

      // Same rule as the summary CARD, which is hidden when empty.
      expect(a.summary.containsKey('Other'), isFalse);
      expect(b.summary.containsKey('Other'), isTrue);
      expect(b.summary['Other'], contains('250'));
    });

    test('the summary is the bucket map, not a recount', () async {
      final rows = [
        payment('P-1', amount: 100, mode: 'cash'),
        payment('P-2', amount: 200, mode: 'upi'),
        payment('P-3', amount: 300, mode: 'card'),
        payment('P-4', amount: 400, mode: 'cheque'),
      ];
      final buckets = CreditPaymentRepository.bucketCollections(rows);
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: buckets,
        period: 'All time',
      );

      // Whatever the cards show is what the file says — by construction.
      expect(export.summary['Cash'], contains('100'));
      expect(export.summary['UPI'], contains('200'));
      expect(export.summary['Card'], contains('300'));
      expect(export.summary['Other'], contains('400'));
      expect(export.summary['Total Collections'], contains('1'));
    });

    test('a null note or reference exports as blank', () async {
      final rows = [payment('P-1')];
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: CreditPaymentRepository.bucketCollections(rows),
        period: 'All time',
      );

      final row = export.rows.single;
      expect(row[5], '');
      expect(row[6], '');
    });

    test('a note and reference are carried through', () async {
      final rows = [payment('P-1', note: 'part payment', referenceId: 'TXN9')];
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: CreditPaymentRepository.bucketCollections(rows),
        period: 'All time',
      );

      final row = export.rows.single;
      expect(row[5], 'TXN9');
      expect(row[6], 'part payment');
    });

    test('an unknown mode keeps its own label in the Mode column', () async {
      final rows = [payment('P-1', mode: 'cheque')];
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: CreditPaymentRepository.bucketCollections(rows),
        period: 'All time',
      );

      // Bucketed as Other, but the row still says what it actually was.
      expect(export.rows.single[2], 'CHEQUE');
      expect(export.summary['Other'], contains('100'));
    });

    test('every row has one cell per header', () async {
      final rows = [payment('P-1'), payment('P-2', isWriteOff: true)];
      final export = CreditReportExport.collections(
        payments: rows,
        buckets: CreditPaymentRepository.bucketCollections(rows),
        period: 'All time',
      );

      for (final row in export.rows) {
        expect(row, hasLength(export.headers.length));
      }
    });

    test('an empty period still produces headers and zeroed totals', () async {
      final export = CreditReportExport.collections(
        payments: const [],
        buckets: CreditPaymentRepository.bucketCollections(const []),
        period: 'All time',
      );

      expect(export.rows, isEmpty);
      expect(export.headers, CreditReportExport.collectionsHeaders);
      expect(export.summary['Rows'], 0);
      expect(export.summary.containsKey('Other'), isFalse);
    });
  });

  // ── Outstanding ──────────────────────────────────────────────────────────

  group('outstanding export', () {
    test('shares add up to 100%', () async {
      final export = CreditReportExport.outstanding(
        customers: [
          customer('C-1', balance: 750),
          customer('C-2', balance: 250),
        ],
        totalOutstanding: 1000,
        asAt: day,
      );

      expect(export.rows.map((r) => r[4]), ['75.0%', '25.0%']);
    });

    test('a zero total does not divide by zero', () async {
      final export = CreditReportExport.outstanding(
        customers: [customer('C-1', balance: 0)],
        totalOutstanding: 0,
        asAt: day,
      );

      expect(export.rows.single[4], '0.0%');
    });

    test('is stamped with a moment, not a period', () async {
      final export = CreditReportExport.outstanding(
        customers: [customer('C-1', balance: 100)],
        totalOutstanding: 100,
        asAt: day,
      );

      // A balance is what is owed NOW; there is no period to state.
      expect(export.summary.containsKey('Report Period'), isFalse);
      expect(export.summary['As At'], isNotNull);
      expect(export.summary['Customers'], 1);
      expect(export.summary['Total Outstanding'], contains('100'));
    });

    test('a missing phone exports as blank', () async {
      final export = CreditReportExport.outstanding(
        customers: [customer('C-1', balance: 100)],
        totalOutstanding: 100,
        asAt: day,
      );

      expect(export.rows.single[1], '');
    });

    test('order is preserved from the screen', () async {
      final export = CreditReportExport.outstanding(
        customers: [
          customer('C-BIG', balance: 900),
          customer('C-1', balance: 100),
          customer('C-2', balance: 100),
        ],
        totalOutstanding: 1100,
        asAt: day,
      );

      expect(export.rows.map((r) => r[2]), ['C-BIG', 'C-1', 'C-2']);
    });

    test('an empty list still produces headers and a summary', () async {
      final export = CreditReportExport.outstanding(
        customers: const [],
        totalOutstanding: 0,
        asAt: day,
      );

      expect(export.rows, isEmpty);
      expect(export.headers, CreditReportExport.outstandingHeaders);
      expect(export.summary['Customers'], 0);
    });

    test('every row has one cell per header', () async {
      final export = CreditReportExport.outstanding(
        customers: [customer('C-1', balance: 100, phone: '9876543210')],
        totalOutstanding: 100,
        asAt: day,
      );

      expect(export.rows.single, hasLength(export.headers.length));
    });
  });

  // ── rowType, on its own ──────────────────────────────────────────────────

  test('rowType names all three kinds', () {
    expect(CreditReportExport.rowType(payment('P-1')), 'Collection');
    expect(CreditReportExport.rowType(payment('P-2', isWriteOff: true)),
        'Write-off');
    expect(
        CreditReportExport.rowType(
            payment('P-3', mode: CreditPaymentModel.returnAdjustmentMode)),
        'Return adjustment');
  });

  test('a write-off recorded under an odd mode is still a write-off', () {
    expect(
        CreditReportExport.rowType(
            payment('P-1', mode: 'cheque', isWriteOff: true)),
        'Write-off');
  });
}
