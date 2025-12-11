import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';

import '../itemmodel_302.dart';


class HiveCart {
  static const String boxName = 'cart_box';

  static Future<Box<CartItem>> _openBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<CartItem>(boxName);
    }
    return Hive.box<CartItem>(boxName);
  }

  static Future<Map<String, dynamic>> addToCart(CartItem item) async {
    try {
      final box = await _openBox();
      
      // Check for existing item
      // The corrected code
      CartItem? existingItem;
      try {
        existingItem = box.values.firstWhere(
                (i) =>
            i.title == item.title &&
                i.variantName == item.variantName &&
                i.choiceNames.toString() == item.choiceNames.toString() &&
                i.extras.toString() == item.extras.toString() &&

                // --- KEY CHANGES ---
                // These two checks ensure that custom-priced or different weight
                // items are treated as separate entries in the cart.
                i.price == item.price &&
                i.weightDisplay == item.weightDisplay
          // --- END OF CHANGES ---
        );
      } catch (e) {
        existingItem = null;
      }

      // Calculate the final quantity after adding
      final int finalQuantity = existingItem != null 
          ? existingItem.quantity + item.quantity 
          : item.quantity;

      // Check stock availability
      final itemBox = await Hive.openBox<Items>('itemBoxs');
      Items? inventoryItem;
      
      try {
        // Try to find by title (item name)
        inventoryItem = itemBox.values.firstWhere(
          (invItem) => invItem.name.toLowerCase().trim() == item.title.toLowerCase().trim(),
        );
      } catch (e) {
        // Item not found in inventory, allow adding (no inventory tracking)
        if (existingItem != null) {
          final index = box.values.toList().indexOf(existingItem);
          existingItem.quantity = finalQuantity;
          await box.putAt(index, existingItem);
        } else {
          await box.add(item);
        }
        return {'success': true, 'message': 'Item added to cart'};
      }
      
      // Check if inventory tracking is enabled and stock is available
      if (inventoryItem != null && inventoryItem.trackInventory) {
        if (!inventoryItem.allowOrderWhenOutOfStock) {
          // Check stock availability
          if (item.variantName != null && inventoryItem.variant != null) {
            // Check variant stock
            try {
              final variantBox = Hive.box<VariantModel>('variante');
              final variant = inventoryItem.variant!.firstWhere(
                (v) => variantBox.get(v.variantId)?.name == item.variantName,
              );
              final availableStock = variant.stockQuantity ?? 0;
              
              if (availableStock < finalQuantity) {
                // Insufficient stock
                return {
                  'success': false, 
                  'message': 'Only ${availableStock.toInt()} ${item.title}${item.variantName != null ? " (${item.variantName})" : ""} available in stock',
                  'availableStock': availableStock.toInt()
                };
              }
            } catch (e) {
              print('Error checking variant stock: $e');
            }
          } else {
            // Check regular item stock
            if (inventoryItem.stockQuantity < finalQuantity) {
              // Insufficient stock
              return {
                'success': false, 
                'message': 'Only ${inventoryItem.stockQuantity.toInt()} ${item.title} available in stock',
                'availableStock': inventoryItem.stockQuantity.toInt()
              };
            }
          }
        }
      }
      
      // If all checks pass, add/update the item
      if (existingItem != null) {
        final index = box.values.toList().indexOf(existingItem);
        existingItem.quantity = finalQuantity;
        await box.putAt(index, existingItem);
      } else {
        await box.add(item);
      }
      
      return {'success': true, 'message': 'Item added to cart'};
    } catch (e) {
      print('Error adding item to cart: $e');
      return {'success': false, 'message': 'Error adding item to cart'};
    }
  }

  static Future<void> removeFromCart(String itemId) async {
    try {
      final box = await _openBox();
      final itemToDelete = box.values.firstWhere((item) => item.id == itemId);
      final index = box.values.toList().indexOf(itemToDelete);
      await box.deleteAt(index);
    } catch (e) {
      print('Error removing item from cart: $e');
      rethrow;
    }
  }

  static Future<void> updateQuantity(String itemId, int newQuantity) async {
    try {
      final box = await _openBox();
      final item = box.values.firstWhere((item) => item.id == itemId);
      final index = box.values.toList().indexOf(item);
      item.quantity = newQuantity;
      await box.putAt(index, item);
    } catch (e) {
      print('Error updating quantity: $e');
      rethrow;
    }
  }

  static Future<List<CartItem>> getAllCartItems() async {
    try {
      final box = await _openBox();
      return box.values.toList();
    } catch (e) {
      print('Error getting cart items: $e');
      rethrow;
    }
  }

  static Future<void> clearCart() async {
    try {
      final box = await _openBox();
      await box.clear();
    } catch (e) {
      print('Error clearing cart: $e');
      rethrow;
    }
  }

  static Future<int> getCartItemCount() async {
    try {
      final box = await _openBox();
      return box.length;
    } catch (e) {
      print('Error getting cart item count: $e');
      rethrow;
    }
  }

  static Future<double> getCartTotal() async {
    try {
      final box = await _openBox();
      double total = 0.0;
      for (var item in box.values) {
        total += item.price * item.quantity;
      }
      return total;
    } catch (e) {
      print('Error calculating cart total: $e');
      rethrow;
    }
  }
}
