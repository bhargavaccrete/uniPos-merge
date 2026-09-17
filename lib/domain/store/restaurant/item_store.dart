import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import '../../../core/plan/entitlement_keys.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../data/repositories/restaurant/item_repository.dart';

part 'item_store.g.dart';

class ItemStore = _ItemStore with _$ItemStore;

abstract class _ItemStore with Store {
  final ItemRepository _repository;

  _ItemStore(this._repository) {
    // Load items on initialization
    _initialLoad = loadItems();
  }

  /// The constructor's load, kept so callers can await it.
  late final Future<void> _initialLoad;
  bool _hasLoaded = false;

  /// Completes once items have loaded, without re-reading Hive.
  ///
  /// The store is lazy and its constructor load isn't awaited, so a caller
  /// that reads `items` in the same turn it first touches the store sees an
  /// empty list. If the initial load failed (`loadItems` records
  /// `errorMessage`), this retries, as the explicit reload it replaces did.
  Future<void> ensureLoaded() async {
    await _initialLoad;
    if (!_hasLoaded) await loadItems();
  }

  // ==================== OBSERVABLES ====================

  @observable
  ObservableList<Items> items = ObservableList<Items>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  String? selectedCategoryId;

  @observable
  String? vegFilter; // 'veg', 'non-veg', or null for all

  @observable
  bool? enabledFilter; // true for enabled, false for disabled, null for all

  @observable
  bool showLowStockOnly = false;

  @observable
  bool showOutOfStockOnly = false;

  // ==================== COMPUTED ====================

  @computed
  List<Items> get filteredItems {
    var result = items.toList();

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final lowercaseQuery = searchQuery.toLowerCase();
      result = result
          .where((item) =>
              item.name.toLowerCase().contains(lowercaseQuery) ||
              (item.itemCode != null && item.itemCode!.toLowerCase().contains(lowercaseQuery)))
          .toList();
    }

    // Apply category filter
    if (selectedCategoryId != null) {
      result = result
          .where((item) => item.categoryOfItem == selectedCategoryId)
          .toList();
    }

    // Apply veg/non-veg filter
    if (vegFilter != null) {
      result = result.where((item) => item.isVeg == vegFilter).toList();
    }

    // Apply enabled/disabled filter
    if (enabledFilter != null) {
      result = result.where((item) => item.isEnabled == enabledFilter).toList();
    }

    // Apply low stock filter
    if (showLowStockOnly) {
      result = result
          .where((item) =>
              item.trackInventory &&
              item.stockQuantity < 10 &&
              item.stockQuantity > 0)
          .toList();
    }

    // Apply out of stock filter
    if (showOutOfStockOnly) {
      result = result
          .where((item) => item.trackInventory && item.stockQuantity <= 0)
          .toList();
    }

    return result;
  }

  @computed
  int get itemCount => items.length;

  @computed
  int get filteredItemCount => filteredItems.length;

  @computed
  bool get hasItems => items.isNotEmpty;

  @computed
  List<Items> get enabledItems => items.where((item) => item.isEnabled).toList();

  @computed
  List<Items> get disabledItems => items.where((item) => !item.isEnabled).toList();

  @computed
  List<Items> get lowStockItems =>
      items.where((item) => item.trackInventory && item.stockQuantity < 10 && item.stockQuantity > 0).toList();

  @computed
  List<Items> get outOfStockItems =>
      items.where((item) => item.trackInventory && item.stockQuantity <= 0).toList();

  @computed
  int get lowStockCount => lowStockItems.length;

  @computed
  int get outOfStockCount => outOfStockItems.length;

  // ==================== ACTIONS ====================

  @action
  Future<void> loadItems() async {
    try {
      isLoading = true;
      errorMessage = null;

      final loadedItems = await _repository.getAllItems();
      items.clear();
      items.addAll(loadedItems);
      _hasLoaded = true;
    } catch (e) {
      errorMessage = 'Failed to load items: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> addItem(Items item) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Plan gate — action permission + item cap (also covers bulk import).
      if (!PlanEnforce.allows(EntKeys.manageMenuItemsAdd)) {
        errorMessage = 'Adding items isn’t available on your current plan.';
        return false;
      }
      if (!PlanEnforce.withinLimit(EntKeys.manageMenuItemsMax, items.length)) {
        final max = PlanEnforce.limit(EntKeys.manageMenuItemsMax);
        errorMessage = 'Item limit reached (max $max). Upgrade to add more.';
        return false;
      }

      // Duplicate name guard — case-insensitive check within the same category
      final duplicate = items.any((i) =>
          i.name.trim().toLowerCase() == item.name.trim().toLowerCase() &&
          i.categoryOfItem == item.categoryOfItem);
      if (duplicate) {
        errorMessage =
            '"${item.name}" already exists in this category. Use a different name.';
        return false;
      }

      // Duplicate item code guard
      if (item.itemCode != null && item.itemCode!.isNotEmpty) {
        final duplicateCode = items.any((i) => i.itemCode == item.itemCode);
        if (duplicateCode) {
          errorMessage = 'Item code already exists. Please enter a different code.';
          return false;
        }
      }

      await _repository.addItem(item);
      items.add(item);

      return true;
    } catch (e) {
      errorMessage = 'Failed to add item: $e';
      debugPrint('Error adding item: $e');

      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateItem(Items item) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Plan gate — edit permission.
      if (!PlanEnforce.allows(EntKeys.manageMenuItemsEdit)) {
        errorMessage = 'Editing items isn’t available on your current plan.';
        return false;
      }

      // Duplicate item code guard for update
      if (item.itemCode != null && item.itemCode!.isNotEmpty) {
        final duplicateCode = items.any((i) => i.itemCode == item.itemCode && i.id != item.id);
        if (duplicateCode) {
          errorMessage = 'Item code already exists. Please enter a different code.';
          return false;
        }
      }

      await _repository.updateItem(item);

      // Replace the item in place so it keeps its list position. Assigning a new
      // object to an ObservableList index triggers MobX (same pattern as
      // toggleItemStatus/updateStock); a full loadItems() would clear+refill the
      // list and, for legacy auto-keyed items, reorder them.
      final index = items.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        items[index] = item;
      } else {
        items.add(item);
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update item: $e';
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> deleteItem(String itemId) async {
    try {
      isLoading = true;
      errorMessage = null;

      // Plan gate — delete permission.
      if (!PlanEnforce.allows(EntKeys.manageMenuItemsDelete)) {
        errorMessage = 'Deleting items isn’t available on your current plan.';
        return false;
      }

      await _repository.deleteItem(itemId);

      // Remove from local list
      items.removeWhere((i) => i.id == itemId);

      return true;
    } catch (e) {
      errorMessage = 'Failed to delete item: $e';
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> toggleItemStatus(String itemId) async {
    try {
      await _repository.toggleItemStatus(itemId);

      // Update in local list
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final item = items[index];
        items[index] = item.copyWith(
          isEnabled: !item.isEnabled,
          lastEditedTime: DateTime.now(),
        );
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to toggle item status: $e';
      return false;
    }
  }

  @action
  Future<bool> updateStock(String itemId, double newQuantity) async {
    try {
      await _repository.updateStock(itemId, newQuantity);

      // Update in local list
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        final item = items[index];
        items[index] = item.copyWith(
          stockQuantity: newQuantity,
          lastEditedTime: DateTime.now(),
        );
      }

      return true;
    } catch (e) {
      errorMessage = 'Failed to update stock: $e';
      return false;
    }
  }

  /// Applies [delta] to an item's stock (or to one variant's when [variantId]
  /// is given) and returns the resulting balance.
  ///
  /// Rebuilds the list entry rather than mutating the model, because mutating
  /// a field on an object already inside an ObservableList is invisible to
  /// MobX — the same reason `TableStore.updateTableStatus` replaces its entry.
  /// This is what lets stock changes reach the UI without a full reload.
  ///
  /// Persists through the repository directly, NOT through [updateItem]: that
  /// one is gated on `manageMenuItemsEdit`, and selling an item is not a menu
  /// edit — routing stock through it would silently stop deducting stock on
  /// plans without that permission.
  ///
  /// [lastPurchaseCost], when supplied, is written in the SAME update so a
  /// caller never has to follow up with a second persist that could clobber
  /// the stock it just wrote (production and GRN both need this).
  ///
  /// Mutations on the same item run one at a time, so each reads the balance
  /// the previous one wrote — two concurrent sales cannot both start from the
  /// same stock and lose a deduction. Different items do not wait on each
  /// other.
  ///
  /// Persistence happens before the in-memory swap, so a failed write never
  /// reports a balance that was not stored; the item is re-read from storage
  /// and the error rethrown. Returns 0 when the item (or variant) is absent.
  @action
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
  }) async {
    // Queued synchronously, before any await, so a caller arriving mid-write
    // always lines up behind this one.
    final previous = _stockMutationTails[itemId] ?? Future<void>.value();
    final run = previous.then((_) => _applyStockDeltaInOrder(
          itemId: itemId,
          variantId: variantId,
          delta: delta,
          lastPurchaseCost: lastPurchaseCost,
        ));
    // A failed mutation must not block the ones queued behind it.
    final tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _stockMutationTails[itemId] = tail;
    try {
      return await run;
    } finally {
      if (identical(_stockMutationTails[itemId], tail)) {
        _stockMutationTails.remove(itemId);
      }
    }
  }

  /// Last queued stock mutation per item id. Sequencing state only — not
  /// observable.
  final Map<String, Future<void>> _stockMutationTails = {};

  Future<double> _applyStockDeltaInOrder({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
  }) async {
    final current = getItemById(itemId);
    if (current == null) return 0;

    final double newBalance;
    final Items updated;

    if (variantId == null) {
      newBalance = current.stockQuantity + delta;
      updated = current.copyWith(
        stockQuantity: newBalance,
        lastPurchaseCost: lastPurchaseCost,
        lastEditedTime: DateTime.now(),
      );
    } else {
      final variants = current.variant;
      if (variants == null) return 0;

      double? matched;
      final rebuilt = variants.map((v) {
        if (v.variantId != variantId) return v;
        matched = (v.stockQuantity ?? 0) + delta;
        // Every field carried over. Dropping `trackInventory` here would
        // silently switch that variant's stock tracking off.
        return ItemVariante(
          variantId: v.variantId,
          price: v.price,
          trackInventory: v.trackInventory,
          stockQuantity: matched,
        );
      }).toList();

      if (matched == null) return 0;
      newBalance = matched!;
      updated = current.copyWith(
        variant: rebuilt,
        lastPurchaseCost: lastPurchaseCost,
        lastEditedTime: DateTime.now(),
      );
    }

    try {
      await _repository.updateItem(updated);
    } catch (_) {
      await _resyncItemFromStorage(itemId);
      rethrow;
    }

    // Re-resolved after the write: a loadItems() that ran meanwhile rebuilds
    // the list, so an index taken before the await could name another item.
    final index = items.indexWhere((i) => i.id == itemId);
    if (index != -1) items[index] = updated;
    return newBalance;
  }

  /// After a failed write, mirror whatever storage actually holds — a partial
  /// write (put succeeded, duplicate-key cleanup did not) leaves storage ahead
  /// of memory, and the next delta must build on the stored balance.
  Future<void> _resyncItemFromStorage(String itemId) async {
    try {
      final stored = await _repository.getItemById(itemId);
      final index = items.indexWhere((i) => i.id == itemId);
      if (stored != null && index != -1) items[index] = stored;
    } catch (_) {
      // Storage unreadable as well — keep the last known in-memory state.
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearSearch() {
    searchQuery = '';
  }

  @action
  void setCategoryFilter(String? categoryId) {
    selectedCategoryId = categoryId;
  }

  @action
  void clearCategoryFilter() {
    selectedCategoryId = null;
  }

  @action
  void setVegFilter(String? vegStatus) {
    vegFilter = vegStatus;
  }

  @action
  void clearVegFilter() {
    vegFilter = null;
  }

  @action
  void setEnabledFilter(bool? enabled) {
    enabledFilter = enabled;
  }

  @action
  void clearEnabledFilter() {
    enabledFilter = null;
  }

  @action
  void toggleLowStockFilter() {
    showLowStockOnly = !showLowStockOnly;
    if (showLowStockOnly) {
      showOutOfStockOnly = false;
    }
  }

  @action
  void toggleOutOfStockFilter() {
    showOutOfStockOnly = !showOutOfStockOnly;
    if (showOutOfStockOnly) {
      showLowStockOnly = false;
    }
  }

  @action
  void clearAllFilters() {
    searchQuery = '';
    selectedCategoryId = null;
    vegFilter = null;
    enabledFilter = null;
    showLowStockOnly = false;
    showOutOfStockOnly = false;
  }

  // ==================== HELPER METHODS ====================

  /// Get item by ID
  Items? getItemById(String itemId) {
    try {
      return items.firstWhere((i) => i.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// Get items by category
  List<Items> getItemsByCategory(String categoryId) {
    return items.where((item) => item.categoryOfItem == categoryId).toList();
  }

  /// Check if item exists
  bool itemExists(String itemId) {
    return items.any((i) => i.id == itemId);
  }

  /// Check if item name exists (for duplicate validation)
  bool itemNameExists(String name, {String? excludeId}) {
    return items.any((item) =>
        item.name.toLowerCase() == name.toLowerCase() &&
        item.id != excludeId);
  }

  /// Refresh items (pull from database)
  @action
  Future<void> refresh() async {
    await loadItems();
  }

  /// Generate next numeric item code (e.g. starting at 1001)
  String generateNextItemCode() {
    int maxCode = 1000;
    for (var item in items) {
      if (item.itemCode != null) {
        final codeInt = int.tryParse(item.itemCode!);
        if (codeInt != null && codeInt >= 1000 && codeInt <= 99999) {
          if (codeInt > maxCode) {
            maxCode = codeInt;
          }
        }
      }
    }
    return (maxCode + 1).toString();
  }
}
