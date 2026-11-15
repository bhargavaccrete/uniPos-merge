import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../util/restaurant/staticswitch.dart';
import 'order_concurrency.dart';
import 'saved_service_charge.dart';
import 'stock_gate.dart';

/// A merge refused before anything was written.
class TableMergeRefused implements Exception {
  final String message;
  const TableMergeRefused(this.message);
  @override
  String toString() => message;
}

/// Merge Table: the source table's order moves into the target's.
///
/// Inside the app-wide [StockGate], against both orders as SAVED (Captain
/// writes the box directly). No stock moves — every line was deducted when
/// it was placed and keeps its stamp.
///
/// Money: the merged order is priced the way every screen prices a saved
/// order ([SavedServiceCharge]) — items, the saved discount AMOUNT, the
/// service charge at the % the saved amount implies. So the merge stores the
/// two discount and service-charge amounts added together, and is refused
/// unless pricing the merged order that way gives exactly the two orders'
/// taxable, GST, discount and service charge added together. Refused too
/// when their service-charge rates differ: a later cancel would re-price the
/// remaining lines at a rate neither bill had.
class TableMerge {
  static const double _eps = 0.01;

  /// Service-charge rates (%) closer than this count as the same rate.
  static const double _rateEps = 0.001;

  static Future<OrderModel> commit({
    required String targetId,
    required String sourceId,
  }) =>
      StockGate.run(() => _commit(targetId: targetId, sourceId: sourceId));

  /// The merge candidates' rule (the picker uses the same): an open,
  /// unpaid Dine In order on a table.
  static bool canBeMergedIn(OrderModel o) =>
      (o.status == 'Cooking' || o.status == 'Processing') &&
      !o.isFullyPaid &&
      (o.totalPaid ?? 0) <= 0 &&
      o.orderType == 'Dine In' &&
      o.tableNo != null &&
      o.tableNo!.isNotEmpty;

  static Future<OrderModel> _commit({
    required String targetId,
    required String sourceId,
  }) async {
    if (targetId == sourceId) {
      throw const TableMergeRefused('Choose a different table to merge.');
    }
    final OrderModel? t;
    final OrderModel? s;
    try {
      t = await orderStore.readSaved(targetId);
      s = await orderStore.readSaved(sourceId);
    } catch (e) {
      throw TableMergeRefused('Could not read the orders: $e');
    }
    if (t == null) {
      throw const TableMergeRefused(OrderConcurrency.goneMessage);
    }
    if (s == null || !canBeMergedIn(s) || s.tableNo == t.tableNo) {
      throw const TableMergeRefused(
          'That table\'s order changed (paid, settled or moved). Pick the '
          'table again.');
    }
    if (t.orderType != 'Dine In') {
      throw const TableMergeRefused('Only Dine In tables can be merged.');
    }
    // An old order flagged paid with no payment recorded counts as settled;
    // the merged lines would never be charged.
    if (t.isPaid == true && (t.totalPaid ?? 0) == 0) {
      throw const TableMergeRefused('This order is already settled.');
    }

    final tIds = {for (final l in t.items) l.id};
    if (s.items.any((l) => tIds.contains(l.id)) ||
        s.kotNumbers.any(t.kotNumbers.contains)) {
      throw const TableMergeRefused(
          'These orders cannot be merged: they share a line or KOT number.');
    }

    final bool tIncl = t.isTaxInclusive ?? AppSettings.isTaxInclusive;
    final bool sIncl = s.isTaxInclusive ?? AppSettings.isTaxInclusive;
    if (tIncl != sIncl) {
      throw const TableMergeRefused(
          'These orders were placed with different tax modes (inclusive / '
          'exclusive) and cannot be merged.');
    }

    final tRate = SavedServiceCharge.ratePercentOf(t, isDelivery: false);
    final sRate = SavedServiceCharge.ratePercentOf(s, isDelivery: false);
    if ((tRate - sRate).abs() > _rateEps) {
      throw const TableMergeRefused(
          'These orders have different service charges and cannot be merged. '
          'Settle them separately.');
    }

    // Lines and KOTs: the source's follow the target's, positions shifted.
    final combined = [...t.items, ...s.items];
    final kotNumbers = [...t.kotNumbers, ...s.kotNumbers];
    final kotBoundaries = [
      ...t.kotBoundaries,
      for (final b in s.kotBoundaries) b + t.items.length,
    ];
    // A KOT with no status of its own takes the ORDER's — so a source KOT
    // that relied on the source order's status gets it written down, or the
    // target's status would change whether its food counts as cooked.
    final kotStatuses = <int, String>{...?t.kotStatuses};
    for (final k in s.kotNumbers) {
      final status = s.getKotStatus(k);
      if ((s.kotStatuses?.containsKey(k) ?? false) || status != t.status) {
        kotStatuses[k] = status;
      }
    }
    final kotTimestamps = <int, DateTime>{
      ...?t.kotTimestamps,
      ...?s.kotTimestamps,
    };

    final draft = t.copyWith(
      items: combined,
      kotNumbers: kotNumbers,
      kotBoundaries: kotBoundaries,
      kotStatuses: kotStatuses,
      kotTimestamps: kotTimestamps,
      itemCountAtLastKot: combined.length,
      discount: (t.discount ?? 0) + (s.discount ?? 0),
      serviceCharge: (t.serviceCharge ?? 0) + (s.serviceCharge ?? 0),
    );

    final tc = SavedServiceCharge.calculate(t, t.items, isDelivery: false);
    final sc = SavedServiceCharge.calculate(s, s.items, isDelivery: false);
    final mc = SavedServiceCharge.calculate(draft, combined, isDelivery: false);
    bool same(double merged, double a, double b) =>
        (merged - (a + b)).abs() < _eps;
    if (!same(mc.taxableAmount, tc.taxableAmount, sc.taxableAmount) ||
        !same(mc.totalGST, tc.totalGST, sc.totalGST) ||
        !same(mc.discountAmount, tc.discountAmount, sc.discountAmount) ||
        !same(mc.serviceChargeAmount, tc.serviceChargeAmount,
            sc.serviceChargeAmount)) {
      throw const TableMergeRefused(
          'Merging would change the bill amounts (the orders\' discounts '
          'apply to items taxed at different rates). Settle them separately.');
    }

    final merged = draft.copyWith(
      totalPrice: mc.grandTotal,
      // Already the pre-tax base in both tax modes (M5).
      subTotal: mc.subtotal,
      gstAmount: mc.totalGST,
    );

    if (!await orderStore.updateOrder(merged)) {
      throw TableMergeRefused(
          orderStore.errorMessage ?? 'Could not save the merge. Nothing changed.');
    }
    if (!await orderStore.deleteOrder(s.id)) {
      // Never leave the source's lines in both orders.
      await orderStore.updateOrder(t);
      throw TableMergeRefused(orderStore.errorMessage ??
          'Could not remove the merged table\'s order. Nothing changed.');
    }
    return orderStore.getOrderById(merged.id) ?? merged;
  }
}
