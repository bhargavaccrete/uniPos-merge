import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

part 'sale_item_model_204.g.dart';

const _uuid = Uuid();

@HiveType(typeId: HiveTypeIds.retailSaleItem)
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

  /// Generic variant descriptors as `{attributeName: value}`, captured at sale
  /// time. This is a HISTORICAL RECORD — render receipts and reports from this
  /// map, never by re-reading the live variant, or editing a product would
  /// rewrite past sales.
  ///
  /// [size], [color] and [weight] remain as a fallback for records written
  /// before this field existed.
  @HiveField(20)
  final Map<String, String>? attributes;

  /// Unit cost of the variant at the moment of sale, for the same reason
  /// [attributes] is captured: profit is a HISTORICAL fact.
  ///
  /// Reading the variant's live `costPrice` instead meant a supplier price
  /// change today silently rewrote last quarter's closed profit report.
  ///
  /// Null on sales written before this field existed — reports fall back to the
  /// live variant cost for those, and must report a line whose cost is genuinely
  /// unknown as unknown rather than as zero.
  @HiveField(21)
  final double? costPrice;

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
    this.attributes,
    this.costPrice,
  });

  factory SaleItemModel.create({
    required String saleId,
    required String varianteId,
    required String productId,
    required String productName,
    String? size,
    String? color,
    String? weight,
    Map<String, String>? attributes,
    required double price,
    required int qty,
    double? discountAmount,
    double? gstRate,
    String? barcode,
    String? hsnCode,
    double? costPrice,
  }) {
    // ✅ FIX: Check if tax is inclusive (for restaurant mode)
    final bool isTaxInclusive = AppConfig.isRestaurant && AppSettings.isTaxInclusive;

    final grossAmount = price * qty;
    final discount = discountAmount ?? 0;
    final rate = gstRate ?? 0;

    double taxableAmt;
    double gstAmt;
    double finalTotal;

    if (isTaxInclusive && rate > 0) {
      // Tax Inclusive: Price already includes tax
      // Example: price=100, rate=18%
      // Base price = 100 / 1.18 = 84.75
      // GST = 100 - 84.75 = 15.25
      // Total = 100 (no addition needed)

      final amountAfterDiscount = grossAmount - discount;
      final basePrice = amountAfterDiscount / (1 + (rate / 100));

      taxableAmt = _roundTo2Decimals(basePrice); // Base price without tax
      gstAmt = _roundTo2Decimals(amountAfterDiscount - basePrice); // Tax extracted
      finalTotal = _roundTo2Decimals(amountAfterDiscount); // Same as price (tax already included)
    } else {
      // Tax Exclusive: Tax is added on top of price (default retail behavior)
      // Example: price=100, rate=18%
      // Taxable amount = 100
      // GST = 100 * 0.18 = 18
      // Total = 100 + 18 = 118

      taxableAmt = grossAmount - discount;
      gstAmt = _roundTo2Decimals(taxableAmt * (rate / 100));
      finalTotal = _roundTo2Decimals(taxableAmt + gstAmt);
    }

    final cgst = _roundTo2Decimals(gstAmt / 2);
    final sgst = _roundTo2Decimals(gstAmt / 2);

    return SaleItemModel(
      saleItemId: _uuid.v4(),
      saleId: saleId,
      varianteId: varianteId,
      productId: productId,
      productName: productName,
      size: size,
      color: color,
      weight: weight,
      attributes: attributes,
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
      costPrice: costPrice,
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
    Map<String, String>? attributes,
    required double price,
    required int qty,
    required double discountAmount,
    required double gstRate,
    required double taxableAmount,
    required double gstAmount,
    required double total,
    String? barcode,
    String? hsnCode,
    double? costPrice,
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
      attributes: attributes,
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
      costPrice: costPrice,
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
      'attributes': attributes,
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
      'costPrice': costPrice,
    };
  }

  // Create from Map (for backup restore)
  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      saleItemId: map['saleItemId'] as String,
      // Identity fields stay STRICT — a line with no saleId or productId can't
      // be attached to anything, and silently defaulting them to '' would
      // restore a corrupt row that looks fine. Better to fail loudly.
      saleId: map['saleId'] as String,
      varianteId: map['varianteId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String?,
      size: map['size'] as String?,
      color: map['color'] as String?,
      // Money and quantity default — a missing amount is recoverable data, and
      // throwing here aborted the whole restore over one line.
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble(),
      taxAmount: (map['taxAmount'] as num?)?.toDouble(),
      barcode: map['barcode'] as String?,
      gstRate: (map['gstRate'] as num?)?.toDouble(),
      taxableAmount: (map['taxableAmount'] as num?)?.toDouble(),
      gstAmount: (map['gstAmount'] as num?)?.toDouble(),
      hsnCode: map['hsnCode'] as String?,
      cgstAmount: (map['cgstAmount'] as num?)?.toDouble(),
      sgstAmount: (map['sgstAmount'] as num?)?.toDouble(),
      weight: map['weight'] as String?,
      attributes: (map['attributes'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      costPrice: (map['costPrice'] as num?)?.toDouble(),
    );
  }
}