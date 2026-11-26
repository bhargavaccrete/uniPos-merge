import '../../../data/models/restaurant/db/cartmodel_308.dart';

/// How a working list of order lines differs from the saved one, keyed by
/// [CartItem.id] — the same rules as Place Order (takeaway.dart
/// `_updateExistingOrder`). Delta lines carry only the changed quantity.
class OrderLineDiff {
  /// Lines not in the baseline, at full quantity.
  final List<CartItem> added;

  /// Baseline lines whose quantity went up, carrying the increase.
  final List<CartItem> increased;

  /// Baseline lines no longer present, at their saved quantity.
  final List<CartItem> removed;

  /// Baseline lines whose quantity went down, carrying the decrease.
  final List<CartItem> reduced;

  const OrderLineDiff._({
    required this.added,
    required this.increased,
    required this.removed,
    required this.reduced,
  });

  bool get hasCancellations => removed.isNotEmpty || reduced.isNotEmpty;

  bool get isEmpty =>
      added.isEmpty && increased.isEmpty && !hasCancellations;

  /// PURE.
  static OrderLineDiff between({
    required List<CartItem> baseline,
    required List<CartItem> current,
  }) {
    final savedById = {for (final b in baseline) b.id: b};
    final currentIds = {for (final c in current) c.id};

    final added = <CartItem>[];
    final increased = <CartItem>[];
    final reduced = <CartItem>[];
    for (final c in current) {
      final saved = savedById[c.id];
      if (saved == null) {
        added.add(c);
        continue;
      }
      final delta = c.quantity - saved.quantity;
      if (delta > 0) increased.add(c.copyWith(quantity: delta));
      if (delta < 0) reduced.add(c.copyWith(quantity: -delta));
    }
    final removed =
        baseline.where((b) => !currentIds.contains(b.id)).toList();

    return OrderLineDiff._(
      added: added,
      increased: increased,
      removed: removed,
      reduced: reduced,
    );
  }
}
