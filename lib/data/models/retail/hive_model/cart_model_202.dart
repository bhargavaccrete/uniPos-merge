import 'package:hive/hive.dart';

part 'cart_model_202.g.dart';

@HiveType(typeId: 202)
class CartItemModel extends HiveObject {
  @HiveField(0)
  final String cartItemId;

  @HiveField(1)
  final String variantId;   // links to VariantModel

  @HiveField(2)
  final String productId;   // links to ProductModel

  @HiveField(3)
  final String productName;

  @HiveField(4)
  final String? size;

  @HiveField(5)
  final String? color;

  @HiveField(6)
  final String? weight;

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

  CartItemModel({
    required this.cartItemId,
    required this.variantId,
    required this.productId,
    required this.productName,
    this.size,
    this.color,
    this.weight,
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
  });

  factory CartItemModel.create({
    required String cartItemId,
    required String variantId,
    required String productId,
    required String productName,
    String? size,
    String? color,
    String? weight,
    required double price,
    int qty = 1,
    String? barcode,
    double? gstRate,
    String? hsnCode,
    double? discountAmount,
    String? categoryName,
    bool taxInclusive = false,
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
      size: size,
      color: color,
      weight: weight,
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
      'size': size,
      'color': color,
      'weight': weight,
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
    };
  }
}
