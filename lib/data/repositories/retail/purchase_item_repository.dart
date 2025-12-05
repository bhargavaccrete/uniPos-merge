import 'package:hive/hive.dart';
import '../../models/retail/hive_model/purchase_Item_model_206.dart';

class PurchaseItemRepository {
  late Box<PurchaseItemModel> _purchaseItemBox;

  PurchaseItemRepository() {
    _purchaseItemBox = Hive.box<PurchaseItemModel>('purchaseItems');
  }

  // Get All Purchase Items
  Future<List<PurchaseItemModel>> getAllPurchaseItems() async {
    return _purchaseItemBox.values.toList();
  }

  // Get Purchase Item by ID
  PurchaseItemModel? getPurchaseItemById(String purchaseItemId) {
    return _purchaseItemBox.get(purchaseItemId);
  }

  // Add Purchase Item
  Future<void> addPurchaseItem(PurchaseItemModel item) async {
    await _purchaseItemBox.put(item.purchaseItemId, item);
  }

  // Add Multiple Purchase Items
  Future<void> addPurchaseItems(List<PurchaseItemModel> items) async {
    for (var item in items) {
      await _purchaseItemBox.put(item.purchaseItemId, item);
    }
  }

  // Update Purchase Item
  Future<void> updatePurchaseItem(PurchaseItemModel item) async {
    await _purchaseItemBox.put(item.purchaseItemId, item);
  }

  // Delete Purchase Item
  Future<void> deletePurchaseItem(String purchaseItemId) async {
    await _purchaseItemBox.delete(purchaseItemId);
  }

  // Get Items by Purchase ID
  Future<List<PurchaseItemModel>> getItemsByPurchaseId(String purchaseId) async {
    final allItems = _purchaseItemBox.values.toList();
    return allItems.where((item) => item.purchaseId == purchaseId).toList();
  }

  // Delete Items by Purchase ID
  Future<void> deleteItemsByPurchaseId(String purchaseId) async {
    final items = await getItemsByPurchaseId(purchaseId);
    for (var item in items) {
      await _purchaseItemBox.delete(item.purchaseItemId);
    }
  }

  // Get Variant-wise Purchase History
  Future<List<PurchaseItemModel>> getVariantPurchaseHistory(String variantId) async {
    final allItems = _purchaseItemBox.values.toList();
    return allItems
        .where((item) => item.variantId == variantId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Product-wise Purchase History
  Future<List<PurchaseItemModel>> getProductPurchaseHistory(String productId) async {
    final allItems = _purchaseItemBox.values.toList();
    return allItems
        .where((item) => item.productId == productId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Get Total Quantity Purchased for a Variant
  Future<int> getTotalQuantityPurchased(String variantId) async {
    final items = await getVariantPurchaseHistory(variantId);
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  // Get Average Cost Price for a Variant
  Future<double> getAverageCostPrice(String variantId) async {
    final items = await getVariantPurchaseHistory(variantId);
    if (items.isEmpty) return 0.0;

    final totalCost = items.fold(0.0, (sum, item) => sum + item.total);
    final totalQuantity = items.fold(0, (sum, item) => sum + item.quantity);

    return totalQuantity > 0 ? totalCost / totalQuantity : 0.0;
  }

  // Get Last Purchase Price for a Variant
  Future<double> getLastPurchasePrice(String variantId) async {
    final items = await getVariantPurchaseHistory(variantId);
    return items.isNotEmpty ? items.first.costPrice : 0.0;
  }
}