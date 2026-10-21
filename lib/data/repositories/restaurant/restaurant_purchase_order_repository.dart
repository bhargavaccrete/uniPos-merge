import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../../domain/services/common/document_number_service.dart';
import '../../models/restaurant/db/restaurant_purchase_order_model.dart';
import '../../models/restaurant/db/restaurant_purchase_order_item_model.dart';

class RestaurantPurchaseOrderRepository {
  final _numbers = DocumentNumberService();

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

  /// `PO-00001` — one continuous series per FINANCIAL year, via the shared
  /// [DocumentNumberService], exactly as retail's PurchaseOrderRepository does.
  ///
  /// This used to embed the date as `PO-YYYYMMDD-NNN`, which restarted the
  /// sequence at 001 every morning — roughly 300 separate series a year
  /// instead of one. The counter is stored, not derived by counting rows, so
  /// deleting a draft can never hand its number to the next order.
  Future<String> generatePONumber() {
    return _numbers.next(
      'PO',
      isTaken: (number) => _box.values.any((po) => po.poNumber == number),
    );
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
