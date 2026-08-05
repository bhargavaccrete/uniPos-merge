import 'package:mobx/mobx.dart';

import '../../../data/models/retail/hive_model/product_model_200.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/retail/product_repository.dart';
import '../../../data/repositories/retail/variant_repository.dart';
import '../../../core/di/service_locator.dart';


part 'product_store.g.dart';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  // Repositories handle all database operations
  late final ProductRepository _productRepository;
  late final VariantRepository _variantRepository;

  @observable
  ObservableList<ProductModel> products = ObservableList<ProductModel>();

  _ProductStore() {
    _productRepository = ProductRepository();
    _variantRepository = VariantRepository();
    _init();
  }

  Future<void> _init() async {
    // Load data from repositories
    await loadProducts();
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

    // Update UI state
    products.removeWhere((p) => p.productId == productId);
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

  /// Get all variants for a product
  Future<List<VarianteModel>> getVariantsForProduct(String productId) async {
    return await _variantRepository.getVariantsByProductId(productId);
  }

  @action
  Future<void> addVariant(VarianteModel variant) async {
    await _variantRepository.addVariant(variant);
  }

  @action
  Future<void> updateVariant(VarianteModel variant) async {
    await _variantRepository.updateVariant(variant);
  }

  @action
  Future<void> deleteVariant(String variantId) async {
    await _variantRepository.deleteVariant(variantId);
  }

  /// Update stock for a variant
  @action
  Future<void> updateVariantStock(String variantId, int newStock) async {
    await _variantRepository.updateStock(variantId, newStock);
  }

  /// Update cost price for a variant
  @action
  Future<void> updateVariantCostPrice(String variantId, double newCostPrice) async {
    await _variantRepository.updateCostPrice(variantId, newCostPrice);
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
              size: size,
              color: color,
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
  }
}