

import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';

part'eodmodel_317.g.dart';
@HiveType(typeId: HiveTypeIds.restaurantEod)
class EndOfDayReport extends HiveObject{

  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double openingBalance;

  @HiveField(2)
  final List<OrderTypeSummary> orderSummaries;

  @HiveField(3)
  final double totalDiscount;

  @HiveField(4)
  final double totalTax;

  @HiveField(5)
  final List<CategorySales> categorySales;

  @HiveField(6)
  final List<PaymentSummary> paymentSummaries;

  @HiveField(7)
  final CashReconciliation cashReconciliation;

  @HiveField(8)
  final double totalSales;

  @HiveField(9)
  final double closingBalance;

  @HiveField(10)
  final List<TaxSummary> taxSummaries;

  @HiveField(11)
  final int totalOrderCount;

  @HiveField(12)
  final double totalRefunds;

  @HiveField(13)
  final String reportId;

  @HiveField(14)
  final double totalExpenses;

  @HiveField(15)
  final double cashExpenses;

  @HiveField(16)
  final String? mode; // 'retail' or 'restaurant' (nullable for backward compatibility)

  @HiveField(17)
  final double roundOff; // Sum of per-order rounding adjustments for the shift

  @HiveField(18)
  final int cancelledOrderCount; // VOID/CANCELLED orders in the shift

  @HiveField(19)
  final double cancelledOrderAmount; // Total value of those cancelled orders

  @HiveField(20)
  final String? sessionId; // The POS session this close belongs to (null = retail/legacy)

  // ==================== CREDIT COLLECTIONS (retail) ====================
  // Repayments taken against existing credit during the day. Distinct from
  // sales: money arriving for goods sold on an EARLIER day, so it must never be
  // added to `totalSales` — but it IS cash that has to be in the drawer.

  @HiveField(21)
  final double cashCollections;

  @HiveField(22)
  final double cardCollections;

  @HiveField(23)
  final double upiCollections;

  // ==================== PROFIT (retail) ====================

  /// Cost of goods sold for the day, from the cost frozen on each sale line.
  @HiveField(24)
  final double totalCost;

  /// Ex-tax revenue minus [totalCost]. Collected GST is not profit.
  @HiveField(25)
  final double grossProfit;

  // ==================== CUSTOMER OUTSTANDING (retail) ====================

  /// How many customers were carrying a balance at close.
  @HiveField(26)
  final int customersWithDue;

  /// Total owed to the shop at close, across all customers.
  @HiveField(27)
  final double totalOutstanding;

  /// Credit repayments across every mode.
  ///
  /// Derived, not stored: persisting it alongside its own three components is
  /// how a stored total drifts from the parts it claims to sum.
  double get totalCollections =>
      cashCollections + cardCollections + upiCollections;

  /// Gross margin as a percentage of **ex-tax** revenue.
  ///
  /// The denominator is `totalSales - totalTax`, not `totalSales`: [grossProfit]
  /// is computed against revenue with the collected GST removed, so dividing by
  /// a tax-inclusive figure would understate the margin by the tax rate.
  ///
  /// `!= 0` rather than `> 0`: a day whose refunds outweigh its sales has
  /// negative revenue, and `> 0` would render that loss as a flat 0%.
  double get profitMargin {
    final exTaxRevenue = totalSales - totalTax;
    return exTaxRevenue != 0 ? (grossProfit / exTaxRevenue) * 100 : 0.0;
  }

  EndOfDayReport({
    required this.date,
    required this.openingBalance,
    required this.orderSummaries,
    required this.totalDiscount,
    required this.totalTax,
    required this.categorySales,
    required this.paymentSummaries,
    required this.cashReconciliation,
    required this.totalSales,
    required this.closingBalance,
    required this.taxSummaries,
    required this.totalOrderCount,
    required this.totalRefunds,
    required this.reportId,
    required this.totalExpenses,
    required this.cashExpenses,
    this.mode, // Nullable - null means restaurant (for backward compatibility)
    this.roundOff = 0,
    this.cancelledOrderCount = 0,
    this.cancelledOrderAmount = 0,
    this.sessionId,
    // Retail-only; default to zero so restaurant closes and reports written
    // before these existed stay constructible unchanged.
    this.cashCollections = 0,
    this.cardCollections = 0,
    this.upiCollections = 0,
    this.totalCost = 0,
    this.grossProfit = 0,
    this.customersWithDue = 0,
    this.totalOutstanding = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'openingBalance': openingBalance,
      'orderSummaries': orderSummaries.map((e) => e.toMap()).toList(),
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'categorySales': categorySales.map((e) => e.toMap()).toList(),
      'paymentSummaries': paymentSummaries.map((e) => e.toMap()).toList(),
      'cashReconciliation': cashReconciliation.toMap(),
      'totalSales': totalSales,
      'closingBalance': closingBalance,
      'taxSummaries': taxSummaries.map((e) => e.toMap()).toList(),
      'totalOrderCount': totalOrderCount,
      'totalRefunds': totalRefunds,
      'reportId': reportId,
      'totalExpenses': totalExpenses,
      'cashExpenses': cashExpenses,
      'mode': mode,
      'roundOff': roundOff,
      'cancelledOrderCount': cancelledOrderCount,
      'cancelledOrderAmount': cancelledOrderAmount,
      'sessionId': sessionId,
      'cashCollections': cashCollections,
      'cardCollections': cardCollections,
      'upiCollections': upiCollections,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'customersWithDue': customersWithDue,
      'totalOutstanding': totalOutstanding,
    };
  }

  factory EndOfDayReport.fromMap(Map<String, dynamic> map) {
    return EndOfDayReport(
      date: DateTime.parse(map['date']),
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      orderSummaries: (map['orderSummaries'] as List?)?.map((e) => OrderTypeSummary.fromMap(e)).toList() ?? [],
      totalDiscount: (map['totalDiscount'] ?? 0).toDouble(),
      totalTax: (map['totalTax'] ?? 0).toDouble(),
      categorySales: (map['categorySales'] as List?)?.map((e) => CategorySales.fromMap(e)).toList() ?? [],
      paymentSummaries: (map['paymentSummaries'] as List?)?.map((e) => PaymentSummary.fromMap(e)).toList() ?? [],
      cashReconciliation: CashReconciliation.fromMap(map['cashReconciliation']),
      totalSales: (map['totalSales'] ?? 0).toDouble(),
      closingBalance: (map['closingBalance'] ?? 0).toDouble(),
      taxSummaries: (map['taxSummaries'] as List?)?.map((e) => TaxSummary.fromMap(e)).toList() ?? [],
      totalOrderCount: map['totalOrderCount'] ?? 0,
      totalRefunds: (map['totalRefunds'] ?? 0).toDouble(),
      reportId: map['reportId'] ?? '',
      totalExpenses: (map['totalExpenses'] ?? 0).toDouble(),
      cashExpenses: (map['cashExpenses'] ?? 0).toDouble(),
      mode: map['mode'],
      roundOff: (map['roundOff'] ?? 0).toDouble(),
      cancelledOrderCount: map['cancelledOrderCount'] ?? 0,
      cancelledOrderAmount: (map['cancelledOrderAmount'] ?? 0).toDouble(),
      sessionId: map['sessionId'],
      cashCollections: (map['cashCollections'] ?? 0).toDouble(),
      cardCollections: (map['cardCollections'] ?? 0).toDouble(),
      upiCollections: (map['upiCollections'] ?? 0).toDouble(),
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      grossProfit: (map['grossProfit'] ?? 0).toDouble(),
      customersWithDue: map['customersWithDue'] ?? 0,
      totalOutstanding: (map['totalOutstanding'] ?? 0).toDouble(),
    );
  }

}


@HiveType(typeId: HiveTypeIds.OrderTypeSummary)
class OrderTypeSummary extends HiveObject{

  @HiveField(0)
  final String orderType;

  @HiveField(1)
  final int orderCount;

  @HiveField(2)
  final double totalAmount;

  @HiveField(3)
  final double averageOrderValue;

  OrderTypeSummary({
    required this.orderType,
    required this.orderCount,
    required this.totalAmount,
    required this.averageOrderValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderType': orderType,
      'orderCount': orderCount,
      'totalAmount': totalAmount,
      'averageOrderValue': averageOrderValue,
    };
  }

  factory OrderTypeSummary.fromMap(Map<String, dynamic> map) {
    return OrderTypeSummary(
      orderType: map['orderType'] ?? '',
      orderCount: map['orderCount'] ?? 0,
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      averageOrderValue: (map['averageOrderValue'] ?? 0).toDouble(),
    );
  }
}


@HiveType(typeId: HiveTypeIds.CategorySales)
class CategorySales extends HiveObject{
  @HiveField(0)
  final String categoryName;

  @HiveField(1)
  final double totalAmount;

  @HiveField(2)
  final int itemsSold;

  @HiveField(3)
  final double percentage;

  CategorySales({
    required this.categoryName,
    required this.totalAmount,
    required this.itemsSold,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryName': categoryName,
      'totalAmount': totalAmount,
      'itemsSold': itemsSold,
      'percentage': percentage,
    };
  }

  factory CategorySales.fromMap(Map<String, dynamic> map) {
    return CategorySales(
      categoryName: map['categoryName'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      itemsSold: map['itemsSold'] ?? 0,
      percentage: (map['percentage'] ?? 0).toDouble(),
    );
  }
}



@HiveType(typeId: HiveTypeIds.PaymentSummary)
class PaymentSummary extends HiveObject{

  @HiveField(0)
  final String paymentType;

  @HiveField(1)
  final double totalAmount;

  @HiveField(2)
  final int transactionCount;

  @HiveField(3)
  final double percentage;

  PaymentSummary({
    required this.paymentType,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentType': paymentType,
      'totalAmount': totalAmount,
      'transactionCount': transactionCount,
      'percentage': percentage,
    };
  }

  factory PaymentSummary.fromMap(Map<String, dynamic> map) {
    return PaymentSummary(
      paymentType: map['paymentType'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      transactionCount: map['transactionCount'] ?? 0,
      percentage: (map['percentage'] ?? 0).toDouble(),
    );
  }
}


@HiveType(typeId: HiveTypeIds.CashReconciliation)
class CashReconciliation extends HiveObject{
  @HiveField(0)
  final double systemExpectedCash;

  @HiveField(1)
  final double actualCash;

  @HiveField(2)
  final double difference;

  @HiveField(3)
  final String reconciliationStatus;

  @HiveField(4)
  final String? remarks;

  CashReconciliation({
    required this.systemExpectedCash,
    required this.actualCash,
    required this.difference,
    required this.reconciliationStatus,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'systemExpectedCash': systemExpectedCash,
      'actualCash': actualCash,
      'difference': difference,
      'reconciliationStatus': reconciliationStatus,
      'remarks': remarks,
    };
  }

  factory CashReconciliation.fromMap(Map<String, dynamic> map) {
    return CashReconciliation(
      systemExpectedCash: (map['systemExpectedCash'] ?? 0).toDouble(),
      actualCash: (map['actualCash'] ?? 0).toDouble(),
      difference: (map['difference'] ?? 0).toDouble(),
      reconciliationStatus: map['reconciliationStatus'] ?? '',
      remarks: map['remarks'],
    );
  }

}




/*
class EndOfDayReport extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double openingBalance;

  @HiveField(2)
  final List<OrderTypeSummary> orderSummaries;

  @HiveField(3)
  final double totalDiscount;

  @HiveField(4)
  final double totalTax;

  @HiveField(5)
  final List<CategorySale> categorySales;

  @HiveField(6)
  final List<PaymentSummary> paymentSummaries;

  @HiveField(7)
  final CashReconciliation cashReconciliation;

  EndOfDayReport({
    required this.date,
    required this.openingBalance,
    required this.orderSummaries,
    required this.totalDiscount,
    required this.totalTax,
    required this.categorySales,
    required this.paymentSummaries,
    required this.cashReconciliation,
  });
}*/

@HiveType(typeId: HiveTypeIds.TaxSummary)
class TaxSummary extends HiveObject{
  @HiveField(0)
  final String taxName;

  @HiveField(1)
  final double taxRate;

  @HiveField(2)
  final double taxAmount;

  @HiveField(3)
  final double taxableAmount;

  TaxSummary({
    required this.taxName,
    required this.taxRate,
    required this.taxAmount,
    required this.taxableAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'taxName': taxName,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'taxableAmount': taxableAmount,
    };
  }

  factory TaxSummary.fromMap(Map<String, dynamic> map) {
    return TaxSummary(
      taxName: map['taxName'] ?? '',
      taxRate: (map['taxRate'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      taxableAmount: (map['taxableAmount'] ?? 0).toDouble(),
    );
  }
}
