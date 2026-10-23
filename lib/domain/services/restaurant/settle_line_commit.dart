import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/ordermodel_309.dart';
import 'inventory_service.dart';
import 'line_stock.dart';
import 'order_line_diff.dart';
import 'stock_journal.dart';

/// What Settle on an existing order committed before taking payment.
class SettleCommitResult {
  /// The order carrying the settled lines and KOT bookkeeping.
  final OrderModel order;

  /// Lines that were new since the last KOT (printed as one add-on KOT).
  final List<CartItem> addedLines;

  /// KOT number minted for [addedLines], or null when nothing was added.
  final int? newKotNumber;

  const SettleCommitResult({
    required this.order,
    required this.addedLines,
    required this.newKotNumber,
  });
}

/// A settle whose lines are saved but whose stock deduction did not finish.
/// The work itself is persisted in the [StockJournal] entry [entryId] (so it
/// survives leaving the screen or a restart); the screen keeps this only to
/// get [result] back — and print the add-on KOT — on its own retry.
class SettlePendingStock {
  final String entryId;

  /// What the commit returns once the stock is complete.
  final SettleCommitResult result;

  SettlePendingStock({required this.entryId, required this.result});
}

/// The lines were saved, but a stock deduction failed part-way. Nothing is
/// lost: the journal entry finishes on the next Settle or at startup.
class SettleStockIncompleteException implements Exception {
  final SettlePendingStock pending;
  final Object cause;
  const SettleStockIncompleteException(this.pending, this.cause);
  @override
  String toString() =>
      'Stock update did not finish ($cause). It is saved and will complete '
      'when you tap Settle again or on the next app start.';
}

/// Settle refused: saved lines were removed or reduced. Those need Place
/// Order, which prints the correction KOT and records the cancellation.
class SettleBlockedException implements Exception {
  final String message;
  const SettleBlockedException(this.message);
  @override
  String toString() => message;
}

/// The line/stock step of Settle on an existing order (customerdetails.dart).
class SettleLineCommit {
  /// Diffs [itemsToSettle] by line id against the SAVED order (the screen's
  /// [snapshot] may predate an immediate cancel), deducts only increases and
  /// new lines, and appends one KOT for the new lines.
  ///
  /// Stock goes through a persisted [StockJournal] entry written BEFORE the
  /// order lines, so a failure part-way is finished later instead of lost.
  ///
  /// Throws [SettleBlockedException] before any write when a saved line was
  /// removed or reduced, and [SettleStockIncompleteException] when the lines
  /// are saved but the deduction stopped part-way — pass its `pending` back
  /// to get the same result once the stock completes.
  static Future<SettleCommitResult> commit({
    required OrderModel snapshot,
    required List<CartItem> itemsToSettle,
    SettlePendingStock? pending,
  }) async {
    // Finish anything left by an earlier attempt or a crash first, so the
    // diff below sees settled stock work (and never redoes it).
    final failures = await StockJournal.recoverAll();

    if (pending != null) {
      final left = StockJournal.get(pending.entryId);
      if (left != null && left.hasUnfinished) {
        throw SettleStockIncompleteException(
            pending, failures[pending.entryId] ?? 'stock still pending');
      }
      final r = pending.result;
      return SettleCommitResult(
        order: orderStore.getOrderById(r.order.id) ?? r.order,
        addedLines: r.addedLines,
        newKotNumber: r.newKotNumber,
      );
    }

    final OrderModel saved = orderStore.getOrderById(snapshot.id) ?? snapshot;
    final diff = OrderLineDiff.between(
      baseline: saved.items,
      current: itemsToSettle,
    );
    if (diff.hasCancellations) {
      throw const SettleBlockedException(
        'Items were removed or reduced. Use Place Order to apply the '
        'cancellation first, then settle.',
      );
    }
    if (diff.isEmpty) {
      return SettleCommitResult(
          order: saved, addedLines: const [], newKotNumber: null);
    }

    // One plan for the increases and new lines: its units go to the journal,
    // its stamps onto the saved lines (LineStock) for every later restore.
    final salePlan =
        await InventoryService.planSale([...diff.increased, ...diff.added]);
    final soldById = {for (final s in salePlan.lines) s.id: s};

    // Saved lines keep their positions (KOT boundaries index into them);
    // new lines go last, as one trailing KOT.
    final currentById = {for (final c in itemsToSettle) c.id: c};
    CartItem restamp(CartItem savedLine) {
      final curr = currentById[savedLine.id]!;
      if (!savedLine.hasStockStamp) return curr; // pre-Phase-1 line
      final base = curr.copyWith(
          ownStockQty: savedLine.ownStockQty, freshQty: savedLine.freshQty);
      final sold = soldById[savedLine.id];
      return sold == null
          ? base
          : LineStock.withSale(base,
              own: sold.ownStockQty ?? 0, fresh: sold.freshQty ?? 0);
    }

    final lines = [
      for (final s in saved.items) restamp(s),
      for (final a in diff.added) soldById[a.id] ?? a,
    ];

    final kotNumbers = List<int>.from(saved.kotNumbers);
    final kotBoundaries = List<int>.from(saved.kotBoundaries);
    final kotStatuses = Map<int, String>.from(saved.kotStatuses ?? {});
    int? newKotNumber;
    if (diff.added.isNotEmpty) {
      newKotNumber = await orderStore.getNextKotNumber();
      kotNumbers.add(newKotNumber);
      kotBoundaries.add(lines.length);
      kotStatuses[newKotNumber] = 'Cooking';
    }

    final committed = saved.copyWith(
      items: lines,
      kotNumbers: kotNumbers,
      kotBoundaries: kotBoundaries,
      kotStatuses: kotStatuses,
      itemCountAtLastKot: lines.length,
      status: diff.added.isNotEmpty ? 'Cooking' : saved.status,
    );

    // 1. Journal first: the exact stock work, before any write it covers.
    final entry = await StockJournal.open(
      orderId: committed.id,
      target: {for (final c in lines) c.id: c.quantity},
      units: salePlan.units,
    );

    // 2. Order lines. On failure nothing has moved: drop the entry.
    if (!await orderStore.updateOrder(committed)) {
      await StockJournal.delete(entry.id);
      throw Exception(orderStore.errorMessage ?? 'Could not save the order.');
    }
    await StockJournal.markOrderSaved(entry);

    final result = SettleCommitResult(
      order: orderStore.getOrderById(committed.id) ?? committed,
      addedLines: diff.added,
      newKotNumber: newKotNumber,
    );

    // 3. Stock. A failure keeps the entry; it resumes, never repeats.
    try {
      await StockJournal.complete(entry);
    } catch (e) {
      throw SettleStockIncompleteException(
          SettlePendingStock(entryId: entry.id, result: result), e);
    }
    return result;
  }
}
