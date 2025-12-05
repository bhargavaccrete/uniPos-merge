import 'package:hive/hive.dart';
import '../../models/retail/hive_model/purchase_order_item_model_212.dart';

class PurchaseOrderItemRepository {
  late Box<PurchaseOrderItemModel> _poItemBox;

  PurchaseOrderItemRepository() {
    _poItemBox = Hive.box<PurchaseOrderItemModel>('purchaseOrderItems');
  }

  // Get All PO Items
  Future<List<PurchaseOrderItemModel>> getAllPOItems() async {
    return _poItemBox.values.toList();
  }

  // Get PO Item by ID
  PurchaseOrderItemModel? getPOItemById(String poItemId) {
    return _poItemBox.get(poItemId);
  }

  // Add PO Item
  Future<void> addPOItem(PurchaseOrderItemModel item) async {
    await _poItemBox.put(item.poItemId, item);
  }

  // Add Multiple PO Items
  Future<void> addPOItems(List<PurchaseOrderItemModel> items) async {
    for (var item in items) {
      await _poItemBox.put(item.poItemId, item);
    }
  }

  // Update PO Item
  Future<void> updatePOItem(PurchaseOrderItemModel item) async {
    await _poItemBox.put(item.poItemId, item);
  }

  // Delete PO Item
  Future<void> deletePOItem(String poItemId) async {
    await _poItemBox.delete(poItemId);
  }

  // Get Items by PO ID
  Future<List<PurchaseOrderItemModel>> getItemsByPOId(String poId) async {
    final allItems = _poItemBox.values.toList();
    return allItems.where((item) => item.poId == poId).toList();
  }

  // Delete Items by PO ID
  Future<void> deleteItemsByPOId(String poId) async {
    final items = await getItemsByPOId(poId);
    for (var item in items) {
      await _poItemBox.delete(item.poItemId);
    }
  }

  // Get Total Ordered Quantity for a PO
  Future<int> getTotalOrderedQty(String poId) async {
    final items = await getItemsByPOId(poId);
    return items.fold<int>(0, (sum, item) => sum + item.orderedQty);
  }

  // Get Total Estimated Amount for a PO
  Future<double> getTotalEstimatedAmount(String poId) async {
    final items = await getItemsByPOId(poId);
    return items.fold<double>(0.0, (sum, item) => sum + (item.estimatedTotal ?? 0));
  }

  // Get Items by Variant ID (to see all orders for a specific product variant)
  Future<List<PurchaseOrderItemModel>> getItemsByVariantId(String variantId) async {
    final allItems = _poItemBox.values.toList();
    return allItems.where((item) => item.variantId == variantId).toList();
  }

  // Get Items by Product ID
  Future<List<PurchaseOrderItemModel>> getItemsByProductId(String productId) async {
    final allItems = _poItemBox.values.toList();
    return allItems.where((item) => item.productId == productId).toList();
  }
}