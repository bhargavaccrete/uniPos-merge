import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';

/// Whether a refunded line goes back to stock by default. PURE.
///
/// Finished items — made to order, made in advance, hybrid, legacy — were
/// cooked or plated and almost never come back, so they start unchecked.
/// Trade Items, Raw Materials and Semi-Finished are handed back as they were
/// sold (a sealed bottle), so they start checked. The cashier can change
/// either; what a ticked line restores comes from its own sale stamp
/// (`InventoryService.restoreLines`), never from this rule.
class RefundRestockRule {
  RefundRestockRule._();

  /// [item] null = the item no longer exists: nothing to restock into.
  static bool defaultFor(Items? item) => item != null && !item.isFinished;

  /// Units of [line] that can still go back to stock: what a void or an
  /// earlier refund already restocked is gone from the offer.
  static int restorable(CartItem line) {
    final left = line.quantity - (line.restockedQuantity ?? 0);
    return left > 0 ? left : 0;
  }
}

/// The refund dialog's "Add back to stock" choices, one per line. Defaults
/// come from [RefundRestockRule]; an explicit choice wins. Keyed by line id,
/// so a choice survives rebuilt line objects and quantity edits.
class RefundRestockSelection {
  final Map<String, bool> _defaults;
  final Map<String, bool> _chosen = {};

  RefundRestockSelection(
    Iterable<CartItem> lines,
    Items? Function(String productId) lookup,
  ) : _defaults = {
          for (final line in lines)
            line.id: RefundRestockRule.defaultFor(lookup(line.productId)),
        };

  /// Whether [line] can still go back to stock at all — false once its void
  /// (or an earlier refund) restocked everything.
  bool canRestock(CartItem line) => RefundRestockRule.restorable(line) > 0;

  bool isSelected(CartItem line) =>
      canRestock(line) && (_chosen[line.id] ?? _defaults[line.id] ?? false);

  void select(CartItem line, bool selected) => _chosen[line.id] = selected;

  /// The refunded lines to restock: selected, still restorable, with a
  /// quantity above zero. The service caps each at what is left.
  Map<CartItem, int> restockFor(Map<CartItem, int> refund) => {
        for (final e in refund.entries)
          if (e.value > 0 && isSelected(e.key)) e.key: e.value,
      };
}
