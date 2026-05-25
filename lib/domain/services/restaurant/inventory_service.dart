
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../common/notification_service.dart';

class InventoryService {
  static const double _lowStockThreshold = 5;

  static Future<void> deductStockForOrder(List<CartItem> cartItems) async {
    await itemStore.loadItems();
    await variantStore.loadVariants(); // Load variants for variant name lookup
    final items = itemStore.items;
    final List<String> lowStockAlerts = [];

    for (final cartItem in cartItems) {
      // Try to find by productId first (matches inventory item key)
      Items? item;
      try {
        item = items.firstWhere(
          (i) => cartItem.productId.isNotEmpty && i.id == cartItem.productId,
        );
      } catch (_) {
        try {
          item = items.firstWhere(
            (i) => i.name.toLowerCase().trim() == cartItem.title.toLowerCase().trim(),
          );
        } catch (_) {
          continue;
        }
      }

      if (!item.trackInventory) continue;

      final double stockAfter;
      if (cartItem.variantName != null) {
        stockAfter = await _deductVariantStock(item, cartItem);
      } else {
        double quantityToDeduct = cartItem.quantity.toDouble();
        if (item.isSoldByWeight && cartItem.weightDisplay != null) {
          final stockUnit = item.unit ?? "kg";
          final singleWeight = _parseWeightToStockUnit(cartItem.weightDisplay!, stockUnit);
          quantityToDeduct = cartItem.quantity * singleWeight;
        }
        stockAfter = await _deductItemStock(item, quantityToDeduct);
      }

      final label = cartItem.variantName != null
          ? "${item.name} (${cartItem.variantName})"
          : item.name;
      if (stockAfter < 0) {
        lowStockAlerts.add("$label is out of stock");
      } else if (stockAfter < _lowStockThreshold) {
        lowStockAlerts.add("$label: ${stockAfter.toStringAsFixed(0)} ${item.unit ?? "units"} left");
      }
    }

    if (lowStockAlerts.isNotEmpty) {
      NotificationService.instance.showWarning(
        "Low Stock - ${lowStockAlerts.join(" | ")}",
      );
    }
  }

  static Future<double> _deductItemStock(Items item, double quantity) async {
    item.stockQuantity = item.stockQuantity - quantity;
    await item.save();
    return item.stockQuantity;
  }




  static Future<double> _deductVariantStock(Items item, CartItem cartItem) async {
    if (item.variant == null) return 0;
    try {
      final variant = item.variant!.firstWhere(
            (v) => _getVariantName(v.variantId) == cartItem.variantName,
      );
      variant.stockQuantity = (variant.stockQuantity ?? 0) - cartItem.quantity.toDouble();
      await item.save();
      return variant.stockQuantity!;
    } catch (e) {
      return 0;
    }
  }

  static String _getVariantName(String variantId) {
    try {
      return variantStore.variants.firstWhere((v) => v.id == variantId).name;
    } catch (_) {
      return '';
    }
  }

  // Stock checking before placing order: checkStockAvailability
  static Future<bool> checkStockAvailability(List<CartItem> cartItems) async {
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
        return false;
      }


      if (!item.trackInventory) {
        continue;
      }

      // Check allowOrderWhenOutOfStock setting
      if (!item.allowOrderWhenOutOfStock) {

        // Check each variant of this item
        for (final variantKey in itemVariantTotals[itemKey]!.keys) {
          final totalQuantity = itemVariantTotals[itemKey]![variantKey]!;

          if (variantKey != null) {
            // Variant item - check variant stock
            if (!_checkVariantStockStrictWithQuantity(item, variantKey, totalQuantity)) {
              return false;
            }
          } else {
            // Regular item - check base stock
            if (item.stockQuantity <= 0) {
              return false;
            }
            if (item.stockQuantity < totalQuantity) {
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  static bool _checkVariantStockStrictWithQuantity(Items item, String variantName, int totalQuantity) {
    if (item.variant == null) return false;
    try {
      final variant = item.variant!.firstWhere(
            (v) => _getVariantName(v.variantId) == variantName,
      );

      final availableStock = variant.stockQuantity ?? 0;

      if (availableStock <= 0) {
        return false;
      }

      if (availableStock < totalQuantity) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parse weight from display string and convert to the item's stock unit.
  /// e.g., weightDisplay="10KG", stockUnit="kg" → returns 10
  ///        weightDisplay="500GM", stockUnit="kg" → returns 0.5
  ///        weightDisplay="2KG", stockUnit="gm" → returns 2000
  static double _parseWeightToStockUnit(String weightDisplay, String stockUnit) {
    final grams = _parseWeightFromDisplay(weightDisplay);
    final normalizedStockUnit = stockUnit.toUpperCase().replaceAll(' ', '');
    // Convert grams to the stock unit
    if (normalizedStockUnit.contains('KG')) {
      return grams / 1000; // grams → kg
    } else if (normalizedStockUnit.contains('G') || normalizedStockUnit.contains('GM') || normalizedStockUnit.contains('GRAM')) {
      return grams; // already in grams
    } else if (normalizedStockUnit.contains('LB') || normalizedStockUnit.contains('POUND')) {
      return grams / 453.592; // grams → pounds
    }
    // Default: assume grams
    return grams;
  }

  // Parse weight from display string to grams (internal)
  static double _parseWeightFromDisplay(String weightDisplay) {
    // Remove spaces and convert to uppercase for consistent parsing
    String normalizedWeight = weightDisplay.replaceAll(' ', '').toUpperCase();

    // Extract numeric value
    RegExp numericRegex = RegExp(r'(\d+\.?\d*)');
    Match? numericMatch = numericRegex.firstMatch(normalizedWeight);

    if (numericMatch == null) {
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
      return numericValue;
    }
  }

  /// Restore stock for a voided/cancelled active order.
  /// Convenience wrapper — builds the quantity map and delegates to restoreStockForRefund.
  static Future<void> restoreStockForOrder(List<CartItem> items) async {
    if (items.isEmpty) return;
    final itemsToRestock = <CartItem, int>{};
    for (final item in items) {
      if (item.quantity > 0) {
        itemsToRestock[item] = (itemsToRestock[item] ?? 0) + item.quantity;
      }
    }
    await restoreStockForRefund(itemsToRestock);
  }

  /// Restore stock for refunded items
  /// Used when processing refunds and items need to be added back to inventory
  static Future<void> restoreStockForRefund(Map<CartItem, int> itemsToRestock) async {
    try {
      await itemStore.loadItems();
      await variantStore.loadVariants();

      for (final entry in itemsToRestock.entries) {
        final cartItem = entry.key;
        final restockQuantity = entry.value;

        if (restockQuantity <= 0) {
          continue;
        }


        // Find the item - try by productId first, then by name
        Items? existingItem;

        // Try to find by productId if it exists and is not empty
        if (cartItem.productId.isNotEmpty) {
          try {
            existingItem = itemStore.items.firstWhere(
              (item) => item.id == cartItem.productId,
            );
          } catch (_) {
          }
        }

        // If not found by productId, try by name
        if (existingItem == null) {
          try {
            existingItem = itemStore.items.firstWhere(
              (item) => item.name.toLowerCase().trim() == cartItem.title.toLowerCase().trim(),
            );
          } catch (e2) {
            continue;
          }
        }

        if (!existingItem.trackInventory) {
          continue;
        }

        // Handle variant items
        if (cartItem.variantName != null && existingItem.variant != null) {
          await _restoreVariantStock(existingItem, cartItem, restockQuantity);
        } else {
          // Handle regular items (non-variant)
          double quantityToRestore = restockQuantity.toDouble();

          // For weight-based items, parse the weight and convert to stock unit
          if (existingItem.isSoldByWeight && cartItem.weightDisplay != null) {
            final stockUnit = existingItem.unit ?? 'kg';
            quantityToRestore = _parseWeightToStockUnit(cartItem.weightDisplay!, stockUnit);
          }

          await _restoreItemStock(existingItem, quantityToRestore);
        }
      }

      // Reload items to reflect changes in UI
      await itemStore.loadItems();

    } catch (e) {
      rethrow;
    }
  }

  /// Restore stock for a regular item (non-variant)
  static Future<void> _restoreItemStock(Items item, double quantity) async {
    final oldStock = item.stockQuantity;
    item.stockQuantity = oldStock + quantity;
    await item.save();

  }

  /// Restore stock for a variant item
  static Future<void> _restoreVariantStock(Items item, CartItem cartItem, int quantity) async {
    if (item.variant == null) {
      return;
    }

    for (var variant in item.variant!) {
      if (_getVariantName(variant.variantId) == cartItem.variantName) {
        variant.stockQuantity = (variant.stockQuantity ?? 0) + quantity;
        await item.save();
        break;
      }
    }
  }
}