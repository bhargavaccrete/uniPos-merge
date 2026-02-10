import 'package:mobx/mobx.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/repositories/restaurant/cart_repository.dart';
import '../../../domain/services/restaurant/notification_service.dart';

part 'cart_store.g.dart';

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

        if (actualItem != null && actualItem.trackInventory == true) {
          final availableStock = actualItem.stockQuantity;

          // Check if item is weight-based (already validated in dialog, but double-check)
          if (!actualItem.isSoldByWeight) {
            // For unit-based items, check if we have enough quantity
            if (availableStock < item.quantity) {
              print('❌ STOCK CHECK FAILED: ${item.title} - Available: $availableStock, Requested: ${item.quantity}');
              return {
                'success': false,
                'message': 'Insufficient stock! Available: ${availableStock.toInt()} units, You requested: ${item.quantity} units'
              };
            }

            // Also check if adding this would exceed stock (if already in cart)
            final existingItem = cartItems.where((ci) => ci.productId == item.productId).firstOrNull;
            if (existingItem != null) {
              final totalNeeded = existingItem.quantity + item.quantity;
              if (totalNeeded > availableStock) {
                print('❌ STOCK CHECK FAILED: ${item.title} - Already in cart: ${existingItem.quantity}, Total needed: $totalNeeded, Available: $availableStock');
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

        if (item != null && item.trackInventory == true) {
          final availableStock = item.stockQuantity;

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