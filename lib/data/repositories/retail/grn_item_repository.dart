import 'package:hive/hive.dart';
import '../../models/retail/hive_model/grn_model_213.dart';
import '../../models/retail/hive_model/grn_item_model_214.dart';

class GRNItemRepository {
  late Box<GRNItemModel> _grnItemBox;

  GRNItemRepository() {
    _grnItemBox = Hive.box<GRNItemModel>('grnItems');
  }

  // Get All GRN Items
  Future<List<GRNItemModel>> getAllGRNItems() async {
    return _grnItemBox.values.toList();
  }

  // Get GRN Item by ID
  GRNItemModel? getGRNItemById(String grnItemId) {
    return _grnItemBox.get(grnItemId);
  }

  // Add GRN Item
  Future<void> addGRNItem(GRNItemModel item) async {
    await _grnItemBox.put(item.grnItemId, item);
  }

  // Add Multiple GRN Items
  Future<void> addGRNItems(List<GRNItemModel> items) async {
    for (var item in items) {
      await _grnItemBox.put(item.grnItemId, item);
    }
  }

  // Update GRN Item
  Future<void> updateGRNItem(GRNItemModel item) async {
    await _grnItemBox.put(item.grnItemId, item);
  }

  // Delete GRN Item
  Future<void> deleteGRNItem(String grnItemId) async {
    await _grnItemBox.delete(grnItemId);
  }

  // Get Items by GRN ID
  Future<List<GRNItemModel>> getItemsByGRNId(String grnId) async {
    final allItems = _grnItemBox.values.toList();
    return allItems.where((item) => item.grnId == grnId).toList();
  }

  // Delete Items by GRN ID
  Future<void> deleteItemsByGRNId(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    for (var item in items) {
      await _grnItemBox.delete(item.grnItemId);
    }
  }

  // Get Items by PO Item ID (to see all receivings for a specific PO item)
  Future<List<GRNItemModel>> getItemsByPOItemId(String poItemId) async {
    final allItems = _grnItemBox.values.toList();
    return allItems.where((item) => item.poItemId == poItemId).toList();
  }

  // Get Items by Variant ID
  Future<List<GRNItemModel>> getItemsByVariantId(String variantId) async {
    final allItems = _grnItemBox.values.toList();
    return allItems.where((item) => item.variantId == variantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Total Received Quantity for a GRN
  Future<int> getTotalReceivedQty(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    return items.fold<int>(0, (sum, item) => sum + item.receivedQty);
  }

  // Get Total Ordered Quantity for a GRN
  Future<int> getTotalOrderedQty(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    return items.fold<int>(0, (sum, item) => sum + item.orderedQty);
  }

  // Get Total Damaged Quantity for a GRN
  Future<int> getTotalDamagedQty(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    return items.fold<int>(0, (sum, item) => sum + (item.damagedQty ?? 0));
  }

  // Get Total Amount for a GRN
  Future<double> getTotalAmount(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    return items.fold<double>(0.0, (sum, item) => sum + (item.totalAmount ?? 0));
  }

  // Get Total Received Quantity for a Variant (across all GRNs)
  Future<int> getTotalReceivedQtyForVariant(String variantId) async {
    final items = await getItemsByVariantId(variantId);
    return items.fold<int>(0, (sum, item) => sum + item.receivedQty);
  }

  // Get Total Received Quantity for a PO Item (across all CONFIRMED GRNs only)
  Future<int> getTotalReceivedQtyForPOItem(String poItemId) async {
    final items = await getItemsByPOItemId(poItemId);
    // Only count items from confirmed GRNs
    final grnBox = Hive.box<GRNModel>('grns');
    int total = 0;
    for (var item in items) {
      final grn = grnBox.get(item.grnId);
      if (grn != null && grn.status == 'confirmed') {
        total += item.receivedQty;
      }
    }
    return total;
  }

  // Get Shortage Items (received less than ordered)
  Future<List<GRNItemModel>> getShortageItemsByGRNId(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    return items.where((item) => item.shortageQty > 0).toList();
  }

  // Get Damaged Items
  Future<List<GRNItemModel>> getDamagedItemsByGRNId(String grnId) async {
    final items = await getItemsByGRNId(grnId);
    return items.where((item) => (item.damagedQty ?? 0) > 0).toList();
  }
}