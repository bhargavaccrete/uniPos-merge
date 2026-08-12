import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/hold_sale_item_model_210.dart';
import '../../../data/models/retail/hive_model/hold_sale_model_209.dart';

/// Park / restore for retail sales.
///
/// Both halves live here on purpose: parking freezes the computed bill, so
/// restoring must replay those frozen figures. When the two sat in separate
/// screens they drifted — park stored the bill, restore re-priced from current
/// rates, and a price change between the two silently altered the sale.
class HoldSaleService {
  const HoldSaleService._();

  /// Park the active cart and clear it. Returns the new hold-sale id.
  ///
  /// Throws [StateError] when the cart is empty — callers gate on that before
  /// prompting for a note.
  static Future<String> park({String? note}) async {
    final bill = retailCartStore.bill;
    if (bill.lines.isEmpty) {
      throw StateError('Cart is empty. Nothing to hold.');
    }

    final holdSaleId = 'HOLD_${const Uuid().v4()}';

    final holdSale = HoldSaleModel.create(
      holdSaleId: holdSaleId,
      note: note,
      totalItems: bill.totalItems,
      subtotal: bill.grandTotal,
      itemTotal: bill.itemTotal,
      discountAmount: bill.discountAmount,
      taxableAmount: bill.taxableAmount,
      gstAmount: bill.totalGst,
      isTaxInclusive: bill.isTaxInclusive,
    );

    final holdSaleItems = bill.lines.map((line) {
      final cartItem = line.item;
      return HoldSaleItemModel.create(
        holdSaleId: holdSaleId,
        variantId: cartItem.variantId,
        productId: cartItem.productId,
        productName: cartItem.productName,
        attributes: cartItem.attributes,
        price: cartItem.price,
        qty: cartItem.qty,
        barcode: cartItem.barcode,
        // Park the tax basis with the line so [restore] can reproduce the bill
        // rather than recomputing it from whatever the rates are then.
        gstRate: line.gstRatePercent,
        taxableAmount: line.taxableAmount,
        gstAmount: line.gstAmount,
        discountAmount: line.discountAmount,
      );
    }).toList();

    await holdSaleStore.addHoldSale(holdSale, holdSaleItems);
    await retailCartStore.clearCart();

    return holdSaleId;
  }

  /// Restore a parked sale into the cart, replacing whatever is there, and
  /// delete the hold. Returns the number of lines that could not be restored
  /// because their product or variant no longer exists.
  ///
  /// Throws [StateError] when the hold has no items.
  static Future<int> restore(HoldSaleModel holdSale) async {
    final items = await holdSaleStore.getItemsForHoldSale(holdSale.holdSaleId);
    if (items.isEmpty) {
      throw StateError('No items found in parked sale');
    }

    await retailCartStore.clearCart();

    int skipped = 0;
    for (final holdItem in items) {
      final product = productStore.getProductById(holdItem.productId);
      final variant = await productStore.getVariantById(holdItem.variantId);

      if (product == null || variant == null) {
        skipped++;
        continue;
      }

      // Replay the parked price and tax rate, not today's — the customer was
      // quoted these figures when the sale was held.
      final result = await retailCartStore.addItem(
        product,
        variant,
        priceOverride: holdItem.price,
        gstRateOverride: holdItem.gstRate,
        qty: holdItem.qty,
      );
      if (!result.success) skipped++;
    }

    await holdSaleStore.deleteHoldSale(holdSale.holdSaleId);
    return skipped;
  }
}
