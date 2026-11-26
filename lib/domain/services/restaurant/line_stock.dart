import '../../../data/models/restaurant/db/cartmodel_308.dart';

/// How [counted] units coming back from an order line split between
/// reversing a fresh make ([fromFresh]) and prepared stock ([fromOwn]).
/// Units the sale never moved stock for are counted but restore nothing.
class LineReturn {
  final int fromFresh;
  final int fromOwn;
  final int counted;

  /// The line carries no stamp (sold before Phase 1): restore [counted] by
  /// the item's current type, as before.
  final bool isLegacy;

  const LineReturn({
    required this.fromFresh,
    required this.fromOwn,
    required this.counted,
    required this.isLegacy,
  });
}

/// The per-line stock marker (`CartItem.ownStockQty / freshQty /
/// restockedQuantity`). A sale records what it took; every restore reads
/// that record — never the item's current type — and returns the fresh
/// part first (Phase 1 decision Q3), never more than is still restorable.
///
/// PURE.
class LineStock {
  /// Of [k] units returned from [line], capped at
  /// `quantity − restockedQuantity`.
  static LineReturn take(CartItem line, int k) {
    final restocked = line.restockedQuantity ?? 0;
    final restorable = line.quantity - restocked;
    final counted = k <= 0 || restorable <= 0
        ? 0
        : (k < restorable ? k : restorable);
    if (!line.hasStockStamp) {
      return LineReturn(
          fromFresh: 0, fromOwn: 0, counted: counted, isLegacy: true);
    }
    final fresh = line.freshQty ?? 0;
    final own = line.ownStockQty ?? 0;
    // Earlier returns consumed the fresh part first.
    final freshLeft = _atLeast0(fresh - restocked);
    final ownLeft = _atLeast0(own - _atLeast0(restocked - fresh));
    final fromFresh = counted < freshLeft ? counted : freshLeft;
    final rest = counted - fromFresh;
    final fromOwn = rest < ownLeft ? rest : ownLeft;
    return LineReturn(
        fromFresh: fromFresh,
        fromOwn: fromOwn,
        counted: counted,
        isLegacy: false);
  }

  /// [line] after [k] of its units leave a live order (cancel, reduce): the
  /// quantity and the stamps shrink, fresh first.
  static CartItem reduced(CartItem line, int k) {
    final r = take(line, k);
    final remaining = line.quantity - r.counted;
    if (r.isLegacy) return line.copyWith(quantity: remaining);
    return line.copyWith(
      quantity: remaining,
      freshQty: (line.freshQty ?? 0) - r.fromFresh,
      ownStockQty: (line.ownStockQty ?? 0) - r.fromOwn,
    );
  }

  /// [line] of a closed order (void, refund) after [k] more units went back
  /// to stock. The quantity is unchanged — it is a record of the sale.
  static CartItem restocked(CartItem line, int k) {
    final r = take(line, k);
    return line.copyWith(
        restockedQuantity: (line.restockedQuantity ?? 0) + r.counted);
  }

  /// [line] after a further sale of its own (a quantity increase) took
  /// [own] from prepared stock and made [fresh].
  static CartItem withSale(CartItem line, {required int own, required int fresh}) =>
      line.copyWith(
        ownStockQty: (line.ownStockQty ?? 0) + own,
        freshQty: (line.freshQty ?? 0) + fresh,
      );

  /// [target] carrying exactly [source]'s stamp (none if [source] has none)
  /// — for lines that come back from a network client, whose own stamp
  /// fields must never be trusted. Built in full because copyWith cannot
  /// clear a field back to null.
  static CartItem withStampOf(CartItem target, CartItem? source) => CartItem(
        id: target.id,
        title: target.title,
        price: target.price,
        productId: target.productId,
        isStockManaged: target.isStockManaged,
        quantity: target.quantity,
        variantName: target.variantName,
        variantPrice: target.variantPrice,
        choiceNames: target.choiceNames,
        instruction: target.instruction,
        taxRate: target.taxRate,
        discount: target.discount,
        extras: target.extras,
        weightDisplay: target.weightDisplay,
        categoryName: target.categoryName,
        refundedQuantity: target.refundedQuantity,
        ownStockQty: source?.ownStockQty,
        freshQty: source?.freshQty,
        restockedQuantity: source?.restockedQuantity,
      );

  static int _atLeast0(int v) => v < 0 ? 0 : v;
}
