import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/purchase_return_item_model_175.dart';
import '../../models/retail/hive_model/purchase_return_model_174.dart';

/// Hive I/O for purchase returns and their lines.
///
/// Owns both boxes rather than splitting into a second `…ItemRepository` the
/// way PO/GRN do: return lines are only ever fetched through their parent
/// return, so the extra indirection would buy nothing.
class PurchaseReturnRepository {
  Box<PurchaseReturnModel> get _box =>
      Hive.box<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);

  Box<PurchaseReturnItemModel> get _itemBox =>
      Hive.box<PurchaseReturnItemModel>(HiveBoxNames.purchaseReturnItems);

  Future<List<PurchaseReturnModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  PurchaseReturnModel? getById(String returnId) => _box.get(returnId);

  Future<void> save(PurchaseReturnModel model) async {
    await _box.put(model.returnId, model);
  }

  Future<void> saveItems(List<PurchaseReturnItemModel> items) async {
    for (final item in items) {
      await _itemBox.put(item.returnItemId, item);
    }
  }

  Future<List<PurchaseReturnItemModel>> getItems(String returnId) async {
    return _itemBox.values.where((i) => i.returnId == returnId).toList();
  }

  Future<List<PurchaseReturnModel>> getByGRN(String grnId) async {
    return _box.values.where((r) => r.grnId == grnId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<PurchaseReturnModel>> getBySupplier(String supplierId) async {
    return _box.values.where((r) => r.supplierId == supplierId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// How many units of a GRN line have already been sent back — the basis for
  /// partial returns. Cancelled returns don't count.
  Future<int> returnedQtyForGRNItem(String grnItemId) async {
    var total = 0;
    for (final item in _itemBox.values.where((i) => i.grnItemId == grnItemId)) {
      final parent = _box.get(item.returnId);
      if (parent == null ||
          parent.statusEnum == PurchaseReturnStatus.cancelled) {
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
