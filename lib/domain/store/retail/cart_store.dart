import 'package:mobx/mobx.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tax_feature.dart';
import '../../../data/models/retail/hive_model/cart_model_202.dart';
import '../../../data/models/retail/hive_model/billing_tab_model_173.dart';
import '../../../data/repositories/retail/cart_repository.dart';
import '../../services/retail/gst_service.dart';
import '../../services/retail/retail_billing_service.dart';



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
  final CartRepository _repository;

  _CartStore(this._repository) {
    // Restore saved tabs, or create the default one on a fresh install
    final savedTabs = _repository.getAllTabs();
    if (savedTabs.isEmpty) {
      _createInitialTab();
    } else {
      tabs.addAll(savedTabs);
    }

    // Load cart items from the active tab
    _loadActiveTabItems();

    // Tax mode lives in SharedPreferences, so it can't be read synchronously
    // here. Load it in the background; `bill` recomputes when it lands.
    loadTaxMode();
  }

  @observable
  ObservableList<CartItemModel> items = ObservableList<CartItemModel>();

  @observable
  ObservableList<BillingTabModel> tabs = ObservableList<BillingTabModel>();

  @observable
  int activeTabIndex = 0;

  // ==================== BILLING INPUTS ====================
  // The inputs to the bill live here rather than in a screen, so the POS
  // footer, checkout and receipt all read the same numbers.

  /// Retail's own tax-inclusive setting (GstService), NOT the restaurant
  /// AppSettings toggle — they are separate keys.
  @observable
  bool isTaxInclusive = false;

  @observable
  DiscountType discountType = DiscountType.amount;

  /// Raw discount input as typed. The engine clamps it to the bill.
  @observable
  double discountValue = 0;

  /// Currency value of loyalty points being redeemed.
  @observable
  double loyaltyRedemption = 0;

  /// The single source of truth for every money figure in retail.
  ///
  /// MobX memoises this, so reading it repeatedly in a build is free; it only
  /// recomputes when the cart or a billing input actually changes.
  ///
  /// Note: it also reads `AppSettings.roundOff` and `TaxFeature.enabled`, which
  /// are not observables — changing those mid-bill won't invalidate this. They
  /// are set in settings screens that rebuild anyway.
  @computed
  RetailBill get bill => RetailBillingService.compute(
        items: items,
        isTaxInclusive: isTaxInclusive,
        discountType: discountType,
        discountValue: discountValue,
        loyaltyRedemption: loyaltyRedemption,
      );

  @action
  Future<void> loadTaxMode() async {
    isTaxInclusive = await RetailBillingService.loadTaxInclusive();
  }

  @action
  void setDiscount({DiscountType? type, double? value}) {
    if (type != null) discountType = type;
    if (value != null) discountValue = value;
  }

  @action
  void setLoyaltyRedemption(double value) {
    loyaltyRedemption = value < 0 ? 0 : value;
  }

  /// Reset the bill inputs. Must run whenever we move to a different sale —
  /// clearing the cart or switching tabs — or a discount silently carries over
  /// onto the next customer's bill.
  @action
  void resetBillingInputs() {
    discountType = DiscountType.amount;
    discountValue = 0;
    loyaltyRedemption = 0;
  }

  /// Create initial default tab
  void _createInitialTab() {
    final defaultTab = BillingTabModel(
      id: const Uuid().v4(),
      name: 'Tab 1',
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _repository.saveTab(defaultTab);
    tabs.add(defaultTab);
  }

  /// Load items from the active tab.
  ///
  /// This is the one choke point for "the active sale changed", so the bill
  /// inputs reset here too — a discount typed on Tab 1 must not follow you to
  /// Tab 2.
  void _loadActiveTabItems() {
    items.clear();
    if (tabs.isNotEmpty && activeTabIndex < tabs.length) {
      items.addAll(tabs[activeTabIndex].items);
    }
    resetBillingInputs();
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

  /// Add [variant] to the cart.
  ///
  /// [priceOverride]/[gstRateOverride]/[qty] exist for restoring a parked sale:
  /// the bill was frozen when it was parked, so it must be replayed at the
  /// parked figures rather than re-priced from whatever the rates are now.
  @action
  Future<CartOperationResult> addItem(
    ProductModel product,
    VarianteModel variant, {
    Category? category,
    double? priceOverride,
    double? gstRateOverride,
    int qty = 1,
  }) async {
    final availableStock = variant.stockQty;

    // Check if the same variant is already in the cart
    final index = items.indexWhere((item) => item.variantId == variant.varianteId);
    final currentQtyInCart = index != -1 ? items[index].qty : 0;
    final requestedQty = currentQtyInCart + qty;

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

    // Fetch category if not provided (to resolve its display name for the receipt)
    Category? effectiveCategory = category;
    if (effectiveCategory == null && product.category.isNotEmpty) {
      effectiveCategory = categoryStore.getCategoryById(product.category) ??
                          await categoryRepository.getCategoryById(product.category);
    }
    final categoryDisplayName = effectiveCategory?.name ?? product.category;

    // Get GST rate using priority: Variant > Product > Default (0%). GST/HSN
    // live on the product/variant, not the category (a category can contain
    // items with different tax classes — e.g. cotton vs synthetic garments).
    final effectiveGstRate =
        gstRateOverride ?? await _getEffectiveGstRate(variant, product);
    final effectiveHsnCode = _getEffectiveHsnCode(variant, product);

    // Check if tax inclusive mode is enabled
    final taxInclusive = await gstService.isTaxInclusiveMode();

    if (index != -1) {
      // Update quantity for existing item
      final item = items[index];
      final updatedQty = item.qty + qty;
      final updatedItem = CartItemModel.create(
        cartItemId: item.cartItemId,
        variantId: item.variantId,
        productId: item.productId,
        productName: item.productName,
        attributes: item.attributes,
        price: item.price,
        qty: updatedQty,
        barcode: item.barcode,
        gstRate: item.gstRate,
        hsnCode: item.hsnCode,
        categoryName: item.categoryName,
        taxInclusive: taxInclusive,
      );

      await _repository.saveCartItem(updatedItem);

      // Update in observable list - use removeAt + insert for better reactivity
      items.removeAt(index);
      items.insert(index, updatedItem);
      return CartOperationResult.success();
    }

    // If not, add it as a new item
    final cartItemId = '${variant.varianteId}_${DateTime.now().millisecondsSinceEpoch}';
    final price = priceOverride ?? variant.sellingPrice ?? variant.mrp ?? 0.0;
    final newItem = CartItemModel.create(
      cartItemId: cartItemId,
      variantId: variant.varianteId,
      productId: product.productId,
      productName: product.productName,
      // Capture ALL descriptors, not just the three legacy columns, so a
      // configured attribute (Flavour, Storage…) survives into the sale.
      attributes: attributeStore.attributesOf(variant),
      price: price,
      qty: qty,
      barcode: variant.barcode,
      gstRate: effectiveGstRate,
      hsnCode: effectiveHsnCode,
      categoryName: categoryDisplayName,
      taxInclusive: taxInclusive,
    );

    await _repository.saveCartItem(newItem);

    // Add to observable list at the top
    items.insert(0, newItem);
    return CartOperationResult.success();
  }

  /// Get effective GST rate using priority: Variant > Product > Default (0%)
  Future<double> _getEffectiveGstRate(VarianteModel variant, ProductModel product) async {
    if (!TaxFeature.enabled) return 0;

    // 1. Check variant level GST
    if (variant.taxRate != null && variant.taxRate! > 0) {
      return variant.taxRate!;
    }

    // 2. Check product level GST
    if (product.gstRate != null && product.gstRate! > 0) {
      return product.gstRate!;
    }

    // 3. Return default GST (0%)
    return await gstService.getDefaultGstRate();
  }

  /// Get effective HSN code using priority: Variant > Product
  String? _getEffectiveHsnCode(VarianteModel variant, ProductModel product) {
    // 1. Check variant level HSN
    if (variant.hsnCode != null && variant.hsnCode!.isNotEmpty) {
      return variant.hsnCode;
    }

    // 2. Check product level HSN
    if (product.hsnCode != null && product.hsnCode!.isNotEmpty) {
      return product.hsnCode;
    }

    return null;
  }

  @action
  Future<void> removeItem(String variantId) async {
    // Idempotent: if the item is already gone (rapid double-tap, or
    // decrementQuantity removing the last unit), no-op instead of throwing.
    final index = items.indexWhere((item) => item.variantId == variantId);
    if (index == -1) return;

    final item = items[index];

    await _repository.deleteCartItem(item.cartItemId);

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
      attributes: item.attributes,
      price: item.price,
      qty: requestedQty,
      barcode: item.barcode,
      gstRate: item.gstRate,
      hsnCode: item.hsnCode,
      categoryName: item.categoryName,
      taxInclusive: taxInclusive,
    );

    await _repository.saveCartItem(updatedItem);

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
          attributes: item.attributes,
          price: item.price,
          qty: updatedQty,
          barcode: item.barcode,
          gstRate: item.gstRate,
          hsnCode: item.hsnCode,
          categoryName: item.categoryName,
          taxInclusive: taxInclusive,
        );

        await _repository.saveCartItem(updatedItem);

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
    await _repository.clearCartItems();
    items.clear();
    // The sale is over — drop the discount/loyalty so they can't leak onto
    // the next customer.
    resetBillingInputs();
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

  /// Get display name for cart item (with variant details).
  ///
  /// Reads the item's own stored attributes, falling back to the legacy
  /// columns for lines added before generic attributes existed.
  String getDisplayName(CartItemModel item) {
    final descriptor = attributeStore.describeAttributes(
      item.attributes,
      separator: ' - ',
    );
    return descriptor.isEmpty
        ? item.productName
        : '${item.productName} - $descriptor';
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

  /// Label for the tab at [index] — a customer name once one is attached,
  /// otherwise its 1-based position.
  ///
  /// Derived from POSITION rather than the stored `name`, because that name is
  /// stamped once at creation and never revisited. Closing a middle tab left
  /// "Tab 1, Tab 3" on screen, and since [createNewTab] numbers by
  /// `tabs.length + 1` the next New button then minted a SECOND "Tab 3".
  /// Numbering is a function of order, so it is computed, not stored.
  String tabLabel(int index) {
    if (index >= 0 && index < tabs.length) {
      final customer = tabs[index].customerName;
      if (customer != null && customer.isNotEmpty) return customer;
    }
    return 'Tab ${index + 1}';
  }

  /// Create a new tab
  @action
  Future<void> createNewTab() async {
    // Persist the current tab's cart before switching away from it,
    // otherwise its items never make it into its BillingTabModel and
    // _loadActiveTabItems() below wipes them from view.
    await _saveCurrentTabItems();

    final tabNumber = tabs.length + 1;
    final newTab = BillingTabModel(
      id: const Uuid().v4(),
      name: 'Tab $tabNumber',
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.saveTab(newTab);

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

    await _repository.deleteTab(tabToClose.id);

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

    await _repository.saveTab(updatedTab);

    // Update in observable list
    tabs[activeTabIndex] = updatedTab;
  }

  /// Update all cart methods to save to active tab

  @action
  Future<CartOperationResult> addItemToTab(ProductModel product, VarianteModel variant, {Category? category}) async {
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

    await _repository.saveTab(updatedTab);

    // Update in observable list
    tabs[activeTabIndex] = updatedTab;
  }

  /// Clear all tabs
  @action
  Future<void> clearAllTabs() async {
    await _repository.clearTabs();
    tabs.clear();
    _createInitialTab();
    activeTabIndex = 0;
    _loadActiveTabItems();
  }


}