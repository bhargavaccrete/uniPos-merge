
import 'package:uuid/uuid.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/recipe_model.dart';
import '../../../data/models/restaurant/db/recipe_production_model.dart';
import '../../../util/restaurant/staticswitch.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';
import 'day_management_service.dart';
import '../common/notification_service.dart';

class InventoryService {
  static Future<void> deductStockForOrder(List<CartItem> cartItems) async {
    await itemStore.loadItems();
    await variantStore.loadVariants(); // Load variants for variant name lookup
    final items = itemStore.items;
    final List<String> lowStockAlerts = [];

    // For logging each deduction to the stock movement history (reason = "Sale").
    final stockRepo = StockMovementRepository();
    final staffName = RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
    final sessionId = await DayManagementService.getCurrentSessionId();

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

      // Recipe-Based items aren't stocked themselves — cascade the deduction
      // into their recipe's ingredients instead. See
      // docs/inventory_recipe_system_plan.md §5.
      if (item.isRecipeBased) {
        await _deductRecipeIngredients(
          recipeItem: item,
          saleQty: cartItem.quantity.toDouble(),
          items: items,
          stockRepo: stockRepo,
          staffName: staffName,
          sessionId: sessionId,
          lowStockAlerts: lowStockAlerts,
        );
        continue;
      }

      if (!item.trackInventory) continue;

      final double stockAfter;
      final double deductedQty;
      String? variantId;
      if (cartItem.variantName != null) {
        deductedQty = cartItem.quantity.toDouble();
        stockAfter = await _deductVariantStock(item, cartItem);
        try {
          variantId = item.variant
              ?.firstWhere((v) => _getVariantName(v.variantId) == cartItem.variantName)
              .variantId;
        } catch (_) {}
      } else {
        double quantityToDeduct = cartItem.quantity.toDouble();
        if (item.isSoldByWeight && cartItem.weightDisplay != null) {
          final stockUnit = item.unit ?? "kg";
          final singleWeight = _parseWeightToStockUnit(cartItem.weightDisplay!, stockUnit);
          quantityToDeduct = cartItem.quantity * singleWeight;
        }
        deductedQty = quantityToDeduct;
        stockAfter = await _deductItemStock(item, quantityToDeduct);
      }

      final label = cartItem.variantName != null
          ? "${item.name} (${cartItem.variantName})"
          : item.name;

      await _logMovementAndAlert(
        stockRepo: stockRepo,
        item: item,
        label: label,
        type: 'out',
        quantity: deductedQty,
        balanceAfter: stockAfter,
        reason: 'Sale',
        variantId: variantId,
        staffName: staffName,
        sessionId: sessionId,
        lowStockAlerts: lowStockAlerts,
      );
    }

    if (lowStockAlerts.isNotEmpty) {
      NotificationService.instance.showWarning(
        "Low Stock - ${lowStockAlerts.join(" | ")}",
      );
    }
  }

  /// Expands a Recipe-Based item's sale into deductions against its recipe's
  /// ingredients (one level deep — an ingredient must be Raw Material or
  /// Semi-Finished, never itself Recipe-Based). Logs one StockMovementModel
  /// per ingredient with a reason that traces back to the finished item, so
  /// the existing per-item stock history explains "why did bun stock drop" as
  /// "linked to Burger sales" with zero new audit UI. See
  /// docs/inventory_recipe_system_plan.md §5.
  static Future<void> _deductRecipeIngredients({
    required Items recipeItem,
    required double saleQty,
    required List<Items> items,
    required StockMovementRepository stockRepo,
    required String staffName,
    required String? sessionId,
    required List<String> lowStockAlerts,
  }) async {
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(recipeItem.id);
    if (recipe == null || !recipe.hasIngredients) return; // unconfigured recipe — nothing to deduct
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
    final batches = saleQty / yieldQty;

    for (final line in recipe.ingredients) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        continue; // ingredient item was deleted — skip rather than crash the sale
      }
      if (!ingredient.trackInventory) continue;

      final deductQty = batches * line.effectiveQuantity;
      final stockAfter = await _deductItemStock(ingredient, deductQty);

      await _logMovementAndAlert(
        stockRepo: stockRepo,
        item: ingredient,
        label: ingredient.name,
        type: 'out',
        quantity: deductQty,
        balanceAfter: stockAfter,
        reason: 'Sale (recipe: ${recipeItem.name})',
        variantId: null,
        staffName: staffName,
        sessionId: sessionId,
        lowStockAlerts: lowStockAlerts,
      );
    }
  }

  /// Shared by every stock deduction path (direct item, variant, and
  /// recipe-ingredient cascade): writes the audit-trail movement row and
  /// raises/resolves the low-stock notification for [item].
  static Future<void> _logMovementAndAlert({
    required StockMovementRepository stockRepo,
    required Items item,
    required String label,
    required String type,
    required double quantity,
    required double balanceAfter,
    required String reason,
    required String? variantId,
    required String staffName,
    required String? sessionId,
    required List<String> lowStockAlerts,
  }) async {
    await stockRepo.saveMovement(StockMovementModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      itemId: item.id,
      variantId: variantId,
      itemName: label,
      type: type,
      quantity: quantity,
      balanceAfter: balanceAfter,
      reason: reason,
      unit: item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs'),
      staffName: staffName,
      sessionId: sessionId,
    ));

    if (type != 'out') return; // low-stock alerts only make sense for deductions

    final lowAlertsOn = item.lowStockAlertEnabled && AppSettings.lowStockAlertsEnabled;
    final subjectId = _lowStockSubjectId(item.id, variantId);
    if (balanceAfter <= 0) {
      lowStockAlerts.add("$label is out of stock");
      if (lowAlertsOn) {
        await notificationStore.raiseEvent(
          eventCode: 'low_stock',
          subjectType: 'item',
          subjectId: subjectId,
          data: {'name': label, 'remaining': 0, 'unit': item.unit ?? 'units'},
        );
      }
    } else if (lowAlertsOn && balanceAfter <= item.effectiveLowStockThreshold) {
      lowStockAlerts.add("$label: ${balanceAfter.toStringAsFixed(0)} ${item.unit ?? "units"} left");
      await notificationStore.raiseEvent(
        eventCode: 'low_stock',
        subjectType: 'item',
        subjectId: subjectId,
        data: {
          'name': label,
          'remaining': balanceAfter,
          'unit': item.unit ?? 'units',
        },
      );
    } else {
      // Stock healthy again — retire any prior low-stock notification.
      await notificationStore.resolve('low_stock', 'item', subjectId);
    }
  }

  /// Live "N can be made" count for a Recipe-Based item — the minimum, across
  /// its recipe's ingredients, of how many batches current ingredient stock
  /// supports. Recipe-Based items have no stored stock (see
  /// [Items.isStockDerivedFromRecipe]), so this replaces the stockQuantity
  /// badge wherever one would normally show. Returns 0 if the item has no
  /// recipe or an ingredient is out of stock/untracked-missing.
  /// See docs/inventory_recipe_system_plan.md §7.
  static double calculateAvailableToMake(Items item) {
    if (!item.isRecipeBased) return item.stockQuantity;
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(item.id);
    if (recipe == null || !recipe.hasIngredients) return 0;
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;

    double? minBatches;
    for (final line in recipe.ingredients) {
      if (line.effectiveQuantity <= 0) continue;
      Items? ingredient;
      try {
        ingredient = itemStore.items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        return 0; // a required ingredient no longer exists — can't be made
      }
      if (!ingredient.trackInventory) continue; // untracked ingredient never limits availability
      final batchesFromThisIngredient = ingredient.stockQuantity / line.effectiveQuantity;
      minBatches = minBatches == null
          ? batchesFromThisIngredient
          : (batchesFromThisIngredient < minBatches ? batchesFromThisIngredient : minBatches);
    }
    if (minBatches == null) return double.infinity; // no tracked ingredients — never limited
    final available = minBatches * yieldQty;
    return available < 0 ? 0 : available.floorToDouble();
  }

  /// Produces one batch of a Semi-Finished item from its recipe: validates
  /// every ingredient has enough stock (all-or-nothing — no partial
  /// deduction on shortage), deducts each ingredient, credits the
  /// Semi-Finished item's own stock by [batchQty], logs a StockMovementModel
  /// per ingredient plus one for the produced item, and writes an append-only
  /// [RecipeProductionModel] row linking all of them. Throws [Exception] with
  /// a user-facing message on validation failure. See
  /// docs/inventory_recipe_system_plan.md §6.3.
  static Future<RecipeProductionModel> produceBatch({
    required Items semiFinishedItem,
    required double batchQty,
  }) async {
    if (batchQty <= 0) {
      throw Exception('Batch quantity must be greater than zero.');
    }
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(semiFinishedItem.id);
    if (recipe == null || !recipe.hasIngredients) {
      throw Exception('${semiFinishedItem.name} has no recipe configured.');
    }

    await itemStore.loadItems();
    final items = itemStore.items;
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
    final batches = batchQty / yieldQty;

    // Validate stock availability up front so production is all-or-nothing.
    final List<String> shortages = [];
    for (final line in recipe.ingredients) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        shortages.add('a required ingredient no longer exists');
        continue;
      }
      if (!ingredient.trackInventory) continue;
      final required = batches * line.effectiveQuantity;
      if (ingredient.stockQuantity < required) {
        shortages.add(
          '${ingredient.name} (need ${required.toStringAsFixed(2)}, '
          'have ${ingredient.stockQuantity.toStringAsFixed(2)})',
        );
      }
    }
    if (shortages.isNotEmpty) {
      throw Exception('Insufficient stock: ${shortages.join(', ')}');
    }

    final stockRepo = StockMovementRepository();
    final staffName = RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
    final sessionId = await DayManagementService.getCurrentSessionId();
    final lowStockAlerts = <String>[];
    final movementIds = <String>[];

    for (final line in recipe.ingredients) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        continue;
      }
      if (!ingredient.trackInventory) continue;

      final deductQty = batches * line.effectiveQuantity;
      final stockAfter = await _deductItemStock(ingredient, deductQty);
      final movementId = const Uuid().v4();
      await stockRepo.saveMovement(StockMovementModel(
        id: movementId,
        timestamp: DateTime.now(),
        itemId: ingredient.id,
        variantId: null,
        itemName: ingredient.name,
        type: 'out',
        quantity: deductQty,
        balanceAfter: stockAfter,
        reason: 'Production (${semiFinishedItem.name})',
        unit: ingredient.unit ?? (ingredient.isSoldByWeight ? 'kg' : 'pcs'),
        staffName: staffName,
        sessionId: sessionId,
      ));
      movementIds.add(movementId);

      final lowAlertsOn = ingredient.lowStockAlertEnabled && AppSettings.lowStockAlertsEnabled;
      final subjectId = _lowStockSubjectId(ingredient.id, null);
      if (stockAfter <= 0) {
        lowStockAlerts.add('${ingredient.name} is out of stock');
        if (lowAlertsOn) {
          await notificationStore.raiseEvent(
            eventCode: 'low_stock',
            subjectType: 'item',
            subjectId: subjectId,
            data: {'name': ingredient.name, 'remaining': 0, 'unit': ingredient.unit ?? 'units'},
          );
        }
      } else if (lowAlertsOn && stockAfter <= ingredient.effectiveLowStockThreshold) {
        lowStockAlerts.add(
          '${ingredient.name}: ${stockAfter.toStringAsFixed(0)} ${ingredient.unit ?? "units"} left',
        );
        await notificationStore.raiseEvent(
          eventCode: 'low_stock',
          subjectType: 'item',
          subjectId: subjectId,
          data: {'name': ingredient.name, 'remaining': stockAfter, 'unit': ingredient.unit ?? 'units'},
        );
      } else {
        await notificationStore.resolve('low_stock', 'item', subjectId);
      }
    }

    await _restoreItemStock(semiFinishedItem, batchQty);
    final producedBalance = semiFinishedItem.stockQuantity;
    final producedMovementId = const Uuid().v4();
    await stockRepo.saveMovement(StockMovementModel(
      id: producedMovementId,
      timestamp: DateTime.now(),
      itemId: semiFinishedItem.id,
      variantId: null,
      itemName: semiFinishedItem.name,
      type: 'in',
      quantity: batchQty,
      balanceAfter: producedBalance,
      reason: 'Production batch',
      unit: semiFinishedItem.unit ?? (semiFinishedItem.isSoldByWeight ? 'kg' : 'pcs'),
      staffName: staffName,
      sessionId: sessionId,
    ));
    movementIds.add(producedMovementId);

    final production = RecipeProductionModel(
      id: const Uuid().v4(),
      recipeId: recipe.id,
      itemId: semiFinishedItem.id,
      itemName: semiFinishedItem.name,
      batchQty: batchQty,
      producedTime: DateTime.now(),
      producedBy: staffName,
      movementIds: movementIds,
    );
    await recipeProductionRepository.saveProduction(production);

    if (lowStockAlerts.isNotEmpty) {
      NotificationService.instance.showWarning(
        "Low Stock - ${lowStockAlerts.join(" | ")}",
      );
    }

    await itemStore.loadItems();
    return production;
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

  // Per-variant identity so variants of one item don't share a notification.
  static String _lowStockSubjectId(String itemId, String? variantId) =>
      variantId != null ? '$itemId:$variantId' : itemId;

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


      // Recipe-Based items derive availability from their ingredients, not
      // their own (unused) stockQuantity — see §5/§7 of the design doc.
      if (item.isRecipeBased) {
        if (!item.allowOrderWhenOutOfStock) {
          for (final totalQuantity in itemVariantTotals[itemKey]!.values) {
            if (InventoryService.calculateAvailableToMake(item) < totalQuantity) {
              return false;
            }
          }
        }
        continue;
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

      // For logging each restock to the stock movement history.
      final stockRepo = StockMovementRepository();
      final staffName = RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
      final sessionId = await DayManagementService.getCurrentSessionId();

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

        // Recipe-Based items have no stock of their own to restore — reverse
        // the sale-time cascade back into their ingredients instead.
        if (existingItem.isRecipeBased) {
          await _restoreRecipeIngredients(
            recipeItem: existingItem,
            restoreQty: restockQuantity.toDouble(),
            items: itemStore.items,
            stockRepo: stockRepo,
            staffName: staffName,
            sessionId: sessionId,
          );
          continue;
        }

        if (!existingItem.trackInventory) {
          continue;
        }

        // Handle variant items
        double restoredQty;
        double balanceAfter = 0;
        String? variantId;
        if (cartItem.variantName != null && existingItem.variant != null) {
          restoredQty = restockQuantity.toDouble();
          await _restoreVariantStock(existingItem, cartItem, restockQuantity);
          try {
            final v = existingItem.variant!
                .firstWhere((vv) => _getVariantName(vv.variantId) == cartItem.variantName);
            variantId = v.variantId;
            balanceAfter = v.stockQuantity ?? 0;
          } catch (_) {}
        } else {
          // Handle regular items (non-variant)
          double quantityToRestore = restockQuantity.toDouble();

          // For weight-based items, parse the weight and convert to stock unit
          if (existingItem.isSoldByWeight && cartItem.weightDisplay != null) {
            final stockUnit = existingItem.unit ?? 'kg';
            quantityToRestore = _parseWeightToStockUnit(cartItem.weightDisplay!, stockUnit);
          }

          restoredQty = quantityToRestore;
          await _restoreItemStock(existingItem, quantityToRestore);
          balanceAfter = existingItem.stockQuantity;
        }

        // Log the restock (void/refund) to the per-item stock history.
        await stockRepo.saveMovement(StockMovementModel(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          itemId: existingItem.id,
          variantId: variantId,
          itemName: cartItem.variantName != null
              ? "${existingItem.name} (${cartItem.variantName})"
              : existingItem.name,
          type: 'in',
          quantity: restoredQty,
          balanceAfter: balanceAfter,
          reason: 'Void / Refund return',
          unit: existingItem.unit ?? (existingItem.isSoldByWeight ? 'kg' : 'pcs'),
          staffName: staffName,
          sessionId: sessionId,
        ));

        // Restock raises stock back up — retire any low-stock notification.
        await notificationStore.resolve(
          'low_stock', 'item', _lowStockSubjectId(existingItem.id, variantId));
      }

      // Reload items to reflect changes in UI
      await itemStore.loadItems();

    } catch (e) {
      rethrow;
    }
  }

  /// Reverses [_deductRecipeIngredients] for a voided/refunded Recipe-Based
  /// sale — adds each ingredient's consumed quantity back and logs an 'in'
  /// movement per ingredient, same tracing convention as the deduction path.
  static Future<void> _restoreRecipeIngredients({
    required Items recipeItem,
    required double restoreQty,
    required List<Items> items,
    required StockMovementRepository stockRepo,
    required String staffName,
    required String? sessionId,
  }) async {
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(recipeItem.id);
    if (recipe == null || !recipe.hasIngredients) return;
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
    final batches = restoreQty / yieldQty;

    for (final line in recipe.ingredients) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        continue;
      }
      if (!ingredient.trackInventory) continue;

      final restoreQtyForLine = batches * line.effectiveQuantity;
      await _restoreItemStock(ingredient, restoreQtyForLine);

      await stockRepo.saveMovement(StockMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: ingredient.id,
        variantId: null,
        itemName: ingredient.name,
        type: 'in',
        quantity: restoreQtyForLine,
        balanceAfter: ingredient.stockQuantity,
        reason: 'Void / Refund return (recipe: ${recipeItem.name})',
        unit: ingredient.unit ?? (ingredient.isSoldByWeight ? 'kg' : 'pcs'),
        staffName: staffName,
        sessionId: sessionId,
      ));

      await notificationStore.resolve('low_stock', 'item', _lowStockSubjectId(ingredient.id, null));
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