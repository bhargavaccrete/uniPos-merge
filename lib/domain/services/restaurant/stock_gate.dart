import 'dart:async';

import '../../../data/models/restaurant/db/cartmodel_308.dart';
import 'inventory_service.dart';

/// Outcome of [StockGate.sell].
class GatedSale {
  /// Non-empty when the order was refused; nothing was written.
  final List<StockShortfall> shortfalls;

  const GatedSale._(this.shortfalls);

  bool get refused => shortfalls.isNotEmpty;

  /// "Paneer Tikka (available 2 pcs, requested 4 pcs); …" — for a refusal.
  String get message => shortfalls.map((s) => s.message).join('; ');
}

/// One app-wide queue for "check stock, then deduct it" (S-04A).
///
/// Every order path that refuses on stock and then deducts it runs that whole
/// operation through [run], one at a time. A check and its deduction are
/// separated by awaits (order numbers, Hive writes), and a second order
/// checked in that gap would see stock the first is about to take — so two
/// orders could both pass and oversell. All such paths live in this one app
/// process (Captain orders arrive over HTTP into it), so one queue covers
/// them all.
///
/// * **Re-entrant**: [run] inside [run] runs directly, so a gated operation
///   that calls another can never wait on itself.
/// * **Failure-safe**: a body that throws releases the queue for the next.
/// * Keep bodies short — no printing, dialogs or network waits inside.
class StockGate {
  StockGate._();

  static Future<void> _tail = Future.value();
  static final Object _zoneKey = Object();

  /// Whether the caller is already inside the gate.
  static bool get isHeld => Zone.current[_zoneKey] == true;

  /// Runs [body] after every earlier gated operation has finished.
  static Future<T> run<T>(Future<T> Function() body) {
    if (isHeld) return body();
    final result = _tail.then(
        (_) => runZoned(body, zoneValues: {_zoneKey: true}));
    // A failed operation must not block the ones queued behind it.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// The common POS shape, gated as ONE operation: check [items] with
  /// [InventoryService.stockShortfalls] — refused → nothing written —
  /// then plan, [write] the order (numbers, customer, the order record), and
  /// deduct the plan's stock. [write] gets the plan so the saved lines carry
  /// its stock stamps; if it throws, nothing is deducted.
  static Future<GatedSale> sell(
    List<CartItem> items, {
    required Future<void> Function(
            ({List<CartItem> lines, List<SaleStockUnit> units}) plan)
        write,
  }) =>
      run(() async {
        final shortfalls = await InventoryService.stockShortfalls(items);
        if (shortfalls.isNotEmpty) return GatedSale._(shortfalls);
        final plan = await InventoryService.planSale(items);
        await write(plan);
        await InventoryService.applyPlannedUnits(plan.units);
        return const GatedSale._([]);
      });
}
