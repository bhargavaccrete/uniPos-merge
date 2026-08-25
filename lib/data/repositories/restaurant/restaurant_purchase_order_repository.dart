import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_purchase_order_model.dart';
import '../../models/restaurant/db/restaurant_purchase_order_item_model.dart';

class RestaurantPurchaseOrderRepository {
  Box<RestaurantPurchaseOrderModel> get _box =>
      Hive.box<RestaurantPurchaseOrderModel>(HiveBoxNames.restaurantPurchaseOrders);

  List<RestaurantPurchaseOrderModel> getAllPurchaseOrders() => _box.values.toList();

  RestaurantPurchaseOrderModel? getPurchaseOrderById(String id) => _box.get(id);

  /// Newest first — drives the supplier detail screen's Documents tab and the
  /// delete-reference guard.
  List<RestaurantPurchaseOrderModel> getPurchaseOrdersBySupplier(String supplierId) =>
      _box.values.where((po) => po.supplierId == supplierId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> savePurchaseOrder(RestaurantPurchaseOrderModel po) async {
    await _box.put(po.poId, po);
  }

  Future<void> deletePurchaseOrder(String id) async {
    await _box.delete(id);
  }

  /// `PO-YYYYMMDD-XXX`, matching retail's numbering convention.
  String generatePONumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final todayCount = _box.values
        .where((po) => po.poNumber.startsWith('PO-$datePart'))
        .length;
    final seq = (todayCount + 1).toString().padLeft(3, '0');
    return 'PO-$datePart-$seq';
  }
}

class RestaurantPurchaseOrderItemRepository {
  Box<RestaurantPurchaseOrderItemModel> get _box =>
      Hive.box<RestaurantPurchaseOrderItemModel>(HiveBoxNames.restaurantPurchaseOrderItems);

  List<RestaurantPurchaseOrderItemModel> getItemsByPOId(String poId) =>
      _box.values.where((i) => i.poId == poId).toList();

  Future<void> saveItem(RestaurantPurchaseOrderItemModel item) async {
    await _box.put(item.poItemId, item);
  }

  Future<void> deleteItemsByPOId(String poId) async {
    final keys = _box.values.where((i) => i.poId == poId).map((i) => i.poItemId).toList();
    for (final key in keys) {
      await _box.delete(key);
    }
  }
}
