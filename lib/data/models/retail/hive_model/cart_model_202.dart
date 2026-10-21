import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/util/common/tax_split.dart';

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

  /// Quantity on this line. `double` so loose goods can be sold fractionally
  /// (1.75 kg); piece products hold whole values and behave as before.
  /// This is the REAL quantity — [price] stays a genuine per-unit price, and
  /// `total`/discount/return proration all key off this figure.
  @HiveField(8)
  final double qty;

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

  // ==================== LINE DISCOUNT ====================
  // A discount belonging to THIS line, distinct from the order-level discount
  // the cart store holds. [price] stays the charged unit price (carrying any
  // override); these five only describe what comes off the line and why.
  //
  // Indices continue at 25 — 4, 5 and 6 are retired legacy size/color/weight
  // columns and reusing them would deserialize old rows as the wrong type.
  //
  // Note the DEAD [discountAmount] @18 above is deliberately left alone: it is
  // never written and never read, and giving it a meaning now would hand
  // `total`/`taxableAmount` a third interpretation.

  /// `DiscountType.name` — 'percentage' or 'amount'. Stored so a percentage can
  /// be RE-DERIVED when the quantity or the unit price changes; keeping only the
  /// resolved amount would let a 10% discount silently decay to 2% at qty 5.
  @HiveField(25)
  final String? lineDiscountType;

  /// Raw input as typed: `10` for 10%, or `90` for a flat 90.
  @HiveField(26)
  final double? lineDiscountValue;

  /// Resolved currency amount for the WHOLE line (not per unit).
  /// **Null means no line discount** — no separate bool to drift, and Hive
  /// returns null for absent fields so every pre-existing cart row reads back as
  /// undiscounted.
  @HiveField(27)
  final double? lineDiscountAmount;

  /// `LineDiscountReason.code`. Set whenever [lineDiscountAmount] is.
  @HiveField(28)
  final String? lineDiscountReason;

  /// Free-text detail; required when the reason is 'other'.
  @HiveField(29)
  final String? lineDiscountNote;

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
    this.lineDiscountType,
    this.lineDiscountValue,
    this.lineDiscountAmount,
    this.lineDiscountReason,
    this.lineDiscountNote,
  });

  /// True when the cashier changed this line's price from the catalogue value.
  bool get isPriceOverridden => originalPrice != null;

  /// True when this line carries a discount of its own.
  bool get hasLineDiscount =>
      lineDiscountAmount != null && lineDiscountAmount! > 0;

  /// Gross for the line before any discount: charged unit price x quantity.
  double get grossAmount => price * qty;

  /// What the line is worth after its own discount, before any order-level
  /// discount. Never negative.
  double get netAmount {
    final net = grossAmount - (lineDiscountAmount ?? 0);
    return net > 0 ? net : 0;
  }

  factory CartItemModel.create({
    required String cartItemId,
    required String variantId,
    required String productId,
    required String productName,
    Map<String, String>? attributes,
    required double price,
    double qty = 1,
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
    String? lineDiscountType,
    double? lineDiscountValue,
    double? lineDiscountAmount,
    String? lineDiscountReason,
    String? lineDiscountNote,
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

    final halves = TaxSplit.halves(gstAmt);
    final cgst = halves.cgst;
    final sgst = halves.sgst;

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
      lineDiscountType: lineDiscountType,
      lineDiscountValue: lineDiscountValue,
      lineDiscountAmount: lineDiscountAmount,
      lineDiscountReason: lineDiscountReason,
      lineDiscountNote: lineDiscountNote,
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
      'lineDiscountType': lineDiscountType,
      'lineDiscountValue': lineDiscountValue,
      'lineDiscountAmount': lineDiscountAmount,
      'lineDiscountReason': lineDiscountReason,
      'lineDiscountNote': lineDiscountNote,
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
      qty: (map['qty'] as num).toDouble(),
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
      lineDiscountType: map['lineDiscountType'] as String?,
      lineDiscountValue: (map['lineDiscountValue'] as num?)?.toDouble(),
      lineDiscountAmount: (map['lineDiscountAmount'] as num?)?.toDouble(),
      lineDiscountReason: map['lineDiscountReason'] as String?,
      lineDiscountNote: map['lineDiscountNote'] as String?,
    );
  }
}
