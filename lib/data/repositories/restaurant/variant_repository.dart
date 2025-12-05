import 'package:hive/hive.dart';

import '../../models/restaurant/db/variantmodel_305.dart';

/// Repository layer for Variant data access
class VariantRepository {
  static const String _boxName = 'variants';
  late Box<VariantModel> _variantBox;

  VariantRepository() {
    _variantBox = Hive.box<VariantModel>(_boxName);
  }

  List<VariantModel> getAllVariants() {
    return _variantBox.values.toList();
  }

  Future<void> addVariant(VariantModel variant) async {
    await _variantBox.put(variant.id, variant);
  }

  Future<void> updateVariant(VariantModel variant) async {
    await _variantBox.put(variant.id, variant);
  }

  Future<void> deleteVariant(String id) async {
    await _variantBox.delete(id);
  }

  VariantModel? getVariantById(String id) {
    return _variantBox.get(id);
  }

  int getVariantCount() {
    return _variantBox.length;
  }

  Future<void> clearAll() async {
    await _variantBox.clear();
  }
}