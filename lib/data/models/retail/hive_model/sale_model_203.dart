

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part 'sale_model_203.g.dart';

/// Sale status constants
class SaleStatus {
  static const String paid = 'paid';
  static const String partiallyPaid = 'partially_paid';
  static const String due = 'due';
}

@HiveType(typeId: HiveTypeIds.retailSale)
class SaleModel extends HiveObject {
  @HiveField(0)
  final String saleId;

  @HiveField(1)
  final String? customerId;

  @HiveField(2)
  final double totalItems;

  @HiveField(3)
  final double subtotal;

  @HiveField(4)
  final double discountAmount;

  @HiveField(5)
  final double taxAmount;

  @HiveField(6)
  final double totalAmount;

  @HiveField(7)
  final String paymentType; // cash / card / upi / credit

  @HiveField(8)
  final String date; // invoice date

  @HiveField(9)
  final String createdAt;

  @HiveField(10)
  final String updatedAt;

  @HiveField(11, defaultValue: false)
  final bool? isReturn; // true if this is a return/refund transaction

  @HiveField(12)
  final String? originalSaleId; // reference to original sale if this is a return

  // New GST fields for bill totals
  @HiveField(13)
  final double? totalTaxableAmount; // Sum of all taxable amounts

  @HiveField(14)
  final double? totalGstAmount; // Sum of all GST amounts

  @HiveField(15)
  final double? totalCgstAmount; // Sum of all CGST amounts

  @HiveField(16)
  final double? totalSgstAmount; // Sum of all SGST amounts

  @HiveField(17)
  final double? grandTotal; // Final bill total (taxable + GST)

  // Split payment fields
  @HiveField(18)
  final String? paymentListJson; // JSON string of payment entries for storage

  @HiveField(19)
  final double? changeReturn; // Change amount to return to customer

  @HiveField(20)
  final double? totalPaid; // Total amount paid by customer

  @HiveField(21)
  final bool? isSplitPayment; // Whether this sale used split payment

  // Credit/Pay-Later fields
  @HiveField(22, defaultValue: 0.0)
  final double paidAmount; // Amount paid at time of sale or later

  @HiveField(23, defaultValue: 0.0)
  final double dueAmount; // Remaining due amount

  @HiveField(24, defaultValue: 'paid')
  final String status; // paid / partially_paid / due

  // ==================== BILL COMPOSITION ====================
  // Stored so a settled sale can be re-rendered exactly as it was charged.
  // `discountAmount` (field 4) holds the resolved currency value; these record
  // HOW that value was arrived at, which a receipt reprint otherwise can't show.

  @HiveField(25)
  final String? discountType; // 'amount' | 'percentage'

  @HiveField(26)
  final double? discountValue; // raw input, e.g. 10 for "10%"

  @HiveField(27)
  final String? discountReason;

  @HiveField(28)
  final int? loyaltyPointsUsed;

  /// Rounding adjustment baked into [totalAmount]; may be negative.
  /// Persisted rather than re-derived at print time, so changing the round-off
  /// setting later cannot make a reprint disagree with the original receipt.
  @HiveField(29)
  final double? roundOff;

  /// Tax mode in force when this sale was made. Frozen here so an old invoice
  /// renders with the labels it was charged under.
  @HiveField(30)
  final bool? isTaxInclusive;

  /// How much of [discountAmount] came from PER-LINE discounts rather than the
  /// order-level one.
  ///
  /// Stored so the receipt can print "Item Discounts" and "Bill Discount" as
  /// separate rows without folding over the sale's items, and so the split is
  /// explicit in the record rather than inferred. `discountType`/`discountValue`
  /// describe only the ORDER-level part.
  ///
  /// Null on every sale written before line discounts existed, which correctly
  /// reads as "all of the discount was order-level".
  @HiveField(31)
  final double? lineDiscountTotal;

  /// Links the two halves of an EXCHANGE: the return document and the
  /// replacement sale both carry the same `EXC-YYYYMMDD-NNN`.
  ///
  /// An exchange is deliberately NOT its own accounting document — it is an
  /// ordinary return plus an ordinary sale, so every report, EOD aggregate and
  /// ledger already understands both halves without being taught anything. This
  /// field is the only thing that says they belong together.
  ///
  /// Null on every sale that is not part of an exchange, which is also how all
  /// pre-existing records read back.
  @HiveField(32)
  final String? exchangeGroupId;

  /// The staff shift this sale was rung up on, or null.
  ///
  /// Retail's Shift Report and Staff Performance attribute a sale to a shift by
  /// this link first, falling back to the shift's time window for rows written
  /// before shifts existed — the same two-step `PastOrderModel.shiftId` gives
  /// the restaurant side. Nullable, so every pre-existing sale reads back as
  /// null and simply takes the time-window path.
  @HiveField(33)
  final String? shiftId;

  /// Why the goods came back — a [SaleReturnReason] code, never a label.
  ///
  /// Set only on a return document (`isReturn == true`); null on every forward
  /// sale, which is also how all pre-existing records read back. A code rather
  /// than free text so the Sales Refund report can group by it — the same
  /// choice `lineDiscountReason` and `overrideReason` made on the sale line.
  @HiveField(34)
  final String? returnReason;

  /// Free text accompanying [returnReason]. The picker demands it when the
  /// chosen reason says so — today that is `other`, where the code alone
  /// explains nothing.
  @HiveField(35)
  final String? returnNote;

  SaleModel({
    required this.saleId,
    this.customerId,
    required this.totalItems,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paymentType,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    bool? isReturn,
    this.originalSaleId,
    this.totalTaxableAmount,
    this.totalGstAmount,
    this.totalCgstAmount,
    this.totalSgstAmount,
    this.grandTotal,
    this.paymentListJson,
    this.changeReturn,
    this.totalPaid,
    this.isSplitPayment,
    double? paidAmount,
    double? dueAmount,
    String? status,
    this.discountType,
    this.discountValue,
    this.discountReason,
    this.loyaltyPointsUsed,
    this.roundOff,
    this.isTaxInclusive,
    this.lineDiscountTotal,
    this.exchangeGroupId,
    this.shiftId,
    this.returnReason,
    this.returnNote,
  })  : isReturn = isReturn ?? false,
        paidAmount = paidAmount ?? totalAmount,
        dueAmount = dueAmount ?? 0.0,
        status = status ?? SaleStatus.paid;

  factory SaleModel.create({
    required String saleId,
    String? customerId,
    required double totalItems,
    required double subtotal,
    double discountAmount = 0,
    double taxAmount = 0,
    required double totalAmount,
    required String paymentType,
    bool isReturn = false,
    String? originalSaleId,
    double? totalTaxableAmount,
    double? totalGstAmount,
    double? totalCgstAmount,
    double? totalSgstAmount,
    double? grandTotal,
    String? shiftId,
  }) {
    final now = DateTime.now().toIso8601String();

    return SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: totalItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      paymentType: paymentType,
      date: now,
      createdAt: now,
      updatedAt: now,
      isReturn: isReturn,
      originalSaleId: originalSaleId,
      totalTaxableAmount: totalTaxableAmount,
      totalGstAmount: totalGstAmount,
      totalCgstAmount: totalCgstAmount,
      totalSgstAmount: totalSgstAmount,
      grandTotal: grandTotal,
      shiftId: shiftId,
    );
  }

  /// Create with GST calculations
  factory SaleModel.createWithGst({
    required String saleId,
    String? customerId,
    required double totalItems,
    required double subtotal,
    required double discountAmount,
    required double totalTaxableAmount,
    required double totalGstAmount,
    required double grandTotal,
    required String paymentType,
    bool isReturn = false,
    String? originalSaleId,
    String? shiftId,
  }) {
    final now = DateTime.now().toIso8601String();
    final cgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));
    final sgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));

    return SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: totalItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: totalGstAmount, // For backward compatibility
      totalAmount: grandTotal, // For backward compatibility
      paymentType: paymentType,
      date: now,
      createdAt: now,
      updatedAt: now,
      isReturn: isReturn,
      originalSaleId: originalSaleId,
      totalTaxableAmount: totalTaxableAmount,
      totalGstAmount: totalGstAmount,
      totalCgstAmount: cgst,
      totalSgstAmount: sgst,
      grandTotal: grandTotal,
      shiftId: shiftId,
    );
  }

  /// Create with GST and Split Payment support
  factory SaleModel.createWithSplitPayment({
    required String saleId,
    String? customerId,
    required double totalItems,
    required double subtotal,
    required double discountAmount,
    required double totalTaxableAmount,
    required double totalGstAmount,
    required double grandTotal,
    required List<Map<String, dynamic>> paymentList,
    required double totalPaid,
    required double changeReturn,
    bool isReturn = false,
    String? originalSaleId,
    String? discountType,
    double? discountValue,
    String? discountReason,
    int? loyaltyPointsUsed,
    double? roundOff,
    bool? isTaxInclusive,
    double? lineDiscountTotal,
    /// Set when this sale is the replacement half of an exchange.
    String? exchangeGroupId,
    String? shiftId,
    /// When the customer tenders less than [grandTotal], pass what was actually
    /// collected. The remainder is recorded as due and the sale is marked
    /// partially paid rather than paid.
    double? amountCollected,
  }) {
    final now = DateTime.now().toIso8601String();
    final cgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));
    final sgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));

    // Clamp to the bill: tendering more than the total is change, not an
    // over-payment, so paidAmount must never exceed totalAmount.
    final collected =
        (amountCollected ?? grandTotal).clamp(0.0, grandTotal).toDouble();
    final due = double.parse((grandTotal - collected).toStringAsFixed(2));
    final isShort = due > 0.009;

    // Determine primary payment type (method with highest amount)
    String primaryPaymentType = 'split';
    if (paymentList.isNotEmpty) {
      paymentList.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      primaryPaymentType = paymentList.first['method'] as String;
    }

    return SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: totalItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: totalGstAmount,
      totalAmount: grandTotal,
      paymentType: paymentList.length > 1 ? 'split' : primaryPaymentType,
      date: now,
      createdAt: now,
      updatedAt: now,
      isReturn: isReturn,
      originalSaleId: originalSaleId,
      totalTaxableAmount: totalTaxableAmount,
      totalGstAmount: totalGstAmount,
      totalCgstAmount: cgst,
      totalSgstAmount: sgst,
      grandTotal: grandTotal,
      paymentListJson: jsonEncode(paymentList),
      changeReturn: changeReturn,
      totalPaid: totalPaid,
      isSplitPayment: paymentList.length > 1,
      discountType: discountType,
      discountValue: discountValue,
      discountReason: discountReason,
      loyaltyPointsUsed: loyaltyPointsUsed,
      roundOff: roundOff,
      isTaxInclusive: isTaxInclusive,
      lineDiscountTotal: lineDiscountTotal,
      exchangeGroupId: exchangeGroupId,
      shiftId: shiftId,
      paidAmount: collected,
      dueAmount: isShort ? due : 0.0,
      status: isShort ? SaleStatus.partiallyPaid : SaleStatus.paid,
    );
  }

  /// Get payment list from JSON
  List<Map<String, dynamic>> get paymentList {
    if (paymentListJson == null || paymentListJson!.isEmpty) {
      // Return single payment entry for backward compatibility
      return [
        {'method': paymentType, 'amount': totalAmount}
      ];
    }
    try {
      final List<dynamic> decoded = jsonDecode(paymentListJson!);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [
        {'method': paymentType, 'amount': totalAmount}
      ];
    }
  }

  /// Create a Credit/Pay-Later Sale
  factory SaleModel.createCreditSale({
    required String saleId,
    required String customerId, // Customer is REQUIRED for credit sales
    required double totalItems,
    required double subtotal,
    required double discountAmount,
    required double totalTaxableAmount,
    required double totalGstAmount,
    required double grandTotal,
    bool isReturn = false,
    String? originalSaleId,
    String? discountType,
    double? discountValue,
    String? discountReason,
    int? loyaltyPointsUsed,
    double? roundOff,
    bool? isTaxInclusive,
    double? lineDiscountTotal,
    String? exchangeGroupId,
    String? shiftId,
  }) {
    final now = DateTime.now().toIso8601String();
    final cgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));
    final sgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));

    return SaleModel(
      saleId: saleId,
      customerId: customerId,
      totalItems: totalItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: totalGstAmount,
      totalAmount: grandTotal,
      paymentType: 'credit', // Credit sale
      date: now,
      createdAt: now,
      updatedAt: now,
      isReturn: isReturn,
      originalSaleId: originalSaleId,
      totalTaxableAmount: totalTaxableAmount,
      totalGstAmount: totalGstAmount,
      totalCgstAmount: cgst,
      totalSgstAmount: sgst,
      grandTotal: grandTotal,
      paymentListJson: jsonEncode([{'method': 'credit', 'amount': grandTotal}]),
      changeReturn: 0,
      totalPaid: 0, // Nothing paid
      isSplitPayment: false,
      paidAmount: 0, // No payment made
      dueAmount: grandTotal, // Full amount is due
      status: SaleStatus.due, // Status is due
      discountType: discountType,
      discountValue: discountValue,
      discountReason: discountReason,
      loyaltyPointsUsed: loyaltyPointsUsed,
      roundOff: roundOff,
      isTaxInclusive: isTaxInclusive,
      lineDiscountTotal: lineDiscountTotal,
      exchangeGroupId: exchangeGroupId,
      shiftId: shiftId,
    );
  }

  /// Check if this sale has any due amount
  bool get hasDue => dueAmount > 0;

  /// Check if this is a credit sale
  bool get isCreditSale => paymentType == 'credit';

  /// Get status display text
  String get statusDisplayText {
    switch (status) {
      case SaleStatus.paid:
        return 'Paid';
      case SaleStatus.partiallyPaid:
        return 'Partially Paid';
      case SaleStatus.due:
        return 'Due';
      default:
        return 'Unknown';
    }
  }

  /// Copy with updated fields (for payment updates)
  SaleModel copyWith({
    String? saleId,
    String? customerId,
    double? totalItems,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? totalAmount,
    String? paymentType,
    String? date,
    String? createdAt,
    String? updatedAt,
    bool? isReturn,
    String? originalSaleId,
    double? totalTaxableAmount,
    double? totalGstAmount,
    double? totalCgstAmount,
    double? totalSgstAmount,
    double? grandTotal,
    String? paymentListJson,
    double? changeReturn,
    double? totalPaid,
    bool? isSplitPayment,
    double? paidAmount,
    double? dueAmount,
    String? status,
    String? discountType,
    double? discountValue,
    String? discountReason,
    int? loyaltyPointsUsed,
    double? roundOff,
    bool? isTaxInclusive,
    double? lineDiscountTotal,
    String? exchangeGroupId,
    String? shiftId,
    String? returnReason,
    String? returnNote,
  }) {
    return SaleModel(
      saleId: saleId ?? this.saleId,
      customerId: customerId ?? this.customerId,
      totalItems: totalItems ?? this.totalItems,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      isReturn: isReturn ?? this.isReturn,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      totalTaxableAmount: totalTaxableAmount ?? this.totalTaxableAmount,
      totalGstAmount: totalGstAmount ?? this.totalGstAmount,
      totalCgstAmount: totalCgstAmount ?? this.totalCgstAmount,
      totalSgstAmount: totalSgstAmount ?? this.totalSgstAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentListJson: paymentListJson ?? this.paymentListJson,
      changeReturn: changeReturn ?? this.changeReturn,
      totalPaid: totalPaid ?? this.totalPaid,
      isSplitPayment: isSplitPayment ?? this.isSplitPayment,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      status: status ?? this.status,
      // Bill composition must survive every copy. A credit instalment goes
      // through here, and dropping these silently rewrote settled invoices:
      // roundOff and isTaxInclusive are persisted precisely so a reprint can't
      // drift (see their field docs), and discountReason is the only record of
      // why a discount was given.
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountReason: discountReason ?? this.discountReason,
      loyaltyPointsUsed: loyaltyPointsUsed ?? this.loyaltyPointsUsed,
      roundOff: roundOff ?? this.roundOff,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      lineDiscountTotal: lineDiscountTotal ?? this.lineDiscountTotal,
      exchangeGroupId: exchangeGroupId ?? this.exchangeGroupId,
      shiftId: shiftId ?? this.shiftId,
      // Must survive a copy for the same reason discountReason must:
      // `ExchangeService._stamp` copyWith's the freshly written return document
      // to rewrite its payment legs, so dropping these would wipe the reason on
      // every exchange leg while leaving plain refunds correct.
      returnReason: returnReason ?? this.returnReason,
      returnNote: returnNote ?? this.returnNote,
    );
  }

  /// Calculate and return the status based on paid and due amounts
  static String calculateStatus(double paidAmount, double dueAmount) {
    if (dueAmount <= 0) return SaleStatus.paid;
    if (paidAmount <= 0) return SaleStatus.due;
    return SaleStatus.partiallyPaid;
  }

  Map<String, dynamic> toMap() {
    return {
      'saleId': saleId,
      'customerId': customerId,
      'totalItems': totalItems,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'paymentType': paymentType,
      'date': date,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isReturn': isReturn,
      'originalSaleId': originalSaleId,
      'totalTaxableAmount': totalTaxableAmount,
      'totalGstAmount': totalGstAmount,
      'totalCgstAmount': totalCgstAmount,
      'totalSgstAmount': totalSgstAmount,
      'grandTotal': grandTotal,
      'paymentList': paymentList,
      'changeReturn': changeReturn ?? 0,
      'totalPaid': totalPaid ?? totalAmount,
      'isSplitPayment': isSplitPayment ?? false,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'status': status,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountReason': discountReason,
      'loyaltyPointsUsed': loyaltyPointsUsed,
      'roundOff': roundOff,
      'isTaxInclusive': isTaxInclusive,
      'lineDiscountTotal': lineDiscountTotal,
      'exchangeGroupId': exchangeGroupId,
      'shiftId': shiftId,
      'returnReason': returnReason,
      'returnNote': returnNote,
    };
  }

  // Create from Map (for backup restore)
  factory SaleModel.fromMap(Map<String, dynamic> map) {
    // `date` and `createdAt` must never diverge — reports, EOD and the
    // dashboard all key off them. Each falls back to its sibling before any
    // default, so a backup carrying only one of them restores with both set to
    // the SAME instant rather than reclassifying the sale into the restore date.
    //
    // Defaulted rather than hard-cast because this runs on the restore path:
    // one missing key used to throw and abort the entire restore.
    final restoredCreatedAt = (map['createdAt'] ?? map['date']) as String? ??
        DateTime.now().toIso8601String();
    final restoredDate = (map['date'] as String?) ?? restoredCreatedAt;

    return SaleModel(
      saleId: map['saleId'] as String,
      customerId: map['customerId'] as String?,
      totalItems: (map['totalItems'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentType: (map['paymentType'] as String?) ?? 'cash',
      date: restoredDate,
      createdAt: restoredCreatedAt,
      updatedAt: (map['updatedAt'] as String?) ?? restoredCreatedAt,
      isReturn: (map['isReturn'] as bool?) ?? false,
      originalSaleId: map['originalSaleId'] as String?,
      totalTaxableAmount: (map['totalTaxableAmount'] as num?)?.toDouble(),
      totalGstAmount: (map['totalGstAmount'] as num?)?.toDouble(),
      totalCgstAmount: (map['totalCgstAmount'] as num?)?.toDouble(),
      totalSgstAmount: (map['totalSgstAmount'] as num?)?.toDouble(),
      grandTotal: (map['grandTotal'] as num?)?.toDouble(),
      paymentListJson: map['paymentListJson'] as String?,
      changeReturn: (map['changeReturn'] as num?)?.toDouble(),
      totalPaid: (map['totalPaid'] as num?)?.toDouble(),
      isSplitPayment: (map['isSplitPayment'] as bool?) ?? false,
      paidAmount: (map['paidAmount'] as num?)?.toDouble(),
      dueAmount: (map['dueAmount'] as num?)?.toDouble(),
      status: (map['status'] as String?) ?? SaleStatus.paid,
      discountType: map['discountType'] as String?,
      discountValue: (map['discountValue'] as num?)?.toDouble(),
      discountReason: map['discountReason'] as String?,
      loyaltyPointsUsed: (map['loyaltyPointsUsed'] as num?)?.toInt(),
      roundOff: (map['roundOff'] as num?)?.toDouble(),
      isTaxInclusive: map['isTaxInclusive'] as bool?,
      lineDiscountTotal:
          (map['lineDiscountTotal'] as num?)?.toDouble(),
      exchangeGroupId: map['exchangeGroupId'] as String?,
      shiftId: map['shiftId'] as String?,
      returnReason: map['returnReason'] as String?,
      returnNote: map['returnNote'] as String?,
    );
  }
}
