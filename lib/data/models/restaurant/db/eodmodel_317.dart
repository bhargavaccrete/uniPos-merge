

import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

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
