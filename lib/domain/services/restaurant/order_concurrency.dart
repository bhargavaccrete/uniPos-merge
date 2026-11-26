import '../../../data/models/restaurant/db/cartmodel_308.dart';

/// Refusal when the saved order changed on another device (Captain) while a
/// POS screen had it open (INVX-1). Thrown or returned before any write.
class OrderChangedElsewhereException implements Exception {
  final String message;
  const OrderChangedElsewhereException([
    this.message = OrderConcurrency.changedElsewhereMessage,
  ]);
  @override
  String toString() => message;
}

/// Detects another device's writes to an order a POS screen is editing.
///
/// Captain writes the order box directly, so the POS screen's copy can be
/// behind. Saving that copy would drop Captain's lines (and their stock
/// would never come back) or revive lines Captain cancelled (and restored).
class OrderConcurrency {
  OrderConcurrency._();

  static const changedElsewhereMessage =
      'This order was changed on another device (Captain) while it was open. '
      'Reopen it and try again.';

  static const goneMessage =
      'This order is no longer open — it was settled, voided or removed on '
      'another device.';

  /// Place Order on an existing order. [baseline] is the line → quantity map
  /// the screen diffs against (the cart keeps it equal to the saved order,
  /// including its own immediate cancels), so ANY difference from [saved]
  /// was made elsewhere — and the screen's removals, reductions and restores
  /// would be computed against the wrong quantities.
  static bool differsFromBaseline({
    required Map<String, int> baseline,
    required List<CartItem> saved,
  }) {
    if (saved.length != baseline.length) return true;
    for (final s in saved) {
      if (baseline[s.id] != s.quantity) return true;
    }
    return false;
  }

  /// Settle on an existing order. The screen's [baseline] may predate its
  /// own immediate cancels, so only changes that saving [current] would
  /// UNDO count:
  ///
  /// * a [saved] line in neither [baseline] nor [current] — added elsewhere,
  ///   and the settle would drop it;
  /// * a [baseline] line [saved] now holds less of (or not at all) while
  ///   [current] still asks for more than [saved] — reduced elsewhere, and
  ///   the settle would sell it again.
  static bool settleWouldUndo({
    required List<CartItem> baseline,
    required List<CartItem> saved,
    required List<CartItem> current,
  }) {
    final baseQty = {for (final b in baseline) b.id: b.quantity};
    final savedQty = {for (final s in saved) s.id: s.quantity};
    final currentIds = {for (final c in current) c.id};
    for (final s in saved) {
      if (!baseQty.containsKey(s.id) && !currentIds.contains(s.id)) {
        return true;
      }
    }
    for (final c in current) {
      final b = baseQty[c.id];
      if (b == null) continue; // a line this screen added
      final s = savedQty[c.id] ?? 0;
      if (s < b && c.quantity > s) return true;
    }
    return false;
  }
}
