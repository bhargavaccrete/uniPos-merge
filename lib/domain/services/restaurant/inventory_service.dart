
import 'package:uuid/uuid.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/product_type.dart';
import '../../../data/models/restaurant/db/recipe_model.dart';
import '../../../data/models/restaurant/db/recipe_production_model.dart';
import '../../../util/restaurant/staticswitch.dart';
import '../../../data/models/restaurant/db/stock_movement_model.dart';
import '../../../data/repositories/restaurant/stock_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';
import 'day_management_service.dart';
import 'line_stock.dart';
import '../common/notification_service.dart';

/// The POS's view of an item's sellability. Mirrors the per-screen enums the
/// menu and menu-grid already render; they map this onto their own so the
/// decision itself lives in one place.
enum PosStockStatus { inStock, orderAvailable, outOfStock, notTracked }

/// One stock change a sale makes: an item, a variant, or one recipe-ingredient
/// row. Planned up front so a journaled Settle can persist the exact work
/// before doing it (StockJournal); a plain sale applies it straight away.
class SaleStockUnit {
  /// The cart line it comes from, and the recipe row for an ingredient.
  final String lineId;
  final int? recipeRow;
  final Items item;
  final String? variantId;

  /// Stock units to deduct (weight already converted).
  final double qty;
  final String reason;
  final String label;

  const SaleStockUnit({
    required this.lineId,
    this.recipeRow,
    required this.item,
    this.variantId,
    required this.qty,
    required this.reason,
    required this.label,
  });

  String get unit => item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');

  /// Stable per entry: `<key>:<lineId>` or `<key>:<lineId>:<row>`.
  String uidFor(String key) =>
      recipeRow == null ? '$key:$lineId' : '$key:$lineId:$recipeRow';
}

class InventoryService {
  /// Deducts [cartItems] straight away. Callers that save the order lines
  /// should use [planSale] instead, so the lines carry the stock stamp
  /// every restore relies on.
  static Future<void> deductStockForOrder(List<CartItem> cartItems) async {
    await applyPlannedUnits(await planSaleDeductions(cartItems));
  }

  /// Writes [units] (from [planSale] / [planSaleDeductions]): stock through
  /// the per-item queue, one movement row each, then the low-stock toast.
  static Future<void> applyPlannedUnits(List<SaleStockUnit> units) async {
    if (units.isEmpty) return;

    // For logging each deduction to the stock movement history (reason = "Sale").
    final stockRepo = StockMovementRepository();
    final staffName = RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
    final sessionId = await DayManagementService.getCurrentSessionId();
    final List<String> lowStockAlerts = [];

    for (final u in units) {
      final stockAfter = await itemStore.applyStockDelta(
        itemId: u.item.id,
        variantId: u.variantId,
        delta: -u.qty,
      );
      await _logMovementAndAlert(
        stockRepo: stockRepo,
        item: u.item,
        label: u.label,
        type: 'out',
        quantity: u.qty,
        balanceAfter: stockAfter,
        reason: u.reason,
        variantId: u.variantId,
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

  /// The stock changes selling [cartItems] makes — no writes.
  static Future<List<SaleStockUnit>> planSaleDeductions(
          List<CartItem> cartItems) async =>
      (await planSale(cartItems)).units;

  /// The single resolution path for every sale, with no writes: the stock
  /// units to apply, and [cartItems] stamped with what each line takes
  /// (`ownStockQty` from prepared stock, `freshQty` made from the recipe) —
  /// the record every restore reads ([LineStock]).
  ///
  /// Product id first, then a lowercase name match. Finished made to order
  /// cascades into its tracked ingredients (one level deep — an ingredient
  /// must be Raw Material or Semi-Finished, see
  /// docs/inventory_recipe_system_plan.md §5); the hybrid takes prepared
  /// stock first and makes the rest fresh; everything else sells its own
  /// stock. Untracked items and deleted ingredients are skipped; a variant
  /// line whose variant no longer exists is skipped (nothing to deduct,
  /// nothing to log); weight lines deduct quantity × single weight.
  static Future<({List<CartItem> lines, List<SaleStockUnit> units})> planSale(
      List<CartItem> cartItems) async {
    await itemStore.ensureLoaded();
    // Variant names are needed for lookup. Load only if not yet loaded: the
    // store is lazy, and a server-side order can be its first caller.
    if (variantStore.variants.isEmpty) await variantStore.loadVariants();
    final items = itemStore.items;
    final units = <SaleStockUnit>[];
    final stampedLines = <CartItem>[];
    // Prepared stock still unclaimed in THIS plan, per hybrid item, so two
    // lines of one dish cannot both take the same prepared units.
    final preparedLeft = <String, int>{};

    // Recipe cascade for [qty] of [dish]: one unit per tracked ingredient
    // row, so the per-item history explains "why did bun stock drop" as
    // "linked to Burger sales". Returns whether a recipe was applied.
    bool addFresh(CartItem cartItem, Items dish, int qty) {
      final RecipeModel? recipe = recipeRepository.getRecipeForItem(dish.id);
      if (recipe == null || !recipe.hasIngredients) return false; // unconfigured recipe
      final lines = ingredientQuantitiesFor(recipe, qty.toDouble());
      for (var row = 0; row < lines.length; row++) {
        final line = lines[row];
        Items? ingredient;
        try {
          ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
        } catch (_) {
          continue; // ingredient item was deleted — skip rather than crash the sale
        }
        if (!ingredient.trackInventory) continue;
        units.add(SaleStockUnit(
          lineId: cartItem.id,
          recipeRow: row,
          item: ingredient,
          qty: line.quantity,
          reason: 'Sale (recipe: ${dish.name})',
          label: ingredient.name,
        ));
      }
      return true;
    }

    // A new sale has returned nothing yet — also overrides any value a
    // network client (server / Captain order) may have sent.
    void stamp(CartItem cartItem, {int own = 0, int fresh = 0}) =>
        stampedLines.add(cartItem.copyWith(
            ownStockQty: own, freshQty: fresh, restockedQuantity: 0));

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
          stamp(cartItem); // not in inventory: nothing moved
          continue;
        }
      }

      // Finished, made to order: no stock of its own — cascade into the
      // recipe (none configured → nothing to deduct).
      if (item.isMadeToOrder) {
        final made = addFresh(cartItem, item, cartItem.quantity);
        stamp(cartItem, fresh: made ? cartItem.quantity : 0);
        continue;
      }

      // Finished, made in advance + make fresh when out: prepared stock
      // first, the shortfall from the recipe. Whole-unit, non-variant,
      // non-weight lines only; anything else sells from prepared stock.
      if (makesFreshWhenOut(item) && usesDerivedAvailability(item)) {
        final left = preparedLeft[item.id] ??=
            item.trackInventory ? item.stockQuantity.floor().clamp(0, 1 << 30) : 0;
        final fromPrepared = cartItem.quantity < left ? cartItem.quantity : left;
        preparedLeft[item.id] = left - fromPrepared;
        if (fromPrepared > 0) {
          units.add(SaleStockUnit(
            lineId: cartItem.id,
            item: item,
            qty: fromPrepared.toDouble(),
            reason: 'Sale',
            label: item.name,
          ));
        }
        final fresh = cartItem.quantity - fromPrepared;
        final made = fresh > 0 && addFresh(cartItem, item, fresh);
        stamp(cartItem, own: fromPrepared, fresh: made ? fresh : 0);
        continue;
      }

      if (!item.trackInventory) {
        stamp(cartItem);
        continue;
      }

      if (cartItem.variantName != null) {
        // Matched by NAME, exactly as before; only the id is handed on.
        final variant = item.variant
            ?.where((v) => _getVariantName(v.variantId) == cartItem.variantName)
            .firstOrNull;
        if (variant == null) {
          stamp(cartItem); // variant gone: nothing to deduct
          continue;
        }
        units.add(SaleStockUnit(
          lineId: cartItem.id,
          item: item,
          variantId: variant.variantId,
          qty: cartItem.quantity.toDouble(),
          reason: 'Sale',
          label: "${item.name} (${cartItem.variantName})",
        ));
        stamp(cartItem, own: cartItem.quantity);
        continue;
      }

      double quantityToDeduct = cartItem.quantity.toDouble();
      if (item.isSoldByWeight && cartItem.weightDisplay != null) {
        final stockUnit = item.unit ?? "kg";
        final singleWeight = _parseWeightToStockUnit(cartItem.weightDisplay!, stockUnit);
        quantityToDeduct = cartItem.quantity * singleWeight;
      }
      units.add(SaleStockUnit(
        lineId: cartItem.id,
        item: item,
        qty: quantityToDeduct,
        reason: 'Sale',
        label: item.name,
      ));
      stamp(cartItem, own: cartItem.quantity);
    }
    return (lines: stampedLines, units: units);
  }

  /// The in-app low-stock toast line for a deduction that left [item] at
  /// [balanceAfter], or null. "Out of stock" is a hard fact and shows even
  /// with alerts switched off; only the "N left" warning respects the flag.
  static String? lowStockToastFor(Items item, String label, double balanceAfter) {
    final lowAlertsOn = item.lowStockAlertEnabled && AppSettings.lowStockAlertsEnabled;
    if (balanceAfter <= 0) return "$label is out of stock";
    if (lowAlertsOn && balanceAfter <= item.effectiveLowStockThreshold) {
      return "$label: ${balanceAfter.toStringAsFixed(0)} ${item.unit ?? "units"} left";
    }
    return null;
  }

  /// Shared by every stock deduction path (direct item, variant, and
  /// recipe-ingredient cascade): writes the audit-trail movement row and
  /// collects the in-app low-stock toast lines for [item]. The persisted
  /// notification is reconciled by `LowStockSyncService`, not raised here.
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
      unitCost: item.lastPurchaseCost,
    ));

    if (type != 'out') return; // low-stock alerts only make sense for deductions

    // These strings are the IN-APP toast shown right after the order ("Low
    // Stock - Paneer: 2 left"). The PERSISTED notification is no longer raised
    // here — LowStockSyncService reconciles the whole set off ItemStore, which
    // also covers the seven other paths that move stock and never had a hook.
    final toast = lowStockToastFor(item, label, balanceAfter);
    if (toast != null) lowStockAlerts.add(toast);
  }

  /// How much of each ingredient [recipe] consumes to make [outputQty] units
  /// of its product. One line per recipe row (not merged by ingredient id), so
  /// a recipe that lists the same ingredient twice still produces two audit
  /// rows, exactly as before this was extracted.
  ///
  /// PURE — no Hive, no service locator. This is the single definition of the
  /// recipe scaling rule; the sale, void/refund and production paths all call
  /// it rather than each re-deriving `batches * effectiveQuantity`.
  static List<({String ingredientItemId, double quantity})> ingredientQuantitiesFor(
    RecipeModel recipe,
    double outputQty,
  ) {
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
    final batches = outputQty / yieldQty;
    return [
      for (final line in recipe.ingredients)
        (
          ingredientItemId: line.ingredientItemId,
          quantity: batches * line.effectiveQuantity,
        ),
    ];
  }

  /// The producible quantity [recipe] supports given a stock lookup.
  ///
  /// PURE — [lookupIngredient] supplies the ingredient records, so this is
  /// testable without Hive or the locator. [calculateAvailableToMake] is the
  /// locator-backed wrapper; both share this one implementation so the POS and
  /// the Recipes screen can never disagree.
  ///
  /// Returns [double.infinity] when no ingredient is inventory-tracked (nothing
  /// constrains production), and 0 when a referenced ingredient no longer
  /// exists.
  static double availableToMakeFrom(
    RecipeModel recipe,
    Items? Function(String ingredientItemId) lookupIngredient,
  ) {
    if (!recipe.hasIngredients) return 0;
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;

    double? minBatches;
    for (final line in recipe.ingredients) {
      if (line.effectiveQuantity <= 0) continue;
      final ingredient = lookupIngredient(line.ingredientItemId);
      if (ingredient == null) {
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
    if (recipe == null) return 0;
    return availableToMakeFrom(recipe, _lookupItem);
  }

  static Items? _lookupItem(String id) {
    try {
      return itemStore.items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  /// The availability figure that governs [item], whatever its product type.
  ///
  /// Recipe-Based items store no stock of their own, so their availability is
  /// derived live from ingredients; every other type reports its stored
  /// [Items.stockQuantity] exactly as before. **This is the only figure the POS
  /// and the cart guards should compare quantities against** — it keeps the
  /// recipe calculation in one place instead of scattered through the UI.
  ///
  /// By Finished preparation mode: made to order → what its recipe can make
  /// (no recipe → not limited); made in advance with "make fresh when out" →
  /// prepared stock plus what the recipe can make; anything else → its own
  /// stored stock.
  static double effectiveAvailableStock(Items item) {
    if (item.isMadeToOrder) {
      final recipe = _usableRecipe(item);
      if (recipe == null) {
        // A legacy Recipe-Based item was meant to have one: nothing can be
        // made (as before). A new made-to-order dish may have none.
        return isRecipeMissing(item) ? 0 : double.infinity;
      }
      return availableToMakeFrom(recipe, _lookupItem);
    }
    if (usesDerivedAvailability(item)) {
      // Hybrid. No usable recipe → prepared stock only.
      final recipe = _usableRecipe(item);
      if (recipe == null) return item.stockQuantity;
      final canMake = availableToMakeFrom(recipe, _lookupItem);
      if (canMake.isInfinite) return double.infinity;
      final prepared = item.trackInventory && item.stockQuantity > 0
          ? item.stockQuantity
          : 0.0;
      return prepared + canMake;
    }
    return item.stockQuantity;
  }

  /// A legacy item still stored as Recipe-Based whose recipe was never set
  /// up. Blocked at the POS exactly as before Phase 1, so a forgotten recipe
  /// never becomes a silent sale with no deduction. New made-to-order
  /// Finished items (recipe optional) are never "missing" one.
  static bool isRecipeMissing(Items item) =>
      item.productType == ProductType.recipeBased && _usableRecipe(item) == null;

  /// The item's recipe when it has ingredients, else null.
  static RecipeModel? _usableRecipe(Items item) {
    final recipe = recipeRepository.getRecipeForItem(item.id);
    return (recipe != null && recipe.hasIngredients) ? recipe : null;
  }

  /// Finished, made in advance, "make fresh when out" on, with a usable
  /// recipe — the hybrid: prepared stock first, the shortfall made fresh.
  static bool makesFreshWhenOut(Items item) =>
      item.isMadeInAdvance &&
      item.makeFreshWhenOut &&
      _usableRecipe(item) != null;

  /// Whether [item]'s availability is derived (made to order, or made in
  /// advance with "make fresh when out") rather than its stored stock alone.
  /// Decided from the item alone — no recipe lookup — so the stock decisions
  /// stay testable without storage; [effectiveAvailableStock] supplies the
  /// number (no recipe → not limited / prepared stock only). Cart, menu and
  /// stock-check code branch on this, never on the product type.
  ///
  /// The hybrid applies to whole-unit, non-variant items only — the same
  /// condition [planSaleDeductions] uses; a variant or weight item sells from
  /// its prepared stock.
  static bool usesDerivedAvailability(Items item) =>
      item.isMadeToOrder ||
      (item.isMadeInAdvance &&
          item.makeFreshWhenOut &&
          !item.hasVariants &&
          !item.isSoldByWeight);

  /// The POS status implied by an availability figure.
  ///
  /// PURE. [available] is whatever [effectiveAvailableStock] returned — a
  /// stored quantity for directly-stocked items, a derived "can make" count for
  /// Recipe-Based ones. An infinite [available] means nothing constrains the
  /// item, which reads the same as untracked.
  ///
  /// [allowOrderWhenOutOfStock] is honoured identically for every product
  /// type: at zero availability it decides between letting the order through
  /// ([PosStockStatus.orderAvailable]) and blocking it
  /// ([PosStockStatus.outOfStock]).
  static PosStockStatus posStatusFromAvailable({
    required double available,
    required bool allowOrderWhenOutOfStock,
  }) {
    if (available.isInfinite) return PosStockStatus.notTracked;
    if (available > 0) return PosStockStatus.inStock;
    return allowOrderWhenOutOfStock
        ? PosStockStatus.orderAvailable
        : PosStockStatus.outOfStock;
  }

  /// Recipe-aware replacement for [Items.isInStock].
  ///
  /// The model getter reads the stored `stockQuantity`, which a Recipe-Based
  /// item never populates — it would report a Burger as out of stock however
  /// many buns are on the shelf. Every screen that shows stock status should
  /// call this instead; non-recipe types delegate straight to the model getter,
  /// so their behaviour is bit-for-bit unchanged.
  /// [available] overrides the resolved availability — production omits it and
  /// the figure is looked up; tests supply it so the decision can be exercised
  /// without Hive or the service locator. One implementation either way.
  static bool isInStock(Items item, {double? available}) {
    if (!usesDerivedAvailability(item)) return item.isInStock;
    final a = available ?? effectiveAvailableStock(item);
    // Infinite = nothing constrains it (no tracked ingredients).
    return a.isInfinite || a > 0;
  }

  /// Recipe-aware replacement for [Items.isLowStock].
  ///
  /// Applies the same opt-in gates the model getter does (per-item alert flag
  /// plus the global switch), but measures against how many can be made rather
  /// than a stored figure. `trackInventory` is deliberately not a gate for
  /// Recipe-Based items — their ingredients carry their own flags, matching
  /// [isStockGoverned].
  /// [available] behaves as it does on [isInStock] — an optional override so
  /// the decision is testable without the locator.
  static bool isLowStock(Items item, {double? available}) {
    if (!usesDerivedAvailability(item)) return item.isLowStock;
    if (!item.lowStockAlertEnabled || !AppSettings.lowStockAlertsEnabled) {
      return false;
    }
    final threshold = item.effectiveLowStockThreshold;
    if (threshold <= 0) return false;
    final a = available ?? effectiveAvailableStock(item);
    if (a.isInfinite) return false;
    return a > 0 && a <= threshold;
  }

  /// Whether [item]'s availability is governed by stock at all.
  ///
  /// `trackInventory` is the switch for directly-stocked items, but
  /// Recipe-Based items are always governed — their availability comes from
  /// ingredients, which have their own tracking flags. Mirrors the branch
  /// [checkStockAvailability] already applies.
  static bool isStockGoverned(Items item) =>
      item.trackInventory || usesDerivedAvailability(item);

  /// Items that own stock made from a recipe ahead of sale: Semi-Finished
  /// and made-in-advance Finished. Raw, Trade and made-to-order never are.
  static bool canProduce(Items item) =>
      item.isSemiFinished || item.isMadeInAdvance;

  /// Produces one batch of [item] from its recipe: validates every
  /// ingredient has enough stock (all-or-nothing — no partial deduction on
  /// shortage), deducts the ingredients for the planned [batchQty], credits
  /// the item with [actualQty] (what was really made; defaults to the
  /// planned batch), logs a StockMovementModel per ingredient plus one for
  /// the produced item, and writes an append-only [RecipeProductionModel]
  /// row linking all of them. Unit cost = consumed cost ÷ actual output.
  /// Throws [Exception] with a user-facing message on validation failure.
  /// See docs/inventory_recipe_system_plan.md §6.3.
  static Future<RecipeProductionModel> produceBatch({
    required Items item,
    required double batchQty,
    double? actualQty,
  }) async {
    final semiFinishedItem = item;
    if (!canProduce(item)) {
      throw Exception('${item.name} is not produced in batches — only '
          'Semi-Finished and made-in-advance Finished items are.');
    }
    if (batchQty <= 0) {
      throw Exception('Batch quantity must be greater than zero.');
    }
    final outputQty = actualQty ?? batchQty;
    if (outputQty <= 0) {
      throw Exception('Actual output must be greater than zero.');
    }
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(semiFinishedItem.id);
    if (recipe == null || !recipe.hasIngredients) {
      throw Exception('${semiFinishedItem.name} has no recipe configured.');
    }

    await itemStore.ensureLoaded();
    final items = itemStore.items;
    final requirements = ingredientQuantitiesFor(recipe, batchQty);

    // Validate stock availability up front so production is all-or-nothing.
    final List<String> shortages = [];
    for (final line in requirements) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        shortages.add('a required ingredient no longer exists');
        continue;
      }
      if (!ingredient.trackInventory) continue;
      final required = line.quantity;
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

    for (final line in requirements) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        continue;
      }
      if (!ingredient.trackInventory) continue;

      final deductQty = line.quantity;
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
        unitCost: ingredient.lastPurchaseCost,
      ));
      movementIds.add(movementId);

      // In-app toast only; the persisted event is reconciled by
      // LowStockSyncService off the ItemStore write this deduction made.
      final lowAlertsOn = ingredient.lowStockAlertEnabled && AppSettings.lowStockAlertsEnabled;
      if (stockAfter <= 0) {
        lowStockAlerts.add('${ingredient.name} is out of stock');
      } else if (lowAlertsOn && stockAfter <= ingredient.effectiveLowStockThreshold) {
        lowStockAlerts.add(
          '${ingredient.name}: ${stockAfter.toStringAsFixed(0)} ${ingredient.unit ?? "units"} left',
        );
      }
    }

    final producedMovementId = const Uuid().v4();
    // Cost per produced unit, from this batch's own recipe cost ÷ yield —
    // never a manually entered figure. Every downstream cost lookup (a
    // parent recipe using this Semi-Finished item as an ingredient, Food
    // Cost Report, ingredient/wastage reports) reads `lastPurchaseCost`, so
    // it must be written back here or the item's cost stays invisible (₹0)
    // to all of them. The next production run overwrites it, the same way a
    // Raw Material's lastPurchaseCost is overwritten by its next GRN.
    // Consumed cost (the planned batch) spread over what was actually made.
    final plannedUnitCost = recipe.estimatedCostPerUnit((id) {
      Items? ing;
      try {
        ing = items.firstWhere((i) => i.id == id);
      } catch (_) {
        return 0.0;
      }
      return ing.lastPurchaseCost ?? 0.0;
    });
    final producedUnitCost = plannedUnitCost * batchQty / outputQty;
    // Stock increase and the new unit cost are applied in ONE write. Done
    // separately, `semiFinishedItem.save()` would write the pre-production
    // stock back over the increase and silently lose the batch.
    final producedBalance = await itemStore.applyStockDelta(
      itemId: semiFinishedItem.id,
      delta: outputQty,
      lastPurchaseCost: producedUnitCost,
    );
    await stockRepo.saveMovement(StockMovementModel(
      id: producedMovementId,
      timestamp: DateTime.now(),
      itemId: semiFinishedItem.id,
      variantId: null,
      itemName: semiFinishedItem.name,
      type: 'in',
      quantity: outputQty,
      balanceAfter: producedBalance,
      reason: 'Production batch',
      unit: semiFinishedItem.unit ?? (semiFinishedItem.isSoldByWeight ? 'kg' : 'pcs'),
      staffName: staffName,
      sessionId: sessionId,
      unitCost: producedUnitCost,
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
      actualQty: outputQty == batchQty ? null : outputQty,
    );
    await recipeProductionRepository.saveProduction(production);

    if (lowStockAlerts.isNotEmpty) {
      NotificationService.instance.showWarning(
        "Low Stock - ${lowStockAlerts.join(" | ")}",
      );
    }

    return production;
  }

  /// Through the store so the ObservableList entry is replaced and MobX fires.
  /// The balance is recomputed from the CURRENT store entry, so several lines
  /// of the same item in one order compound correctly instead of each starting
  /// from the same captured snapshot.
  static Future<double> _deductItemStock(Items item, double quantity) async {
    return itemStore.applyStockDelta(itemId: item.id, delta: -quantity);
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
    await itemStore.ensureLoaded();
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


      // Made to order / hybrid: availability is derived (ingredients, plus
      // prepared stock for the hybrid), not the stored stockQuantity alone.
      if (usesDerivedAvailability(item)) {
        if (!item.allowOrderWhenOutOfStock) {
          final available = effectiveAvailableStock(item);
          for (final totalQuantity in itemVariantTotals[itemKey]!.values) {
            if (available < totalQuantity) return false;
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
            // Variant names resolve through variantStore. This item has
            // variants, so an empty list can only mean the lazy store hasn't
            // loaded yet.
            if (item.variant != null &&
                item.variant!.isNotEmpty &&
                variantStore.variants.isEmpty) {
              await variantStore.loadVariants();
            }
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

  /// Restore stock for a voided/cancelled active order: every line in full.
  /// Unstamped (pre-Phase-1) lines that are identical merge into one restore,
  /// as they always did; stamped lines stay separate — each carries its own
  /// record of what its sale took.
  static Future<void> restoreStockForOrder(List<CartItem> items) {
    final legacy = <CartItem, int>{};
    final requests = <({CartItem line, int qty})>[];
    for (final item in items) {
      if (item.quantity <= 0) continue;
      if (item.hasStockStamp) {
        requests.add((line: item, qty: item.quantity));
      } else {
        legacy[item] = (legacy[item] ?? 0) + item.quantity;
      }
    }
    return restoreLines([
      for (final e in legacy.entries)
        (line: e.key.copyWith(quantity: e.value), qty: e.value),
      ...requests,
    ]);
  }

  /// Restore the given quantity per key. A key may be a merge of several
  /// identical lines (so its own quantity can be smaller than the amount):
  /// the amount is honoured exactly, as before — the restockedQuantity cap
  /// applies only on the per-line path ([restoreLines]).
  static Future<void> restoreStockForRefund(Map<CartItem, int> itemsToRestock) =>
      restoreLines([
        for (final e in itemsToRestock.entries)
          (
            line: e.key.copyWith(
              quantity: e.key.quantity > e.value ? e.key.quantity : e.value,
              restockedQuantity: 0,
            ),
            qty: e.value,
          ),
      ]);

  /// Returns [qty] units of each order line to stock — the single restore
  /// path (void, cancel, edit-reduce, refund, EOD).
  ///
  /// A stamped line (sold since Phase 1) restores what its sale actually
  /// did, per [LineStock.take]: the fresh part back into the recipe's
  /// ingredients first, the rest to prepared stock — never by the item's
  /// current type, and never more than `quantity − restockedQuantity`. An
  /// unstamped line restores by the current type, exactly as before.
  ///
  /// Callers that keep the line (closed orders) record the return with
  /// [LineStock.restocked]; callers that shrink it use [LineStock.reduced].
  static Future<void> restoreLines(
      List<({CartItem line, int qty})> requests) async {
    if (requests.isEmpty) return;
    await itemStore.ensureLoaded();
    if (variantStore.variants.isEmpty) await variantStore.loadVariants();

    // For logging each restock to the stock movement history.
    final stockRepo = StockMovementRepository();
    final staffName = RestaurantSession.staffName ?? RestaurantSession.effectiveRole;
    final sessionId = await DayManagementService.getCurrentSessionId();

    for (final req in requests) {
      final cartItem = req.line;
      final r = LineStock.take(cartItem, req.qty);
      if (r.counted <= 0) continue;

      // Find the item - try by productId first, then by name
      Items? existingItem;
      if (cartItem.productId.isNotEmpty) {
        try {
          existingItem = itemStore.items.firstWhere(
            (item) => item.id == cartItem.productId,
          );
        } catch (_) {}
      }
      if (existingItem == null) {
        try {
          existingItem = itemStore.items.firstWhere(
            (item) => item.name.toLowerCase().trim() == cartItem.title.toLowerCase().trim(),
          );
        } catch (_) {
          continue;
        }
      }

      final int freshUnits;
      final int ownUnits;
      if (r.isLegacy) {
        // Pre-Phase-1 line: decide by the item's current type, as before.
        freshUnits = existingItem.isRecipeBased ? r.counted : 0;
        ownUnits = existingItem.isRecipeBased ? 0 : r.counted;
      } else {
        freshUnits = r.fromFresh;
        ownUnits = r.fromOwn;
      }

      if (freshUnits > 0) {
        await _restoreRecipeIngredients(
          recipeItem: existingItem,
          restoreQty: freshUnits.toDouble(),
          items: itemStore.items,
          stockRepo: stockRepo,
          staffName: staffName,
          sessionId: sessionId,
        );
      }
      if (ownUnits > 0 && existingItem.trackInventory) {
        await _restoreOwnStock(
          existingItem: existingItem,
          cartItem: cartItem,
          restockQuantity: ownUnits,
          stockRepo: stockRepo,
          staffName: staffName,
          sessionId: sessionId,
        );
      }
    }
  }

  /// Puts [restockQuantity] units of [cartItem] back into [existingItem]'s
  /// own stock (variant, weight or plain) and logs the movement.
  static Future<void> _restoreOwnStock({
    required Items existingItem,
    required CartItem cartItem,
    required int restockQuantity,
    required StockMovementRepository stockRepo,
    required String staffName,
    required String? sessionId,
  }) async {
    double restoredQty;
    double balanceAfter = 0;
    String? variantId;
    if (cartItem.variantName != null && existingItem.variant != null) {
      restoredQty = restockQuantity.toDouble();
      // Balance comes from the helper — re-reading `existingItem` would
      // report the pre-restore figure into the movement row.
      balanceAfter =
          await _restoreVariantStock(existingItem, cartItem, restockQuantity);
      try {
        variantId = existingItem.variant!
            .firstWhere((vv) => _getVariantName(vv.variantId) == cartItem.variantName)
            .variantId;
      } catch (_) {}
    } else {
      // Handle regular items (non-variant)
      double quantityToRestore = restockQuantity.toDouble();

      // For weight-based items, parse the weight and convert to stock unit.
      // Mirrors the deduction: quantity × single weight.
      if (existingItem.isSoldByWeight && cartItem.weightDisplay != null) {
        final stockUnit = existingItem.unit ?? 'kg';
        quantityToRestore = restockQuantity *
            _parseWeightToStockUnit(cartItem.weightDisplay!, stockUnit);
      }

      restoredQty = quantityToRestore;
      balanceAfter =
          await _restoreItemStock(existingItem, quantityToRestore);
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
      unitCost: existingItem.lastPurchaseCost,
    ));
    // Restock raises stock back up; LowStockSyncService retires the
    // notification off the ItemStore write above.
  }

  /// Reverses the recipe cascade of [planSaleDeductions] for a voided/refunded Recipe-Based
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

    for (final line in ingredientQuantitiesFor(recipe, restoreQty)) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        continue;
      }
      if (!ingredient.trackInventory) continue;

      final restoreQtyForLine = line.quantity;
      final ingredientBalance =
          await _restoreItemStock(ingredient, restoreQtyForLine);

      await stockRepo.saveMovement(StockMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: ingredient.id,
        variantId: null,
        itemName: ingredient.name,
        type: 'in',
        quantity: restoreQtyForLine,
        balanceAfter: ingredientBalance,
        reason: 'Void / Refund return (recipe: ${recipeItem.name})',
        unit: ingredient.unit ?? (ingredient.isSoldByWeight ? 'kg' : 'pcs'),
        staffName: staffName,
        sessionId: sessionId,
        unitCost: ingredient.lastPurchaseCost,
      ));

      // Ingredient stock went back up; LowStockSyncService retires the
      // notification off the ItemStore write above.
    }
  }

  /// Restore stock for a regular item (non-variant). Returns the new balance —
  /// callers must use it rather than re-reading the passed instance, which the
  /// store's list replacement leaves stale.
  static Future<double> _restoreItemStock(Items item, double quantity) async {
    return itemStore.applyStockDelta(itemId: item.id, delta: quantity);
  }

  /// Restore stock for a variant item. Returns the new balance for the matched
  /// variant, or 0 when no variant matches (same no-op as before).
  static Future<double> _restoreVariantStock(
      Items item, CartItem cartItem, int quantity) async {
    if (item.variant == null) {
      return 0;
    }

    for (var variant in item.variant!) {
      if (_getVariantName(variant.variantId) == cartItem.variantName) {
        // First match only, as the original `break` did.
        return itemStore.applyStockDelta(
          itemId: item.id,
          variantId: variant.variantId,
          delta: quantity.toDouble(),
        );
      }
    }
    return 0;
  }
}