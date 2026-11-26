import '../../../data/models/restaurant/db/cartmodel_308.dart';
import 'kot_status_rule.dart';
import 'line_stock.dart';

/// An order's lines plus the KOT bookkeeping that indexes into them.
///
/// `kotBoundaries[i]` is the exclusive end index of KOT `kotNumbers[i]` in
/// [items], so removing a line must shift every later boundary or the void's
/// served/unserved split (activeorder.dart) reads the wrong lines.
class KotLayout {
  final List<CartItem> items;
  final List<int> kotNumbers;
  final List<int> kotBoundaries;
  final Map<int, String> kotStatuses;

  const KotLayout({
    required this.items,
    required this.kotNumbers,
    required this.kotBoundaries,
    required this.kotStatuses,
  });

  /// Every saved line has been sent to the kitchen.
  int get itemCountAtLastKot => items.length;

  /// What a void puts back, per line: every line in a KOT whose food is not
  /// yet consumed ([KotStatusRule]) restores what is still restorable, and
  /// the void record keeps those lines marked restocked
  /// ([LineStock.restocked]) — so a later refund of the same record finds
  /// nothing left to restock (F2). Served lines are untouched.
  ///
  /// PURE. Used by the Active Orders void and the EOD auto-void.
  static ({
    List<CartItem> recordItems,
    List<({CartItem line, int qty})> restores,
  }) voidPlan({
    required List<CartItem> items,
    required List<int> kotNumbers,
    required List<int> kotBoundaries,
    required Map<int, String> kotStatuses,
    required String orderStatus,
  }) {
    final recordItems = List<CartItem>.from(items);
    final restores = <({CartItem line, int qty})>[];
    int start = 0;
    for (int i = 0; i < kotNumbers.length; i++) {
      final end = (i < kotBoundaries.length ? kotBoundaries[i] : items.length)
          .clamp(start, items.length);
      final status = kotStatuses[kotNumbers[i]] ?? orderStatus;
      if (!KotStatusRule.isConsumed(status)) {
        for (int idx = start; idx < end; idx++) {
          final line = items[idx];
          final qty = line.quantity - (line.restockedQuantity ?? 0);
          if (qty <= 0) continue;
          restores.add((line: line, qty: qty));
          recordItems[idx] = LineStock.restocked(line, qty);
        }
      }
      start = end;
    }
    return (recordItems: recordItems, restores: restores);
  }

  /// Quantities a void may put back: every line in a KOT whose food is not
  /// yet consumed ([KotStatusRule]; a KOT with no status of its own takes
  /// [orderStatus]). Boundaries past the item count are clamped.
  ///
  /// PURE. Used by the Active Orders void and the EOD auto-void.
  static Map<CartItem, int> unservedQuantities({
    required List<CartItem> items,
    required List<int> kotNumbers,
    required List<int> kotBoundaries,
    required Map<int, String> kotStatuses,
    required String orderStatus,
  }) {
    final itemsToRestock = <CartItem, int>{};
    int start = 0;
    for (int i = 0; i < kotNumbers.length; i++) {
      final kotNum = kotNumbers[i];
      final end = (i < kotBoundaries.length ? kotBoundaries[i] : items.length)
          .clamp(start, items.length);
      final kotStatus = kotStatuses[kotNum] ?? orderStatus;

      if (!KotStatusRule.isConsumed(kotStatus)) {
        for (final item in items.sublist(start, end)) {
          if (item.quantity > 0) {
            itemsToRestock[item] = (itemsToRestock[item] ?? 0) + item.quantity;
          }
        }
      }
      start = end;
    }
    return itemsToRestock;
  }

  /// The layout after cancelling [qty] of the line [lineId].
  ///
  /// PURE. Unknown [lineId] or a non-positive [qty] returns the input as-is.
  static KotLayout removeQuantity({
    required List<CartItem> items,
    required List<int> kotNumbers,
    required List<int> kotBoundaries,
    required Map<int, String> kotStatuses,
    required String lineId,
    required int qty,
  }) {
    final newItems = [for (final o in items) o.copyWith()];
    final numbers = List<int>.from(kotNumbers);
    final boundaries = List<int>.from(kotBoundaries);
    final statuses = Map<int, String>.from(kotStatuses);
    final layout = KotLayout(
      items: newItems,
      kotNumbers: numbers,
      kotBoundaries: boundaries,
      kotStatuses: statuses,
    );

    final idx = items.indexWhere((o) => o.id == lineId);
    if (idx == -1 || qty <= 0) return layout;

    final remaining = items[idx].quantity - qty;
    if (remaining > 0) {
      // Line stays, so every index — and every boundary — stays put. Its
      // stock stamp shrinks with it (fresh first), matching the restore.
      newItems[idx] = LineStock.reduced(items[idx], qty);
      return layout;
    }

    newItems.removeAt(idx);
    // Same rules as the Active Orders single-item cancel
    // (activeorder.dart:1563-1578): the owning KOT and every later one shrink
    // by one; a KOT left empty is dropped with its number and status.
    final kotIndex = boundaries.indexWhere((b) => idx < b);
    if (kotIndex == -1) return layout;
    for (var i = kotIndex; i < boundaries.length; i++) {
      boundaries[i] = boundaries[i] - 1;
    }
    final prev = kotIndex == 0 ? 0 : boundaries[kotIndex - 1];
    // OrderModel requires at least one KOT, so the last one stays (empty)
    // when the order survives with only unplaced items pending.
    if (boundaries[kotIndex] == prev && boundaries.length > 1) {
      boundaries.removeAt(kotIndex);
      if (kotIndex < numbers.length) {
        statuses.remove(numbers[kotIndex]);
        numbers.removeAt(kotIndex);
      }
    }
    return layout;
  }
}
