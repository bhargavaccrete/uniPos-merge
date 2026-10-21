import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../../domain/services/common/document_number_service.dart';
import '../../models/restaurant/db/restaurant_grn_model.dart';
import '../../models/restaurant/db/restaurant_grn_item_model.dart';

class RestaurantGRNRepository {
  final _numbers = DocumentNumberService();

  Box<RestaurantGRNModel> get _box => Hive.box<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);

  List<RestaurantGRNModel> getAllGRNs() => _box.values.toList();

  RestaurantGRNModel? getGRNById(String id) => _box.get(id);

  List<RestaurantGRNModel> getGRNsByPOId(String poId) =>
      _box.values.where((g) => g.poId == poId).toList();

  /// Newest first — drives the supplier detail screen's Documents tab and the
  /// delete-reference guard.
  List<RestaurantGRNModel> getGRNsBySupplier(String supplierId) =>
      _box.values.where((g) => g.supplierId == supplierId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> saveGRN(RestaurantGRNModel grn) async {
    await _box.put(grn.grnId, grn);
  }

  /// `GRN-00001` — one continuous series per FINANCIAL year, via the shared
  /// [DocumentNumberService], exactly as retail's GRNRepository does.
  ///
  /// Replaces `GRN-YYYYMMDD-<ms suffix>`, which was neither sequential nor
  /// readable: the suffix was a slice of the epoch millisecond, so two receipts
  /// on the same day sorted arbitrarily and nothing told you it was the shop's
  /// fourth receipt of the year.
  Future<String> generateGRNNumber() {
    return _numbers.next(
      'GRN',
      isTaken: (number) => _box.values.any((g) => g.grnNumber == number),
    );
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

  /// Every GRN line in the box, unsorted — reports join them back to their
  /// GRN header themselves. Mirrors retail's `GRNItemRepository.getAllGRNItems`.
  List<RestaurantGRNItemModel> getAllItems() => _box.values.toList();

  Future<void> saveItem(RestaurantGRNItemModel item) async {
    await _box.put(item.grnItemId, item);
  }

  double getTotalReceivedQtyForPOItem(String poItemId) {
    return _box.values
        .where((i) => i.poItemId == poItemId)
        .fold(0.0, (sum, i) => sum + i.receivedQty);
  }
}
