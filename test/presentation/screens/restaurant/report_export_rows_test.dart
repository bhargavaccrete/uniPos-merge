import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/report_export_rows.dart';

import '../../../helpers/test_helpers.dart';

/// The eight transaction reports: export rows keep their columns, amounts
/// and dates are typed cells, and every summary is computed from exactly the
/// records exported (All, a page, or a date range).
void main() {
  String money(double v) => ReportExportService.formatCurrency(v);

  PastOrderModel order(
    String id,
    DateTime at,
    double total, {
    double refund = 0,
    DateTime? refundedAt,
    String? refundReason,
    double discount = 0,
    double? subTotal,
    String status = 'COMPLETED',
    String payment = 'Cash',
    String? voidReason,
    int? bill,
  }) =>
      PastOrderModel(
        id: id,
        customerName: 'C$id',
        totalPrice: total,
        items: [makeCartItem(price: total, quantity: 1)],
        orderAt: at,
        orderType: 'Dine In',
        paymentmode: payment,
        orderStatus: status,
        refundAmount: refund,
        refundedAt: refundedAt,
        refundReason: refundReason,
        Discount: discount,
        subTotal: subTotal,
        voidReason: voidReason,
        billNumber: bill,
        kotNumbers: [1],
        kotBoundaries: [1],
      );

  final d1 = DateTime(2026, 11, 10, 9);
  final d2 = DateTime(2026, 11, 15, 23, 59);
  final d3 = DateTime(2026, 11, 20, 13);

  List<T> range<T>(List<T> items, DateTime from, DateTime to,
          DateTime? Function(T) dateOf) =>
      ReportExportService.selectForExport(items,
          scope: ExportScope.dateRange, from: from, to: to, dateOf: dateOf);

  group('Total Sales', () {
    final orders = [
      order('a', d3, 300, bill: 3),
      order('b', d2, 200, refund: 50, status: 'PARTIALLY_REFUNDED', bill: 2),
      order('c', d1, 100, bill: 1),
    ];

    test('row: same columns, typed date and net amount', () {
      final row = RestaurantReportExports.totalSalesRow(orders[1]);
      expect(row.length, RestaurantReportExports.totalSalesHeaders.length);
      expect((row[0] as ExportDateTime).value, d2);
      expect(row[1], 'INV 2');
      expect(row[5], 'Partial Refund');
      expect((row[6] as ExportMoney).value, 150);
    });

    test('All: summary equals the whole filtered list', () {
      final s = RestaurantReportExports.totalSalesSummary(orders, 'This Month');
      expect(s['Total Orders'], '3');
      expect(s['Total Sales'], money(550));
      expect(s['Report Period'], 'This Month');
    });

    test('date range 10–15 Nov (whole end day): only those orders counted', () {
      final picked = range(orders, DateTime(2026, 11, 10),
          DateTime(2026, 11, 15), (o) => o.orderAt);
      expect(picked.map((o) => o.id), ['b', 'c'],
          reason: '15 Nov 23:59 is inside the end day');
      final s = RestaurantReportExports.totalSalesSummary(picked, 'This Month');
      expect(s['Total Orders'], '2');
      expect(s['Total Sales'], money(250));
    });

    test('Excel total of the exported rows equals the summary total', () {
      final picked = range(orders, DateTime(2026, 11, 15),
          DateTime(2026, 11, 20), (o) => o.orderAt);
      final bytes = ReportExportService.buildExcelBytesForTesting(
        headers: RestaurantReportExports.totalSalesHeaders,
        data: picked.map(RestaurantReportExports.totalSalesRow).toList(),
        summary: RestaurantReportExports.totalSalesSummary(picked, 'x'),
      );
      final rows = Excel.decodeBytes(bytes).tables.values.first.rows;
      final h = rows.indexWhere(
          (r) => r.isNotEmpty && r.first?.value.toString() == 'Date');
      final amounts = rows.sublist(h + 1).map((r) => switch (r[6]?.value) {
            DoubleCellValue(:final value) => value,
            IntCellValue(:final value) => value.toDouble(),
            _ => double.nan,
          });
      final excelTotal = amounts.reduce((a, b) => a + b);
      expect(excelTotal, 450, reason: '300 + (200 − 50)');
      expect(RestaurantReportExports.totalSalesSummary(picked, 'x')['Total Sales'],
          money(excelTotal));
    });
  });

  group('Payment Mode', () {
    final orders = [
      order('a', d3, 300, payment: 'UPI'),
      order('b', d2, 200, payment: 'Cash'),
      order('c', d1, 100, payment: 'Cash'),
    ];

    test('per-method lines and total are re-aggregated for the selection', () {
      final picked = range(orders, DateTime(2026, 11, 15),
          DateTime(2026, 11, 20), (o) => o.orderAt);
      final s = RestaurantReportExports.paymentModeSummary(picked, 'P');
      expect(s['Total Transactions'], '2');
      expect(s['Total Collected'], money(500));
      final methodLines = s.keys
          .where((k) => !const {
                'Report Period',
                'Total Collected',
                'Total Transactions',
                'Generated'
              }.contains(k))
          .toList();
      expect(methodLines.length, 2, reason: 'UPI and Cash in this range');
    });

    test('row amounts are numbers', () {
      final row = RestaurantReportExports.paymentModeRow(orders.first);
      expect((row[3] as ExportMoney).value, 300);
    });
  });

  group('Discount Orders', () {
    final orders = [
      order('a', d3, 270, discount: 30, subTotal: 300),
      order('b', d1, 90, discount: 10, subTotal: 100),
    ];

    test('row: Original = net + discount (unchanged)', () {
      final row = RestaurantReportExports.discountRow(orders.first);
      expect((row[5] as ExportMoney).value, 300);
      expect((row[6] as ExportMoney).value, 30);
      expect((row[7] as ExportMoney).value, 270);
    });

    test('summary for a single page of one order', () {
      final page = ReportExportService.selectForExport(orders,
          scope: ExportScope.page, page: 0, rowsPerPage: 1);
      final s = RestaurantReportExports.discountSummary(page, 'P');
      expect(s['Total Orders'], '1');
      expect(s['Total Discount'], money(30));
      expect(s['Total Subtotal'], money(300));
      expect(s['Total Amount'], money(270));
      expect(s['Average Discount'], money(30));
    });
  });

  group('Refund Details (by refund date)', () {
    final orders = [
      order('a', d1, 300,
          refund: 300,
          refundedAt: d3,
          refundReason: 'old\nWrong item',
          status: 'FULLY_REFUNDED'),
      order('short', d1, 100,
          refund: 40, refundedAt: d1, refundReason: 'Cold', status: 'PARTIALLY_REFUNDED'),
    ];

    test('the range uses refundedAt, not the order date', () {
      // Both orders were placed on 10 Nov; only one was refunded on 20 Nov.
      final picked = range(orders, DateTime(2026, 11, 20),
          DateTime(2026, 11, 20), (o) => o.refundedAt);
      expect(picked.single.id, 'a');
      final s = RestaurantReportExports.refundSummary(picked, 'P');
      expect(s['Total Refunds'], '1');
      expect(s['Total Refund Amount'], money(300));
      expect(s['Most Common Reason'], 'Wrong item');
    });

    test('row: refund date + amount typed; a short id no longer throws', () {
      final row = RestaurantReportExports.refundRow(orders[1]);
      expect((row[0] as ExportDateTime).value, d1);
      expect(row[1], 'short');
      expect((row[5] as ExportMoney).value, 40);
    });
  });

  group('Void Orders', () {
    final orders = [
      order('v1', d3, 500, status: 'VOIDED', voidReason: 'Duplicate'),
      order('v2', d1, 100, status: 'VOIDED', voidReason: 'Duplicate'),
      order('v3', d1, 50, status: 'VOIDED', voidReason: 'Test'),
    ];

    test('summary recomputed for the selected records', () {
      final picked = range(orders, DateTime(2026, 11, 10),
          DateTime(2026, 11, 10), (o) => o.orderAt);
      final s = RestaurantReportExports.voidSummary(picked, 'P');
      expect(s['Total Void Orders'], '2');
      expect(s['Total Void Amount'], money(150));
      expect(s['Average Void Amount'], money(75));
    });

    test('row: amount typed; short id safe', () {
      final row = RestaurantReportExports.voidRow(orders[0]);
      expect(row[0], 'v1');
      expect((row[4] as ExportMoney).value, 500);
    });
  });

  group('Expenses', () {
    final expenses = [
      Expense(id: 'e1', dateandTime: d3, amount: 120.5, reason: 'Gas'),
      Expense(id: 'e2', dateandTime: d1, amount: 79.5, reason: 'Milk'),
    ];

    test('summary for a date range', () {
      final picked = range(expenses, DateTime(2026, 11, 20),
          DateTime(2026, 11, 20), (e) => e.dateandTime);
      final s = RestaurantReportExports.expenseSummary(picked, 'P');
      expect(s['Total Expenses Count'], '1');
      expect(s['Total Expenses Amount'], money(120.5));
      expect(s['Average Expense'], money(120.5));
    });

    test('row keeps the category name and typed amount', () {
      final row = RestaurantReportExports.expenseRow(expenses.first, 'Utilities');
      expect(row[1], 'Utilities');
      expect((row[4] as ExportMoney).value, 120.5);
    });
  });

  group('Item Cancellation', () {
    ItemCancellationModel c(String id, DateTime at, int qty, double amount,
            String reason) =>
        ItemCancellationModel(
          id: id,
          itemName: 'Soup',
          quantity: qty,
          amount: amount,
          reason: reason,
          orderId: 'o-$id',
          timestamp: at,
        );
    final rows = [
      c('1', d3, 2, 240, 'Cold'),
      c('2', d1, 1, 120, 'No reason given'),
    ];

    test('qty is a number; summary for the selection', () {
      final row = RestaurantReportExports.cancellationRow(rows.first);
      expect(row[2], 2);
      expect((row[3] as ExportMoney).value, 240);
      final s = RestaurantReportExports.cancellationSummary(rows);
      expect(s['Total Cancellations'], '2');
      expect(s['Total Items Qty'], '3');
      expect(s['Total Amount'], money(360));
      expect(s['Top Reason'], 'Cold', reason: '"No reason given" ignored');
    });
  });

  group('POS End Day', () {
    EndOfDayReport eod(String id, DateTime at, double opening, double closing,
            double discount) =>
        EndOfDayReport(
          date: at,
          openingBalance: opening,
          orderSummaries: const [],
          totalDiscount: discount,
          totalTax: 0,
          categorySales: const [],
          paymentSummaries: [
            PaymentSummary(
                paymentType: 'Cash',
                totalAmount: 400,
                transactionCount: 4,
                percentage: 80),
            PaymentSummary(
                paymentType: 'UPI',
                totalAmount: 100,
                transactionCount: 1,
                percentage: 20),
          ],
          cashReconciliation: CashReconciliation(
              systemExpectedCash: 400,
              actualCash: 390,
              difference: -10,
              reconciliationStatus: 'short'),
          totalSales: 500,
          closingBalance: closing,
          taxSummaries: const [],
          totalOrderCount: 5,
          totalRefunds: 0,
          reportId: id,
          totalExpenses: 0,
          cashExpenses: 0,
        );
    final reports = [eod('r2', d3, 1000, 1390, 20), eod('r1', d1, 500, 890, 5)];

    test('row: every money column numeric, payment split kept', () {
      final row = RestaurantReportExports.endDayRow(reports.first);
      expect(row.length, RestaurantReportExports.endDayHeaders.length);
      expect((row[1] as ExportMoney).value, 500);
      expect((row[6] as ExportMoney).value, -10);
      expect((row[7] as ExportMoney).value, 400, reason: 'cash');
      expect((row[9] as ExportMoney).value, 100, reason: 'online/upi');
    });

    test('summary for a date range of End Day reports', () {
      final picked = range(reports, DateTime(2026, 11, 20),
          DateTime(2026, 11, 20), (r) => r.date);
      final s = RestaurantReportExports.endDaySummary(picked, 'All Dates');
      expect(s['Total Reports'], '1');
      expect(s['Total Opening Balance'], money(1000));
      expect(s['Total Closing Balance'], money(1390));
      expect(s['Total Discount'], money(20));
    });
  });
}
