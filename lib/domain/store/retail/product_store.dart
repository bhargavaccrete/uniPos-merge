import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/retail/product_repository.dart';
import '../../../data/repositories/retail/variant_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../core/plan/retail_entitlement_keys.dart';
import '../../services/retail/expiry_status.dart';
import '../../services/retail/inventory_service.dart';
import '../../services/retail/retail_notification_sync_service.dart';


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

  /// The constructor's hydration, kept so callers can await it.
  late final Future<void> _hydration;

  _ProductStore() {
    _productRepository = ProductRepository();
    _variantRepository = VariantRepository();
    _hydration = _init();
  }

  Future<void> _init() async {
    // Load data from repositories
    await loadProducts();
    await loadVariants();
  }

  /// Completes once the constructor's initial load has finished.
  ///
  /// The store hydrates asynchronously from its constructor, so a caller that
  /// touches `products` in the same turn it first reads `productStore` sees an
  /// empty catalogue. Screens don't notice — they sit inside an `Observer` and
  /// repaint when the load lands — but a one-shot startup job (the notification
  /// sync) would silently conclude nothing is low on stock. Awaiting this
  /// returns the in-flight future rather than re-reading Hive.
  Future<void> ensureLoaded() => _hydration;

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

  /// Plan gate for adding a product: module + add action allowed, AND under the
  /// products cap. Mirrors restaurant's `item_store.addItem`
  /// (`manage_menu.items` + `.add` + `.max`).
  /// No-op (true) until a retail manifest is present — see `PlanEnforce`.
  bool get canAddProduct =>
      PlanEnforce.allows(RetailEntKeys.catalog) &&
      PlanEnforce.allows(RetailEntKeys.catalogProductsAdd) &&
      PlanEnforce.withinLimit(RetailEntKeys.catalogProductsMax, products.length);

  /// The products cap for messages; null = unlimited.
  int? get productLimit => PlanEnforce.limit(RetailEntKeys.catalogProductsMax);

  /// Create a single-variant product in one step — used by the POS "product not
  /// found for this barcode" flow. Model construction lives here rather than in
  /// the screen so the id/timestamp rules stay in one place.
  ///
  /// Throws [StateError] when [barcode] already belongs to a variant. Checked
  /// BEFORE the product is written: creating the product first and letting the
  /// variant be refused would leave an orphan product in the catalogue, which is
  /// worse than the collision. Reaching this is unlikely (the caller only gets
  /// here after a lookup missed) but a whitespace difference could do it.
  @action
  Future<(ProductModel, VarianteModel)> createSimpleProduct({
    required String name,
    required String categoryId,
    required String barcode,
    required double sellingPrice,
    double? mrp,
    double stockQty = 1,
  }) async {
    final code = barcode.trim();
    if (code.isNotEmpty && isBarcodeTaken(code)) {
      throw StateError('Barcode "$code" is already used by another variant.');
    }

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
      barcode: code.isEmpty ? null : code,
      sellingPrice: sellingPrice,
      mrp: effectiveMrp,
      // Unknown, not ₹0: profit reports count a null cost as "unknown" and
      // leave it out, while 0 made every such sale look 100% margin. A GRN
      // or Edit Variant supplies the real cost later.
      costPrice: null,
      stockQty: stockQty,
      sku: null,
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

  /// Bulk tax assignment (retail Tax Settings → Apply to products).
  ///
  /// Writes the pair the product form writes — [taxId] plus the cached rate —
  /// on the product AND each of its variants. The cart prefers a variant's own
  /// rate, so updating only the product would leave variants on the old one.
  /// Returns how many products were updated.
  Future<int> applyTaxToProducts(
    Iterable<String> productIds, {
    required String taxId,
    required double rate,
  }) async {
    var updated = 0;
    for (final id in productIds) {
      final product = getProductById(id);
      if (product == null) continue;
      await updateProduct(product.copyWith(taxId: taxId, gstRate: rate));
      // Copied first: updateVariant rewrites the list variantsFor reads from.
      for (final v in List.of(variantsFor(id))) {
        await updateVariant(v.copyWith(taxId: taxId, taxRate: rate));
      }
      updated++;
    }
    return updated;
  }

  /// Removes any named tax from the products and their variants; they then
  /// bill at the default GST rate from Tax Settings.
  Future<int> clearTaxFromProducts(Iterable<String> productIds) async {
    var updated = 0;
    for (final id in productIds) {
      final product = getProductById(id);
      if (product == null) continue;
      await updateProduct(product.copyWith(clearTax: true));
      for (final v in List.of(variantsFor(id))) {
        await updateVariant(v.copyWith(clearTax: true));
      }
      updated++;
    }
    return updated;
  }

  /// Names of OTHER products whose bundle/kit recipe uses any of
  /// [variantIds] as a component. Deleting such a variant used to leave the
  /// bundle selling with that component silently skipped (no deduction) and
  /// unassemblable, so a delete is refused while this is non-empty — the
  /// recipe is the owner's to change, never silently rewritten.
  List<String> bundlesUsing(Iterable<String> variantIds) {
    final ids = variantIds.toSet();
    final names = <String>{};
    for (final bundle in bundleRepository.getAllBundles()) {
      if (bundle.components.any((c) => ids.contains(c.componentVariantId))) {
        names.add(getProductById(bundle.productId)?.productName ?? 'a bundle');
      }
    }
    return names.toList()..sort();
  }

  /// Records that die with a deleted product/variant: its own bundle/kit
  /// recipe rows and (for a product) its attribute assignments — left behind
  /// they were orphans, and the attribute rows blocked deleting an attribute.
  ///
  /// Runs AFTER the delete and never throws: tidying leftovers must not be
  /// able to stop the delete itself (import rollback depends on it).
  Future<void> _dropOwnedRecords(
    Iterable<String> variantIds, {
    String? productId,
  }) async {
    try {
      for (final id in variantIds) {
        await bundleRepository.deleteBundleForVariant(id);
      }
      if (productId != null) {
        await attributeStore.removeAttributesFromProduct(productId);
      }
    } catch (e) {
      debugPrint('Cleanup after delete incomplete: $e');
    }
  }

  @action
  Future<void> deleteProduct(String productId) async {
    final variantIds =
        variantsFor(productId).map((v) => v.varianteId).toList();

    // Delete from database (also deletes variants)
    await _productRepository.deleteProduct(productId);

    // Update UI state — the repository cascades the variant delete, so the
    // in-memory list has to be pruned to match.
    products.removeWhere((p) => p.productId == productId);
    variants.removeWhere((v) => v.productId == productId);

    await _dropOwnedRecords(variantIds, productId: productId);
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
      // `category` holds the category's ID; match its NAME, which is what a
      // cashier types. Matching the id never found anything.
      final categoryMatch = categoryStore
          .displayNameFor(product.category)
          .toLowerCase()
          .contains(lowerQuery);
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

  double totalStockFor(String productId) =>
      variantsFor(productId).fold<double>(0.0, (sum, v) => sum + v.stockQty);

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

  RetailStockStatus stockStatusForQty(double qty) =>
      statusFor(qty, lowStockThreshold.toDouble());

  /// The one stock rule, so the inventory colouring, the Stock Alerts card and
  /// the low-stock report can never disagree.
  ///
  /// [reorderPoint] is the level at or below which stock counts as low — a
  /// variant's own `minStock` when it has one, otherwise the global threshold.
  /// The "critical" band is a third of that (min 1), rather than a fixed 3, so
  /// a variant that reorders at 2 is not permanently red.
  RetailStockStatus statusFor(double qty, double reorderPoint) {
    if (qty <= 0) return RetailStockStatus.outOfStock;
    // Hand-bounded rather than `clamp`, which THROWS when the reorder point is
    // a fraction below 1 (a decimal variant may legitimately reorder at 0.5 kg).
    // Same result as the old clamp(1, reorderPoint) for every whole value.
    final raw = (reorderPoint / 3).ceilToDouble();
    final atLeastOne = raw < 1.0 ? 1.0 : raw;
    final critical = atLeastOne > reorderPoint ? reorderPoint : atLeastOne;
    if (qty <= critical) return RetailStockStatus.critical;
    if (qty <= reorderPoint) return RetailStockStatus.low;
    return RetailStockStatus.inStock;
  }

  /// A variant's own `minStock` wins over the global threshold — that is the
  /// whole point of collecting it on the variant forms.
  double reorderPointFor(VarianteModel variant) =>
      variant.minStock ?? lowStockThreshold.toDouble();

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

  // ==================== EXPIRY CLASSIFICATION ====================
  // Thin wrappers over the ONE rule in `expiry_status.dart`, mirroring the
  // stock-status wrappers above. The maths lives there, not here, so the
  // inventory badge, the variant row and the Expiry Alerts screen cannot drift.

  RetailExpiryStatus expiryStatusForVariant(VarianteModel variant) =>
      expiryStatusFor(variant.expiryDateTime);

  /// The most urgent expiry across a product's variants — what a single
  /// product row in the inventory list should show. `noExpiry` when none of
  /// its variants carries a date.
  RetailExpiryStatus expiryStatusForProduct(String productId) {
    var worst = RetailExpiryStatus.noExpiry;
    for (final variant in variantsFor(productId)) {
      final status = expiryStatusForVariant(variant);
      if (status == RetailExpiryStatus.noExpiry) continue;
      // Enum order is noExpiry < expired < expiringToday < expiringSoon < valid,
      // so the lowest non-noExpiry index is the most urgent.
      if (worst == RetailExpiryStatus.noExpiry || status.index < worst.index) {
        worst = status;
      }
    }
    return worst;
  }

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

  /// Keeps the product's derived `hasVariants`/`productType` in step with its
  /// actual variant count after an add or delete. They were only set at
  /// creation, so a product grown to 2+ variants in Product Detail kept
  /// saying "simple" and its variant chip stayed wrong.
  Future<void> _syncVariantFlags(String productId) async {
    final product = getProductById(productId);
    if (product == null) return;
    final hasMany = variantsFor(productId).length > 1;
    if (product.hasVariants == hasMany) return;
    await updateProduct(product.copyWith(
      hasVariants: hasMany,
      productType: hasMany ? 'variable' : 'simple',
    ));
  }

  /// Re-reads [variant] from the box after a successful write and mirrors THAT
  /// into memory, so the cache holds exactly what the repository stored.
  Future<void> _mirrorSaved(VarianteModel variant) async {
    final saved = await _variantRepository.getVariantById(variant.varianteId);
    _upsertVariantInMemory(saved ?? variant);
  }

  /// Get all variants for a product
  Future<List<VarianteModel>> getVariantsForProduct(String productId) async {
    return await _variantRepository.getVariantsByProductId(productId);
  }

  /// Add a variant.
  ///
  /// The repository refuses a barcode another variant already holds; the result
  /// says why so a form can show it. The in-memory list is only updated on
  /// success, or the cache would disagree with the box.
  @action
  Future<VariantWriteResult> addVariant(VarianteModel variant) async {
    final result = await _variantRepository.addVariant(variant);
    // Only mirror into the in-memory list on success, or the cache would
    // disagree with the box. The failure message rides on the result — callers
    // surface it, so there is no store-level error state to keep in sync.
    if (result.success) {
      // Mirror what was SAVED, not the input: the repository mints a barcode
      // for a blank one, and mirroring the input kept `null` in memory — a
      // later save from memory (e.g. Apply Tax) then wrote the barcode away.
      await _mirrorSaved(variant);
      // Every create path lands here, so the history starts at the first unit.
      if (variant.stockQty > 0) {
        await RetailInventoryService.recordMovement(
          variant: variant,
          type: 'in',
          quantity: variant.stockQty,
          balanceAfter: variant.stockQty,
          reason: 'Opening stock',
        );
      }
      await _syncVariantFlags(variant.productId);
    }
    return result;
  }

  @action
  Future<VariantWriteResult> updateVariant(VarianteModel variant) async {
    final before = await _variantRepository.getVariantById(variant.varianteId);
    final result = await _variantRepository.updateVariant(variant);
    // Only mirror into the in-memory list on success, or the cache would
    // disagree with the box. The failure message rides on the result — callers
    // surface it, so there is no store-level error state to keep in sync.
    if (result.success) {
      // What was saved — the repository normalises the barcode on write.
      await _mirrorSaved(variant);
      // Stock, min stock or expiry may have changed — refresh alerts.
      RetailNotificationSyncService.scheduleSync();
      // A whole-record save that carries a different stock figure is a stock
      // change like any other — log it rather than let stock jump silently.
      final delta = variant.stockQty - (before?.stockQty ?? variant.stockQty);
      if (delta != 0) {
        await RetailInventoryService.recordMovement(
          variant: variant,
          type: delta > 0 ? 'in' : 'out',
          quantity: delta.abs(),
          balanceAfter: variant.stockQty,
          reason: 'Stock edited',
        );
      }
    }
    return result;
  }

  @action
  Future<void> deleteVariant(String variantId) async {
    final productId = variants
        .where((v) => v.varianteId == variantId)
        .firstOrNull
        ?.productId;
    await _variantRepository.deleteVariant(variantId);
    await _dropOwnedRecords([variantId]);
    variants.removeWhere((v) => v.varianteId == variantId);
    if (productId != null) await _syncVariantFlags(productId);
  }

  /// Update stock for a variant
  @action
  Future<void> updateVariantStock(String variantId, double newStock) async {
    await _variantRepository.updateStock(variantId, newStock);
    // Every retail stock movement lands here — keep alerts current.
    RetailNotificationSyncService.scheduleSync();
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