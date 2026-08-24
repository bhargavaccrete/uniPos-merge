import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/bundle_model.dart';

/// Data access layer for [RetailBundleModel]. One bundle per product (its
/// `variantId` is effectively unique) — see
/// docs/retail_inventory_system_plan.md §3.2.
class BundleRepository {
  Box<RetailBundleModel> get _box =>
      Hive.box<RetailBundleModel>(HiveBoxNames.bundles);

  List<RetailBundleModel> getAllBundles() => _box.values.toList();

  RetailBundleModel? getBundleById(String id) => _box.get(id);

  /// The bundle configured for [variantId], if any.
  RetailBundleModel? getBundleForVariant(String variantId) {
    try {
      return _box.values.firstWhere((b) => b.variantId == variantId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBundle(RetailBundleModel bundle) async {
    await _box.put(bundle.id, bundle);
  }

  Future<void> deleteBundle(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteBundleForVariant(String variantId) async {
    final bundle = getBundleForVariant(variantId);
    if (bundle != null) await _box.delete(bundle.id);
  }
}
