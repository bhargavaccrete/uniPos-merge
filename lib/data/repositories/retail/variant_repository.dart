import 'package:hive/hive.dart';
import '../../models/retail/hive_model/variante_model_201.dart';
import '../../../domain/services/retail/barcode_generator_service.dart';

/// Outcome of a variant write that can be refused.
///
/// A typed result rather than an exception: every caller is a form or an import
/// row that wants to show the reason, and an uncaught throw mid-import would
/// abandon the rest of the file.
class VariantWriteResult {
  final bool success;
  final String? errorMessage;

  const VariantWriteResult._(this.success, [this.errorMessage]);

  const VariantWriteResult.ok() : this._(true);
  const VariantWriteResult.failure(String message) : this._(false, message);
}

/// Repository layer for Variant data access
/// Handles all Hive database operations for product variants
///
/// **This is the authoritative layer for barcode uniqueness.** Every write path
/// funnels through [addVariant] / [updateVariant], so guarding here closes the
/// paths that individual forms miss. A duplicate barcode is not cosmetic:
/// [findByBarcode] is a `firstWhere`, so the second variant becomes permanently
/// unscannable and its stock never decrements — silently.
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

  /// Trimmed barcode, or null when there is nothing meaningful stored.
  ///
  /// Bulk import writes `''` for a blank column, which would otherwise make
  /// every un-barcoded variant "share" the empty string and collide with each
  /// other. Normalising on write keeps absence representable.
  static String? _normaliseBarcode(String? raw) {
    final code = raw?.trim() ?? '';
    return code.isEmpty ? null : code;
  }

  /// The variant currently holding [barcode], ignoring [exceptVariantId].
  ///
  /// Scans the BOX, not an in-memory cache — `ProductStore.isBarcodeTaken` reads
  /// the observable list, which is stale during an import.
  VarianteModel? variantHoldingBarcode(
    String barcode, {
    String? exceptVariantId,
  }) {
    final code = _normaliseBarcode(barcode);
    if (code == null) return null;
    for (final variant in _variantBox.values) {
      if (variant.varianteId == exceptVariantId) continue;
      if (_normaliseBarcode(variant.barcode) == code) return variant;
    }
    return null;
  }

  /// True when [barcode] already belongs to a DIFFERENT variant.
  bool isBarcodeTaken(String barcode, {String? exceptVariantId}) =>
      variantHoldingBarcode(barcode, exceptVariantId: exceptVariantId) != null;

  /// Add a new variant, refusing a barcode another variant already holds.
  ///
  /// A blank barcode is FILLED IN automatically, so every new variant is
  /// scannable and printable the moment it exists. Done here rather than at the
  /// half-dozen creation sites because that is exactly how SKU generation ended
  /// up inconsistent — Add Variant fills a blank SKU, Add Product does not.
  /// One choke point, no drift. (Same shape as `GrnRepository` using
  /// `DocumentNumberService`.)
  ///
  /// Only on ADD. [updateVariant] never generates, so deliberately clearing a
  /// barcode stays cleared instead of being re-minted on the next save.
  Future<VariantWriteResult> addVariant(VarianteModel variant) async {
    final guard = _guardBarcode(variant);
    if (!guard.success) return guard;

    final prepared = await _withGeneratedBarcodeIfBlank(
      _withNormalisedBarcode(variant),
    );
    await _variantBox.put(prepared.varianteId, prepared);
    return const VariantWriteResult.ok();
  }

  /// Mint a barcode when the variant has none.
  ///
  /// Never overwrites an existing value, so a manufacturer barcode is safe.
  /// Failure is non-fatal: saving the variant without a barcode is far better
  /// than losing it, and the user can Generate one later from Print Labels.
  Future<VarianteModel> _withGeneratedBarcodeIfBlank(
    VarianteModel variant,
  ) async {
    if (_normaliseBarcode(variant.barcode) != null) return variant;
    try {
      final code = await BarcodeGeneratorService().next(
        isTaken: (candidate) => isBarcodeTaken(candidate),
      );
      return variant.copyWith(barcode: code);
    } catch (e) {
      // ignore: avoid_print
      print('Barcode generation skipped for ${variant.varianteId}: $e');
      return variant;
    }
  }

  /// Update an existing variant, refusing a barcode another variant already
  /// holds. Re-saving a variant with its OWN barcode is always allowed.
  ///
  /// Deliberately does NOT generate a blank barcode: an admin who clears one
  /// (behind a confirmation) means it, and re-minting here would make the
  /// Remove action impossible.
  Future<VariantWriteResult> updateVariant(VarianteModel variant) async {
    final guard = _guardBarcode(variant);
    if (!guard.success) return guard;
    await _variantBox.put(variant.varianteId, _withNormalisedBarcode(variant));
    return const VariantWriteResult.ok();
  }

  /// Write without the barcode guard. **Restore only.**
  ///
  /// A backup must always restore: refusing a row because the backup itself
  /// contains a duplicate would leave the catalogue half-populated, which is
  /// worse than the duplicate. Callers should REPORT what they saw instead.
  Future<void> putVariantUnchecked(VarianteModel variant) async {
    await _variantBox.put(variant.varianteId, variant);
  }

  VariantWriteResult _guardBarcode(VarianteModel variant) {
    final code = _normaliseBarcode(variant.barcode);
    if (code == null) return const VariantWriteResult.ok();

    final holder =
        variantHoldingBarcode(code, exceptVariantId: variant.varianteId);
    if (holder == null) return const VariantWriteResult.ok();

    return VariantWriteResult.failure(
      'Barcode "$code" is already used by another variant.',
    );
  }

  VarianteModel _withNormalisedBarcode(VarianteModel variant) {
    final code = _normaliseBarcode(variant.barcode);
    if (code == variant.barcode) return variant;
    return variant.copyWith(barcode: code, clearBarcode: code == null);
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

  /// Find variant by barcode.
  ///
  /// Trims both sides so a scanner that appends whitespace, or a variant saved
  /// with a stray space, still matches.
  Future<VarianteModel?> findByBarcode(String barcode) async {
    final code = _normaliseBarcode(barcode);
    if (code == null) return null;
    for (final variant in _variantBox.values) {
      if (_normaliseBarcode(variant.barcode) == code) return variant;
    }
    return null;
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