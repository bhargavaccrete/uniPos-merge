import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/domain/services/retail/retail_billing_service.dart';

/// The sale lines a Retail checkout persists — ONE implementation, used by
/// the Checkout screen and by the debug test-data generator, so generated
/// sales are stored exactly as real ones.
class CheckoutSaleLines {
  CheckoutSaleLines._();

  /// Persist the sale lines exactly as the engine computed them.
  ///
  /// The per-item taxable amount and discount share must come from [bill],
  /// not from the cart row: a cart row's taxable amount is computed at
  /// add-time and knows nothing about an order-level discount applied later.
  /// Reading it back here is what used to store an inflated tax base on every
  /// invoice.
  ///
  /// The variant's cost is read here and frozen onto the line. Profit reports
  /// used to look up the variant's live `costPrice` instead, so a supplier
  /// price change re-wrote the profit on sales that had already been settled.
  static Future<List<SaleItemModel>> build(
    String saleId,
    RetailBill bill,
  ) async {
    // One lookup per distinct variant in the basket, not per report row.
    final costByVariantId = <String, double?>{};
    for (final line in bill.lines) {
      final variantId = line.item.variantId;
      if (costByVariantId.containsKey(variantId)) continue;
      final variant = await productStore.getVariantById(variantId);
      costByVariantId[variantId] = variant?.costPrice;
    }

    return bill.lines.map((line) {
      final cartItem = line.item;
      return SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: cartItem.variantId,
        productId: cartItem.productId,
        productName: cartItem.productName,
        attributes: cartItem.attributes,
        price: cartItem.price,
        qty: cartItem.qty,
        discountAmount: line.discountAmount,
        gstRate: line.gstRatePercent,
        taxableAmount: line.taxableAmount,
        gstAmount: line.gstAmount,
        total: line.total,
        barcode: cartItem.barcode,
        hsnCode: cartItem.hsnCode,
        costPrice: costByVariantId[cartItem.variantId],
        // Price-override audit. `price` above is already the charged figure,
        // so these only carry WHAT the catalogue said and WHY it changed —
        // without them a settled sale's squeezed margin is unexplainable.
        originalPrice: cartItem.originalPrice,
        overrideReason: cartItem.overrideReason,
        overrideNote: cartItem.overrideNote,
        // Line-discount audit. The AMOUNT comes from the engine, not the cart
        // row: a discount larger than the line is capped there, and persisting
        // the uncapped figure would print a receipt that does not reconcile.
        // `discountAmount` above stays the TOTAL (line + bill share).
        lineDiscountType: cartItem.lineDiscountType,
        lineDiscountValue: cartItem.lineDiscountValue,
        lineDiscountAmount:
            line.lineDiscountAmount > 0 ? line.lineDiscountAmount : null,
        lineDiscountReason: cartItem.lineDiscountReason,
        lineDiscountNote: cartItem.lineDiscountNote,
      );
    }).toList();
  }
}
