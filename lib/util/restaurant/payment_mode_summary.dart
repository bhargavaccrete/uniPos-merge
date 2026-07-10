import '../../data/models/restaurant/db/eodmodel_317.dart';
import '../../data/models/restaurant/db/pastordermodel_313.dart';
import 'order_status_filter.dart';

/// Aggregates past orders into one [PaymentSummary] per payment method.
///
/// Shared by End of Day and the Sales by Payment Mode report so both read the
/// same numbers. Handles the three cases a naive `groupBy(paymentmode)` gets
/// wrong: split bills, proportional refunds, and the case/spacing variants the
/// two settle paths write.
class PaymentModeSummary {
  PaymentModeSummary._();

  /// One [PaymentSummary] per method, sorted by amount descending.
  ///
  /// Split bills are decomposed per leg, refunds are spread proportionally
  /// across every leg, and orders excluded from revenue (void / cancelled /
  /// fully refunded) are skipped.
  static List<PaymentSummary> summarize(List<PastOrderModel> orders) {
    final Map<String, double> paymentTotals = {};
    final Map<String, int> paymentCounts = {};

    double grandTotal = 0.0;

    for (final order in orders) {
      final status = order.orderStatus?.toUpperCase() ?? '';
      if (OrderStatusFilter.isExcludedFromRevenue(status)) continue;

      final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);

      // Always decode paymentListJson if present — it's the source of truth.
      // Avoid relying on isSplitPayment flag which can be null for legacy orders.
      if (order.paymentListJson != null && order.paymentListJson!.isNotEmpty) {
        final refundRatio =
            order.totalPrice > 0 ? netAmount / order.totalPrice : 1.0;
        for (final entry in order.paymentList) {
          // Normalise so 'Cash'/'cash'/'CASH' collapse into one bucket.
          final method = normalizeMethod(entry['method'] as String?);
          final amt =
              ((entry['amount'] as num?)?.toDouble() ?? 0.0) * refundRatio;
          paymentTotals[method] = (paymentTotals[method] ?? 0.0) + amt;
          paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
          grandTotal += amt;
        }
      } else {
        final paymentType = normalizeMethod(order.paymentmode);
        paymentTotals[paymentType] =
            (paymentTotals[paymentType] ?? 0.0) + netAmount;
        paymentCounts[paymentType] = (paymentCounts[paymentType] ?? 0) + 1;
        grandTotal += netAmount;
      }
    }

    return paymentTotals.entries.map((entry) {
      final paymentType = entry.key;
      final totalAmount = entry.value;
      final transactionCount = paymentCounts[paymentType] ?? 0;
      final percentage = grandTotal > 0 ? (totalAmount / grandTotal) * 100 : 0.0;

      return PaymentSummary(
        paymentType: paymentType,
        totalAmount: totalAmount,
        transactionCount: transactionCount,
        percentage: percentage,
      );
    }).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  /// Canonical display label for a payment method so case/spacing variants
  /// (e.g. 'Cash', 'cash', 'CASH ') collapse into one bucket in summaries.
  static String normalizeMethod(String? raw) {
    final m = (raw ?? '').trim().toLowerCase();
    if (m.isEmpty) return 'Unknown';
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'wallet':
        return 'Wallet';
      case 'credit':
        return 'Credit';
      case 'split':
      case 'split payment':
        return 'Split Payment';
      default:
        // Title-case unknown/custom methods for a tidy label.
        return m[0].toUpperCase() + m.substring(1);
    }
  }

  /// Per-order display label: the legs of a split bill joined ("Cash + UPI"),
  /// or the single normalised method.
  static String methodLabel(PastOrderModel order) {
    if (order.paymentListJson != null && order.paymentListJson!.isNotEmpty) {
      final legs = order.paymentList
          .map((e) => normalizeMethod(e['method'] as String?))
          .toSet()
          .toList();
      if (legs.isNotEmpty) return legs.join(' + ');
    }
    return normalizeMethod(order.paymentmode);
  }
}
