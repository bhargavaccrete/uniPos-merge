// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ProductStore on _ProductStore, Store {
  late final _$productsAtom =
      Atom(name: '_ProductStore.products', context: context);

  @override
  ObservableList<ProductModel> get products {
    _$productsAtom.reportRead();
    return super.products;
  }

  @override
  set products(ObservableList<ProductModel> value) {
    _$productsAtom.reportWrite(value, super.products, () {
      super.products = value;
    });
  }

  late final _$loadProductsAsyncAction =
      AsyncAction('_ProductStore.loadProducts', context: context);

  @override
  Future<void> loadProducts() {
    return _$loadProductsAsyncAction.run(() => super.loadProducts());
  }

  late final _$addProductAsyncAction =
      AsyncAction('_ProductStore.addProduct', context: context);

  @override
  Future<void> addProduct(ProductModel product) {
    return _$addProductAsyncAction.run(() => super.addProduct(product));
  }

  late final _$updateProductAsyncAction =
      AsyncAction('_ProductStore.updateProduct', context: context);

  @override
  Future<void> updateProduct(ProductModel product) {
    return _$updateProductAsyncAction.run(() => super.updateProduct(product));
  }

  late final _$deleteProductAsyncAction =
      AsyncAction('_ProductStore.deleteProduct', context: context);

  @override
  Future<void> deleteProduct(String productId) {
    return _$deleteProductAsyncAction.run(() => super.deleteProduct(productId));
  }

  late final _$addVariantAsyncAction =
      AsyncAction('_ProductStore.addVariant', context: context);

  @override
  Future<void> addVariant(VarianteModel variant) {
    return _$addVariantAsyncAction.run(() => super.addVariant(variant));
  }

  late final _$updateVariantAsyncAction =
      AsyncAction('_ProductStore.updateVariant', context: context);

  @override
  Future<void> updateVariant(VarianteModel variant) {
    return _$updateVariantAsyncAction.run(() => super.updateVariant(variant));
  }

  late final _$deleteVariantAsyncAction =
      AsyncAction('_ProductStore.deleteVariant', context: context);

  @override
  Future<void> deleteVariant(String variantId) {
    return _$deleteVariantAsyncAction.run(() => super.deleteVariant(variantId));
  }

  late final _$updateVariantStockAsyncAction =
      AsyncAction('_ProductStore.updateVariantStock', context: context);

  @override
  Future<void> updateVariantStock(String variantId, int newStock) {
    return _$updateVariantStockAsyncAction
        .run(() => super.updateVariantStock(variantId, newStock));
  }

  late final _$updateVariantCostPriceAsyncAction =
      AsyncAction('_ProductStore.updateVariantCostPrice', context: context);

  @override
  Future<void> updateVariantCostPrice(String variantId, double newCostPrice) {
    return _$updateVariantCostPriceAsyncAction
        .run(() => super.updateVariantCostPrice(variantId, newCostPrice));
  }

  late final _$clearAllDataAsyncAction =
      AsyncAction('_ProductStore.clearAllData', context: context);

  @override
  Future<void> clearAllData() {
    return _$clearAllDataAsyncAction.run(() => super.clearAllData());
  }

  @override
  String toString() {
    return '''
products: ${products}
    ''';
  }
}
