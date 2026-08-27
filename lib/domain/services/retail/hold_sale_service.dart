import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/hold_sale_item_model_210.dart';
import '../../../data/models/retail/hive_model/hold_sale_model_209.dart';
import 'quick_item_service.dart';
import 'retail_billing_service.dart' show DiscountType;

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
        // Park the price override too, or restoring would silently re-price the
        // line to the catalogue figure and lose the agreed reason.
        originalPrice: cartItem.originalPrice,
        overrideReason: cartItem.overrideReason,
        overrideNote: cartItem.overrideNote,
        // And the line discount. A cashier can retype one bill discount; fifteen
        // per-line discounts are not recoverable, and the loss would be silent.
        lineDiscountType: cartItem.lineDiscountType,
        lineDiscountValue: cartItem.lineDiscountValue,
        lineDiscountAmount: cartItem.lineDiscountAmount,
        lineDiscountReason: cartItem.lineDiscountReason,
        lineDiscountNote: cartItem.lineDiscountNote,
      );
    }).toList();

    await holdSaleStore.addHoldSale(holdSale, holdSaleItems);
    await retailCartStore.clearCartAndSave();

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

    await retailCartStore.clearCartAndSave();

    int skipped = 0;
    for (final holdItem in items) {
      // A quick item has no catalogue row to look up, so it must be replayed
      // before the lookup below — which treats a miss as "this product was
      // deleted" and drops the line. The parked figures are replayed as-is, for
      // the same reason catalogue lines are: the customer was quoted them.
      if (QuickItemService.isQuickItem(holdItem.variantId)) {
        final result = await retailCartStore.addQuickItemToTab(
          name: holdItem.productName,
          price: holdItem.price,
          gstRate: holdItem.gstRate ?? 0,
          qty: holdItem.qty.round(),
        );
        if (!result.success) skipped++;
        continue;
      }

      final product = productStore.getProductById(holdItem.productId);
      final variant = await productStore.getVariantById(holdItem.variantId);

      if (product == null || variant == null) {
        skipped++;
        continue;
      }

      // Replay the parked price and tax rate, not today's — the customer was
      // quoted these figures when the sale was held. The override audit rides
      // along so a restored line still says why it is below list.
      //
      // Via the tab wrapper, so a restored bill reaches the active tab's
      // snapshot: restoring straight into the cart box left a restart showing
      // the pre-restore tab, i.e. an empty cart.
      final result = await retailCartStore.addItemToTab(
        product,
        variant,
        priceOverride: holdItem.price,
        gstRateOverride: holdItem.gstRate,
        qty: holdItem.qty,
        originalPrice: holdItem.originalPrice,
        overrideReason: holdItem.overrideReason,
        overrideNote: holdItem.overrideNote,
        // The amount is re-resolved from type+value inside addItem, so a
        // percentage is exact for the restored quantity.
        lineDiscountType: holdItem.lineDiscountType,
        lineDiscountValue: holdItem.lineDiscountValue,
        lineDiscountReason: holdItem.lineDiscountReason,
        lineDiscountNote: holdItem.lineDiscountNote,
      );
      if (!result.success) skipped++;
    }

    // Replay the ORDER-level discount too. `clearCartAndSave` above runs
    // `resetBillingInputs`, which zeroes it, and nothing put it back — so a
    // parked 10%-off bill used to restore at full price. The parked figure is a
    // resolved amount, so it is replayed as an amount regardless of how it was
    // originally entered.
    final parkedDiscount = holdSale.discountAmount ?? 0;
    if (parkedDiscount > 0) {
      retailCartStore.setDiscount(
        type: DiscountType.amount,
        value: parkedDiscount,
      );
    }

    await holdSaleStore.deleteHoldSale(holdSale.holdSaleId);
    return skipped;
  }
}
