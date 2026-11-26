import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import 'inventory_service.dart';
import 'order_concurrency.dart';
import 'settle_new_order.dart' show OrderSaveFailedException;
import 'stock_gate.dart';
import 'stock_journal.dart';

export 'settle_new_order.dart' show OrderSaveFailedException;

/// Outcome of [ExistingOrderUpdate.commit].
class ExistingOrderUpdateResult {
  /// Non-empty when refused for stock; nothing was written.
  final List<StockShortfall> shortfalls;

  /// Set when refused because the saved order changed on another device or
  /// is gone (INVX-1); nothing was written.
  final String? conflict;
  final OrderModel? order;
  final int? newKotNumber;

  const ExistingOrderUpdateResult._(
      this.shortfalls, this.order, this.newKotNumber, {this.conflict});

  bool get refused => conflict != null || shortfalls.isNotEmpty;

  String get message =>
      conflict ?? shortfalls.map((s) => s.message).join('; ');
}

/// Place Order on an EXISTING order (takeaway `_updateExistingOrder`): lines
/// added or increased are sold, lines removed or reduced are restored, and
/// the order is saved with the new KOT bookkeeping.
class ExistingOrderUpdate {
  ExistingOrderUpdate._();

  /// Inside the app-wide [StockGate] as ONE operation (S-04D):
  ///
  /// 0. The order [orderId] is read as SAVED (`OrderStore.readSaved`). Gone,
  ///    or its lines differ from [baseline] (the line → quantity map the
  ///    screen diffed against) → refused with [ExistingOrderUpdateResult.conflict],
  ///    nothing written (INVX-1). Captain writes the box directly; the
  ///    screen's copy would drop or revive its lines. Otherwise the in-memory
  ///    order is the saved one, so [build] reads it with
  ///    `orderStore.getOrderById` for KOT statuses, timestamps and payments.
  /// 1. Stock check with `InventoryService.stockShortfalls` on [deduct]
  ///    (increases carry the delta, plus new lines), crediting [returning]
  ///    (the removed / reduced lines). Refused → nothing written.
  ///    Before 0, unfinished cancel returns are finished
  ///    (`StockJournal.recoverCancels`). One still owed on this order, or
  ///    on an item this sale or its restores write, refuses with
  ///    [cancelPendingMessage] before the KOT number, nothing written.
  /// 2. The add-on KOT number when [needsKot].
  /// 3. [build] the order from the sale plan (stamped lines) and that number.
  /// 4. Save it — a failed save throws [OrderSaveFailedException] before any
  ///    stock moves.
  /// 5. Restore [restores], then deduct the plan.
  ///
  /// [build] must not open dialogs or print.
  static Future<ExistingOrderUpdateResult> commit({
    required String orderId,
    required Map<String, int> baseline,
    required List<CartItem> deduct,
    List<CartItem> returning = const [],
    required List<({CartItem line, int qty})> restores,
    required bool needsKot,
    required Future<OrderModel> Function(
            ({List<CartItem> lines, List<SaleStockUnit> units}) plan,
            int? newKotNumber)
        build,
  }) =>
      StockGate.run(() async {
        // Earlier cancels a stop left part-way first (Settle's recovery is
        // separate and unchanged).
        await StockJournal.recoverCancels();
        final List<JournalEntry> owed;
        try {
          owed = [
            for (final e in StockJournal.cancelEntries())
              if (e.hasUnfinished) e,
          ];
        } catch (e) {
          return ExistingOrderUpdateResult._([], null, null,
              conflict: '$cancelPendingMessage (the journal could not be '
                  'read: $e). Nothing was placed — try again.');
        }

        final OrderModel? latest;
        try {
          latest = await orderStore.readSaved(orderId);
        } catch (e) {
          // Nothing written yet: the same "not saved, no stock moved" outcome.
          throw OrderSaveFailedException('The order could not be read: $e');
        }
        if (latest == null) {
          return const ExistingOrderUpdateResult._([], null, null,
              conflict: OrderConcurrency.goneMessage);
        }
        if (OrderConcurrency.differsFromBaseline(
            baseline: baseline, saved: latest.items)) {
          return const ExistingOrderUpdateResult._([], null, null,
              conflict: OrderConcurrency.changedElsewhereMessage);
        }
        final shortfalls = await InventoryService.stockShortfalls(deduct,
            returning: returning);
        if (shortfalls.isNotEmpty) {
          return ExistingOrderUpdateResult._(shortfalls, null, null);
        }
        final plan = await InventoryService.planSale(deduct);
        // A return still owed on an item this writes, or on this order,
        // must finish before new stock moves.
        if (owed.isNotEmpty) {
          final touched = {
            for (final u in plan.units) u.item.id,
            for (final u in await InventoryService.planRestoreUnits(restores))
              u.item.id,
          };
          final names = <String>{
            for (final e in owed)
              for (final u in e.units)
                if (_owes(u) &&
                    (e.orderId == orderId || touched.contains(u.itemId)))
                  u.itemName,
          };
          if (names.isNotEmpty) {
            return ExistingOrderUpdateResult._([], null, null,
                conflict: '$cancelPendingMessage (${names.join(', ')}). '
                    'Nothing was placed — try Place Order again; if this '
                    'keeps happening, restart the app.');
          }
        }
        final kot = needsKot ? await orderStore.getNextKotNumber() : null;
        final order = await build(plan, kot);
        if (!await orderStore.updateOrder(order)) {
          throw OrderSaveFailedException(
              orderStore.errorMessage ?? 'The order could not be saved.');
        }
        await InventoryService.restoreLines(restores);
        await InventoryService.applyPlannedUnits(plan.units);
        return ExistingOrderUpdateResult._(const [], order, kot);
      });

  static const cancelPendingMessage =
      'Stock from an earlier item cancel is still being returned';

  /// Still to be applied automatically (a `review` unit is with a person).
  static bool _owes(JournalUnit u) =>
      u.state == StockJournal.planned ||
      u.state == StockJournal.applying ||
      u.state == StockJournal.written;
}
