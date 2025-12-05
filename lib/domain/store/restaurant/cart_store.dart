
import 'package:mobx/mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/repositories/restaurant/cart_repository.dart';

part 'cart_store.g.dart';

class CartStorer = _CartStorer with _$CartStorer;

abstract class _CartStorer with Store{
  final CartRepository _cartRepository = locator<CartRepository>();

  // Using final to avoid InvalidType code generation issue
  final ObservableList<CartItem> cartItems = ObservableList<CartItem>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? lastOperationMessage;

  _CartStorer() {
    _init();
  }

  Future<void> _init() async {
    await loadCartItems();
  }

  // ==================== COMPUTED ====================

  @computed
  int get itemCount => cartItems.length;

  @computed
  int get totalQuantity {
    int total = 0;
    for (var item in cartItems) {
      total += item.quantity;
    }
    return total;
  }

  @computed
  double get subtotal {
    double total = 0.0;
    for (var item in cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  @computed
  double get totalTax {
    double tax = 0.0;
    for (var item in cartItems) {
      if (item.taxRate != null) {
        tax += (item.price * item.quantity) * item.taxRate!;
      }
    }
    return tax;
  }

  @computed
  double get totalDiscount {
    double discount = 0.0;
    for (var item in cartItems) {
      if (item.discount != null) {
        discount += item.discount! * item.quantity;
      }
    }
    return discount;
  }

  @computed
  double get grandTotal => subtotal + totalTax - totalDiscount;

  @computed
  bool get isEmpty => cartItems.isEmpty;

  @computed
  bool get isNotEmpty => cartItems.isNotEmpty;

  // ==================== ACTIONS ====================

  @action
  Future<void> loadCartItems() async {
    isLoading = true;
    errorMessage = null;
    try {
      final items = _cartRepository.getAllCartItems();
      cartItems.clear();
      cartItems.addAll(items);
    } catch (e) {
      errorMessage = 'Failed to load cart: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<Map<String, dynamic>> addToCart(CartItem item) async {
    try {
      final result = await _cartRepository.addToCart(item);
      if (result['success'] == true) {
        await loadCartItems(); // Reload to get updated state
        lastOperationMessage = result['message'];
      } else {
        lastOperationMessage = result['message'];
        errorMessage = result['message'];
      }
      return result;
    } catch (e) {
      errorMessage = 'Failed to add item to cart: $e';
      return {'success': false, 'message': 'Failed to add item to cart: $e'};
    }
  }

  @action
  Future<void> removeFromCart(String itemId) async {
    try {
      await _cartRepository.removeFromCart(itemId);
      cartItems.removeWhere((item) => item.id == itemId);
      lastOperationMessage = 'Item removed from cart';
    } catch (e) {
      errorMessage = 'Failed to remove item: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateQuantity(String itemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(itemId);
      return;
    }
    try {
      await _cartRepository.updateQuantity(itemId, newQuantity);
      final index = cartItems.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        final item = cartItems[index];
        cartItems[index] = item.copyWith(quantity: newQuantity);
      }
    } catch (e) {
      errorMessage = 'Failed to update quantity: $e';
      rethrow;
    }
  }

  @action
  Future<void> incrementQuantity(String itemId) async {
    final item = getCartItemById(itemId);
    if (item != null) {
      await updateQuantity(itemId, item.quantity + 1);
    }
  }

  @action
  Future<void> decrementQuantity(String itemId) async {
    final item = getCartItemById(itemId);
    if (item != null) {
      await updateQuantity(itemId, item.quantity - 1);
    }
  }

  @action
  Future<void> clearCart() async {
    try {
      await _cartRepository.clearCart();
      cartItems.clear();
      lastOperationMessage = 'Cart cleared';
    } catch (e) {
      errorMessage = 'Failed to clear cart: $e';
      rethrow;
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void clearLastMessage() {
    lastOperationMessage = null;
  }

  // ==================== HELPERS ====================

  CartItem? getCartItemById(String id) {
    try {
      return cartItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  List<CartItem> getItemsByCategory(String categoryName) {
    return cartItems.where((item) => item.categoryName == categoryName).toList();
  }

  /// Get cart items as a list of maps (for order creation)
  List<Map<String, dynamic>> toMapList() {
    return cartItems.map((item) => item.toMap()).toList();
  }
}