import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import '../../models/restaurant/db/restaurant_supplier_claim_model.dart';

/// Hive I/O for restaurant supplier claims and their lines. Mirrors
/// retail's `SupplierClaimRepository`.
class RestaurantSupplierClaimRepository {
  Box<RestaurantSupplierClaimModel> get _box =>
      Hive.box<RestaurantSupplierClaimModel>(HiveBoxNames.restaurantSupplierClaims);

  Box<RestaurantSupplierClaimItemModel> get _itemBox => Hive
      .box<RestaurantSupplierClaimItemModel>(HiveBoxNames.restaurantSupplierClaimItems);

  Future<List<RestaurantSupplierClaimModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  RestaurantSupplierClaimModel? getById(String claimId) => _box.get(claimId);

  Future<void> save(RestaurantSupplierClaimModel model) async {
    await _box.put(model.claimId, model);
  }

  Future<void> saveItems(List<RestaurantSupplierClaimItemModel> items) async {
    for (final item in items) {
      await _itemBox.put(item.claimItemId, item);
    }
  }

  Future<List<RestaurantSupplierClaimItemModel>> getItems(String claimId) async {
    return _itemBox.values.where((i) => i.claimId == claimId).toList();
  }

  Future<List<RestaurantSupplierClaimModel>> getByGRN(String grnId) async {
    return _box.values.where((c) => c.grnId == grnId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<RestaurantSupplierClaimModel>> getBySupplier(String supplierId) async {
    return _box.values.where((c) => c.supplierId == supplierId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> delete(String claimId) async {
    final items = await getItems(claimId);
    for (final item in items) {
      await _itemBox.delete(item.claimItemId);
    }
    await _box.delete(claimId);
  }
}
