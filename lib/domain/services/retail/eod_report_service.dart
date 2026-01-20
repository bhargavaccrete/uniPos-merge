

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/customer_model_208.dart';
import '../../../data/repositories/retail/credit_payment_repository.dart';

/// End of Day Report Service
/// Generates comprehensive EOD reports including sales, collections, profit, and cash drawer summary
class EODReportService {
  final CreditPaymentRepository _creditPaymentRepository = CreditPaymentRepository();

  /// Generate comprehensive EOD Report for a given date
  Future<EODReport> generateEODReport({DateTime? date}) async {
    final reportDate = date ?? DateTime.now();
    final startOfDay = DateTime(reportDate.year, reportDate.month, reportDate.day);
    final endOfDay = DateTime(reportDate.year, reportDate.month, reportDate.day, 23, 59, 59);

    // Get all sales for the day
    final sales = await saleStore.getSalesByDateRange(startOfDay, endOfDay);

    // Sales Summary
    double cashSales = 0;
    double cardSales = 0;
    double upiSales = 0;
    double creditSales = 0;
    double splitSales = 0;
    int cashCount = 0;
    int cardCount = 0;
    int upiCount = 0;
    int creditCount = 0;
    int splitCount = 0;

    for (var sale in sales) {
      if (sale.isReturn == true) continue;

      switch (sale.paymentType.toLowerCase()) {
        case 'cash':
          cashSales += sale.totalAmount;
          cashCount++;
          break;
        case 'card':
          cardSales += sale.totalAmount;
          cardCount++;
          break;
        case 'upi':
          upiSales += sale.totalAmount;
          upiCount++;
          break;
        case 'credit':
          creditSales += sale.totalAmount;
          creditCount++;
          break;
        case 'split':
          splitSales += sale.totalAmount;
          splitCount++;
          break;
      }
    }

    final totalSales = cashSales + cardSales + upiSales + creditSales + splitSales;
    final totalTransactions = cashCount + cardCount + upiCount + creditCount + splitCount;

    // Collections Summary (credit payments received)
    final collections = await _creditPaymentRepository.getCollectionByModeInRange(startOfDay, endOfDay);
    final cashCollections = collections['cash'] ?? 0.0;
    final cardCollections = collections['card'] ?? 0.0;
    final upiCollections = collections['upi'] ?? 0.0;
    final totalCollections = collections['total'] ?? 0.0;

    // Profit Calculation (includes credit sales)
    double totalProfit = 0;
    double totalCost = 0;

    for (var sale in sales) {
      if (sale.isReturn == true) continue;

      final saleItems = await saleItemRepository.getItemsBySaleId(sale.saleId);
      for (var item in saleItems) {
        // Get variant to calculate cost
        final variant = await variantRepository.getVariantById(item.varianteId);
        if (variant != null) {
          totalCost += variant.costPrice! * item.qty;
        }
      }
    }

    totalProfit = totalSales - totalCost;

    // Customer Outstanding Summary
    final customersWithCredit = await customerStoreRestail.getCustomersWithCredit();
    final totalOutstanding = await saleStore.getTotalDueAmount();

    // Cash Drawer Summary
    final openingBalance = 0.0; // This should be stored/retrieved from settings
    final cashInDrawer = openingBalance + cashSales + cashCollections;

    return EODReport(
      date: reportDate,
      // Sales Summary
      cashSales: cashSales,
      cardSales: cardSales,
      upiSales: upiSales,
      creditSales: creditSales,
      splitSales: splitSales,
      totalSales: totalSales,
      cashCount: cashCount,
      cardCount: cardCount,
      upiCount: upiCount,
      creditCount: creditCount,
      splitCount: splitCount,
      totalTransactions: totalTransactions,
      // Collections Summary
      cashCollections: cashCollections,
      cardCollections: cardCollections,
      upiCollections: upiCollections,
      totalCollections: totalCollections,
      // Profit Summary
      totalRevenue: totalSales,
      totalCost: totalCost,
      totalProfit: totalProfit,
      profitMargin: totalSales > 0 ? (totalProfit / totalSales) * 100 : 0,
      // Cash Drawer
      openingBalance: openingBalance,
      cashInDrawer: cashInDrawer,
      // Outstanding Summary
      customersWithDue: customersWithCredit.length,
      totalOutstanding: totalOutstanding,
      customersWithCredit: customersWithCredit,
    );
  }
}

/// EOD Report Data Model
class EODReport {
  final DateTime date;

  // Sales Summary
  final double cashSales;
  final double cardSales;
  final double upiSales;
  final double creditSales;
  final double splitSales;
  final double totalSales;
  final int cashCount;
  final int cardCount;
  final int upiCount;
  final int creditCount;
  final int splitCount;
  final int totalTransactions;

  // Collections Summary
  final double cashCollections;
  final double cardCollections;
  final double upiCollections;
  final double totalCollections;

  // Profit Summary
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double profitMargin;

  // Cash Drawer
  final double openingBalance;
  final double cashInDrawer;

  // Outstanding Summary
  final int customersWithDue;
  final double totalOutstanding;
  final List<CustomerModel> customersWithCredit;

  EODReport({
    required this.date,
    required this.cashSales,
    required this.cardSales,
    required this.upiSales,
    required this.creditSales,
    required this.splitSales,
    required this.totalSales,
    required this.cashCount,
    required this.cardCount,
    required this.upiCount,
    required this.creditCount,
    required this.splitCount,
    required this.totalTransactions,
    required this.cashCollections,
    required this.cardCollections,
    required this.upiCollections,
    required this.totalCollections,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.profitMargin,
    required this.openingBalance,
    required this.cashInDrawer,
    required this.customersWithDue,
    required this.totalOutstanding,
    required this.customersWithCredit,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'cashSales': cashSales,
      'cardSales': cardSales,
      'upiSales': upiSales,
      'creditSales': creditSales,
      'splitSales': splitSales,
      'totalSales': totalSales,
      'cashCount': cashCount,
      'cardCount': cardCount,
      'upiCount': upiCount,
      'creditCount': creditCount,
      'splitCount': splitCount,
      'totalTransactions': totalTransactions,
      'cashCollections': cashCollections,
      'cardCollections': cardCollections,
      'upiCollections': upiCollections,
      'totalCollections': totalCollections,
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'totalProfit': totalProfit,
      'profitMargin': profitMargin,
      'openingBalance': openingBalance,
      'cashInDrawer': cashInDrawer,
      'customersWithDue': customersWithDue,
      'totalOutstanding': totalOutstanding,
    };
  }
}