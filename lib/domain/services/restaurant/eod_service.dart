
import 'package:unipos/data/models/restaurant/db/database/hive_eod.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_expensecategory.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_pastorder.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../data/models/restaurant/db/pastordermodel_313.dart';

class EODService {
  static const _uuid = Uuid();

  static Future<EndOfDayReport> generateEODReport({
    required DateTime date,
    required double openingBalance,
    required double actualCash,
    String? remarks,
  }) async {
    final pastOrders = await HivePastOrder.getAllPastOrderModel();

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Get ALL orders for the day
    final allDayOrders = pastOrders.where((order) {
      return order.orderAt != null &&
          order.orderAt!.isAfter(startOfDay) &&
          order.orderAt!.isBefore(endOfDay);
    }).toList();

    // Separate fully refunded orders from active orders for reporting
    final activeDayOrders = allDayOrders.where((order) {
      return order.orderStatus != 'FULLY_REFUNDED';
    }).toList();

    // Use activeDayOrders for count-based statistics (excludes fully refunded orders)
    final orderSummaries = _calculateOrderTypeSummaries(activeDayOrders);
    final categorySales = _calculateCategorySales(allDayOrders); // Use all orders for accurate financial calculation
    final paymentSummaries = _calculatePaymentSummaries(activeDayOrders);
    final taxSummaries = _calculateTaxSummaries(allDayOrders);

    // Calculate totals with refunds properly deducted (use all orders for accurate totals)
    final totalSales = allDayOrders.fold<double>(0.0, (sum, order) => sum + (order.totalPrice - (order.refundAmount ?? 0.0)));
    final totalDiscount = allDayOrders.fold<double>(0.0, (sum, order) => sum + (order.Discount ?? 0.0));

    // Calculate proportional tax amount (subtract tax on refunded amount)
    final totalTax = allDayOrders.fold<double>(0.0, (sum, order) {
      if (order.orderStatus == 'FULLY_REFUNDED') return sum;

      final orderRefundRatio = order.totalPrice > 0
          ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
          : 1.0;
      final effectiveTax = (order.gstAmount ?? 0.0) * orderRefundRatio;
      return sum + effectiveTax;
    });

    final totalRefunds = allDayOrders.fold<double>(0.0, (sum, order) => sum + (order.refundAmount ?? 0.0));
    final totalOrderCount = activeDayOrders.length; // Count only active orders

    // Calculate expenses for the day
    final allExpenses = await HiveExpenceL.getAllItems();
    final dayExpenses = allExpenses.where((expense) {
      return (expense.dateandTime.isAfter(startOfDay) || expense.dateandTime.isAtSameMomentAs(startOfDay)) &&
          (expense.dateandTime.isBefore(endOfDay) || expense.dateandTime.isAtSameMomentAs(endOfDay));
    }).toList();

    // Calculate total expenses (all payment types) for P&L reporting
    final totalExpenses = dayExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);

    // Calculate ONLY cash expenses for cash drawer reconciliation
    final cashExpenses = dayExpenses.where((expense) {
      return expense.paymentType?.toLowerCase().trim() == 'cash';
    }).fold<double>(0.0, (sum, expense) => sum + expense.amount);

    final expectedCash = paymentSummaries
        .where((payment) => payment.paymentType.toLowerCase() == 'cash')
        .fold<double>(0.0, (sum, payment) => sum + payment.totalAmount);

    // Adjust closing balance and cash difference by subtracting ONLY cash expenses
    // Non-cash expenses don't affect the physical cash drawer
    final closingBalance = openingBalance + expectedCash - cashExpenses;
    final cashDifference = actualCash - (openingBalance + expectedCash - cashExpenses);

    String reconciliationStatus;
    if (cashDifference == 0) {
      reconciliationStatus = 'Balanced';
    } else if (cashDifference > 0) {
      reconciliationStatus = 'Overage';
    } else {
      reconciliationStatus = 'Shortage';
    }

    final cashReconciliation = CashReconciliation(
      systemExpectedCash: expectedCash,
      actualCash: actualCash,
      difference: cashDifference,
      reconciliationStatus: reconciliationStatus,
      remarks: remarks,
    );

    final reportId = _uuid.v4();

    return EndOfDayReport(
      reportId: reportId,
      date: date,
      openingBalance: openingBalance,
      orderSummaries: orderSummaries,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      categorySales: categorySales,
      paymentSummaries: paymentSummaries,
      cashReconciliation: cashReconciliation,
      totalSales: totalSales,
      closingBalance: closingBalance,
      taxSummaries: taxSummaries,
      totalOrderCount: totalOrderCount,
      totalRefunds: totalRefunds,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
    );
  }

  static List<OrderTypeSummary> _calculateOrderTypeSummaries(List<pastOrderModel> orders) {
    final Map<String, List<pastOrderModel>> groupedOrders = {};

    for (final order in orders) {
      final orderType = order.orderType ?? 'Unknown';
      groupedOrders.putIfAbsent(orderType, () => []).add(order);
    }

    return groupedOrders.entries.map((entry) {
      final orderType = entry.key;
      final typeOrders = entry.value;
      final totalAmount = typeOrders.fold<double>(0.0, (sum, order) => sum + (order.totalPrice - (order.refundAmount ?? 0.0)));
      final orderCount = typeOrders.length;
      final averageOrderValue = orderCount > 0 ? totalAmount / orderCount : 0.0;

      return OrderTypeSummary(
        orderType: orderType,
        orderCount: orderCount,
        totalAmount: totalAmount,
        averageOrderValue: averageOrderValue,
      );
    }).toList();
  }

  static List<CategorySales> _calculateCategorySales(List<pastOrderModel> orders) {
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryItemCounts = {};

    double grandTotal = 0.0;

    for (final order in orders) {
      final netOrderAmount = order.totalPrice - (order.refundAmount ?? 0.0);
      grandTotal += netOrderAmount;

      // For partially refunded orders, calculate proportional category amounts
      final refundRatio = order.totalPrice > 0 ? (netOrderAmount / order.totalPrice) : 1.0;

      for (final item in order.items) {
        final category = item.categoryName ?? 'Uncategorized';
        // Apply proportional reduction for refunds
        final itemTotal = item.totalPrice * refundRatio;
        // Only count non-refunded quantities
        final effectiveQuantity = (item.quantity - (item.refundedQuantity ?? 0));

        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + itemTotal;
        categoryItemCounts[category] = (categoryItemCounts[category] ?? 0) + effectiveQuantity;
      }
    }

    return categoryTotals.entries.map((entry) {
      final categoryName = entry.key;
      final totalAmount = entry.value;
      final itemsSold = categoryItemCounts[categoryName] ?? 0;
      final percentage = grandTotal > 0 ? (totalAmount / grandTotal) * 100 : 0.0;

      return CategorySales(
        categoryName: categoryName,
        totalAmount: totalAmount,
        itemsSold: itemsSold,
        percentage: percentage,
      );
    }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  static List<PaymentSummary> _calculatePaymentSummaries(List<pastOrderModel> orders) {
    final Map<String, double> paymentTotals = {};
    final Map<String, int> paymentCounts = {};

    double grandTotal = 0.0;

    for (final order in orders) {
      final paymentType = order.paymentmode ?? 'Unknown';
      final amount = order.totalPrice - (order.refundAmount ?? 0.0); // Net amount after refunds

      paymentTotals[paymentType] = (paymentTotals[paymentType] ?? 0.0) + amount;
      paymentCounts[paymentType] = (paymentCounts[paymentType] ?? 0) + 1;
      grandTotal += amount;
    }

    return paymentTotals.entries.map((entry) {
      final paymentType = entry.key;
      final totalAmount = entry.value;
      final transactionCount = paymentCounts[paymentType] ?? 0;
      final percentage = grandTotal > 0 ? (totalAmount / grandTotal) * 100 : 0.0;

      return PaymentSummary(
        paymentType: paymentType,
        totalAmount: totalAmount,
        transactionCount: transactionCount,
        percentage: percentage,
      );
    }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  static List<TaxSummary> _calculateTaxSummaries(List<pastOrderModel> orders) {
    final Map<String, TaxInfo> taxData = {};

    for (final order in orders) {
      // Skip fully refunded orders
      if (order.orderStatus == 'FULLY_REFUNDED') continue;

      if (order.gstRate != null && order.gstAmount != null && order.gstRate! > 0) {
        final taxKey = 'GST ${(order.gstRate! * 100).toStringAsFixed(1)}%';

        // Calculate proportional tax amount for partially refunded orders
        final orderRefundRatio = order.totalPrice > 0
            ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
            : 1.0;

        final effectiveTaxAmount = order.gstAmount! * orderRefundRatio;
        final taxableAmount = (order.subTotal ?? (order.totalPrice - (order.gstAmount ?? 0.0))) * orderRefundRatio;

        if (taxData.containsKey(taxKey)) {
          taxData[taxKey]!.taxAmount += effectiveTaxAmount;
          taxData[taxKey]!.taxableAmount += taxableAmount;
        } else {
          taxData[taxKey] = TaxInfo(
            taxName: taxKey,
            taxRate: order.gstRate!,
            taxAmount: effectiveTaxAmount,
            taxableAmount: taxableAmount,
          );
        }
      }
    }

    return taxData.values.map((taxInfo) {
      return TaxSummary(
        taxName: taxInfo.taxName,
        taxRate: taxInfo.taxRate,
        taxAmount: taxInfo.taxAmount,
        taxableAmount: taxInfo.taxableAmount,
      );
    }).toList();
  }

  static Future<void> saveEODReport(EndOfDayReport report) async {
    await HiveEOD.addEODReport(report);
  }

  static Future<List<EndOfDayReport>> getAllEODReports() async {
    return await HiveEOD.getAllEODReports();
  }

  static Future<EndOfDayReport?> getTodaysEOD() async {
    final today = DateTime.now();
    return await HiveEOD.getEODByDate(today);
  }

  static Future<double> getLastClosingBalance() async {
    final latestEOD = await HiveEOD.getLatestEOD();
    return latestEOD?.closingBalance ?? 0.0;
  }

  // ==================== RETAIL EOD GENERATION ====================

  static Future<EndOfDayReport> generateRetailEODReport({
    required DateTime date,
    required double openingBalance,
    required double actualCash,
    String? remarks,
  }) async {
    // Get all sales for the day using SaleStore
    final allSales = await saleStore.getSalesByDateRange(
      DateTime(date.year, date.month, date.day),
      DateTime(date.year, date.month, date.day, 23, 59, 59),
    );

    // Filter out returns for count-based stats, but include them in financial calculations
    final activeSales = allSales.where((sale) => sale.isReturn != true).toList();

    // Calculate payment summaries (Cash, Card, UPI, Credit, Split)
    final paymentSummaries = _calculateRetailPaymentSummaries(activeSales);

    // Calculate totals
    final totalSales = allSales.fold<double>(0.0, (sum, sale) {
      // Returns have negative amounts
      return sum + (sale.isReturn == true ? -sale.totalAmount : sale.totalAmount);
    });

    final totalDiscount = allSales.fold<double>(0.0, (sum, sale) => sum + sale.discountAmount);
    final totalTax = allSales.fold<double>(0.0, (sum, sale) => sum + (sale.totalGstAmount ?? sale.taxAmount));

    // Calculate tax summaries (CGST/SGST breakdown)
    final taxSummaries = _calculateRetailTaxSummaries(allSales);

    // Calculate total returns
    final totalRefunds = allSales
        .where((sale) => sale.isReturn == true)
        .fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);

    final totalSaleCount = activeSales.length;

    // Calculate expenses for the day (reuse restaurant expense system)
    final allExpenses = await HiveExpenceL.getAllItems();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final dayExpenses = allExpenses.where((expense) {
      return (expense.dateandTime.isAfter(startOfDay) || expense.dateandTime.isAtSameMomentAs(startOfDay)) &&
          (expense.dateandTime.isBefore(endOfDay) || expense.dateandTime.isAtSameMomentAs(endOfDay));
    }).toList();

    final totalExpenses = dayExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    final cashExpenses = dayExpenses
        .where((expense) => expense.paymentType?.toLowerCase().trim() == 'cash')
        .fold<double>(0.0, (sum, expense) => sum + expense.amount);

    // Calculate expected cash
    final expectedCash = paymentSummaries
        .where((payment) => payment.paymentType.toLowerCase() == 'cash')
        .fold<double>(0.0, (sum, payment) => sum + payment.totalAmount);

    // Calculate closing balance and difference
    final closingBalance = openingBalance + expectedCash - cashExpenses;
    final cashDifference = actualCash - (openingBalance + expectedCash - cashExpenses);

    String reconciliationStatus;
    if (cashDifference == 0) {
      reconciliationStatus = 'Balanced';
    } else if (cashDifference > 0) {
      reconciliationStatus = 'Overage';
    } else {
      reconciliationStatus = 'Shortage';
    }

    final cashReconciliation = CashReconciliation(
      systemExpectedCash: expectedCash,
      actualCash: actualCash,
      difference: cashDifference,
      reconciliationStatus: reconciliationStatus,
      remarks: remarks,
    );

    final reportId = _uuid.v4();

    return EndOfDayReport(
      reportId: reportId,
      date: date,
      openingBalance: openingBalance,
      orderSummaries: [], // Empty for retail - not applicable
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      categorySales: [], // Empty for retail - can be added later if needed
      paymentSummaries: paymentSummaries,
      cashReconciliation: cashReconciliation,
      totalSales: totalSales,
      closingBalance: closingBalance,
      taxSummaries: taxSummaries,
      totalOrderCount: totalSaleCount,
      totalRefunds: totalRefunds,
      totalExpenses: totalExpenses,
      cashExpenses: cashExpenses,
      mode: 'retail', // Mark as retail EOD
    );
  }

  static List<PaymentSummary> _calculateRetailPaymentSummaries(List sales) {
    final Map<String, double> paymentTotals = {};
    final Map<String, int> paymentCounts = {};
    double grandTotal = 0.0;

    for (final sale in sales) {
      String paymentType = sale.paymentType ?? 'Unknown';

      // Handle split payments - expand into individual payment methods
      if (sale.isSplitPayment == true && sale.paymentListJson != null && sale.paymentListJson!.isNotEmpty) {
        for (final payment in sale.paymentList) {
          final method = payment['method'] as String;
          final amount = payment['amount'] as double;

          paymentTotals[method] = (paymentTotals[method] ?? 0.0) + amount;
          paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
          grandTotal += amount;
        }
      } else {
        // Single payment
        final amount = sale.totalAmount as double;
        paymentTotals[paymentType] = (paymentTotals[paymentType] ?? 0.0) + amount;
        paymentCounts[paymentType] = (paymentCounts[paymentType] ?? 0) + 1;
        grandTotal += amount;
      }
    }

    return paymentTotals.entries.map((entry) {
      final paymentType = entry.key;
      final totalAmount = entry.value;
      final transactionCount = paymentCounts[paymentType] ?? 0;
      final percentage = grandTotal > 0 ? (totalAmount / grandTotal) * 100 : 0.0;

      return PaymentSummary(
        paymentType: paymentType,
        totalAmount: totalAmount,
        transactionCount: transactionCount,
        percentage: percentage,
      );
    }).toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  static List<TaxSummary> _calculateRetailTaxSummaries(List sales) {
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double totalTaxableAmount = 0.0;

    for (final sale in sales) {
      if (sale.isReturn == true) continue; // Skip returns

      if (sale.totalCgstAmount != null && sale.totalSgstAmount != null) {
        totalCgst += sale.totalCgstAmount!;
        totalSgst += sale.totalSgstAmount!;
        totalTaxableAmount += (sale.totalTaxableAmount ?? 0.0);
      }
    }

    List<TaxSummary> summaries = [];

    // Add CGST summary if present
    if (totalCgst > 0) {
      summaries.add(TaxSummary(
        taxName: 'CGST',
        taxRate: 0.0, // Rate varies by product, so we'll show 0 for overall
        taxAmount: totalCgst,
        taxableAmount: totalTaxableAmount / 2, // Half for CGST
      ));
    }

    // Add SGST summary if present
    if (totalSgst > 0) {
      summaries.add(TaxSummary(
        taxName: 'SGST',
        taxRate: 0.0,
        taxAmount: totalSgst,
        taxableAmount: totalTaxableAmount / 2, // Half for SGST
      ));
    }

    return summaries;
  }
}

class TaxInfo {
  final String taxName;
  final double taxRate;
  double taxAmount;
  double taxableAmount;

  TaxInfo({
    required this.taxName,
    required this.taxRate,
    required this.taxAmount,
    required this.taxableAmount,
  });
}