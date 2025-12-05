import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'sale_item_model_204.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 204)
class SaleItemModel extends HiveObject {
  @HiveField(0)
  final String saleItemId;

  @HiveField(1)
  final String saleId;

  @HiveField(2)
  final String varianteId;

  @HiveField(3)
  final String productId;

  @HiveField(4)
  final String? productName;

  @HiveField(5)
  final String? size;

  @HiveField(6)
  final String? color;

  @HiveField(7)
  final double price; // Unit price before tax

  @HiveField(8)
  final int qty;

  @HiveField(9)
  final double total; // Final total after discount and tax

  @HiveField(10)
  final double? discountAmount; // Discount on this item

  @HiveField(11)
  final double? taxAmount; // GST amount (kept for backward compatibility)

  @HiveField(12)
  final String? barcode;

  // New GST fields
  @HiveField(13)
  final double? gstRate; // GST percentage applied (e.g., 5, 12, 18, 28)

  @HiveField(14)
  final double? taxableAmount; // Amount on which GST is calculated (after discount)

  @HiveField(15)
  final double? gstAmount; // Calculated GST amount

  @HiveField(16)
  final String? hsnCode; // HSN/SAC code for this item

  @HiveField(17)
  final double? cgstAmount; // CGST component (gstAmount / 2)

  @HiveField(18)
  final double? sgstAmount; // SGST component (gstAmount / 2)

  @HiveField(19)
  final String? weight; // Weight attribute

  SaleItemModel({
    required this.saleItemId,
    required this.saleId,
    required this.varianteId,
    required this.productId,
    required this.productName,
    this.size,
    this.color,
    required this.price,
    required this.qty,
    required this.total,
    this.discountAmount,
    this.taxAmount,
    this.barcode,
    this.gstRate,
    this.taxableAmount,
    this.gstAmount,
    this.hsnCode,
    this.cgstAmount,
    this.sgstAmount,
    this.weight,
  });

  factory SaleItemModel.create({
    required String saleId,
    required String varianteId,
    required String productId,
    required String productName,
    String? size,
    String? color,
    String? weight,
    required double price,
    required int qty,
    double? discountAmount,
    double? gstRate,
    String? barcode,
    String? hsnCode,
  }) {
    // Calculate GST properly
    final grossAmount = price * qty;
    final discount = discountAmount ?? 0;
    final taxableAmt = grossAmount - discount;
    final rate = gstRate ?? 0;
    final gstAmt = _roundTo2Decimals(taxableAmt * (rate / 100));
    final cgst = _roundTo2Decimals(gstAmt / 2);
    final sgst = _roundTo2Decimals(gstAmt / 2);
    final finalTotal = _roundTo2Decimals(taxableAmt + gstAmt);

    return SaleItemModel(
      saleItemId: _uuid.v4(),
      saleId: saleId,
      varianteId: varianteId,
      productId: productId,
      productName: productName,
      size: size,
      color: color,
      weight: weight,
      price: price,
      qty: qty,
      total: finalTotal,
      discountAmount: discount,
      taxAmount: gstAmt, // For backward compatibility
      gstRate: rate,
      taxableAmount: taxableAmt,
      gstAmount: gstAmt,
      cgstAmount: cgst,
      sgstAmount: sgst,
      barcode: barcode,
      hsnCode: hsnCode,
    );
  }

  /// Create with pre-calculated values (for checkout)
  factory SaleItemModel.fromCalculated({
    required String saleId,
    required String varianteId,
    required String productId,
    required String productName,
    String? size,
    String? color,
    String? weight,
    required double price,
    required int qty,
    required double discountAmount,
    required double gstRate,
    required double taxableAmount,
    required double gstAmount,
    required double total,
    String? barcode,
    String? hsnCode,
  }) {
    final cgst = _roundTo2Decimals(gstAmount / 2);
    final sgst = _roundTo2Decimals(gstAmount / 2);

    return SaleItemModel(
      saleItemId: _uuid.v4(),
      saleId: saleId,
      varianteId: varianteId,
      productId: productId,
      productName: productName,
      size: size,
      color: color,
      weight: weight,
      price: price,
      qty: qty,
      total: total,
      discountAmount: discountAmount,
      taxAmount: gstAmount,
      gstRate: gstRate,
      taxableAmount: taxableAmount,
      gstAmount: gstAmount,
      cgstAmount: cgst,
      sgstAmount: sgst,
      barcode: barcode,
      hsnCode: hsnCode,
    );
  }

  static double _roundTo2Decimals(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() {
    return {
      'saleItemId': saleItemId,
      'saleId': saleId,
      'varianteId': varianteId,
      'productId': productId,
      'productName': productName,
      'size': size,
      'color': color,
      'weight': weight,
      'price': price,
      'qty': qty,
      'total': total,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'gstRate': gstRate,
      'taxableAmount': taxableAmount,
      'gstAmount': gstAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'barcode': barcode,
      'hsnCode': hsnCode,
    };
  }
}