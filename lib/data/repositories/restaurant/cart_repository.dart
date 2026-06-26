import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/cartmodel_308.dart';
import '../../models/restaurant/db/itemmodel_302.dart';
import '../../models/restaurant/db/variantmodel_305.dart';

/// Repository layer for Cart data access (Restaurant)
/// Handles all Hive database operations for cart items
class CartRepository {
  late Box<CartItem> _cartBox;
  late Box<Items> _itemBox;
  late Box<VariantModel> _variantBox;

  CartRepository() {
    _cartBox = Hive.box<CartItem>('cart_box');
    _itemBox = Hive.box<Items>('itemBoxs');
    _variantBox = Hive.box<VariantModel>('variante');
  }

  /// Add item to cart with stock validation
  Future<Map<String, dynamic>> addToCart(CartItem item) async {
    try {
      // Check for existing item
      CartItem? existingItem;
      try {
        existingItem = _cartBox.values.firstWhere((i) => i == item);
      } catch (e) {
        existingItem = null;
      }

      // Calculate the final quantity after adding
      final int finalQuantity = existingItem != null
          ? existingItem.quantity + item.quantity
          : item.quantity;

      // Check stock availability
      Items? inventoryItem;

      try {
        // ✅ FIX: Get fresh item data from Hive, not cached values
        // First try to find by productId if available
        if (item.productId.isNotEmpty) {
          inventoryItem = _itemBox.get(item.productId);
        }

        // If not found by ID, try by title (item name)
        if (inventoryItem == null) {
          inventoryItem = _itemBox.values.firstWhere(
            (invItem) =>
                invItem.name.toLowerCase().trim() ==
                item.title.toLowerCase().trim(),
          );
        }
      } catch (e) {
        // Item not found in inventory database, reject addition to prevent stock bypass.
        return {'success': false, 'message': 'Item not found in inventory database'};
      }

      // Check if inventory tracking is enabled and stock is available
      if (inventoryItem != null && inventoryItem.trackInventory) {
        if (!inventoryItem.allowOrderWhenOutOfStock) {
          // Check stock availability
          if (item.variantName != null && inventoryItem.variant != null) {
            // Check variant stock
            try {

              final variant = inventoryItem.variant!.firstWhere(
                (v) {
                  final variantDetails = _variantBox.get(v.variantId);
                  final variantName = variantDetails?.name;
                  return variantName == item.variantName;
                },
              );
              final availableStock = variant.stockQuantity ?? 0;


              if (availableStock < finalQuantity) {
                // Insufficient stock
                return {
                  'success': false,
                  'message':
                      'Only ${availableStock.toInt()} ${item.title}${item.variantName != null ? " (${item.variantName})" : ""} available in stock',
                  'availableStock': availableStock.toInt()
                };
              }
            } catch (e) {
            }
          } else {
            // Check regular item stock
            if (inventoryItem.stockQuantity < finalQuantity) {
              // Insufficient stock
              return {
                'success': false,
                'message':
                    'Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock',
                'availableStock': inventoryItem.stockQuantity.toInt()
              };
            }
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

  /// Remove item from cart
  Future<void> removeFromCart(String itemId) async {
    try {
      final itemToDelete =
          _cartBox.values.firstWhere((item) => item.id == itemId);
      final index = _cartBox.values.toList().indexOf(itemToDelete);
      await _cartBox.deleteAt(index);
    } catch (e) {
      rethrow;
    }
  }

  /// Update item quantity in cart
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

  /// Get all cart items
  Future<List<CartItem>> getAllCartItems() async {
    try {
      return _cartBox.values.toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all cart items
  Future<void> clearCart() async {
    try {
      await _cartBox.clear();
    } catch (e) {
      rethrow;
    }
  }

  /// Get cart item count
  Future<int> getCartItemCount() async {
    try {
      return _cartBox.length;
    } catch (e) {
      rethrow;
    }
  }

  /// Get cart total amount
  Future<double> getCartTotal() async {
    try {
      double total = 0.0;
      for (var item in _cartBox.values) {
        total += item.price * item.quantity;
      }
      return total;
    } catch (e) {
      rethrow;
    }
  }

  /// Get cart total quantity
  Future<int> getTotalQuantity() async {
    try {
      int total = 0;
      for (var item in _cartBox.values) {
        total += item.quantity;
      }
      return total;
    } catch (e) {
      rethrow;
    }
  }
}