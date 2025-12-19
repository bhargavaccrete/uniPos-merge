import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:unipos/data/models/retail/hive_model/category_model_215.dart';
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/cart_model_202.dart';
import '../../../data/models/retail/hive_model/billing_tab_model.dart';
import '../../services/retail/gst_service.dart';



part 'cart_store.g.dart';

/// Result of cart operations with stock validation
class CartOperationResult {
  final bool success;
  final String? errorMessage;
  final int? availableStock;
  final int? requestedQuantity;

  CartOperationResult({
    required this.success,
    this.errorMessage,
    this.availableStock,
    this.requestedQuantity,
  });

  factory CartOperationResult.success() => CartOperationResult(success: true);

  factory CartOperationResult.outOfStock() => CartOperationResult(
        success: false,
        errorMessage: 'Item is out of stock',
        availableStock: 0,
      );

  factory CartOperationResult.insufficientStock({
    required int available,
    required int requested,
  }) =>
      CartOperationResult(
        success: false,
        errorMessage: 'Only $available items available in stock',
        availableStock: available,
        requestedQuantity: requested,
      );
}

class CartStore = _CartStore with _$CartStore;

abstract class _CartStore with Store {
  late Box<CartItemModel> _cartBox;
  late Box<BillingTabModel> _tabBox;

  _CartStore() {
    _cartBox = Hive.box<CartItemModel>('cartItems');
    _tabBox = Hive.box<BillingTabModel>('billingTabs');

    // Initialize tabs from Hive or create default tab
    if (_tabBox.isEmpty) {
      _createInitialTab();
    } else {
      tabs.addAll(_tabBox.values);
    }

    // Load cart items from the active tab
    _loadActiveTabItems();
  }

  @observable
  ObservableList<CartItemModel> items = ObservableList<CartItemModel>();

  @observable
  ObservableList<BillingTabModel> tabs = ObservableList<BillingTabModel>();

  @observable
  int activeTabIndex = 0;

  /// Create initial default tab
  void _createInitialTab() {
    final defaultTab = BillingTabModel(
      id: const Uuid().v4(),
      name: 'Tab 1',
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _tabBox.put(defaultTab.id, defaultTab);
    tabs.add(defaultTab);
  }

  /// Load items from the active tab
  void _loadActiveTabItems() {
    items.clear();
    if (tabs.isNotEmpty && activeTabIndex < tabs.length) {
      items.addAll(tabs[activeTabIndex].items);
    }
  }

  @computed
  int get itemCount => items.length;

  @computed
  int get totalItems {
    int total = 0;
    for (var item in items) {
      total += item.qty;
    }
    return total;
  }

  @computed
  double get totalPrice {
    double total = 0.0;
    for (var item in items) {
      total += item.total;
    }
    return total;
  }

  /// Total taxable amount (before GST)
  @computed
  double get totalTaxableAmount {
    double total = 0.0;
    for (var item in items) {
      total += item.taxableAmount ?? (item.price * item.qty);
    }
    return double.parse(total.toStringAsFixed(2));
  }

  /// Total GST amount
  @computed
  double get totalGstAmount {
    double total = 0.0;
    for (var item in items) {
      total += item.gstAmount ?? 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  /// Total CGST amount
  @computed
  double get totalCgstAmount {
    double total = 0.0;
    for (var item in items) {
      total += item.cgstAmount ?? 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  /// Total SGST amount
  @computed
  double get totalSgstAmount {
    double total = 0.0;
    for (var item in items) {
      total += item.sgstAmount ?? 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  /// Grand total (taxable + GST)
  @computed
  double get grandTotal {
    return double.parse((totalTaxableAmount + totalGstAmount).toStringAsFixed(2));
  }

  /// Get GST breakdown by rate
  Map<double, GstRateBreakdown> get gstBreakdown {
    final breakdown = <double, GstRateBreakdown>{};

    for (var item in items) {
      final rate = item.gstRate ?? 0;
      if (!breakdown.containsKey(rate)) {
        breakdown[rate] = GstRateBreakdown(
          gstRate: rate,
          taxableAmount: 0,
          cgstAmount: 0,
          sgstAmount: 0,
          totalGstAmount: 0,
        );
      }
      final existing = breakdown[rate]!;
      breakdown[rate] = GstRateBreakdown(
        gstRate: rate,
        taxableAmount: existing.taxableAmount + (item.taxableAmount ?? 0),
        cgstAmount: existing.cgstAmount + (item.cgstAmount ?? 0),
        sgstAmount: existing.sgstAmount + (item.sgstAmount ?? 0),
        totalGstAmount: existing.totalGstAmount + (item.gstAmount ?? 0),
      );
    }

    return breakdown;
  }

  @action
  Future<CartOperationResult> addItem(ProductModel product, VarianteModel variant, {CategoryModel? category}) async {
    final availableStock = variant.stockQty;

    // Check if the same variant is already in the cart
    final index = items.indexWhere((item) => item.variantId == variant.varianteId);
    final currentQtyInCart = index != -1 ? items[index].qty : 0;
    final requestedQty = currentQtyInCart + 1;

    // Stock validation: Check if item is out of stock
    if (availableStock <= 0) {
      return CartOperationResult.outOfStock();
    }

    // Stock validation: Check if requested quantity exceeds available stock
    if (requestedQty > availableStock) {
      return CartOperationResult.insufficientStock(
        available: availableStock,
        requested: requestedQty,
      );
    }

    // Fetch category if not provided (to get category GST rate)
    CategoryModel? effectiveCategory = category;
    if (effectiveCategory == null && product.category.isNotEmpty) {
      effectiveCategory = await categoryModelRepository.getCategoryByName(product.category);
    }

    // Get GST rate using priority: Variant > Product > Category > Default (0%)
    final effectiveGstRate = await _getEffectiveGstRate(variant, product, effectiveCategory);
    final effectiveHsnCode = _getEffectiveHsnCode(variant, product, effectiveCategory);

    // Check if tax inclusive mode is enabled
    final taxInclusive = await gstService.isTaxInclusiveMode();

    if (index != -1) {
      // Update quantity for existing item
      final item = items[index];
      final updatedQty = item.qty + 1;
      final updatedItem = CartItemModel.create(
        cartItemId: item.cartItemId,
        variantId: item.variantId,
        productId: item.productId,
        productName: item.productName,
        size: item.size,
        color: item.color,
        weight: item.weight,
        price: item.price,
        qty: updatedQty,
        barcode: item.barcode,
        gstRate: item.gstRate,
        hsnCode: item.hsnCode,
        categoryName: item.categoryName,
        taxInclusive: taxInclusive,
      );

      // Update in Hive
      await _cartBox.put(item.cartItemId, updatedItem);

      // Update in observable list - use removeAt + insert for better reactivity
      items.removeAt(index);
      items.insert(index, updatedItem);
      return CartOperationResult.success();
    }

    // If not, add it as a new item
    final cartItemId = '${variant.varianteId}_${DateTime.now().millisecondsSinceEpoch}';
    final price = variant.sellingPrice ?? variant.mrp ?? 0.0;
    final newItem = CartItemModel.create(
      cartItemId: cartItemId,
      variantId: variant.varianteId,
      productId: product.productId,
      productName: product.productName,
      size: variant.size,
      color: variant.color,
      weight: variant.weight,
      price: price,
      qty: 1,
      barcode: variant.barcode,
      gstRate: effectiveGstRate,
      hsnCode: effectiveHsnCode,
      categoryName: product.category,
      taxInclusive: taxInclusive,
    );

    // Save to Hive
    await _cartBox.put(cartItemId, newItem);

    // Add to observable list at the top
    items.insert(0, newItem);
    return CartOperationResult.success();
  }

  /// Get effective GST rate using priority: Variant > Product > Category > Default (0%)
  Future<double> _getEffectiveGstRate(VarianteModel variant, ProductModel product, CategoryModel? category) async {
    // 1. Check variant level GST
    if (variant.taxRate != null && variant.taxRate! > 0) {
      return variant.taxRate!;
    }

    // 2. Check product level GST
    if (product.gstRate != null && product.gstRate! > 0) {
      return product.gstRate!;
    }

    // 3. Check category level GST
    if (category != null && category.gstRate != null && category.gstRate! > 0) {
      return category.gstRate!;
    }

    // 4. Return default GST (0%)
    return await gstService.getDefaultGstRate();
  }

  /// Get effective HSN code using priority: Variant > Product > Category
  String? _getEffectiveHsnCode(VarianteModel variant, ProductModel product, CategoryModel? category) {
    // 1. Check variant level HSN
    if (variant.hsnCode != null && variant.hsnCode!.isNotEmpty) {
      return variant.hsnCode;
    }

    // 2. Check product level HSN
    if (product.hsnCode != null && product.hsnCode!.isNotEmpty) {
      return product.hsnCode;
    }

    // 3. Check category level HSN
    if (category != null && category.hsnCode != null && category.hsnCode!.isNotEmpty) {
      return category.hsnCode;
    }

    return null;
  }

  @action
  Future<void> removeItem(String variantId) async {
    final item = items.firstWhere(
      (item) => item.variantId == variantId,
      orElse: () => throw Exception('Item not found'),
    );

    // Remove from Hive
    await _cartBox.delete(item.cartItemId);

    // Remove from observable list
    items.removeWhere((item) => item.variantId == variantId);
  }

  @action
  Future<CartOperationResult> incrementQuantity(String variantId) async {
    final index = items.indexWhere((item) => item.variantId == variantId);
    if (index == -1) {
      return CartOperationResult(success: false, errorMessage: 'Item not found in cart');
    }

    final item = items[index];
    final requestedQty = item.qty + 1;

    // Fetch current variant stock from repository for validation
    final variant = await variantRepository.getVariantById(variantId);

    // Validate stock if variant is found
    if (variant != null) {
      final availableStock = variant.stockQty;
      if (requestedQty > availableStock) {
        return CartOperationResult.insufficientStock(
          available: availableStock,
          requested: requestedQty,
        );
      }
    }

    // Check if tax inclusive mode is enabled
    final taxInclusive = await gstService.isTaxInclusiveMode();

    final updatedItem = CartItemModel.create(
      cartItemId: item.cartItemId,
      variantId: item.variantId,
      productId: item.productId,
      productName: item.productName,
      size: item.size,
      color: item.color,
      weight: item.weight,
      price: item.price,
      qty: requestedQty,
      barcode: item.barcode,
      gstRate: item.gstRate,
      hsnCode: item.hsnCode,
      categoryName: item.categoryName,
      taxInclusive: taxInclusive,
    );

    // Update in Hive
    await _cartBox.put(item.cartItemId, updatedItem);

    // Update in observable list - use removeAt + insert for better reactivity
    items.removeAt(index);
    items.insert(index, updatedItem);
    return CartOperationResult.success();
  }

  @action
  Future<void> decrementQuantity(String variantId) async {
    final index = items.indexWhere((item) => item.variantId == variantId);
    if (index != -1) {
      final item = items[index];
      if (item.qty > 1) {
        final updatedQty = item.qty - 1;

        // Check if tax inclusive mode is enabled
        final taxInclusive = await gstService.isTaxInclusiveMode();

        final updatedItem = CartItemModel.create(
          cartItemId: item.cartItemId,
          variantId: item.variantId,
          productId: item.productId,
          productName: item.productName,
          size: item.size,
          color: item.color,
          weight: item.weight,
          price: item.price,
          qty: updatedQty,
          barcode: item.barcode,
          gstRate: item.gstRate,
          hsnCode: item.hsnCode,
          categoryName: item.categoryName,
          taxInclusive: taxInclusive,
        );

        // Update in Hive
        await _cartBox.put(item.cartItemId, updatedItem);

        // Update in observable list - use removeAt + insert for better reactivity
        items.removeAt(index);
        items.insert(index, updatedItem);
      } else {
        await removeItem(variantId);
      }
    }
  }

  @action
  Future<void> clearCart() async {
    await _cartBox.clear();
    items.clear();
  }

  /// Check if a variant is in cart
  bool isInCart(String variantId) {
    return items.any((item) => item.variantId == variantId);
  }

  /// Get quantity of a variant in cart
  int getQuantity(String variantId) {
    for (var item in items) {
      if (item.variantId == variantId) {
        return item.qty;
      }
    }
    return 0;
  }

  /// Get display name for cart item (with variant details)
  String getDisplayName(CartItemModel item) {
    final parts = <String>[item.productName];
    if (item.size != null) parts.add('Size: ${item.size}');
    if (item.color != null) parts.add('Color: ${item.color}');
    if (item.weight != null) parts.add('Weight: ${item.weight}');
    return parts.join(' - ');
  }

  /// Get available stock for a variant
  Future<int> getAvailableStock(String variantId) async {
    final variant = await variantRepository.getVariantById(variantId);
    return variant?.stockQty ?? 0;
  }

  /// Check if can add more of a variant to cart
  Future<bool> canAddMore(String variantId) async {
    final currentQty = getQuantity(variantId);
    final availableStock = await getAvailableStock(variantId);
    return currentQty < availableStock;
  }
  @action
  setactiveTab(int index){
    activeTabIndex = index;
  }

  // ==================== TAB MANAGEMENT METHODS ====================

  /// Get current active tab
  @computed
  BillingTabModel? get activeTab {
    if (tabs.isEmpty || activeTabIndex >= tabs.length) return null;
    return tabs[activeTabIndex];
  }

  /// Create a new tab
  @action
  Future<void> createNewTab() async {
    final tabNumber = tabs.length + 1;
    final newTab = BillingTabModel(
      id: const Uuid().v4(),
      name: 'Tab $tabNumber',
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to Hive
    await _tabBox.put(newTab.id, newTab);

    // Add to tabs list
    tabs.add(newTab);

    // Switch to the new tab
    activeTabIndex = tabs.length - 1;
    _loadActiveTabItems();
  }

  /// Switch to a different tab
  @action
  Future<void> switchTab(int index) async {
    if (index < 0 || index >= tabs.length) return;

    // Save current tab items before switching
    await _saveCurrentTabItems();

    // Switch to new tab
    activeTabIndex = index;
    _loadActiveTabItems();
  }

  /// Close a tab
  @action
  Future<void> closeTab(int index) async {
    if (index < 0 || index >= tabs.length) return;
    if (tabs.length <= 1) {
      // Don't allow closing the last tab, just clear it instead
      await clearCart();
      return;
    }

    final tabToClose = tabs[index];

    // Remove from Hive
    await _tabBox.delete(tabToClose.id);

    // Remove from tabs list
    tabs.removeAt(index);

    // Adjust active tab index if necessary
    if (activeTabIndex >= tabs.length) {
      activeTabIndex = tabs.length - 1;
    } else if (activeTabIndex > index) {
      activeTabIndex--;
    }

    // Load items for the new active tab
    _loadActiveTabItems();
  }

  /// Save current tab items to tab model and Hive
  Future<void> _saveCurrentTabItems() async {
    if (tabs.isEmpty || activeTabIndex >= tabs.length) return;

    final currentTab = tabs[activeTabIndex];
    final updatedTab = currentTab.copyWith(
      items: List<CartItemModel>.from(items),
      updatedAt: DateTime.now(),
    );

    // Update in Hive
    await _tabBox.put(updatedTab.id, updatedTab);

    // Update in observable list
    tabs[activeTabIndex] = updatedTab;
  }

  /// Update all cart methods to save to active tab

  @action
  Future<CartOperationResult> addItemToTab(ProductModel product, VarianteModel variant, {CategoryModel? category}) async {
    final result = await addItem(product, variant, category: category);
    if (result.success) {
      await _saveCurrentTabItems();
    }
    return result;
  }

  @action
  Future<void> removeItemFromTab(String variantId) async {
    await removeItem(variantId);
    await _saveCurrentTabItems();
  }

  @action
  Future<CartOperationResult> incrementQuantityInTab(String variantId) async {
    final result = await incrementQuantity(variantId);
    if (result.success) {
      await _saveCurrentTabItems();
    }
    return result;
  }

  @action
  Future<void> decrementQuantityInTab(String variantId) async {
    await decrementQuantity(variantId);
    await _saveCurrentTabItems();
  }

  @action
  Future<void> clearCartAndSave() async {
    await clearCart();
    await _saveCurrentTabItems();
  }

  /// Update tab customer info
  @action
  Future<void> updateTabCustomerInfo(String? name, String? phone) async {
    if (tabs.isEmpty || activeTabIndex >= tabs.length) return;

    final currentTab = tabs[activeTabIndex];
    final updatedTab = currentTab.copyWith(
      customerName: name,
      customerPhone: phone,
      updatedAt: DateTime.now(),
    );

    // Update in Hive
    await _tabBox.put(updatedTab.id, updatedTab);

    // Update in observable list
    tabs[activeTabIndex] = updatedTab;
  }

  /// Clear all tabs
  @action
  Future<void> clearAllTabs() async {
    await _tabBox.clear();
    tabs.clear();
    _createInitialTab();
    activeTabIndex = 0;
    _loadActiveTabItems();
  }


}