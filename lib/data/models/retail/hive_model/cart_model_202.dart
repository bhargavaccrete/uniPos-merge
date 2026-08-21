import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'cart_model_202.g.dart';

@HiveType(typeId: HiveTypeIds.retailCart)
class CartItemModel extends HiveObject {
  @HiveField(0)
  final String cartItemId;

  @HiveField(1)
  final String variantId;   // links to VariantModel

  @HiveField(2)
  final String productId;   // links to ProductModel

  @HiveField(3)
  final String productName;

  @HiveField(7)
  final double price;       // selling price (mrp or after discount)

  @HiveField(8)
  final int qty;

  @HiveField(9)
  final double total;       // price * qty

  @HiveField(10)
  final String? barcode;

  @HiveField(11)
  final String addedAt;     // time of adding to cart

  // GST fields
  @HiveField(12)
  final double? gstRate;         // GST percentage applied

  @HiveField(13)
  final double? taxableAmount;   // Amount before GST

  @HiveField(14)
  final double? gstAmount;       // Total GST amount

  @HiveField(15)
  final double? cgstAmount;      // CGST (half of GST)

  @HiveField(16)
  final double? sgstAmount;      // SGST (half of GST)

  @HiveField(17)
  final String? hsnCode;         // HSN/SAC code

  @HiveField(18)
  final double? discountAmount;  // Discount on this item

  @HiveField(19)
  final String? categoryName;    // For GST lookup

  @HiveField(20)
  final int? tabIndex;

  /// Variant descriptors as `{attributeName: value}`, captured from the variant
  /// at add-to-cart time so every configured attribute survives into the sale.
  @HiveField(21)
  final Map<String, String>? attributes;

  // ==================== PRICE OVERRIDE ====================
  // [price] above is ALWAYS the charged unit price, overridden or not, so the
  // billing pipeline needs no knowledge of this block. These three only record
  // WHAT the price would have been and WHY it changed.

  /// Catalogue price this line was seeded from, kept only when the cashier
  /// overrode it. **Null means the line was never overridden** — there is no
  /// separate bool to drift out of sync, and Hive returns null for absent
  /// fields, so every pre-existing cart row reads back as "not overridden".
  @HiveField(22)
  final double? originalPrice;

  /// `PriceOverrideReason.code`. Set whenever [originalPrice] is.
  @HiveField(23)
  final String? overrideReason;

  /// Free-text detail; required when the reason is 'other'.
  @HiveField(24)
  final String? overrideNote;

  CartItemModel({
    required this.cartItemId,
    required this.variantId,
    required this.productId,
    required this.productName,
    this.attributes,
    required this.price,
    required this.qty,
    required this.total,
    this.barcode,
    required this.addedAt,
    this.gstRate,
    this.taxableAmount,
    this.gstAmount,
    this.cgstAmount,
    this.sgstAmount,
    this.hsnCode,
    this.discountAmount,
    this.categoryName,
    this.tabIndex,
    this.originalPrice,
    this.overrideReason,
    this.overrideNote,
  });

  /// True when the cashier changed this line's price from the catalogue value.
  bool get isPriceOverridden => originalPrice != null;

  factory CartItemModel.create({
    required String cartItemId,
    required String variantId,
    required String productId,
    required String productName,
    Map<String, String>? attributes,
    required double price,
    int qty = 1,
    String? barcode,
    double? gstRate,
    String? hsnCode,
    double? discountAmount,
    String? categoryName,
    bool taxInclusive = false,
    int ? tabIndex = 1,
    double? originalPrice,
    String? overrideReason,
    String? overrideNote,
  }) {
    final now = DateTime.now().toIso8601String();
    final rate = gstRate ?? 0;
    final discount = discountAmount ?? 0;

    double taxableAmt;
    double gstAmt;
    double finalTotal;

    if (taxInclusive && rate > 0) {
      // Tax Inclusive: Price already includes GST, extract it
      // Formula: Taxable = Price / (1 + rate/100)
      final grossAmount = price * qty;
      final grossAfterDiscount = grossAmount - discount;
      taxableAmt = _roundTo2Decimals(grossAfterDiscount / (1 + rate / 100));
      gstAmt = _roundTo2Decimals(grossAfterDiscount - taxableAmt);
      finalTotal = _roundTo2Decimals(grossAfterDiscount); // Total stays same as price includes GST
    } else {
      // Tax Exclusive: GST is added on top of price
      final grossAmount = price * qty;
      taxableAmt = _roundTo2Decimals(grossAmount - discount);
      gstAmt = _roundTo2Decimals(taxableAmt * (rate / 100));
      finalTotal = _roundTo2Decimals(taxableAmt); // Line item total WITHOUT GST
    }

    final cgst = _roundTo2Decimals(gstAmt / 2);
    final sgst = _roundTo2Decimals(gstAmt / 2);

    return CartItemModel(
      cartItemId: cartItemId,
      variantId: variantId,
      productId: productId,
      productName: productName,
      attributes: attributes,
      price: price,
      qty: qty,
      total: finalTotal,
      barcode: barcode,
      addedAt: now,
      gstRate: rate,
      taxableAmount: taxableAmt,
      gstAmount: gstAmt,
      cgstAmount: cgst,
      sgstAmount: sgst,
      hsnCode: hsnCode,
      discountAmount: discount,
      categoryName: categoryName,
      tabIndex: tabIndex,
      originalPrice: originalPrice,
      overrideReason: overrideReason,
      overrideNote: overrideNote,
    );
  }

  static double _roundTo2Decimals(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() {
    return {
      'cartItemId': cartItemId,
      'variantId': variantId,
      'productId': productId,
      'productName': productName,
      'attributes': attributes,
      'price': price,
      'qty': qty,
      'total': total,
      'barcode': barcode,
      'addedAt': addedAt,
      'gstRate': gstRate,
      'taxableAmount': taxableAmount,
      'gstAmount': gstAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'hsnCode': hsnCode,
      'discountAmount': discountAmount,
      'categoryName': categoryName,
      'originalPrice': originalPrice,
      'overrideReason': overrideReason,
      'overrideNote': overrideNote,
    };
  }


  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      cartItemId: map['cartItemId'] as String,
      variantId: map['variantId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      attributes: (map['attributes'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      price: (map['price'] as num).toDouble(),
      qty: (map['qty'] as num).toInt(),
      total: (map['total'] as num).toDouble(),
      barcode: map['barcode'] as String?,
      addedAt: map['addedAt'] as String,
      gstRate: (map['gstRate'] as num?)?.toDouble(),
      taxableAmount: (map['taxableAmount'] as num?)?.toDouble(),
      gstAmount: (map['gstAmount'] as num?)?.toDouble(),
      cgstAmount: (map['cgstAmount'] as num?)?.toDouble(),
      sgstAmount: (map['sgstAmount'] as num?)?.toDouble(),
      hsnCode: map['hsnCode'] as String?,
      discountAmount: (map['discountAmount'] as num?)?.toDouble(),
      categoryName: map['categoryName'] as String?,
      tabIndex: (map['tabIndex'] as num?)?.toInt(),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      overrideReason: map['overrideReason'] as String?,
      overrideNote: map['overrideNote'] as String?,
    );
  }
}
