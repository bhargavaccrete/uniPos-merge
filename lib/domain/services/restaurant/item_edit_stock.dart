import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/itemvariantemodel_312.dart';

/// Edit Item never changes stock levels — those move only through stock
/// adjustments, purchases, production and sales. PURE.
class ItemEditStock {
  ItemEditStock._();

  /// [edited] (the form's result) with the stock quantities of [live] (the
  /// item as stored now), so a sale or adjustment made while the editor was
  /// open is never written back over. Everything else — tracking, alert
  /// threshold, prices, type — comes from [edited]. [live] null (the item
  /// is gone) returns [edited] unchanged.
  static Items carryLiveStock({required Items edited, required Items? live}) {
    if (live == null) return edited;
    final liveVariantStock = {
      for (final v in live.variant ?? const <ItemVariante>[])
        v.variantId: v.stockQuantity,
    };
    final variants = edited.variant
        ?.map((v) => liveVariantStock.containsKey(v.variantId)
            ? ItemVariante(
                variantId: v.variantId,
                price: v.price,
                trackInventory: v.trackInventory,
                stockQuantity: liveVariantStock[v.variantId],
              )
            : v)
        .toList();
    return edited.copyWith(
      stockQuantity: live.stockQuantity,
      variant: variants,
    );
  }
}
