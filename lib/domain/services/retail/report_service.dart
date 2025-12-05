



import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_model_207.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';

import '../../../data/models/retail/hive_model/sale_item_model_204.dart';

/// Service for generating various business reports
class ReportService {
  // ==================== Daily Sales Report ====================

  /// Get daily sales report for a specific date
  Future<Map<String, dynamic>> getDailySalesReport(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final allSales = await saleStore.getAllSales();
    final dailySales = allSales.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return saleDate.isAfter(startOfDay) && saleDate.isBefore(endOfDay) && !(sale.isReturn ?? false);
    }).toList();

    final totalSales = dailySales.length;
    final totalRevenue = dailySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalItems = dailySales.fold<int>(0, (sum, sale) => sum + sale.totalItems);
    final totalDiscount = dailySales.fold<double>(0.0, (sum, sale) => sum + sale.discountAmount);
    final totalTax = dailySales.fold<double>(0.0, (sum, sale) => sum + sale.taxAmount);

    // Get returns for the day
    final dailyReturns = allSales.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return saleDate.isAfter(startOfDay) && saleDate.isBefore(endOfDay) && (sale.isReturn ?? false);
    }).toList();

    final totalReturns = dailyReturns.length;
    final totalReturnAmount = dailyReturns.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount.abs());

    return {
      'date': date,
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'totalItems': totalItems,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'totalReturns': totalReturns,
      'totalReturnAmount': totalReturnAmount,
      'netRevenue': totalRevenue - totalReturnAmount,
      'averageSaleValue': totalSales > 0 ? totalRevenue / totalSales : 0.0,
      'sales': dailySales,
    };
  }

  // ==================== Monthly Sales Report ====================

  /// Get monthly sales report
  Future<Map<String, dynamic>> getMonthlySalesReport(int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final allSales = await saleStore.getAllSales();
    final monthlySales = allSales.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return saleDate.isAfter(startOfMonth) && saleDate.isBefore(endOfMonth) && !(sale.isReturn ?? false);
    }).toList();

    final totalSales = monthlySales.length;
    final totalRevenue = monthlySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalItems = monthlySales.fold<int>(0, (sum, sale) => sum + sale.totalItems);
    final totalDiscount = monthlySales.fold<double>(0.0, (sum, sale) => sum + sale.discountAmount);
    final totalTax = monthlySales.fold<double>(0.0, (sum, sale) => sum + sale.taxAmount);

    // Get returns for the month
    final monthlyReturns = allSales.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return saleDate.isAfter(startOfMonth) && saleDate.isBefore(endOfMonth) && (sale.isReturn ?? false);
    }).toList();

    final totalReturns = monthlyReturns.length;
    final totalReturnAmount = monthlyReturns.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount.abs());

    // Group by day for trend analysis
    final dailyBreakdown = <int, double>{};
    for (var sale in monthlySales) {
      final saleDate = DateTime.parse(sale.date);
      final day = saleDate.day;
      dailyBreakdown[day] = (dailyBreakdown[day] ?? 0.0) + sale.totalAmount;
    }

    return {
      'year': year,
      'month': month,
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'totalItems': totalItems,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'totalReturns': totalReturns,
      'totalReturnAmount': totalReturnAmount,
      'netRevenue': totalRevenue - totalReturnAmount,
      'averageSaleValue': totalSales > 0 ? totalRevenue / totalSales : 0.0,
      'dailyBreakdown': dailyBreakdown,
      'sales': monthlySales,
    };
  }

  // ==================== Product-wise Sales Report ====================

  /// Get sales report grouped by products
  Future<List<Map<String, dynamic>>> getProductWiseSalesReport({DateTime? startDate, DateTime? endDate}) async {
    final allItems = await saleItemRepository.getAllSaleItems();

    // Filter by date if provided
    List<SaleItemModel> filteredItems = allItems;
    if (startDate != null || endDate != null) {
      final allSales = await saleStore.getAllSales();
      final validSaleIds = <String>{};

      for (var sale in allSales) {
        final saleDate = DateTime.parse(sale.date);
        if ((startDate == null || saleDate.isAfter(startDate)) &&
            (endDate == null || saleDate.isBefore(endDate)) &&
            !(sale.isReturn ?? false)) {
          validSaleIds.add(sale.saleId);
        }
      }

      filteredItems = allItems.where((item) => validSaleIds.contains(item.saleId)).toList();
    }

    // Group by productId
    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in filteredItems) {
      if (!productStats.containsKey(item.productId)) {
        productStats[item.productId] = {
          'productId': item.productId,
          'productName': item.productName,
          'totalQuantity': 0,
          'totalRevenue': 0.0,
          'totalDiscount': 0.0,
          'totalTax': 0.0,
        };
      }

      productStats[item.productId]!['totalQuantity'] += item.qty;
      productStats[item.productId]!['totalRevenue'] += item.total;
      productStats[item.productId]!['totalDiscount'] += (item.discountAmount ?? 0.0);
      productStats[item.productId]!['totalTax'] += (item.taxAmount ?? 0.0);
    }

    // Convert to list and sort by revenue
    final statsList = productStats.values.toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList;
  }

  // ==================== Variant-wise Sales Report ====================

  /// Get sales report grouped by variants
  Future<List<Map<String, dynamic>>> getVariantWiseSalesReport({DateTime? startDate, DateTime? endDate}) async {
    final allItems = await saleItemRepository.getAllSaleItems();

    // Filter by date if provided
    List<SaleItemModel> filteredItems = allItems;
    if (startDate != null || endDate != null) {
      final allSales = await saleStore.getAllSales();
      final validSaleIds = <String>{};

      for (var sale in allSales) {
        final saleDate = DateTime.parse(sale.date);
        if ((startDate == null || saleDate.isAfter(startDate)) &&
            (endDate == null || saleDate.isBefore(endDate)) &&
            !(sale.isReturn ?? false)) {
          validSaleIds.add(sale.saleId);
        }
      }

      filteredItems = allItems.where((item) => validSaleIds.contains(item.saleId)).toList();
    }

    // Group by variantId
    final Map<String, Map<String, dynamic>> variantStats = {};

    for (var item in filteredItems) {
      if (!variantStats.containsKey(item.varianteId)) {
        variantStats[item.varianteId] = {
          'variantId': item.varianteId,
          'productId': item.productId,
          'productName': item.productName,
          'size': item.size,
          'color': item.color,
          'totalQuantity': 0,
          'totalRevenue': 0.0,
          'totalDiscount': 0.0,
          'totalTax': 0.0,
        };
      }

      variantStats[item.varianteId]!['totalQuantity'] += item.qty;
      variantStats[item.varianteId]!['totalRevenue'] += item.total;
      variantStats[item.varianteId]!['totalDiscount'] += (item.discountAmount ?? 0.0);
      variantStats[item.varianteId]!['totalTax'] += (item.taxAmount ?? 0.0);
    }

    // Convert to list and sort by revenue
    final statsList = variantStats.values.toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList;
  }

  // ==================== Category-wise Sales Report ====================

  /// Get sales report grouped by categories
  Future<List<Map<String, dynamic>>> getCategoryWiseSalesReport({DateTime? startDate, DateTime? endDate}) async {
    final allItems = await saleItemRepository.getAllSaleItems();
    final allProducts = productStore.products;

    // Filter by date if provided
    List<SaleItemModel> filteredItems = allItems;
    if (startDate != null || endDate != null) {
      final allSales = await saleStore.getAllSales();
      final validSaleIds = <String>{};

      for (var sale in allSales) {
        final saleDate = DateTime.parse(sale.date);
        if ((startDate == null || saleDate.isAfter(startDate)) &&
            (endDate == null || saleDate.isBefore(endDate)) &&
            !(sale.isReturn ?? false)) {
          validSaleIds.add(sale.saleId);
        }
      }

      filteredItems = allItems.where((item) => validSaleIds.contains(item.saleId)).toList();
    }

    // Group by category
    final Map<String, Map<String, dynamic>> categoryStats = {};

    for (var item in filteredItems) {
      // Find product to get category
      final product = allProducts.where((p) => p.productId == item.productId).firstOrNull;

      final category = product?.category ?? 'Uncategorized';

      if (!categoryStats.containsKey(category)) {
        categoryStats[category] = {
          'category': category,
          'totalQuantity': 0,
          'totalRevenue': 0.0,
          'totalDiscount': 0.0,
          'totalTax': 0.0,
          'productCount': <String>{},
        };
      }

      categoryStats[category]!['totalQuantity'] += item.qty;
      categoryStats[category]!['totalRevenue'] += item.total;
      categoryStats[category]!['totalDiscount'] += (item.discountAmount ?? 0.0);
      categoryStats[category]!['totalTax'] += (item.taxAmount ?? 0.0);
      (categoryStats[category]!['productCount'] as Set<String>).add(item.productId);
    }

    // Convert to list and calculate product count
    final statsList = categoryStats.values.map((stat) {
      return {
        'category': stat['category'],
        'totalQuantity': stat['totalQuantity'],
        'totalRevenue': stat['totalRevenue'],
        'totalDiscount': stat['totalDiscount'],
        'totalTax': stat['totalTax'],
        'productCount': (stat['productCount'] as Set<String>).length,
      };
    }).toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList;
  }

  // ==================== Supplier-wise Purchase Report ====================

  /// Get purchase report grouped by suppliers
  Future<List<Map<String, dynamic>>> getSupplierWisePurchaseReport({DateTime? startDate, DateTime? endDate}) async {
    final allPurchases = purchaseStore.purchases;
    final allSuppliers = supplierStore.suppliers;

    // Filter by date if provided
    List<PurchaseModel> filteredPurchases = allPurchases;
    if (startDate != null || endDate != null) {
      filteredPurchases = allPurchases.where((purchase) {
        final purchaseDate = DateTime.parse(purchase.purchaseDate);
        return (startDate == null || purchaseDate.isAfter(startDate)) &&
            (endDate == null || purchaseDate.isBefore(endDate));
      }).toList();
    }

    // Group by supplierId
    final Map<String, Map<String, dynamic>> supplierStats = {};

    for (var purchase in filteredPurchases) {
      final supplier = allSuppliers.where((s) => s.supplierId == purchase.supplierId).firstOrNull;

      final supplierName = supplier?.name ?? 'Unknown Supplier';
      final supplierId = purchase.supplierId;

      if (!supplierStats.containsKey(supplierId)) {
        supplierStats[supplierId] = {
          'supplierId': supplierId,
          'supplierName': supplierName,
          'totalPurchases': 0,
          'totalAmount': 0.0,
          'totalItems': 0,
        };
      }

      supplierStats[supplierId]!['totalPurchases'] += 1;
      supplierStats[supplierId]!['totalAmount'] += purchase.totalAmount;
      supplierStats[supplierId]!['totalItems'] += purchase.totalItems;
    }

    // Convert to list and sort by total amount
    final statsList = supplierStats.values.toList()
      ..sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));

    return statsList;
  }

  // ==================== Low Stock Report ====================

  /// Get low stock report
  Future<List<Map<String, dynamic>>> getLowStockReport({int threshold = 10}) async {
    final allProducts = productStore.products;
    final lowStockItems = <Map<String, dynamic>>[];

    for (var product in allProducts) {
      final variants = await productStore.getVariantsForProduct(product.productId);
      for (var variant in variants) {
        if (variant.stockQty <= threshold) {
          lowStockItems.add({
            'productId': product.productId,
            'productName': product.productName,
            'variantId': variant.varianteId,
            'size': variant.size,
            'color': variant.color,
            'weight': variant.weight,
            'currentStock': variant.stockQty,
            'costPrice': variant.costPrice,
            'mrp': variant.mrp,
            'barcode': variant.barcode,
          });
        }
      }
    }

    // Sort by stock quantity (lowest first)
    lowStockItems.sort((a, b) => (a['currentStock'] as int).compareTo(b['currentStock'] as int));

    return lowStockItems;
  }

  // ==================== Top Selling Products Report ====================

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProductsReport({int limit = 20, DateTime? startDate, DateTime? endDate}) async {
    final productWiseReport = await getProductWiseSalesReport(startDate: startDate, endDate: endDate);
    return productWiseReport.take(limit).toList();
  }

  // ==================== Profit Report ====================

  /// Get profit report (Revenue - Cost)
  Future<Map<String, dynamic>> getProfitReport({DateTime? startDate, DateTime? endDate}) async {
    final allItems = await saleItemRepository.getAllSaleItems();

    // Filter by date if provided
    List<SaleItemModel> filteredItems = allItems;
    if (startDate != null || endDate != null) {
      final allSales = await saleStore.getAllSales();
      final validSaleIds = <String>{};

      for (var sale in allSales) {
        final saleDate = DateTime.parse(sale.date);
        if ((startDate == null || saleDate.isAfter(startDate)) &&
            (endDate == null || saleDate.isBefore(endDate)) &&
            !(sale.isReturn ?? false)) {
          validSaleIds.add(sale.saleId);
        }
      }

      filteredItems = allItems.where((item) => validSaleIds.contains(item.saleId)).toList();
    }

    double totalRevenue = 0.0;
    double totalCost = 0.0;

    for (var item in filteredItems) {
      totalRevenue += item.total;

      // Get variant to find cost price
      final variant = await productStore.getVariantById(item.varianteId);
      if (variant != null && variant.costPrice != null) {
        totalCost += (variant.costPrice! * item.qty);
      }
    }

    final profit = totalRevenue - totalCost;
    final profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0.0;

    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': profit,
      'profitMargin': profitMargin,
      'itemCount': filteredItems.length,
    };
  }

  // ==================== Profit Per Item Report ====================

  /// Get profit breakdown per item/variant
  Future<List<Map<String, dynamic>>> getProfitPerItemReport({DateTime? startDate, DateTime? endDate}) async {
    final allItems = await saleItemRepository.getAllSaleItems();

    // Filter by date if provided
    List<SaleItemModel> filteredItems = allItems;
    if (startDate != null || endDate != null) {
      final allSales = await saleStore.getAllSales();
      final validSaleIds = <String>{};

      for (var sale in allSales) {
        final saleDate = DateTime.parse(sale.date);
        if ((startDate == null || saleDate.isAfter(startDate)) &&
            (endDate == null || saleDate.isBefore(endDate)) &&
            !(sale.isReturn ?? false)) {
          validSaleIds.add(sale.saleId);
        }
      }

      filteredItems = allItems.where((item) => validSaleIds.contains(item.saleId)).toList();
    }

    // Group by variant and calculate profit
    final Map<String, Map<String, dynamic>> itemProfits = {};

    for (var item in filteredItems) {
      final variant = await productStore.getVariantById(item.varianteId);

      if (!itemProfits.containsKey(item.varianteId)) {
        itemProfits[item.varianteId] = {
          'variantId': item.varianteId,
          'productId': item.productId,
          'productName': item.productName,
          'size': item.size,
          'color': item.color,
          'barcode': item.barcode,
          'totalQuantitySold': 0,
          'totalRevenue': 0.0,
          'totalCost': 0.0,
          'totalProfit': 0.0,
          'profitMargin': 0.0,
          'avgSellingPrice': 0.0,
          'costPrice': variant?.costPrice ?? 0.0,
        };
      }

      final revenue = item.total;
      final cost = (variant?.costPrice ?? 0.0) * item.qty;
      final profit = revenue - cost;

      itemProfits[item.varianteId]!['totalQuantitySold'] += item.qty;
      itemProfits[item.varianteId]!['totalRevenue'] += revenue;
      itemProfits[item.varianteId]!['totalCost'] += cost;
      itemProfits[item.varianteId]!['totalProfit'] += profit;
    }

    // Calculate profit margin and average selling price
    final statsList = itemProfits.values.map((stat) {
      final revenue = stat['totalRevenue'] as double;
      final profit = stat['totalProfit'] as double;
      final qty = stat['totalQuantitySold'] as int;

      return {
        ...stat,
        'profitMargin': revenue > 0 ? (profit / revenue) * 100 : 0.0,
        'avgSellingPrice': qty > 0 ? revenue / qty : 0.0,
      };
    }).toList()
      ..sort((a, b) => (b['totalProfit'] as double).compareTo(a['totalProfit'] as double));

    return statsList;
  }

  // ==================== Profit Per Sale Report ====================

  /// Get profit breakdown per individual sale transaction
  Future<List<Map<String, dynamic>>> getProfitPerSaleReport({DateTime? startDate, DateTime? endDate}) async {
    final allSales = await saleStore.getAllSales();

    // Filter by date and exclude returns
    List<SaleModel> filteredSales = allSales.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return ((startDate == null || saleDate.isAfter(startDate)) &&
          (endDate == null || saleDate.isBefore(endDate)) &&
          !(sale.isReturn ?? false));
    }).toList();

    final saleProfits = <Map<String, dynamic>>[];

    for (var sale in filteredSales) {
      final saleItems = await saleItemRepository.getItemsBySaleId(sale.saleId);

      double totalCost = 0.0;
      double totalRevenue = sale.totalAmount;

      for (var item in saleItems) {
        final variant = await productStore.getVariantById(item.varianteId);
        if (variant != null && variant.costPrice != null) {
          totalCost += (variant.costPrice! * item.qty);
        }
      }

      final profit = totalRevenue - totalCost;
      final profitMargin = totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0.0;

      saleProfits.add({
        'saleId': sale.saleId,
        'date': sale.date,
        'customerId': sale.customerId,
        'totalItems': sale.totalItems,
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'profit': profit,
        'profitMargin': profitMargin,
        'paymentType': sale.paymentType,
        'discountAmount': sale.discountAmount,
        'taxAmount': sale.taxAmount,
      });
    }

    // Sort by profit (highest first)
    saleProfits.sort((a, b) => (b['profit'] as double).compareTo(a['profit'] as double));

    return saleProfits;
  }

  // ==================== Profit Per Day Report ====================

  /// Get daily profit breakdown over a date range
  Future<List<Map<String, dynamic>>> getProfitPerDayReport({DateTime? startDate, DateTime? endDate}) async {
    final allSales = await saleStore.getAllSales();

    // Filter by date and exclude returns
    List<SaleModel> filteredSales = allSales.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return ((startDate == null || saleDate.isAfter(startDate)) &&
          (endDate == null || saleDate.isBefore(endDate)) &&
          !(sale.isReturn ?? false));
    }).toList();

    // Group by day
    final Map<String, Map<String, dynamic>> dailyProfits = {};

    for (var sale in filteredSales) {
      final saleDate = DateTime.parse(sale.date);
      final dayKey = DateTime(saleDate.year, saleDate.month, saleDate.day).toIso8601String();

      if (!dailyProfits.containsKey(dayKey)) {
        dailyProfits[dayKey] = {
          'date': dayKey,
          'totalSales': 0,
          'totalRevenue': 0.0,
          'totalCost': 0.0,
          'totalProfit': 0.0,
          'profitMargin': 0.0,
          'totalItems': 0,
        };
      }

      final saleItems = await saleItemRepository.getItemsBySaleId(sale.saleId);

      double saleCost = 0.0;
      for (var item in saleItems) {
        final variant = await productStore.getVariantById(item.varianteId);
        if (variant != null && variant.costPrice != null) {
          saleCost += (variant.costPrice! * item.qty);
        }
      }

      dailyProfits[dayKey]!['totalSales'] += 1;
      dailyProfits[dayKey]!['totalRevenue'] += sale.totalAmount;
      dailyProfits[dayKey]!['totalCost'] += saleCost;
      dailyProfits[dayKey]!['totalProfit'] += (sale.totalAmount - saleCost);
      dailyProfits[dayKey]!['totalItems'] += sale.totalItems;
    }

    // Calculate profit margin for each day
    final statsList = dailyProfits.values.map((stat) {
      final revenue = stat['totalRevenue'] as double;
      final profit = stat['totalProfit'] as double;

      return {
        ...stat,
        'profitMargin': revenue > 0 ? (profit / revenue) * 100 : 0.0,
      };
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return statsList;
  }
}