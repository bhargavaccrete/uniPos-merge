import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/restaurant_grn_model.dart';
import '../../models/restaurant/db/restaurant_grn_item_model.dart';

class RestaurantGRNRepository {
  Box<RestaurantGRNModel> get _box => Hive.box<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);

  List<RestaurantGRNModel> getAllGRNs() => _box.values.toList();

  RestaurantGRNModel? getGRNById(String id) => _box.get(id);

  List<RestaurantGRNModel> getGRNsByPOId(String poId) =>
      _box.values.where((g) => g.poId == poId).toList();

  Future<void> saveGRN(RestaurantGRNModel grn) async {
    await _box.put(grn.grnId, grn);
  }

  /// Total accepted qty across all CONFIRMED GRNs for a PO — used to decide
  /// whether the PO is now partially or fully received.
  double getTotalReceivedQtyForPO(String poId) {
    return getGRNsByPOId(poId)
        .where((g) => g.isConfirmed)
        .fold(0.0, (sum, g) => sum + g.totalReceivedQty);
  }
}

class RestaurantGRNItemRepository {
  Box<RestaurantGRNItemModel> get _box =>
      Hive.box<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems);

  List<RestaurantGRNItemModel> getItemsByGRNId(String grnId) =>
      _box.values.where((i) => i.grnId == grnId).toList();

  Future<void> saveItem(RestaurantGRNItemModel item) async {
    await _box.put(item.grnItemId, item);
  }

  double getTotalReceivedQtyForPOItem(String poItemId) {
    return _box.values
        .where((i) => i.poItemId == poItemId)
        .fold(0.0, (sum, i) => sum + i.receivedQty);
  }
}
