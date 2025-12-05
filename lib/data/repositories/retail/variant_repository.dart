import 'package:hive/hive.dart';
import '../../models/retail/hive_model/variante_model_201.dart';

/// Repository layer for Variant data access
/// Handles all Hive database operations for product variants
class VariantRepository {
  late Box<VarianteModel> _variantBox;

  VariantRepository() {
    _variantBox = Hive.box<VarianteModel>('variants');
  }

  /// Get all variants
  Future<List<VarianteModel>> getAllVariants() async {
    return _variantBox.values.toList();
  }

  /// Get variants for a specific product
  Future<List<VarianteModel>> getVariantsByProductId(String productId) async {
    return _variantBox.values
        .where((variant) => variant.productId == productId)
        .toList();
  }

  /// Add a new variant
  Future<void> addVariant(VarianteModel variant) async {
    await _variantBox.put(variant.varianteId, variant);
  }

  /// Update an existing variant
  Future<void> updateVariant(VarianteModel variant) async {
    await _variantBox.put(variant.varianteId, variant);
  }

  /// Delete a variant
  Future<void> deleteVariant(String variantId) async {
    await _variantBox.delete(variantId);
  }

  /// Delete all variants for a product
  Future<void> deleteVariantsByProductId(String productId) async {
    final variantsToDelete = _variantBox.values
        .where((variant) => variant.productId == productId)
        .toList();

    for (var variant in variantsToDelete) {
      await _variantBox.delete(variant.varianteId);
    }
  }

  /// Get a variant by ID
  Future<VarianteModel?> getVariantById(String variantId) async {
    // First try direct key lookup
    final directLookup = _variantBox.get(variantId);
    if (directLookup != null) {
      return directLookup;
    }

    // Fallback to searching by varianteId property
    try {
      return _variantBox.values.firstWhere(
        (variant) => variant.varianteId == variantId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find variant by barcode
  Future<VarianteModel?> findByBarcode(String barcode) async {
    try {
      return _variantBox.values.firstWhere(
        (variant) => variant.barcode == barcode,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find variant by SKU
  Future<VarianteModel?> findBySku(String sku) async {
    try {
      return _variantBox.values.firstWhere(
        (variant) => variant.sku == sku,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if variant exists
  Future<bool> variantExists(String variantId) async {
    return _variantBox.containsKey(variantId);
  }

  /// Get variants with low stock
  Future<List<VarianteModel>> getLowStockVariants() async {
    return _variantBox.values
        .where((variant) =>
            variant.minStock != null &&
            variant.stockQty <= variant.minStock!)
        .toList();
  }

  /// Update stock quantity
  Future<void> updateStock(String variantId, int newStockQty) async {
    final variant = _variantBox.get(variantId);
    if (variant != null) {
      final updatedVariant = variant.copyWith(stockQty: newStockQty);
      await _variantBox.put(variantId, updatedVariant);
    }
  }

  /// Get total variant count
  int getVariantCount() {
    return _variantBox.length;
  }

  /// Get total stock across all variants
  int getTotalStock() {
    return _variantBox.values.fold(0, (sum, variant) => sum + variant.stockQty);
  }

  /// Update cost price
  Future<void> updateCostPrice(String variantId, double newCostPrice) async {
    final variant = _variantBox.get(variantId);
    if (variant != null) {
      final updatedVariant = variant.copyWith(costPrice: newCostPrice);
      await _variantBox.put(variantId, updatedVariant);
    }
  }

  /// Update custom attributes
  Future<void> updateCustomAttributes(String variantId, Map<String, String> customAttributes) async {
    final variant = _variantBox.get(variantId);
    if (variant != null) {
      final updatedVariant = variant.copyWith(customAttributes: customAttributes);
      await _variantBox.put(variantId, updatedVariant);
    }
  }

  /// Search variants by custom attribute
  Future<List<VarianteModel>> findByCustomAttribute(String key, String value) async {
    return _variantBox.values.where((variant) {
      if (variant.customAttributes == null) return false;
      return variant.customAttributes![key] == value;
    }).toList();
  }

  /// Clear all variants
  Future<void> clearAll() async {
    await _variantBox.clear();
  }
}