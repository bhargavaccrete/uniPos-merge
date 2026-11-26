import '../../data/models/restaurant/db/pastordermodel_313.dart';
import '../../domain/services/restaurant/refund_service.dart';
import 'payment_mode_summary.dart';

/// The ONE restaurant rule for "how much came in, and went back, by method".
///
/// End of Day, the cash drawer and the Sales by Payment Mode report all read
/// these, so a refund paid out in cash can never come off UPI in one place and
/// off Cash in another. Method keys are the normalised labels of
/// [PaymentModeSummary.normalizeMethod] ('Cash', 'UPI', …).
class RefundAllocation {
  RefundAllocation._();

  static const double _eps = 0.000001;

  /// What [order] collected, per method.
  ///
  /// The recorded payment legs when there are any. Otherwise the single
  /// payment mode with the bill total — or, for a paid-then-voided order,
  /// `totalPaid` when recorded: a part-paid void collected less than its bill.
  /// (Voids written before part-paid voids existed were always fully paid,
  /// so the bill total is what they collected.) No legs for an unpaid order.
  static Map<String, double> paidLegsOf(PastOrderModel order) {
    final legs = <String, double>{};
    if (order.paymentListJson != null && order.paymentListJson!.isNotEmpty) {
      for (final p in order.paymentList) {
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount == 0) continue;
        final method = PaymentModeSummary.normalizeMethod(p['method'] as String?);
        legs[method] = (legs[method] ?? 0) + amount;
      }
      return legs;
    }
    final mode = (order.paymentmode ?? '').trim();
    if (mode.isEmpty || mode.toUpperCase() == 'N/A') return legs;
    final isVoided = (order.orderStatus ?? '').toUpperCase().trim() == 'VOIDED';
    final amount = isVoided
        ? (order.totalPaid ?? order.totalPrice)
        : order.totalPrice;
    if (amount != 0) legs[PaymentModeSummary.normalizeMethod(mode)] = amount;
    return legs;
  }

  /// Total collected by [order] — the base a refund can never exceed.
  static double collectedOf(PastOrderModel order) =>
      paidLegsOf(order).values.fold(0.0, (s, v) => s + v);

  /// What went back to the customer, per method, for the refunds of [order]
  /// that [where] keeps (all by default).
  ///
  /// A refund recorded with its methods comes off exactly those methods — a
  /// cash refund on a UPI sale comes off Cash. A refund recorded before the
  /// method was asked for is spread across what the order collected, in
  /// proportion: an APPROXIMATION, kept because the real method was never
  /// stored and cannot be recovered.
  static Map<String, double> refundedByMethod(
    PastOrderModel order, {
    bool Function(RefundEvent event)? where,
  }) {
    final out = <String, double>{};
    Map<String, double>? paid;
    for (final event in RefundService.refundEventsOf(order)) {
      if (where != null && !where(event)) continue;
      final legs = event.legs;
      if (legs != null) {
        for (final l in legs) {
          final method = PaymentModeSummary.normalizeMethod(l.method);
          out[method] = (out[method] ?? 0) + l.amount;
        }
        continue;
      }
      paid ??= paidLegsOf(order);
      final collected = paid.values.fold(0.0, (s, v) => s + v);
      if (collected.abs() < _eps) continue;
      for (final e in paid.entries) {
        out[e.key] = (out[e.key] ?? 0) + event.amount * e.value / collected;
      }
    }
    return out;
  }

  /// Whether [order]'s money belongs in the drawer and collection totals:
  /// everything except an UNPAID void ('VOID') and a cancellation. A paid
  /// void ('VOIDED') is refund pending — its money is still held (M7).
  static bool holdsMoney(PastOrderModel order) {
    final s = (order.orderStatus ?? '').toUpperCase().trim();
    if (s == 'CANCELLED') return false;
    return !s.contains('VOID') || s == 'VOIDED';
  }

  /// A session's collections per method: what its own orders hold net of
  /// their refunds, minus the refunds paid out in the session on orders of
  /// earlier sessions — each refund off the method it was paid by. The cash
  /// drawer reads this directly; End of Day reaches the same figure through
  /// its payment summary, external-refund adjustment and held voids.
  static Map<String, double> sessionCollections({
    required Iterable<PastOrderModel> orders,
    required bool Function(PastOrderModel order) inSession,
    required bool Function(RefundEvent event) refundInSession,
  }) {
    final out = <String, double>{};
    void add(String method, double amount) =>
        out[method] = (out[method] ?? 0) + amount;
    for (final o in orders) {
      if (!holdsMoney(o)) continue;
      if (inSession(o)) {
        netLegsOf(o).forEach(add);
      } else {
        refundedByMethod(o, where: refundInSession)
            .forEach((method, amount) => add(method, -amount));
      }
    }
    return out;
  }

  /// What [order] still holds per method: collected minus every refund.
  ///
  /// Not clamped at zero: a cash refund on a UPI sale really did take cash
  /// out of the drawer, so Cash goes negative while UPI stays whole.
  static Map<String, double> netLegsOf(PastOrderModel order) {
    final net = Map<String, double>.of(paidLegsOf(order));
    refundedByMethod(order).forEach((method, amount) {
      net[method] = (net[method] ?? 0) - amount;
    });
    return net;
  }
}
