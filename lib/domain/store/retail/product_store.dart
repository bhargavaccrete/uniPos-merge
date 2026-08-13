import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/retail/product_repository.dart';
import '../../../data/repositories/retail/variant_repository.dart';
import '../../../core/di/service_locator.dart';


part 'product_store.g.dart';

/// Stock tiers, aligned with the canonical rule in `report_service`/`StockAlertService`
/// so Inventory and the Stock Alerts screen never disagree.
enum RetailStockStatus { outOfStock, critical, low, inStock }

/// Variant status a till may sell. Anything else stays in the catalogue with
/// its stock and history intact, but is hidden from the POS.
///
/// Top level rather than a static: `ProductStore` is a mixin application
/// (`= _ProductStore with _$ProductStore`), so statics on the private class
/// are not reachable through it.
const String kActiveVariantStatus = 'active';
const String kInactiveVariantStatus = 'inactive';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  // Repositories handle all database operations
  late final ProductRepository _productRepository;
  late final VariantRepository _variantRepository;

  @observable
  ObservableList<ProductModel> products = ObservableList<ProductModel>();

  /// Variants live in their own box — products and variants stay separate models.
  /// Holding them here lets screens read stock/price synchronously inside an
  /// `Observer`, without a `FutureBuilder` per card.
  @observable
  ObservableList<VarianteModel> variants = ObservableList<VarianteModel>();

  _ProductStore() {
    _productRepository = ProductRepository();
    _variantRepository = VariantRepository();
    _init();
  }

  Future<void> _init() async {
    // Load data from repositories
    await loadProducts();
    await loadVariants();
  }

  // ==================== PRODUCT OPERATIONS ====================

  @action
  Future<void> loadProducts() async {
    print('ProductStore.loadProducts: Loading products from repository...');
    final loadedProducts = await _productRepository.getAllProducts();
    print('ProductStore.loadProducts: Repository returned ${loadedProducts.length} products');
    products.clear();
    products.addAll(loadedProducts);
    print('ProductStore.loadProducts: products list now has ${products.length} items');
  }

  @action
  Future<void> addProduct(ProductModel product) async {
    // Save to database through repository
    await _productRepository.addProduct(product);

    // Update UI state
    products.add(product);
  }

  /// Create a single-variant product in one step — used by the POS "product not
  /// found for this barcode" flow. Model construction lives here rather than in
  /// the screen so the id/timestamp rules stay in one place.
  @action
  Future<(ProductModel, VarianteModel)> createSimpleProduct({
    required String name,
    required String categoryId,
    required String barcode,
    required double sellingPrice,
    double? mrp,
    int stockQty = 1,
  }) async {
    const uuid = Uuid();
    final productId = uuid.v4();
    final now = DateTime.now().toIso8601String();
    final effectiveMrp = mrp ?? sellingPrice;

    final product = ProductModel(
      productId: productId,
      productName: name,
      category: categoryId,
      description: '',
      hasVariants: false,
      createdAt: now,
      updateAt: now,
      productType: 'simple',
      defaultPrice: sellingPrice,
      defaultMrp: effectiveMrp,
    );

    final variant = VarianteModel(
      varianteId: uuid.v4(),
      productId: productId,
      barcode: barcode,
      sellingPrice: sellingPrice,
      mrp: effectiveMrp,
      costPrice: 0,
      stockQty: stockQty,
      sku: '',
      createdAt: now,
      updateAt: now,
      isDefault: true,
      status: 'active',
    );

    await addProduct(product);
    await addVariant(variant);

    return (product, variant);
  }

  @action
  Future<void> updateProduct(ProductModel product) async {
    // Update in database
    await _productRepository.updateProduct(product);

    // Update UI state
    final index = products.indexWhere((p) => p.productId == product.productId);
    if (index != -1) {
      products[index] = product;
    }
  }

  @action
  Future<void> deleteProduct(String productId) async {
    // Delete from database (also deletes variants)
    await _productRepository.deleteProduct(productId);

    // Update UI state — the repository cascades the variant delete, so the
    // in-memory list has to be pruned to match.
    products.removeWhere((p) => p.productId == productId);
    variants.removeWhere((v) => v.productId == productId);
  }

  /// Find product by barcode (searches through variants)
  Future<ProductModel?> findByBarcode(String barcode) async {
    return await _productRepository.findByBarcode(barcode);
  }

  /// Get product by ID
  ProductModel? getProductById(String productId) {
    try {
      return products.firstWhere((p) => p.productId == productId);
    } catch (e) {
      return null;
    }
  }

  /// Suggests a taxId based on the most recently saved product that used the
  /// same HSN code. Returns null if no prior product used this HSN code, or
  /// if the match has no tax set — the caller decides what to do with it
  /// (e.g. pre-fill a dropdown that the user can still override).
  String? findTaxIdByHsnCode(String hsnCode) {
    final trimmed = hsnCode.trim();
    if (trimmed.isEmpty) return null;

    final matches = products
        .where((p) => p.hsnCode == trimmed && p.taxId != null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return matches.isEmpty ? null : matches.first.taxId;
  }

  /// Search products by name or category
  Future<List<ProductModel>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return products.where((product) {
      final nameMatch = product.productName.toLowerCase().contains(lowerQuery);
      final categoryMatch = product.category.toLowerCase().contains(lowerQuery);
      final brandMatch = product.brandName?.toLowerCase().contains(lowerQuery) ?? false;
      return nameMatch || categoryMatch || brandMatch;
    }).toList();
  }

  // ==================== VARIANT OPERATIONS ====================

  @action
  Future<void> loadVariants() async {
    final loaded = await _variantRepository.getAllVariants();
    variants
      ..clear()
      ..addAll(loaded);
  }

  /// Product id → its variants. This is the join between the two separate
  /// models; MobX memoises it, so reading it repeatedly inside one reaction is
  /// free. Building it once is O(V) instead of O(products × variants).
  @computed
  Map<String, List<VarianteModel>> get variantsByProduct {
    final map = <String, List<VarianteModel>>{};
    for (final v in variants) {
      (map[v.productId] ??= <VarianteModel>[]).add(v);
    }
    return map;
  }

  /// Synchronous variant lookup — safe to call inside an `Observer`.
  List<VarianteModel> variantsFor(String productId) =>
      variantsByProduct[productId] ?? const <VarianteModel>[];

  int variantCountFor(String productId) => variantsFor(productId).length;

  int totalStockFor(String productId) =>
      variantsFor(productId).fold<int>(0, (sum, v) => sum + v.stockQty);

  /// The variant whose price represents the product on a card. Deliberately
  /// `.first` (Hive insertion order) to preserve existing display behaviour.
  VarianteModel? primaryVariantFor(String productId) {
    final vs = variantsFor(productId);
    return vs.isEmpty ? null : vs.first;
  }

  double costPriceFor(String productId) =>
      primaryVariantFor(productId)?.costPrice ?? 0.0;

  // ==================== STOCK CLASSIFICATION ====================

  /// Canonical threshold, from the same SharedPreferences key the Stock Alerts
  /// screen uses. Observable, so changing it re-renders every dependent view.
  int get lowStockThreshold => stockAlertStore.threshold;

  RetailStockStatus stockStatusForQty(int qty) =>
      statusFor(qty, lowStockThreshold);

  /// The one stock rule, so the inventory colouring, the Stock Alerts card and
  /// the low-stock report can never disagree.
  ///
  /// [reorderPoint] is the level at or below which stock counts as low — a
  /// variant's own `minStock` when it has one, otherwise the global threshold.
  /// The "critical" band is a third of that (min 1), rather than a fixed 3, so
  /// a variant that reorders at 2 is not permanently red.
  RetailStockStatus statusFor(int qty, int reorderPoint) {
    if (qty <= 0) return RetailStockStatus.outOfStock;
    final critical = (reorderPoint / 3).ceil().clamp(1, reorderPoint);
    if (qty <= critical) return RetailStockStatus.critical;
    if (qty <= reorderPoint) return RetailStockStatus.low;
    return RetailStockStatus.inStock;
  }

  /// A variant's own `minStock` wins over the global threshold — that is the
  /// whole point of collecting it on the variant forms.
  int reorderPointFor(VarianteModel variant) =>
      variant.minStock ?? lowStockThreshold;

  bool isSellable(VarianteModel variant) =>
      variant.status == kActiveVariantStatus;

  /// True when [barcode] already belongs to some other variant.
  ///
  /// Barcode lookup is `firstWhere`, so a duplicate does not fail loudly — it
  /// silently makes the second variant unscannable and sells the first. Forms
  /// must check this before saving. Pass [exceptVariantId] when editing.
  bool isBarcodeTaken(String barcode, {String? exceptVariantId}) {
    final code = barcode.trim();
    if (code.isEmpty) return false;
    return variants.any(
        (v) => v.barcode == code && v.varianteId != exceptVariantId);
  }

  RetailStockStatus stockStatusForVariant(VarianteModel variant) =>
      statusFor(variant.stockQty, reorderPointFor(variant));

  RetailStockStatus stockStatusForProduct(String productId) =>
      stockStatusForQty(totalStockFor(productId));

  /// Replace in place, never remove-then-add: card prices key off
  /// `variants.first`, so reordering would silently change what's displayed.
  void _upsertVariantInMemory(VarianteModel variant) {
    final i = variants.indexWhere((v) => v.varianteId == variant.varianteId);
    if (i == -1) {
      variants.add(variant);
    } else {
      variants[i] = variant;
    }
  }

  /// Get all variants for a product
  Future<List<VarianteModel>> getVariantsForProduct(String productId) async {
    return await _variantRepository.getVariantsByProductId(productId);
  }

  @action
  Future<void> addVariant(VarianteModel variant) async {
    await _variantRepository.addVariant(variant);
    _upsertVariantInMemory(variant);
  }

  @action
  Future<void> updateVariant(VarianteModel variant) async {
    await _variantRepository.updateVariant(variant);
    _upsertVariantInMemory(variant);
  }

  @action
  Future<void> deleteVariant(String variantId) async {
    await _variantRepository.deleteVariant(variantId);
    variants.removeWhere((v) => v.varianteId == variantId);
  }

  /// Update stock for a variant
  @action
  Future<void> updateVariantStock(String variantId, int newStock) async {
    await _variantRepository.updateStock(variantId, newStock);
    // Re-read rather than rebuilding with copyWith — copyWith bumps `updateAt`
    // to now, which would drift the in-memory copy from what was persisted.
    final persisted = await _variantRepository.getVariantById(variantId);
    if (persisted != null) _upsertVariantInMemory(persisted);
  }

  /// Update cost price for a variant
  @action
  Future<void> updateVariantCostPrice(String variantId, double newCostPrice) async {
    await _variantRepository.updateCostPrice(variantId, newCostPrice);
    final persisted = await _variantRepository.getVariantById(variantId);
    if (persisted != null) _upsertVariantInMemory(persisted);
  }

  /// Find variant by barcode
  Future<VarianteModel?> findVariantByBarcode(String barcode) async {
    return await _variantRepository.findByBarcode(barcode);
  }

  /// Get low stock variants
  Future<List<VarianteModel>> getLowStockVariants() async {
    return await _variantRepository.getLowStockVariants();
  }

  /// Get variant by ID
  Future<VarianteModel?> getVariantById(String variantId) async {
    return await _variantRepository.getVariantById(variantId);
  }

  /// Get all variants
  Future<List<VarianteModel>> getAllVariants() async {
    return await _variantRepository.getAllVariants();
  }



  // ==================== UTILITY METHODS ====================

  Future<void> _addSampleProducts() async {
    // Create sample products with variants
    for (int index = 0; index < 10; index++) {
      final category = index % 3 == 0
          ? 'Electronics'
          : index % 3 == 1
              ? 'Clothing'
              : 'Groceries';

      final hasVariants = index % 3 == 1; // Clothing has variants

      // Create product
      final product = ProductModel.fromProduct(
        productId: 'p$index',
        productName: 'Product $index',
        category: category,
        imagePath: 'https://via.placeholder.com/150?text=Product+$index',
        hasVariants: hasVariants,
      );

      await addProduct(product);

      // Create variants
      if (hasVariants) {
        // Clothing with size and color variants
        final sizes = ['S', 'M', 'L'];
        final colors = ['Red', 'Blue', 'Green'];

        int variantIndex = 0;
        for (var size in sizes) {
          for (var color in colors) {
            final variant = VarianteModel.create(
              varianteId: 'p${index}_v$variantIndex',
              productId: 'p$index',


              costPrice: (index + 1) * 10.0 + variantIndex,
              stockQty: (index + 1) * 5,
              barcode: '123456789$index$variantIndex',
              sku: 'SKU-$index-$variantIndex',
            );
            await addVariant(variant);
            variantIndex++;
          }
        }
      } else {
        // Products without variants get a single default variant
        final variant = VarianteModel.create(
          varianteId: 'p${index}_default',
          productId: 'p$index',
          costPrice: (index + 1) * 10.0,
          stockQty: (index + 1) * 5,
          barcode: '123456789$index',
          sku: 'SKU-$index',
        );
        await addVariant(variant);
      }
    }
  }

  @action
  Future<void> clearAllData() async {
    await _productRepository.clearAll();
    await _variantRepository.clearAll();
    await categoryRepository.clearAll();
    await categoryStore.loadCategories();
    products.clear();
    variants.clear();
  }
}