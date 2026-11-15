import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import 'inventory_service.dart';
import 'kot_layout.dart';
import 'order_concurrency.dart';
import 'order_line_cancel.dart';
import 'saved_service_charge.dart';
import 'stock_gate.dart';
import 'stock_journal.dart';

/// A cancel refused before anything was written.
class ActiveLineCancelRefused implements Exception {
  final String message;
  const ActiveLineCancelRefused(this.message);
  @override
  String toString() => message;
}

/// What a cancel that emptied the order does with it.
enum WhenEmpty {
  /// Refused: emptying an order is a void (Active Orders).
  refuse,

  /// The order is deleted (Takeaway, nothing new pending).
  delete,

  /// The order is kept with no lines (Takeaway, new lines still pending).
  keep,
}

class ActiveLineCancelResult {
  /// The saved order the cancel was applied to.
  final OrderModel before;

  /// The order as saved after it; null when it was deleted.
  final OrderModel? order;

  /// The saved line at the cancelled quantity (Cancel KOT, audit).
  final CartItem cancelled;

  /// The KOT that held the line, or null.
  final int? kotNumber;

  /// Set when the order is saved but its stock return did not finish; the
  /// journal finishes it later.
  final String? stockWarning;

  const ActiveLineCancelResult({
    required this.before,
    required this.order,
    required this.cancelled,
    required this.kotNumber,
    this.stockWarning,
  });

  bool get orderDeleted => order == null;
}

/// Cancelling part or all of one KOT'd line of an ACTIVE order — Takeaway's
/// immediate cancel and Active Orders' single-item cancel.
///
/// Inside the app-wide [StockGate], against the order as SAVED (Captain
/// writes the box directly, so a screen's copy can be behind):
/// refused before any write when the order or line is gone, the saved line
/// holds less than [qty], or its KOT is cooked. The stock return goes
/// through a persisted [StockJournal] cancel entry written before the order,
/// so a stop at any point returns it exactly once.
class ActiveLineCancel {
  static const cookedMessage = 'Cannot cancel cooked items';
  static const lastItemMessage =
      'This is the order\'s last item — void the order instead.';
  static const alreadyCancelledMessage = 'This item was already cancelled.';
  static const paidLastItemMessage =
      'This order has a payment recorded, so its last item cannot be '
      'cancelled here. Void the order from Active Orders — the payment is '
      'kept and can be refunded.';

  /// Whether [order] records money received. Only recorded payment counts —
  /// not `isFullyPaid`, which is also true of an order totalling zero.
  static bool holdsPayment(OrderModel order) =>
      (order.totalPaid ?? 0) > 0 ||
      order.isPaid == true ||
      const {'paid', 'partially paid'}
          .contains(order.paymentStatus?.toLowerCase());

  /// [qty] null cancels the whole saved line. [isDelivery] defaults to the
  /// order's type.
  static Future<ActiveLineCancelResult> commit({
    required String orderId,
    required String lineId,
    int? qty,
    required WhenEmpty whenEmpty,
    bool? isDelivery,
  }) =>
      StockGate.run(() => _commit(
            orderId: orderId,
            lineId: lineId,
            qty: qty,
            whenEmpty: whenEmpty,
            isDelivery: isDelivery,
          ));

  static Future<ActiveLineCancelResult> _commit({
    required String orderId,
    required String lineId,
    required int? qty,
    required WhenEmpty whenEmpty,
    required bool? isDelivery,
  }) async {
    // Earlier cancels a stop left part-way first, so the read below sees
    // their stock settled.
    await StockJournal.recoverCancels();

    final OrderModel? saved;
    try {
      saved = await orderStore.readSaved(orderId);
    } catch (e) {
      throw ActiveLineCancelRefused('Could not read the order: $e');
    }
    if (saved == null) {
      throw const ActiveLineCancelRefused(OrderConcurrency.goneMessage);
    }
    final line = saved.items.where((i) => i.id == lineId).firstOrNull;
    if (line == null) {
      throw const ActiveLineCancelRefused(alreadyCancelledMessage);
    }
    final cancelQty = qty ?? line.quantity;
    if (cancelQty < 1) {
      throw ArgumentError.value(qty, 'qty', 'must be at least 1');
    }
    if (cancelQty > line.quantity) {
      throw const ActiveLineCancelRefused(
          OrderConcurrency.changedElsewhereMessage);
    }
    if (OrderLineCancel.isCooked(saved, lineId)) {
      throw const ActiveLineCancelRefused(cookedMessage);
    }

    final layout = KotLayout.removeQuantity(
      items: saved.items,
      kotNumbers: saved.kotNumbers,
      kotBoundaries: saved.kotBoundaries,
      kotStatuses: saved.kotStatuses ?? {},
      lineId: lineId,
      qty: cancelQty,
    );
    final emptied = layout.items.isEmpty;
    if (emptied && whenEmpty == WhenEmpty.refuse) {
      throw const ActiveLineCancelRefused(lastItemMessage);
    }
    final deleting = emptied && whenEmpty == WhenEmpty.delete;
    // Deleting would drop the payment from the order, End of Day and the
    // drawer; a void keeps it (VOIDED) for a refund.
    if (deleting && holdsPayment(saved)) {
      throw const ActiveLineCancelRefused(paidLastItemMessage);
    }

    final calc = SavedServiceCharge.calculate(saved, layout.items,
        isDelivery:
            isDelivery ?? saved.orderType.toLowerCase().contains('delivery'));
    final updated = saved.copyWith(
      items: layout.items,
      kotNumbers: layout.kotNumbers,
      kotBoundaries: layout.kotBoundaries,
      kotStatuses: layout.kotStatuses,
      itemCountAtLastKot: layout.itemCountAtLastKot,
      totalPrice: calc.grandTotal,
      // Already the pre-tax base in both tax modes (M5).
      subTotal: calc.subtotal,
      gstAmount: calc.totalGST,
      // The new amount, so a later recalculation finds the same %.
      serviceCharge: calc.serviceChargeAmount,
    );

    // 1. Journal: the return, from the SAVED line's stamp, before the write.
    final entry = await StockJournal.openCancel(
      orderId: orderId,
      target: deleting ? const {} : {lineId: line.quantity - cancelQty},
      units: await InventoryService.planRestoreUnits(
          [(line: line, qty: cancelQty)]),
      tableNo: saved.tableNo,
    );

    // 2. The order. The store reports a failure as false — but the write may
    // have landed, so the saved order decides.
    final ok = deleting
        ? await orderStore.deleteOrder(orderId)
        : await orderStore.updateOrder(updated);
    if (!ok) {
      final landed = await StockJournal.cancelWasSaved(entry);
      if (landed == false) {
        await StockJournal.delete(entry.id);
        throw ActiveLineCancelRefused(
            orderStore.errorMessage ?? 'Could not save the order. Nothing '
                'was cancelled.');
      }
      if (landed == null) {
        throw const ActiveLineCancelRefused(
            'The cancel could not be confirmed. It will be checked again — '
            'reopen the order before cancelling again.');
      }
    }
    await StockJournal.markOrderSaved(entry);

    // 3. Stock. A failure keeps the entry; it resumes, never repeats.
    String? stockWarning;
    try {
      await StockJournal.complete(entry);
      if (entry.units.any((u) => u.state == StockJournal.review)) {
        stockWarning = 'Item cancelled. Some stock could not be returned '
            'automatically — check the Stock Check alert.';
      }
    } catch (e) {
      stockWarning = 'Item cancelled, but returning its stock did not finish '
          '($e). It will finish automatically.';
    }

    return ActiveLineCancelResult(
      before: saved,
      order: deleting ? null : (orderStore.getOrderById(orderId) ?? updated),
      cancelled: line.copyWith(quantity: cancelQty),
      kotNumber: _kotOf(saved, lineId),
      stockWarning: stockWarning,
    );
  }

  static int? _kotOf(OrderModel order, String lineId) {
    final idx = order.items.indexWhere((i) => i.id == lineId);
    if (idx == -1) return null;
    final kotIndex = order.kotBoundaries.indexWhere((b) => idx < b);
    if (kotIndex == -1 || kotIndex >= order.kotNumbers.length) return null;
    return order.kotNumbers[kotIndex];
  }
}
