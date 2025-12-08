import 'package:hive/hive.dart';
import '../../models/retail/hive_model/hold_sale_model_209.dart';
import '../../models/retail/hive_model/hold_sale_item_model_210.dart';

class HoldSaleRepository {
  late Box<HoldSaleModel> _holdSaleBox;
  late Box<HoldSaleItemModel> _holdSaleItemBox;

  Future<void> init() async {
    // Use Hive.box() instead of openBox() since boxes are already opened in main.dart
    // If box is not open, try to open it
    if (Hive.isBoxOpen('holdSales')) {
      _holdSaleBox = Hive.box<HoldSaleModel>('holdSales');
    } else {
      _holdSaleBox = await Hive.openBox<HoldSaleModel>('holdSales');
    }

    if (Hive.isBoxOpen('holdSaleItems')) {
      _holdSaleItemBox = Hive.box<HoldSaleItemModel>('holdSaleItems');
    } else {
      _holdSaleItemBox = await Hive.openBox<HoldSaleItemModel>('holdSaleItems');
    }
  }

  // ==================== HoldSale CRUD ====================

  /// Add a new hold sale
  Future<void> addHoldSale(HoldSaleModel holdSale) async {
    await _holdSaleBox.put(holdSale.holdSaleId, holdSale);
  }

  /// Get hold sale by ID
  Future<HoldSaleModel?> getHoldSaleById(String holdSaleId) async {
    return _holdSaleBox.get(holdSaleId);
  }

  /// Get all hold sales
  Future<List<HoldSaleModel>> getAllHoldSales() async {
    return _holdSaleBox.values.toList();
  }

  /// Delete hold sale
  Future<void> deleteHoldSale(String holdSaleId) async {
    await _holdSaleBox.delete(holdSaleId);
    // Also delete all items associated with this hold sale
    await deleteHoldSaleItems(holdSaleId);
  }

  /// Update hold sale
  Future<void> updateHoldSale(HoldSaleModel holdSale) async {
    await _holdSaleBox.put(holdSale.holdSaleId, holdSale);
  }

  /// Get hold sale count
  int getHoldSaleCount() {
    return _holdSaleBox.length;
  }

  // ==================== HoldSaleItem CRUD ====================

  /// Add multiple hold sale items
  Future<void> addHoldSaleItems(List<HoldSaleItemModel> items) async {
    for (var item in items) {
      await _holdSaleItemBox.put(item.holdSaleItemId, item);
    }
  }

  /// Add single hold sale item
  Future<void> addHoldSaleItem(HoldSaleItemModel item) async {
    await _holdSaleItemBox.put(item.holdSaleItemId, item);
  }

  /// Get all items for a specific hold sale
  Future<List<HoldSaleItemModel>> getItemsByHoldSaleId(String holdSaleId) async {
    final allItems = _holdSaleItemBox.values.toList();
    return allItems.where((item) => item.holdSaleId == holdSaleId).toList();
  }

  /// Delete all items for a specific hold sale
  Future<void> deleteHoldSaleItems(String holdSaleId) async {
    final items = await getItemsByHoldSaleId(holdSaleId);
    for (var item in items) {
      await _holdSaleItemBox.delete(item.holdSaleItemId);
    }
  }

  /// Update hold sale item
  Future<void> updateHoldSaleItem(HoldSaleItemModel item) async {
    await _holdSaleItemBox.put(item.holdSaleItemId, item);
  }

  // ==================== Analytics ====================

  /// Get total items count across all hold sales
  Future<int> getTotalItemsCount() async {
    return _holdSaleItemBox.length;
  }

  /// Get total value of all hold sales
  Future<double> getTotalHoldSalesValue() async {
    final holdSales = await getAllHoldSales();
    return holdSales.fold<double>(0.0, (sum, sale) => sum + sale.subtotal);
  }

  /// Search hold sales by customer name or note
  Future<List<HoldSaleModel>> searchHoldSales(String query) async {
    if (query.isEmpty) return [];

    final allHoldSales = await getAllHoldSales();
    final lowerQuery = query.toLowerCase();

    return allHoldSales.where((sale) {
      final customerName = sale.customerName?.toLowerCase() ?? '';
      final note = sale.note?.toLowerCase() ?? '';
      return customerName.contains(lowerQuery) || note.contains(lowerQuery);
    }).toList();
  }

  /// Get oldest hold sale (for alerting stale holds)
  Future<HoldSaleModel?> getOldestHoldSale() async {
    final holdSales = await getAllHoldSales();
    if (holdSales.isEmpty) return null;

    holdSales.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return holdSales.first;
  }

  /// Clear all hold sales (useful for testing or end-of-day cleanup)
  Future<void> clearAllHoldSales() async {
    await _holdSaleBox.clear();
    await _holdSaleItemBox.clear();
  }
}