import 'package:hive/hive.dart';
import '../../models/retail/hive_model/sale_item_model_204.dart';

/// Repository layer for SaleItem data access
/// Handles all Hive database operations for sale items
/// Links individual items to sales with product details, quantities, prices, discounts, and taxes
class SaleItemRepository {
  /// Get the Hive box (lazy loaded)
  Box<SaleItemModel> get _saleItemBox => Hive.box<SaleItemModel>('saleItems');

  // ==================== Basic CRUD Operations ====================

  /// Get all sale items from Hive
  Future<List<SaleItemModel>> getAllSaleItems() async {
    return _saleItemBox.values.toList();
  }

  /// Get a sale item by ID
  SaleItemModel? getSaleItemById(String saleItemId) {
    return _saleItemBox.get(saleItemId);
  }

  /// Add a single sale item
  Future<void> addSaleItem(SaleItemModel item) async {
    await _saleItemBox.put(item.saleItemId, item);

  }

  /// Add multiple sale items (for a sale transaction)
  Future<void> addSaleItems(List<SaleItemModel> items) async {
    for (var item in items) {
      await _saleItemBox.put(item.saleItemId, item);
    }
  }

  /// Update a sale item
  Future<void> updateSaleItem(SaleItemModel item) async {
    await _saleItemBox.put(item.saleItemId, item);
  }

  /// Delete a sale item by ID
  Future<void> deleteSaleItem(String saleItemId) async {
    await _saleItemBox.delete(saleItemId);
  }

  /// Clear all sale items
  Future<void> clearAll() async {
    await _saleItemBox.clear();
  }

  // ==================== Sale-Related Queries ====================

  /// Get all items for a specific sale
  Future<List<SaleItemModel>> getItemsBySaleId(String saleId) async {
    final allItems = _saleItemBox.values.toList();
    return allItems.where((item) => item.saleId == saleId).toList();
  }

  /// Delete all items for a specific sale
  Future<void> deleteItemsBySaleId(String saleId) async {
    final items = await getItemsBySaleId(saleId);
    for (var item in items) {
      await _saleItemBox.delete(item.saleItemId);
    }
  }

  /// Get total quantity of items in a sale
  Future<int> getTotalItemsInSale(String saleId) async {
    final items = await getItemsBySaleId(saleId);
    return items.fold<int>(0, (sum, item) => sum + item.qty);
  }

  /// Get subtotal (before discount/tax) for a sale
  Future<double> getSaleSubtotal(String saleId) async {
    final items = await getItemsBySaleId(saleId);
    return items.fold<double>(0.0, (sum, item) => sum + (item.price * item.qty));
  }

  /// Get total discount amount for a sale
  Future<double> getSaleTotalDiscount(String saleId) async {
    final items = await getItemsBySaleId(saleId);
    return items.fold<double>(0.0, (sum, item) => sum + (item.discountAmount ?? 0.0));
  }

  /// Get total tax amount for a sale
  Future<double> getSaleTotalTax(String saleId) async {
    final items = await getItemsBySaleId(saleId);
    return items.fold<double>(0.0, (sum, item) => sum + (item.taxAmount ?? 0.0));
  }

  /// Get final total for a sale (includes discount and tax)
  Future<double> getSaleFinalTotal(String saleId) async {
    final items = await getItemsBySaleId(saleId);
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  // ==================== Product/Variant Analytics ====================

  /// Get all sale items for a specific variant
  Future<List<SaleItemModel>> getItemsByVariantId(String variantId) async {
    final allItems = _saleItemBox.values.toList();
    return allItems
        .where((item) => item.varianteId == variantId)
        .toList()
      ..sort((a, b) => b.saleId.compareTo(a.saleId)); // Sort by most recent
  }

  /// Get all sale items for a specific product
  Future<List<SaleItemModel>> getItemsByProductId(String productId) async {
    final allItems = _saleItemBox.values.toList();
    return allItems
        .where((item) => item.productId == productId)
        .toList()
      ..sort((a, b) => b.saleId.compareTo(a.saleId));
  }

  /// Get total quantity sold for a variant
  Future<int> getTotalQuantitySold(String variantId) async {
    final items = await getItemsByVariantId(variantId);
    return items.fold<int>(0, (sum, item) => sum + item.qty);
  }

  /// Get total revenue for a variant
  Future<double> getTotalRevenueByVariant(String variantId) async {
    final items = await getItemsByVariantId(variantId);
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  /// Get total revenue for a product (all variants)
  Future<double> getTotalRevenueByProduct(String productId) async {
    final items = await getItemsByProductId(productId);
    return items.fold<double>(0.0, (sum, item) => sum + item.total);
  }

  /// Get average selling price for a variant
  Future<double> getAverageSellingPrice(String variantId) async {
    final items = await getItemsByVariantId(variantId);
    if (items.isEmpty) return 0.0;

    final totalRevenue = items.fold(0.0, (sum, item) => sum + (item.price * item.qty));
    final totalQuantity = items.fold(0, (sum, item) => sum + item.qty);

    return totalQuantity > 0 ? totalRevenue / totalQuantity : 0.0;
  }

  /// Get last selling price for a variant
  Future<double> getLastSellingPrice(String variantId) async {
    final items = await getItemsByVariantId(variantId);
    return items.isNotEmpty ? items.first.price : 0.0;
  }

  // ==================== Sales Performance & Reporting ====================

  /// Get top selling products by quantity
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    final allItems = _saleItemBox.values.toList();

    // Group by productId and calculate totals
    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in allItems) {
      if (!productStats.containsKey(item.productId)) {
        productStats[item.productId] = {
          'productId': item.productId,
          'productName': item.productName,
          'totalQuantity': 0,
          'totalRevenue': 0.0,
        };
      }

      productStats[item.productId]!['totalQuantity'] += item.qty;
      productStats[item.productId]!['totalRevenue'] += item.total;
    }

    // Convert to list and sort by quantity
    final statsList = productStats.values.toList()
      ..sort((a, b) => (b['totalQuantity'] as int).compareTo(a['totalQuantity'] as int));

    return statsList.take(limit).toList();
  }

  /// Get top selling variants by quantity
  Future<List<Map<String, dynamic>>> getTopSellingVariants({int limit = 10}) async {
    final allItems = _saleItemBox.values.toList();

    // Group by variantId and calculate totals
    final Map<String, Map<String, dynamic>> variantStats = {};

    for (var item in allItems) {
      if (!variantStats.containsKey(item.varianteId)) {
        variantStats[item.varianteId] = {
          'variantId': item.varianteId,
          'productId': item.productId,
          'productName': item.productName,
          'size': item.size,
          'color': item.color,
          'totalQuantity': 0,
          'totalRevenue': 0.0,
        };
      }

      variantStats[item.varianteId]!['totalQuantity'] += item.qty;
      variantStats[item.varianteId]!['totalRevenue'] += item.total;
    }

    // Convert to list and sort by quantity
    final statsList = variantStats.values.toList()
      ..sort((a, b) => (b['totalQuantity'] as int).compareTo(a['totalQuantity'] as int));

    return statsList.take(limit).toList();
  }

  /// Get top revenue generating products
  Future<List<Map<String, dynamic>>> getTopRevenueProducts({int limit = 10}) async {
    final allItems = _saleItemBox.values.toList();

    // Group by productId and calculate revenue
    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in allItems) {
      if (!productStats.containsKey(item.productId)) {
        productStats[item.productId] = {
          'productId': item.productId,
          'productName': item.productName,
          'totalQuantity': 0,
          'totalRevenue': 0.0,
        };
      }

      productStats[item.productId]!['totalQuantity'] += item.qty;
      productStats[item.productId]!['totalRevenue'] += item.total;
    }

    // Convert to list and sort by revenue
    final statsList = productStats.values.toList()
      ..sort((a, b) => (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    return statsList.take(limit).toList();
  }

  // ==================== Barcode Search ====================

  /// Get all sale items by barcode
  Future<List<SaleItemModel>> getItemsByBarcode(String barcode) async {
    final allItems = _saleItemBox.values.toList();
    return allItems.where((item) => item.barcode == barcode).toList();
  }

  /// Check if a barcode has been sold
  Future<bool> isBarcodeEverSold(String barcode) async {
    final items = await getItemsByBarcode(barcode);
    return items.isNotEmpty;
  }

  // ==================== Statistics & Aggregations ====================

  /// Get overall sales statistics
  Future<Map<String, dynamic>> getSalesItemStats() async {
    final allItems = _saleItemBox.values.toList();

    final totalItemsSold = allItems.fold<int>(0, (sum, item) => sum + item.qty);
    final totalRevenue = allItems.fold<double>(0.0, (sum, item) => sum + item.total);
    final totalDiscount = allItems.fold<double>(0.0, (sum, item) => sum + (item.discountAmount ?? 0.0));
    final totalTax = allItems.fold<double>(0.0, (sum, item) => sum + (item.taxAmount ?? 0.0));

    // Count unique products and variants
    final uniqueProducts = <String>{};
    final uniqueVariants = <String>{};

    for (var item in allItems) {
      uniqueProducts.add(item.productId);
      uniqueVariants.add(item.varianteId);
    }

    return {
      'totalTransactions': allItems.length,
      'totalItemsSold': totalItemsSold,
      'totalRevenue': totalRevenue,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
      'uniqueProductsSold': uniqueProducts.length,
      'uniqueVariantsSold': uniqueVariants.length,
      'averageItemPrice': totalItemsSold > 0 ? totalRevenue / totalItemsSold : 0.0,
    };
  }

  /// Get total item count
  int getSaleItemCount() {
    return _saleItemBox.length;
  }
}