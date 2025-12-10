import 'package:hive/hive.dart';

import '../../models/restaurant/db/cartmodel_308.dart';
import '../../models/restaurant/db/itemmodel_302.dart';
import '../../models/restaurant/db/variantmodel_305.dart';

/// Repository layer for Cart data access
/// Handles all Hive database operations for cart
class CartRepository {
  static const String _boxName = 'restaurant_cart'; // Changed from 'cartItems' to avoid conflict with retail
  static const String _itemBoxName = 'itemBoxs';
  static const String _variantBoxName = 'variants';
  late Box<CartItem> _cartBox;
  late Box<Items> _itemBox;
  late Box<VariantModel> _variantBox;

  CartRepository() {
    _cartBox = Hive.box<CartItem>(_boxName);
    _itemBox = Hive.box<Items>(_itemBoxName);
    _variantBox = Hive.box<VariantModel>(_variantBoxName);
  }

  /// Get all cart items
  List<CartItem> getAllCartItems() {
    return _cartBox.values.toList();
  }

  /// Add item to cart with stock validation
  Future<Map<String, dynamic>> addToCart(CartItem item) async {
    try {
      // Check for existing item
      CartItem? existingItem;
      try {
        existingItem = _cartBox.values.firstWhere(
          (i) =>
              i.title == item.title &&
              i.variantName == item.variantName &&
              i.choiceNames.toString() == item.choiceNames.toString() &&
              i.extras.toString() == item.extras.toString() &&
              i.price == item.price &&
              i.weightDisplay == item.weightDisplay,
        );
      } catch (e) {
        existingItem = null;
      }

      // Calculate the final quantity after adding
      final int finalQuantity =
          existingItem != null ? existingItem.quantity + item.quantity : item.quantity;

      // Check stock availability
      Items? inventoryItem;
      try {
        inventoryItem = _itemBox.values.firstWhere(
          (invItem) =>
              invItem.name.toLowerCase().trim() == item.title.toLowerCase().trim(),
        );
      } catch (e) {
        // Item not found in inventory, allow adding (no inventory tracking)
        if (existingItem != null) {
          final index = _cartBox.values.toList().indexOf(existingItem);
          existingItem.quantity = finalQuantity;
          await _cartBox.putAt(index, existingItem);
        } else {
          await _cartBox.add(item);
        }
        return {'success': true, 'message': 'Item added to cart'};
      }

      // Check if inventory tracking is enabled and stock is available
      if (inventoryItem.trackInventory && !inventoryItem.allowOrderWhenOutOfStock) {
        if (item.variantName != null && inventoryItem.variant != null) {
          // Check variant stock
          try {
            final variant = inventoryItem.variant!.firstWhere(
              (v) => _variantBox.get(v.variantId)?.name == item.variantName,
            );
            final availableStock = variant.stockQuantity ?? 0;

            if (availableStock < finalQuantity) {
              return {
                'success': false,
                'message':
                    'Only ${availableStock.toInt()} ${item.title}${item.variantName != null ? " (${item.variantName})" : ""} available in stock',
                'availableStock': availableStock.toInt()
              };
            }
          } catch (e) {
            // Variant not found, continue
          }
        } else {
          // Check regular item stock
          if (inventoryItem.stockQuantity < finalQuantity) {
            return {
              'success': false,
              'message':
                  'Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock',
              'availableStock': inventoryItem.stockQuantity.toInt()
            };
          }
        }
      }

      // If all checks pass, add/update the item
      if (existingItem != null) {
        final index = _cartBox.values.toList().indexOf(existingItem);
        existingItem.quantity = finalQuantity;
        await _cartBox.putAt(index, existingItem);
      } else {
        await _cartBox.add(item);
      }

      return {'success': true, 'message': 'Item added to cart'};
    } catch (e) {
      return {'success': false, 'message': 'Error adding item to cart'};
    }
  }

  /// Remove item from cart by id
  Future<void> removeFromCart(String itemId) async {
    try {
      final itemToDelete = _cartBox.values.firstWhere((item) => item.id == itemId);
      final index = _cartBox.values.toList().indexOf(itemToDelete);
      await _cartBox.deleteAt(index);
    } catch (e) {
      rethrow;
    }
  }

  /// Update quantity of a cart item
  Future<void> updateQuantity(String itemId, int newQuantity) async {
    try {
      final item = _cartBox.values.firstWhere((item) => item.id == itemId);
      final index = _cartBox.values.toList().indexOf(item);
      item.quantity = newQuantity;
      await _cartBox.putAt(index, item);
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all cart items
  Future<void> clearCart() async {
    await _cartBox.clear();
  }

  /// Get cart item count
  int getCartItemCount() {
    return _cartBox.length;
  }

  /// Get total quantity of items in cart
  int getTotalQuantity() {
    int total = 0;
    for (var item in _cartBox.values) {
      total += item.quantity;
    }
    return total;
  }

  /// Get cart total price
  double getCartTotal() {
    double total = 0.0;
    for (var item in _cartBox.values) {
      total += item.price * item.quantity;
    }
    return total;
  }

  /// Get cart total with tax
  double getCartTotalWithTax() {
    double total = 0.0;
    for (var item in _cartBox.values) {
      double itemTotal = item.price * item.quantity;
      if (item.taxRate != null) {
        itemTotal += itemTotal * item.taxRate!;
      }
      total += itemTotal;
    }
    return total;
  }

  /// Get total tax amount
  double getTotalTax() {
    double totalTax = 0.0;
    for (var item in _cartBox.values) {
      if (item.taxRate != null) {
        totalTax += (item.price * item.quantity) * item.taxRate!;
      }
    }
    return totalTax;
  }

  /// Check if cart is empty
  bool get isEmpty => _cartBox.isEmpty;

  /// Get cart item by id
  CartItem? getCartItemById(String id) {
    try {
      return _cartBox.values.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}