
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
class InventoryService {
  static Future<void> deductStockForOrder(List<CartItem> cartItems) async {
    print('🔍 InventoryService: Starting stock deduction for ${cartItems.length} items');
    await itemStore.loadItems();
    await variantStore.loadVariants(); // Load variants for variant name lookup
    final items = itemStore.items;

    for (final cartItem in cartItems) {
      print('🔍 Processing cart item: ${cartItem.title} (ID: ${cartItem.id}), Quantity: ${cartItem.quantity}');
      try {
        // Try to find by ID first
        Items? item;
        try {
          item = items.firstWhere(
                (item) => item.id == cartItem.id,
          );
        } catch (e) {
          // If not found by ID, try to find by name
          print('🔍 Item not found by ID, searching by name: ${cartItem.title}');
          try {
            item = items.firstWhere(
                  (item) => item.name.toLowerCase().trim() == cartItem.title.toLowerCase().trim(),
            );
            print('🔍 Found item by name: ${item.name} (ID: ${item.id})');
          } catch (e2) {
            print('❌ Item not found by ID or name: ${cartItem.title}');
            continue;
          }
        }
        // If the item doesn’t track inventory, no deductions happen (skipped).


        print('🔍 Found item: ${item.name}, trackInventory: ${item.trackInventory}, current stock: ${item.stockQuantity}');

        if (!item.trackInventory) {
          print('⚠️ Item ${item.name} does not track inventory - skipping');
          continue;
        }


        //     If the cart line has a variant, delegate to _deductVariantStock.
        // Else, deduct directly from the base item via _deductItemStock.

        if (cartItem.variantName != null) {
          print('🔍 Item has variant: ${cartItem.variantName}');
          await _deductVariantStock(item, cartItem);
        } else {
          // For weight-based items, extract the weight from weightDisplay
          double quantityToDeduct = cartItem.quantity.toDouble();

          if (item.isSoldByWeight && cartItem.weightDisplay != null) {
            // Parse the weight from weightDisplay (e.g., "500GM" -> 500, "1.5KG" -> 1500)
            final singleWeight = _parseWeightFromDisplay(cartItem.weightDisplay!);
            // ✅ FIX: Multiply by quantity (e.g., 3 qty × 5kg = 15kg)
            quantityToDeduct = cartItem.quantity * singleWeight;
            print('🔍 Weight-based item detected. Single weight: $singleWeight, Quantity: ${cartItem.quantity}, Total: $quantityToDeduct');
          }

          print('🔍 Deducting $quantityToDeduct from item ${item.name}');
          await _deductItemStock(item, quantityToDeduct);
        }
      } catch (e) {
        print('❌ Error deducting stock for item ${cartItem.id}: $e');
      }
    }
    print('✅ InventoryService: Stock deduction completed');
  }

  // Directly subtracts quantity (converted to double).
  // Allows negatives (oversell). It only warns if negative after saving.
  static Future<void> _deductItemStock(Items item, double quantity) async {
    // Always deduct stock, allowing negative values
    item.stockQuantity = item.stockQuantity - quantity;
    await item.save();

    if (item.stockQuantity < 0) {
      print('Warning: Stock went negative for item ${item.name}. New stock: ${item.stockQuantity}');
    } else {
      print('Deducted $quantity from item ${item.name}. New stock: ${item.stockQuantity}');
    }
  }




  static Future<void> _deductVariantStock(Items item, CartItem cartItem) async {
    if (item.variant == null) return;

    try {
      final variant = item.variant!.firstWhere(
            (v) => _getVariantName(v.variantId) == cartItem.variantName,
      );

      final quantity = cartItem.quantity.toDouble();
      // Always deduct stock, allowing negative values
      variant.stockQuantity = (variant.stockQuantity ?? 0) - quantity;
      await item.save();

      if (variant.stockQuantity! < 0) {
        print('Warning: Stock went negative for variant ${cartItem.variantName} of item ${item.name}. New stock: ${variant.stockQuantity}');
      } else {
        print('Deducted $quantity from variant ${cartItem.variantName} of item ${item.name}. New stock: ${variant.stockQuantity}');
      }
    } catch (e) {
      print('Error finding variant ${cartItem.variantName} for item ${item.name}: $e');
    }
  }

  static String _getVariantName(String variantId) {
    try {
      final variant = variantStore.variants.firstWhere(
        (v) => v.id == variantId,
        orElse: () => variantStore.variants.first,
      );

      print('🔍 DEBUG: Found variant for ID \"$variantId\": ${variant.name}');
      return variant.name;
    } catch (e) {
      print('🔍 DEBUG: Error in _getVariantName: $e');
      return 'Unknown Variant';
    }
  }

  // Stock checking before placing order: checkStockAvailability
  static Future<bool> checkStockAvailability(List<CartItem> cartItems) async {
    print('🔍 InventoryService: Starting stock availability check for ${cartItems.length} items');
    await itemStore.loadItems();
    final items = itemStore.items;

    // Group cart items by item name and variant to calculate total quantities
    Map<String, Map<String?, int>> itemVariantTotals = {};

    // First pass: Calculate total quantities for each item-variant combination
    for (final cartItem in cartItems) {
      final itemKey = cartItem.title.toLowerCase().trim();
      final variantKey = cartItem.variantName;

      if (!itemVariantTotals.containsKey(itemKey)) {
        itemVariantTotals[itemKey] = {};
      }

      if (!itemVariantTotals[itemKey]!.containsKey(variantKey)) {
        itemVariantTotals[itemKey]![variantKey] = 0;
      }

      itemVariantTotals[itemKey]![variantKey] = itemVariantTotals[itemKey]![variantKey]! + cartItem.quantity;
      print('🔍 AGGREGATION: ${cartItem.title}${variantKey != null ? " ($variantKey)" : ""} - Adding ${cartItem.quantity}, Total: ${itemVariantTotals[itemKey]![variantKey]}');
    }

    // Second pass: Validate stock for each unique item-variant combination
    for (final itemKey in itemVariantTotals.keys) {
      // Find the inventory item
      Items? item;
      try {
        item = items.firstWhere(
              (invItem) => invItem.name.toLowerCase().trim() == itemKey,
        );
      } catch (e) {
        print('❌ Item not found by name: $itemKey');
        return false;
      }

      print('🔍 Found item: ${item.name}, trackInventory: ${item.trackInventory}, stockQuantity: ${item.stockQuantity}, allowOrderWhenOutOfStock: ${item.allowOrderWhenOutOfStock}');

      if (!item.trackInventory) {
        print('⚠️ Item ${item.name} does not track inventory - allowing order');
        continue;
      }

      // Check allowOrderWhenOutOfStock setting
      if (!item.allowOrderWhenOutOfStock) {
        print('🔍 Item ${item.name} has allowOrderWhenOutOfStock = FALSE - checking stock strictly');

        // Check each variant of this item
        for (final variantKey in itemVariantTotals[itemKey]!.keys) {
          final totalQuantity = itemVariantTotals[itemKey]![variantKey]!;

          if (variantKey != null) {
            // Variant item - check variant stock
            if (!await _checkVariantStockStrictWithQuantity(item, variantKey, totalQuantity)) {
              return false;
            }
          } else {
            // Regular item - check base stock
            if (item.stockQuantity <= 0) {
              print('❌ Item ${item.name} is out of stock and ordering when out of stock is disabled');
              return false;
            }
            if (item.stockQuantity < totalQuantity) {
              print('❌ Insufficient stock for item ${item.name}. Available: ${item.stockQuantity}, Required: $totalQuantity');
              return false;
            }
          }
        }
      } else {
        print('✅ Item ${item.name} has allowOrderWhenOutOfStock = TRUE - allowing order regardless of stock');
      }
    }

    print('✅ InventoryService: All items passed stock availability check - allowing order');
    return true;
  }

  static Future<bool> _checkVariantStock(Items item, CartItem cartItem) async {
    if (item.variant == null) return false;

    try {
      final variant = item.variant!.firstWhere(
            (v) => _getVariantName(v.variantId) == cartItem.variantName,
      );

      if ((variant.stockQuantity ?? 0) < cartItem.quantity) {
        print('Insufficient stock for variant ${cartItem.variantName}. Available: ${variant.stockQuantity}, Required: ${cartItem.quantity}');
        return false;
      }
      return true;
    } catch (e) {
      print('Error finding variant ${cartItem.variantName} for item ${item.name}: $e');
      return false;
    }
  }

  static Future<bool> _checkVariantStockStrict(Items item, CartItem cartItem) async {
    if (item.variant == null) {
      print('❌ Item ${item.name} has no variants but cart item ${cartItem.title} expects variant ${cartItem.variantName}');
      return false;
    }

    print('🔍 DEBUG: Checking variant stock for item ${item.name}');
    print('🔍 DEBUG: Cart item variant name: "${cartItem.variantName}"');
    print('🔍 DEBUG: Available variants in item:');

    for (int i = 0; i < item.variant!.length; i++) {
      final v = item.variant![i];
      final variantName = _getVariantName(v.variantId);
      print('🔍 DEBUG:   Variant $i: ID="${v.variantId}", Name="$variantName", Stock=${v.stockQuantity}');
    }

    try {
      final variant = item.variant!.firstWhere(
            (v) => _getVariantName(v.variantId) == cartItem.variantName,
      );

      final availableStock = variant.stockQuantity ?? 0;
      print('🔍 DEBUG: Found matching variant with stock: $availableStock, required: ${cartItem.quantity}');

      if (availableStock <= 0) {
        print('❌ Variant ${cartItem.variantName} is out of stock and ordering when out of stock is disabled');
        return false;
      }

      if (availableStock < cartItem.quantity) {
        print('❌ Insufficient stock for variant ${cartItem.variantName}. Available: $availableStock, Required: ${cartItem.quantity}');
        return false;
      }

      print('✅ Variant ${cartItem.variantName} has sufficient stock');
      return true;
    } catch (e) {
      print('❌ Error finding variant ${cartItem.variantName} for item ${item.name}: $e');
      print('❌ This means no variant with name "${cartItem.variantName}" was found');
      return false;
    }
  }

  static Future<bool> _checkVariantStockStrictWithQuantity(Items item, String variantName, int totalQuantity) async {
    if (item.variant == null) {
      print('❌ Item ${item.name} has no variants but expects variant $variantName');
      return false;
    }

    print('🔍 AGGREGATED CHECK: Checking variant stock for item ${item.name}');
    print('🔍 AGGREGATED CHECK: Variant name: "$variantName", Total quantity: $totalQuantity');

    try {
      final variant = item.variant!.firstWhere(
            (v) => _getVariantName(v.variantId) == variantName,
      );

      final availableStock = variant.stockQuantity ?? 0;
      print('🔍 AGGREGATED CHECK: Found variant with stock: $availableStock, required total: $totalQuantity');

      if (availableStock <= 0) {
        print('❌ Variant $variantName is out of stock and ordering when out of stock is disabled');
        return false;
      }

      if (availableStock < totalQuantity) {
        print('❌ Insufficient stock for variant $variantName. Available: $availableStock, Required total: $totalQuantity');
        return false;
      }

      print('✅ Variant $variantName has sufficient stock for total quantity');
      return true;
    } catch (e) {
      print('❌ Error finding variant $variantName for item ${item.name}: $e');
      return false;
    }
  }

  // Parse weight from display string to grams for stock deduction
  static double _parseWeightFromDisplay(String weightDisplay) {
    // Remove spaces and convert to uppercase for consistent parsing
    String normalizedWeight = weightDisplay.replaceAll(' ', '').toUpperCase();

    // Extract numeric value
    RegExp numericRegex = RegExp(r'(\d+\.?\d*)');
    Match? numericMatch = numericRegex.firstMatch(normalizedWeight);

    if (numericMatch == null) {
      print('⚠️ Could not parse weight from: $weightDisplay, defaulting to 0');
      return 0.0;
    }

    double numericValue = double.parse(numericMatch.group(1)!);

    // Convert to grams based on unit
    if (normalizedWeight.contains('KG')) {
      return numericValue * 1000; // Convert kg to grams
    } else if (normalizedWeight.contains('G') || normalizedWeight.contains('GM') || normalizedWeight.contains('GRAM')) {
      return numericValue; // Already in grams
    } else if (normalizedWeight.contains('LB') || normalizedWeight.contains('POUND')) {
      return numericValue * 453.592; // Convert pounds to grams
    } else {
      // Default: assume it's already in the same unit as inventory
      print('⚠️ Unknown unit in weight display: $weightDisplay, using value as-is: $numericValue');
      return numericValue;
    }
  }

  /// Restore stock for refunded items
  /// Used when processing refunds and items need to be added back to inventory
  static Future<void> restoreStockForRefund(Map<CartItem, int> itemsToRestock) async {
    try {
      print('📦 InventoryService: Starting stock restoration for ${itemsToRestock.length} items');
      await itemStore.loadItems();
      await variantStore.loadVariants();

      for (final entry in itemsToRestock.entries) {
        final cartItem = entry.key;
        final restockQuantity = entry.value;

        if (restockQuantity <= 0) {
          print('⚠️ Skipping ${cartItem.title}: quantity is 0');
          continue;
        }

        print('🔄 Restoring stock for: ${cartItem.title}, Quantity: $restockQuantity');

        // Find the item - try by productId first, then by name
        Items? existingItem;

        // Try to find by productId if it exists and is not empty
        if (cartItem.productId.isNotEmpty) {
          try {
            existingItem = itemStore.items.firstWhere(
              (item) => item.id == cartItem.productId,
            );
            print('✅ Found item by productId: ${existingItem.name}');
          } catch (e) {
            print('⚠️ productId not found, trying by name...');
          }
        }

        // If not found by productId, try by name
        if (existingItem == null) {
          try {
            existingItem = itemStore.items.firstWhere(
              (item) => item.name.toLowerCase().trim() == cartItem.title.toLowerCase().trim(),
            );
            print('✅ Found item by name: ${existingItem.name}');
          } catch (e2) {
            print('❌ Item not found for restocking: ${cartItem.title}');
            continue;
          }
        }

        if (!existingItem.trackInventory) {
          print('⚠️ Item ${cartItem.title} does not track inventory - skipping restock');
          continue;
        }

        // Handle variant items
        if (cartItem.variantName != null && existingItem.variant != null) {
          print('🔍 Item has variant: ${cartItem.variantName}');
          await _restoreVariantStock(existingItem, cartItem, restockQuantity);
        } else {
          // Handle regular items (non-variant)
          double quantityToRestore = restockQuantity.toDouble();

          // For weight-based items, parse the weight from weightDisplay
          if (existingItem.isSoldByWeight && cartItem.weightDisplay != null) {
            quantityToRestore = _parseWeightFromDisplay(cartItem.weightDisplay!);
            print('🔍 Weight-based item detected. Parsed weight: $quantityToRestore');
          }

          await _restoreItemStock(existingItem, quantityToRestore);
        }
      }

      // Reload items to reflect changes in UI
      await itemStore.loadItems();

      print('✅ InventoryService: Stock restoration completed');
    } catch (e, stackTrace) {
      print('❌ InventoryService: Error restoring stock: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Rethrow so caller can handle
    }
  }

  /// Restore stock for a regular item (non-variant)
  static Future<void> _restoreItemStock(Items item, double quantity) async {
    final oldStock = item.stockQuantity;
    item.stockQuantity = oldStock + quantity;
    await item.save();

    print('✅ Stock restored: ${item.name}, Old: $oldStock, New: ${item.stockQuantity}');
  }

  /// Restore stock for a variant item
  static Future<void> _restoreVariantStock(Items item, CartItem cartItem, int quantity) async {
    if (item.variant == null) {
      print('❌ Item ${item.name} has no variants');
      return;
    }

    bool variantFound = false;
    for (var variant in item.variant!) {
      final variantName = _getVariantName(variant.variantId);
      if (variantName == cartItem.variantName) {
        // Restore variant stock
        final oldStock = variant.stockQuantity ?? 0;
        variant.stockQuantity = oldStock + quantity;
        await item.save();

        print('✅ Variant stock restored: ${cartItem.variantName}, Old: $oldStock, New: ${variant.stockQuantity}');
        variantFound = true;
        break;
      }
    }

    if (!variantFound) {
      print('❌ Variant ${cartItem.variantName} not found for item ${item.name}');
    }
  }
}