import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/repositories/restaurant/cart_repository.dart';
import '../../../domain/services/restaurant/notification_service.dart';
import '../../../domain/services/restaurant/inventory_service.dart';

part 'cart_store.g.dart';

/// What the menu needs to know about ONE product's presence in the cart.
///
/// Compared by value, which is the whole point: the per-product derivation in
/// [_CartStore.cartStateFor] only notifies its observers when the value it
/// produces actually differs, so a cart write rebuilds the tiles of the item
/// that changed rather than every tile on the menu.
@immutable
class ProductCartState {
  /// Total units of this product across every cart line.
  final int quantity;

  /// One "Large ×2" label per cart line, in cart order — empty when none of
  /// the lines carries a variant name, which is what tells the menu to show a
  /// plain count instead of a breakdown.
  final List<String> variantBreakdown;

  const ProductCartState({
    required this.quantity,
    required this.variantBreakdown,
  });

  static const ProductCartState empty =
      ProductCartState(quantity: 0, variantBreakdown: <String>[]);

  bool get inCart => quantity > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCartState &&
          other.quantity == quantity &&
          listEquals(other.variantBreakdown, variantBreakdown);

  @override
  int get hashCode => Object.hash(quantity, Object.hashAll(variantBreakdown));
}

class CartStoreRes = _CartStore with _$CartStoreRes;

abstract class _CartStore with Store {
  final CartRepository _repository;

  _CartStore(this._repository);

  @observable
  ObservableList<CartItem> cartItems = ObservableList<CartItem>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // Computed properties
  @computed
  double get cartTotal =>
      cartItems.fold<double>(0.0, (double sum, item) => sum + (item.price * item.quantity));

  @computed
  int get totalItems => cartItems.length;

  @computed
  int get totalQuantity =>
      cartItems.fold<int>(0, (int sum, item) => sum + item.quantity);

  @computed
  bool get isEmpty => cartItems.isEmpty;

  @computed
  bool get isNotEmpty => cartItems.isNotEmpty;

  /// One memoised derivation per product id. Sequencing/derivation state only
  /// — never a cached value: each entry re-reads [cartItems] when asked.
  final Map<String, Computed<ProductCartState>> _productCartStates = {};

  /// This product's cart state, as a MobX derivation an item tile can observe
  /// on its own.
  ///
  /// Every cart write invalidates every entry here, but MobX only notifies the
  /// observers whose value CHANGED, so adding one item rebuilds that item's
  /// tiles instead of the category sections around them. Reading the whole
  /// `cartItems` list inside a tile would defeat that — the list is one
  /// observable, so every reader of it reacts to every cart write.
  Computed<ProductCartState> cartStateFor(String productId) =>
      _productCartStates.putIfAbsent(
        productId,
        () => Computed(
          () => _cartStateOf(productId),
          name: 'CartStoreRes.cartStateFor($productId)',
        ),
      );

  ProductCartState _cartStateOf(String productId) {
    var quantity = 0;
    var hasVariantLine = false;
    final labels = <String>[];
    for (final line in cartItems) {
      if (line.productId != productId) continue;
      quantity += line.quantity;
      final variantName = line.variantName ?? '';
      if (variantName.isNotEmpty) hasVariantLine = true;
      labels.add('${variantName.isNotEmpty ? variantName : 'Regular'} ×${line.quantity}');
    }
    if (quantity == 0) return ProductCartState.empty;
    return ProductCartState(
      quantity: quantity,
      // Mirrors what the menu showed before: a breakdown only once some line
      // of this product was added with a variant.
      variantBreakdown: hasVariantLine ? labels : const <String>[],
    );
  }

  // Actions
  @action
  Future<void> loadCartItems() async {
    try {
      isLoading = true;
      errorMessage = null;
      final items = await _repository.getAllCartItems();
      cartItems = ObservableList.of(items);
    } catch (e) {
      errorMessage = 'Failed to load cart items: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadCartItems();
  }

  @action
  Future<Map<String, dynamic>> addToCart(CartItem item) async {
    try {
      // ✅ VALIDATION: Check stock availability before adding
      if (item.isStockManaged == true) {
        // Get the actual item to check stock
        final actualItem = await itemStore.getItemById(item.productId);

        if (actualItem != null &&
            InventoryService.isStockGoverned(actualItem) &&
            !actualItem.allowOrderWhenOutOfStock) {
          double availableStock;

          // ✅ FIX: For items with variants, check variant stock, not base stock
          // (Recipe-Based skips this: v1 recipes are item-level, so its
          // availability always comes from ingredients — see effectiveAvailableStock.)
          if (!actualItem.isRecipeBased &&
              item.variantName != null &&
              actualItem.variant != null &&
              actualItem.variant!.isNotEmpty) {
            // Item has variants - check variant stock
            try {
              // Load only if not yet loaded (lazy store); writes keep it current.
              if (variantStore.variants.isEmpty) await variantStore.loadVariants();
              final itemVariant = actualItem.variant!.firstWhere(
                (v) {
                  final variantDetails = variantStore.variants.where((vd) => vd.id == v.variantId).firstOrNull;
                  return variantDetails?.name == item.variantName;
                },
              );
              availableStock = itemVariant.stockQuantity ?? 0;
            } catch (e) {
              return {
                'success': false,
                'message': 'Variant "${item.variantName}" not found'
              };
            }
          } else {
            // No variants - use base item stock (or recipe availability)
            availableStock = InventoryService.effectiveAvailableStock(actualItem);
          }

          // Check if item is weight-based (already validated in dialog, but double-check)
          if (!actualItem.isSoldByWeight) {
            // For unit-based items, check if we have enough quantity
            if (availableStock < item.quantity) {
              return {
                'success': false,
                'message': 'Insufficient stock! Available: ${availableStock.toInt()} units, You requested: ${item.quantity} units'
              };
            }

            // Also check if adding this would exceed stock (if already in cart)
            final existingItem = cartItems.where((ci) =>
              ci.productId == item.productId &&
              ci.variantName == item.variantName
            ).firstOrNull;
            if (existingItem != null) {
              final totalNeeded = existingItem.quantity + item.quantity;
              if (totalNeeded > availableStock) {
                return {
                  'success': false,
                  'message': 'Insufficient stock! Available: ${availableStock.toInt()} units, In cart: ${existingItem.quantity}, Total needed: $totalNeeded units'
                };
              }
            }
          }
        }
      }

      // If validation passed, add to cart
      final result = await _repository.addToCart(item);
      if (result['success'] == true) {
        await loadCartItems(); // Reload to reflect changes
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to add item to cart: $e';
      return {'success': false, 'message': errorMessage};
    }
  }

  @action
  Future<bool> removeFromCart(String itemId) async {
    try {
      await _repository.removeFromCart(itemId);
      cartItems.removeWhere((item) => item.id == itemId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to remove item from cart: $e';
      return false;
    }
  }

  @action
  Future<bool> updateQuantity(String itemId, int newQuantity) async {
    try {
      if (newQuantity <= 0) {
        return await removeFromCart(itemId);
      }

      // ✅ VALIDATION: Check stock for both weight-based and unit-based items
      final index = cartItems.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        final cartItem = cartItems[index];

        // Get the actual item to check stock
        final item = await itemStore.getItemById(cartItem.productId);

        if (item != null &&
            InventoryService.isStockGoverned(item) &&
            !item.allowOrderWhenOutOfStock) {
          double availableStock;

          // ✅ FIX: For items with variants, check variant stock, not base stock
          if (!item.isRecipeBased &&
              cartItem.variantName != null &&
              item.variant != null &&
              item.variant!.isNotEmpty) {
            // Item has variants - check variant stock
            try {
              // Load only if not yet loaded (lazy store); writes keep it current.
              if (variantStore.variants.isEmpty) await variantStore.loadVariants();
              final itemVariant = item.variant!.firstWhere(
                (v) {
                  final variantDetails = variantStore.variants.where((vd) => vd.id == v.variantId).firstOrNull;
                  return variantDetails?.name == cartItem.variantName;
                },
              );
              availableStock = itemVariant.stockQuantity ?? 0;
            } catch (e) {
              NotificationService.instance.showError('Variant "${cartItem.variantName}" not found');
              return false;
            }
          } else {
            // No variants - use base item stock (or recipe availability)
            availableStock = InventoryService.effectiveAvailableStock(item);
          }

          if (item.isSoldByWeight == true) {
            // WEIGHT-BASED ITEMS
            // Extract weight from weightDisplay (e.g., "5.0KG" -> 5.0)
            double weight = 0.0;
            if (cartItem.weightDisplay != null) {
              final weightStr = cartItem.weightDisplay!.replaceAll(RegExp(r'[^0-9.]'), '');
              weight = double.tryParse(weightStr) ?? 0.0;
            }

            // Calculate total weight needed
            final totalWeightNeeded = newQuantity * weight;

            // Check if there's enough stock
            if (totalWeightNeeded > availableStock) {
              NotificationService.instance.showError(
                'Insufficient stock!\n'
                'You need: $totalWeightNeeded ${item.unit ?? "kg"}\n'
                'Available: $availableStock ${item.unit ?? "kg"}'
              );
              return false;
            }
          } else {
            // UNIT-BASED ITEMS
            // Check if new quantity exceeds available stock
            if (newQuantity > availableStock) {
              NotificationService.instance.showError(
                'Insufficient stock for ${item.name}!\n'
                'Available: ${availableStock.toInt()} units\n'
                'You requested: $newQuantity units'
              );
              return false;
            }
          }
        }

        // If validation passed, update quantity
        await _repository.updateQuantity(itemId, newQuantity);
        cartItems[index].quantity = newQuantity;
        cartItems = ObservableList.of(cartItems); // Trigger update
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update quantity: $e';
      return false;
    }
  }

  @action
  Future<bool> clearCart() async {
    try {
      await _repository.clearCart();
      cartItems.clear();
      return true;
    } catch (e) {
      errorMessage = 'Failed to clear cart: $e';
      return false;
    }
  }

  @action
  Future<int> getCartItemCount() async {
    try {
      return await _repository.getCartItemCount();
    } catch (e) {
      errorMessage = 'Failed to get cart item count: $e';
      return 0;
    }
  }

  @action
  Future<double> getCartTotal() async {
    try {
      return await _repository.getCartTotal();
    } catch (e) {
      errorMessage = 'Failed to calculate cart total: $e';
      return 0.0;
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}