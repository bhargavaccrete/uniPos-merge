import '../../data/models/restaurant/db/eodmodel_317.dart';
import '../../data/models/restaurant/db/pastordermodel_313.dart';
import 'order_status_filter.dart';
import 'refund_allocation.dart';
import '../../domain/services/restaurant/refund_service.dart';

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
      if (OrderStatusFilter.isExcludedFromRevenue(status)) {
        // A fully refunded order nets to nothing overall — but a refund paid
        // out by a different method than the sale (cash back on a UPI bill)
        // still moved money between methods. Counted only when the refund's
        // methods were recorded; older refunds keep the old exclusion.
        if (status == 'FULLY_REFUNDED' &&
            RefundService.refundEventsOf(order).any((e) => e.legs != null)) {
          RefundAllocation.netLegsOf(order).forEach((method, amt) {
            if (amt.abs() < 0.000001) return;
            paymentTotals[method] = (paymentTotals[method] ?? 0.0) + amt;
            grandTotal += amt;
          });
        }
        continue;
      }

      // What the order collected per method, net of its refunds — each
      // refund off the method it was actually paid out by, or (refunds
      // recorded before that was asked) spread in proportion. The same rule
      // End of Day and the cash drawer use (RefundAllocation).
      final hasLegs =
          order.paymentListJson != null && order.paymentListJson!.isNotEmpty;
      final net = RefundAllocation.netLegsOf(order);
      if (net.isEmpty && !hasLegs) {
        // No recorded method at all: one row under the stored mode, as before.
        final paymentType = normalizeMethod(order.paymentmode);
        final netAmount = order.totalPrice - (order.refundAmount ?? 0.0);
        paymentTotals[paymentType] =
            (paymentTotals[paymentType] ?? 0.0) + netAmount;
        paymentCounts[paymentType] = (paymentCounts[paymentType] ?? 0) + 1;
        grandTotal += netAmount;
        continue;
      }
      net.forEach((method, amt) {
        paymentTotals[method] = (paymentTotals[method] ?? 0.0) + amt;
        paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
        grandTotal += amt;
      });
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
