

import 'dart:convert';
import 'package:hive/hive.dart';

part 'sale_model_203.g.dart';

/// Sale status constants
class SaleStatus {
  static const String paid = 'paid';
  static const String partiallyPaid = 'partially_paid';
  static const String due = 'due';
}

@HiveType(typeId: 203)
class SaleModel extends HiveObject {
  @HiveField(0)
  final String saleId;

  @HiveField(1)
  final String? customerId;

  @HiveField(2)
  final int totalItems;

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
  })  : isReturn = isReturn ?? false,
        paidAmount = paidAmount ?? totalAmount,
        dueAmount = dueAmount ?? 0.0,
        status = status ?? SaleStatus.paid;

  factory SaleModel.create({
    required String saleId,
    String? customerId,
    required int totalItems,
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
    );
  }

  /// Create with GST calculations
  factory SaleModel.createWithGst({
    required String saleId,
    String? customerId,
    required int totalItems,
    required double subtotal,
    required double discountAmount,
    required double totalTaxableAmount,
    required double totalGstAmount,
    required double grandTotal,
    required String paymentType,
    bool isReturn = false,
    String? originalSaleId,
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
    );
  }

  /// Create with GST and Split Payment support
  factory SaleModel.createWithSplitPayment({
    required String saleId,
    String? customerId,
    required int totalItems,
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
  }) {
    final now = DateTime.now().toIso8601String();
    final cgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));
    final sgst = double.parse((totalGstAmount / 2).toStringAsFixed(2));

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
    required int totalItems,
    required double subtotal,
    required double discountAmount,
    required double totalTaxableAmount,
    required double totalGstAmount,
    required double grandTotal,
    bool isReturn = false,
    String? originalSaleId,
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
    int? totalItems,
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
    };
  }
}
