import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/domain/services/common/report_export_service.dart';
import 'package:billberrylite/util/restaurant/payment_mode_summary.dart';
import 'package:billberrylite/util/restaurant/refund_state.dart';

/// Export rows and summaries for the eight transaction-level restaurant
/// reports, kept in one pure place so the ranged export can recompute a
/// summary for exactly the records exported, and tests can check it.
///
/// * Columns and summary keys are the ones each report always exported.
/// * Formulas are copied from each screen's filter method unchanged (quirks
///   included — see the notes on Discount and Payment Mode).
/// * Amounts are [ExportMoney] and dates [ExportDateTime]: genuine numeric
///   and date cells in Excel, the same text as before in PDF.
class RestaurantReportExports {
  RestaurantReportExports._();

  static String _money(double v) => ReportExportService.formatCurrency(v);
  static String _generated() =>
      ReportExportService.formatDateTime(DateTime.now());

  static String _invoice(PastOrderModel o) => o.billNumber != null
      ? 'INV ${o.billNumber}'
      : '#${o.id.length > 8 ? o.id.substring(0, 8) : o.id}';

  /// Bill number, or the first 8 characters of the id (guarded: an id
  /// shorter than 8 used to throw).
  static String _billOrId(PastOrderModel o) =>
      o.billNumber?.toString() ??
      (o.id.length > 8 ? o.id.substring(0, 8) : o.id);

  static double _net(PastOrderModel o) => o.totalPrice - (o.refundAmount ?? 0.0);

  /// Most frequent non-empty reason; ties keep the first seen.
  static String _topReason(Iterable<String> reasons, String none) {
    final counts = <String, int>{};
    for (final r in reasons) {
      if (r.isNotEmpty) counts[r] = (counts[r] ?? 0) + 1;
    }
    if (counts.isEmpty) return none;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  // ── Total Sales (date: orderAt) ──────────────────────────────────────
  static const totalSalesHeaders = [
    'Date', 'Invoice', 'Customer', 'Payment', 'Type', 'Status', 'Amount'
  ];

  static List<dynamic> totalSalesRow(PastOrderModel o) => [
        ExportDateTime(o.orderAt!),
        _invoice(o),
        o.customerName,
        o.paymentDisplay.isNotEmpty ? o.paymentDisplay : 'N/A',
        o.orderType ?? 'N/A',
        o.orderStatus == 'PARTIALLY_REFUNDED' ? 'Partial Refund' : 'Completed',
        ExportMoney(_net(o)),
      ];

  static Map<String, dynamic> totalSalesSummary(
      List<PastOrderModel> rows, String period) {
    double sales = 0.0;
    for (final o in rows) {
      sales += _net(o);
    }
    return {
      'Report Period': period,
      'Total Orders': rows.length.toString(),
      'Total Sales': _money(sales),
      'Generated': _generated(),
    };
  }

  // ── Payment Mode (date: orderAt) ─────────────────────────────────────
  static const paymentModeHeaders = [
    'Date & Time', 'Invoice', 'Payment Mode', 'Amount'
  ];

  static List<dynamic> paymentModeRow(PastOrderModel o) => [
        ExportDateTime(o.orderAt!),
        _invoice(o),
        PaymentModeSummary.methodLabel(o),
        ExportMoney(_net(o)),
      ];

  /// Same aggregation the screen and End of Day use (split legs,
  /// proportional refunds), recomputed for exactly [rows].
  static Map<String, dynamic> paymentModeSummary(
      List<PastOrderModel> rows, String period) {
    final summaries = PaymentModeSummary.summarize(rows);
    final collected = summaries.fold(0.0, (sum, s) => sum + s.totalAmount);
    return {
      'Report Period': period,
      'Total Collected': _money(collected),
      'Total Transactions': rows.length.toString(),
      for (final s in summaries)
        s.paymentType:
            '${_money(s.totalAmount)} (${s.transactionCount} txns, ${s.percentage.toStringAsFixed(1)}%)',
      'Generated': _generated(),
    };
  }

  // ── Discount Orders (date: orderAt) ──────────────────────────────────
  static const discountHeaders = [
    'Date', 'Invoice', 'Customer', 'Payment', 'Type', 'Original', 'Discount',
    'Final'
  ];

  static List<dynamic> discountRow(PastOrderModel o) {
    final discount = o.Discount ?? 0.0;
    final net = _net(o);
    return [
      ExportDateTime(o.orderAt!),
      _invoice(o),
      o.customerName.isNotEmpty ? o.customerName : 'Guest',
      o.paymentmode ?? 'N/A',
      o.orderType ?? 'N/A',
      ExportMoney(net + discount),
      ExportMoney(discount),
      ExportMoney(net),
    ];
  }

  /// Note (unchanged quirk): "Total Subtotal" sums `subTotal`, while the
  /// Original column is net + discount.
  static Map<String, dynamic> discountSummary(
      List<PastOrderModel> rows, String period) {
    double discount = 0.0, subtotal = 0.0, net = 0.0;
    for (final o in rows) {
      discount += o.Discount ?? 0.0;
      subtotal += o.subTotal ?? 0.0;
      net += _net(o);
    }
    return {
      'Report Period': period,
      'Total Orders': rows.length.toString(),
      'Total Subtotal': _money(subtotal),
      'Total Discount': _money(discount),
      'Total Amount': _money(net),
      'Average Discount': _money(rows.isNotEmpty ? discount / rows.length : 0.0),
      'Generated': _generated(),
    };
  }

  // ── Refund Details (date: refundedAt) ────────────────────────────────
  static const refundHeaders = [
    'Date & Time', 'Bill #', 'Customer', 'Payment Method', 'Order Type',
    'Refund Amount', 'Refunded By', 'Reason'
  ];

  /// The last line of the refund reason, as the report shows it.
  static String refundReasonOf(PastOrderModel o) {
    final r = o.refundReason;
    if (r == null || r.isEmpty) return '';
    final lines = r.split('\n');
    return lines.isNotEmpty ? lines.last.trim() : '';
  }

  static List<dynamic> refundRow(PastOrderModel o) => [
        ExportDateTime(o.refundedAt!),
        _billOrId(o),
        o.customerName,
        o.paymentmode ?? 'N/A',
        o.orderType ?? 'N/A',
        ExportMoney(o.refundAmount ?? 0.0),
        o.refundedBy ?? '—',
        refundReasonOf(o),
      ];

  static Map<String, dynamic> refundSummary(
      List<PastOrderModel> rows, String period) {
    double total = 0.0;
    for (final o in rows) {
      total += o.refundAmount ?? 0.0;
    }
    return {
      'Report Period': period,
      'Total Refunds': rows.length.toString(),
      'Total Refund Amount': _money(total),
      'Most Common Reason': _topReason(rows.map(refundReasonOf), '-'),
      'Generated': _generated(),
    };
  }

  // ── Void Orders (date: orderAt) ──────────────────────────────────────
  static const voidHeaders = [
    'Bill #', 'Date & Time', 'Customer', 'Payment Method', 'Amount',
    'Refund Status', 'Voided By', 'Reason'
  ];

  static String voidRefundStatus(PastOrderModel o) {
    switch (RefundInfo.state(o)) {
      case RefundState.full:
        return 'Fully Refunded';
      case RefundState.partial:
        return 'Partially Refunded';
      case RefundState.none:
        final pm = o.paymentmode ?? '';
        return pm.isNotEmpty && pm != 'N/A' ? 'Refund Pending' : '—';
    }
  }

  static List<dynamic> voidRow(PastOrderModel o) => [
        _billOrId(o),
        ExportDateTime(o.orderAt!),
        o.customerName,
        o.paymentmode ?? 'N/A',
        ExportMoney(o.totalPrice),
        voidRefundStatus(o),
        o.voidedBy ?? '—',
        o.voidReason ?? '—',
      ];

  static Map<String, dynamic> voidSummary(
      List<PastOrderModel> rows, String period) {
    double total = 0.0;
    for (final o in rows) {
      total += o.totalPrice;
    }
    return {
      'Report Period': period,
      'Total Void Orders': rows.length.toString(),
      'Total Void Amount': _money(total),
      'Average Void Amount':
          _money(rows.isNotEmpty ? total / rows.length : 0.0),
      'Top Void Reason':
          _topReason(rows.map((o) => (o.voidReason ?? '').trim()), '—'),
      'Generated': _generated(),
    };
  }

  // ── Expenses (date: dateandTime) ─────────────────────────────────────
  static const expenseHeaders = [
    'Date & Time', 'Category', 'Reason', 'Payment Type', 'Amount'
  ];

  static List<dynamic> expenseRow(Expense e, String categoryName) => [
        ExportDateTime(e.dateandTime),
        categoryName,
        e.reason ?? '-',
        e.paymentType ?? '-',
        ExportMoney(e.amount),
      ];

  static Map<String, dynamic> expenseSummary(List<Expense> rows, String period) {
    double total = 0.0;
    for (final e in rows) {
      total += e.amount;
    }
    return {
      'Report Period': period,
      'Total Expenses Count': rows.length.toString(),
      'Total Expenses Amount': _money(total),
      'Average Expense': _money(rows.isNotEmpty ? total / rows.length : 0.0),
      'Generated': _generated(),
    };
  }

  // ── Item Cancellation (date: timestamp) ──────────────────────────────
  static const cancellationHeaders = [
    'Date & Time', 'Item', 'Qty', 'Amount', 'Reason', 'Staff', 'KOT'
  ];

  static List<dynamic> cancellationRow(ItemCancellationModel r) => [
        ExportDateTime(r.timestamp),
        r.variantName != null && r.variantName!.isNotEmpty
            ? '${r.itemName} (${r.variantName})'
            : r.itemName,
        r.quantity,
        ExportMoney(r.amount),
        r.reason,
        r.staffName ?? '—',
        r.kotNumber?.toString() ?? '—',
      ];

  static Map<String, dynamic> cancellationSummary(
      List<ItemCancellationModel> rows) {
    int qty = 0;
    double amount = 0;
    for (final r in rows) {
      qty += r.quantity;
      amount += r.amount;
    }
    final reasons = rows
        .map((r) => r.reason.trim())
        .where((r) => r != 'No reason given');
    return {
      'Total Cancellations': rows.length.toString(),
      'Total Items Qty': qty.toString(),
      'Total Amount': _money(amount),
      'Top Reason': _topReason(reasons, '—'),
      'Generated': _generated(),
    };
  }

  // ── POS End Day (date: report.date) ──────────────────────────────────
  static const endDayHeaders = [
    'Date', 'Total Sales', 'Discount', 'Opening Balance', 'Closing Balance',
    'Actual Cash', 'Difference', 'Cash Payment', 'Card Payment',
    'Online Payment'
  ];

  static List<dynamic> endDayRow(EndOfDayReport r) {
    double cash = 0.0, card = 0.0, online = 0.0;
    for (final p in r.paymentSummaries) {
      final type = p.paymentType.toLowerCase();
      if (type == 'cash') {
        cash += p.totalAmount;
      } else if (type == 'card') {
        card += p.totalAmount;
      } else if (type == 'online' || type == 'upi') {
        online += p.totalAmount;
      }
    }
    return [
      ExportDateTime(r.date),
      ExportMoney(r.totalSales),
      ExportMoney(r.totalDiscount),
      ExportMoney(r.openingBalance),
      ExportMoney(r.closingBalance),
      ExportMoney(r.cashReconciliation.actualCash),
      ExportMoney(r.cashReconciliation.difference),
      ExportMoney(cash),
      ExportMoney(card),
      ExportMoney(online),
    ];
  }

  static Map<String, dynamic> endDaySummary(
      List<EndOfDayReport> rows, String period) {
    double opening = 0.0, closing = 0.0, discount = 0.0;
    for (final r in rows) {
      opening += r.openingBalance;
      closing += r.closingBalance;
      discount += r.totalDiscount;
    }
    return {
      'Report Period': period,
      'Total Reports': rows.length.toString(),
      'Total Discount': _money(discount),
      'Total Opening Balance': _money(opening),
      'Total Closing Balance': _money(closing),
      'Generated': _generated(),
    };
  }
}
