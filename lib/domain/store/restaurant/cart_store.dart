import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/repositories/restaurant/cart_repository.dart';

part 'cart_store.g.dart';

class CartStore = _CartStore with _$CartStore;

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

      await _repository.updateQuantity(itemId, newQuantity);
      final index = cartItems.indexWhere((item) => item.id == itemId);
      if (index != -1) {
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