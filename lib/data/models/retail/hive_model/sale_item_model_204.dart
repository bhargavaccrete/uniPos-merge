import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/util/common/tax_split.dart';

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

  /// Quantity sold (or returned — return lines store this POSITIVE). `double`
  /// so loose goods sell fractionally; piece products hold whole values.
  @HiveField(8)
  final double qty;

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

  // ==================== PRICE OVERRIDE (audit) ====================
  // [price] is ALWAYS what was charged. These record what the catalogue said
  // and why it was changed, so a squeezed margin on a settled sale is
  // explainable months later. The variant master is never rewritten.

  /// Catalogue price at the moment of override. **Null means this line sold at
  /// the catalogue price** — no bool to keep in sync, and old sale lines read
  /// back as null automatically.
  @HiveField(22)
  final double? originalPrice;

  /// `PriceOverrideReason.code`. Set whenever [originalPrice] is.
  @HiveField(23)
  final String? overrideReason;

  /// Free-text detail; required when the reason is 'other'.
  @HiveField(24)
  final String? overrideNote;

  // ==================== LINE DISCOUNT (audit) ====================
  // [discountAmount] @10 above keeps its existing meaning: the TOTAL discount on
  // this line, i.e. its own discount PLUS its share of the order-level discount.
  // Every report reads that field and must keep doing so.
  //
  // These five describe only the line's OWN part, so a receipt can show
  // "Discount 10% -90" on the line and the order remainder separately.

  /// `DiscountType.name` of the line discount that was applied.
  @HiveField(25)
  final String? lineDiscountType;

  /// Raw input as typed: `10` for 10%, or `90` for a flat 90.
  @HiveField(26)
  final double? lineDiscountValue;

  /// The line's own discount in currency, AFTER the engine's cap.
  ///
  /// **A SUBSET of [discountAmount] — never add the two together.** A report that
  /// summed both would double-count. Null means this line sold with no discount
  /// of its own, which is also how every pre-existing sale line reads back.
  @HiveField(27)
  final double? lineDiscountAmount;

  /// `LineDiscountReason.code`. Set whenever [lineDiscountAmount] is.
  @HiveField(28)
  final String? lineDiscountReason;

  /// Free-text detail; required when the reason is 'other'.
  @HiveField(29)
  final String? lineDiscountNote;

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
    this.originalPrice,
    this.overrideReason,
    this.overrideNote,
    this.lineDiscountType,
    this.lineDiscountValue,
    this.lineDiscountAmount,
    this.lineDiscountReason,
    this.lineDiscountNote,
  });

  /// True when this line sold with a discount of its own.
  bool get hasLineDiscount =>
      lineDiscountAmount != null && lineDiscountAmount! > 0;

  /// This line's share of the ORDER-level discount: the total minus its own.
  double get billDiscountShare {
    final share = (discountAmount ?? 0) - (lineDiscountAmount ?? 0);
    return share > 0 ? share : 0;
  }

  /// True when this line was sold at a price other than the catalogue price.
  bool get isPriceOverridden => originalPrice != null;

  /// What the override saved (positive) or added (negative) per unit.
  double get overrideDeltaPerUnit =>
      originalPrice == null ? 0 : originalPrice! - price;

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
    required double qty,
    double? discountAmount,
    double? gstRate,
    String? barcode,
    String? hsnCode,
    double? costPrice,
    double? originalPrice,
    String? overrideReason,
    String? overrideNote,
    String? lineDiscountType,
    double? lineDiscountValue,
    double? lineDiscountAmount,
    String? lineDiscountReason,
    String? lineDiscountNote,
    /// The order's stored tax mode. A reprint passes it so line amounts don't
    /// follow a later change to the inclusive/exclusive setting.
    bool? isTaxInclusive,
  }) {
    // Restaurant only; retail lines come through fromCalculated.
    final bool inclusive = AppConfig.isRestaurant &&
        (isTaxInclusive ?? AppSettings.isTaxInclusive);

    final grossAmount = price * qty;
    final discount = discountAmount ?? 0;
    final rate = gstRate ?? 0;

    double taxableAmt;
    double gstAmt;
    double finalTotal;

    if (inclusive && rate > 0) {
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

    final halves = TaxSplit.halves(gstAmt);
    final cgst = halves.cgst;
    final sgst = halves.sgst;

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
    required double qty,
    required double discountAmount,
    required double gstRate,
    required double taxableAmount,
    required double gstAmount,
    required double total,
    String? barcode,
    String? hsnCode,
    double? costPrice,
    double? originalPrice,
    String? overrideReason,
    String? overrideNote,
    String? lineDiscountType,
    double? lineDiscountValue,
    double? lineDiscountAmount,
    String? lineDiscountReason,
    String? lineDiscountNote,
  }) {
    final halves = TaxSplit.halves(gstAmount);
    final cgst = halves.cgst;
    final sgst = halves.sgst;

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
      qty: (map['qty'] as num?)?.toDouble() ?? 0.0,
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