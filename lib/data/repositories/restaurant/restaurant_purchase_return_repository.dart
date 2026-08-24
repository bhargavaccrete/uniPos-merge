import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_purchase_return_item_model.dart';
import '../../models/restaurant/db/restaurant_purchase_return_model.dart';

/// Hive I/O for restaurant purchase returns and their lines. Mirrors
/// retail's `PurchaseReturnRepository` — owns both boxes since lines are
/// only ever fetched through their parent return.
class RestaurantPurchaseReturnRepository {
  Box<RestaurantPurchaseReturnModel> get _box =>
      Hive.box<RestaurantPurchaseReturnModel>(HiveBoxNames.restaurantPurchaseReturns);

  Box<RestaurantPurchaseReturnItemModel> get _itemBox => Hive
      .box<RestaurantPurchaseReturnItemModel>(HiveBoxNames.restaurantPurchaseReturnItems);

  Future<List<RestaurantPurchaseReturnModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  RestaurantPurchaseReturnModel? getById(String returnId) => _box.get(returnId);

  Future<void> save(RestaurantPurchaseReturnModel model) async {
    await _box.put(model.returnId, model);
  }

  Future<void> saveItems(List<RestaurantPurchaseReturnItemModel> items) async {
    for (final item in items) {
      await _itemBox.put(item.returnItemId, item);
    }
  }

  Future<List<RestaurantPurchaseReturnItemModel>> getItems(String returnId) async {
    return _itemBox.values.where((i) => i.returnId == returnId).toList();
  }

  Future<List<RestaurantPurchaseReturnModel>> getByGRN(String grnId) async {
    return _box.values.where((r) => r.grnId == grnId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<RestaurantPurchaseReturnModel>> getBySupplier(String supplierId) async {
    return _box.values.where((r) => r.supplierId == supplierId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// How much of a GRN line has already been sent back — the basis for
  /// partial returns. Cancelled returns don't count.
  Future<double> returnedQtyForGRNItem(String grnItemId) async {
    var total = 0.0;
    for (final item in _itemBox.values.where((i) => i.grnItemId == grnItemId)) {
      final parent = _box.get(item.returnId);
      if (parent == null ||
          parent.statusEnum == RestaurantPurchaseReturnStatus.cancelled) {
        continue;
      }
      total += item.returnedQty;
    }
    return total;
  }

  Future<void> delete(String returnId) async {
    final items = await getItems(returnId);
    for (final item in items) {
      await _itemBox.delete(item.returnItemId);
    }
    await _box.delete(returnId);
  }
}
