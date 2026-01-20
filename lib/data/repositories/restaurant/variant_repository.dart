import 'package:hive/hive.dart';
import '../../models/restaurant/db/variantmodel_305.dart';

/// Repository layer for Variant data access (Restaurant)
/// Handles all Hive database operations for variants
class VariantRepositoryRes {
  late Box<VariantModel> _variantBox;

  VariantRepositoryRes() {
    _variantBox = Hive.box<VariantModel>('variante');
  }

  /// Add a new variant
  Future<void> addVariant(VariantModel variant) async {
    await _variantBox.put(variant.id, variant);
  }

  /// Get all variants
  Future<List<VariantModel>> getAllVariants() async {
    return _variantBox.values.toList();
  }

  /// Get variant by ID
  Future<VariantModel?> getVariantById(String id) async {
    return _variantBox.get(id);
  }

  /// Update variant
  Future<void> updateVariant(VariantModel variant) async {
    await _variantBox.put(variant.id, variant);
  }

  /// Delete variant
  Future<void> deleteVariant(String id) async {
    await _variantBox.delete(id);
  }

  /// Search variants by name
  Future<List<VariantModel>> searchVariants(String query) async {
    if (query.isEmpty) return getAllVariants();

    final lowercaseQuery = query.toLowerCase();
    return _variantBox.values
        .where((variant) => variant.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get variant count
  Future<int> getVariantCount() async {
    return _variantBox.length;
  }
}