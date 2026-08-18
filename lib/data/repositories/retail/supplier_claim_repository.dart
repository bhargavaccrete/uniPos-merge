import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/supplier_claim_item_model_177.dart';
import '../../models/retail/hive_model/supplier_claim_model_176.dart';

/// Hive I/O for supplier claims and their lines. Owns both boxes for the same
/// reason as [PurchaseReturnRepository] — lines are only read via their parent.
class SupplierClaimRepository {
  Box<SupplierClaimModel> get _box =>
      Hive.box<SupplierClaimModel>(HiveBoxNames.supplierClaims);

  Box<SupplierClaimItemModel> get _itemBox =>
      Hive.box<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems);

  Future<List<SupplierClaimModel>> getAll() async {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  SupplierClaimModel? getById(String claimId) => _box.get(claimId);

  Future<void> save(SupplierClaimModel model) async {
    await _box.put(model.claimId, model);
  }

  Future<void> saveItems(List<SupplierClaimItemModel> items) async {
    for (final item in items) {
      await _itemBox.put(item.claimItemId, item);
    }
  }

  Future<List<SupplierClaimItemModel>> getItems(String claimId) async {
    return _itemBox.values.where((i) => i.claimId == claimId).toList();
  }

  Future<List<SupplierClaimModel>> getByGRN(String grnId) async {
    return _box.values.where((c) => c.grnId == grnId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<SupplierClaimModel>> getBySupplier(String supplierId) async {
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
