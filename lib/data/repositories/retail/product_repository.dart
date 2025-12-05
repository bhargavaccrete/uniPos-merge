import 'package:hive/hive.dart';
import '../../models/retail/hive_model/product_model_200.dart';
import '../../models/retail/hive_model/variante_model_201.dart';

/// Repository layer for Product data access
/// Handles all Hive database operations for products
/// Works directly with ProductModel (no Product model needed)
class ProductRepository {
  late Box<ProductModel> _productBox;
  late Box<VarianteModel> _variantBox;

  ProductRepository() {
    _productBox = Hive.box<ProductModel>('products');
    _variantBox = Hive.box<VarianteModel>('variants');
  }

  /// Get all products from Hive
  Future<List<ProductModel>> getAllProducts() async {
    print('ProductRepository.getAllProducts: _productBox has ${_productBox.length} items');
    print('ProductRepository.getAllProducts: _productBox.values = ${_productBox.values.map((p) => p.productName).toList()}');
    return _productBox.values.toList();
  }

  /// Add a new product to Hive
  Future<void> addProduct(ProductModel product) async {
    print('ProductRepository.addProduct: Saving product ${product.productName} with ID ${product.productId}');
    await _productBox.put(product.productId, product);
    print('ProductRepository.addProduct: _productBox now has ${_productBox.length} items');
  }

  /// Update an existing product in Hive
  Future<void> updateProduct(ProductModel product) async {
    await _productBox.put(product.productId, product);
  }

  /// Delete a product from Hive
  /// Also deletes all associated variants
  Future<void> deleteProduct(String productId) async {
    // Delete the product
    await _productBox.delete(productId);

    // Delete all variants for this product
    final variantsToDelete = _variantBox.values
        .where((variant) => variant.productId == productId)
        .toList();

    for (var variant in variantsToDelete) {
      await _variantBox.delete(variant.varianteId);
    }
  }

  /// Get a product by ID
  Future<ProductModel?> getProductById(String productId) async {
    return _productBox.get(productId);
  }

  /// Find product by searching through variants' barcodes
  Future<ProductModel?> findByBarcode(String barcode) async {
    try {
      final variant = _variantBox.values.firstWhere(
        (v) => v.barcode == barcode,
      );

      return _productBox.get(variant.productId);
    } catch (e) {
      return null;
    }
  }

  /// Check if product exists
  Future<bool> productExists(String productId) async {
    return _productBox.containsKey(productId);
  }

  /// Get products by category
  Future<List<ProductModel>> getProductsByCategory(String category) async {
    return _productBox.values
        .where((p) => p.category == category)
        .toList();
  }

  /// Get products with variants
  Future<List<ProductModel>> getProductsWithVariants() async {
    return _productBox.values
        .where((p) => p.hasVariants == true)
        .toList();
  }

  /// Get products without variants
  Future<List<ProductModel>> getProductsWithoutVariants() async {
    return _productBox.values
        .where((p) => p.hasVariants == false)
        .toList();
  }

  /// Get variants for a specific product
  Future<List<VarianteModel>> getVariantsForProduct(String productId) async {
    return _variantBox.values
        .where((v) => v.productId == productId)
        .toList();
  }

  /// Clear all products
  Future<void> clearAll() async {
    await _productBox.clear();
  }

  /// Get total product count
  int getProductCount() {
    return _productBox.length;
  }
}