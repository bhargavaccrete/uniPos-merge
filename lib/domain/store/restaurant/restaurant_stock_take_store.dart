import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../../../data/models/restaurant/db/restaurant_stock_take_item_model.dart';
import '../../../data/models/restaurant/db/restaurant_stock_take_model.dart';
import '../../../data/repositories/restaurant/restaurant_stock_take_repository.dart';
import '../../services/common/document_number_service.dart';
import '../../services/restaurant/stock_adjust_service.dart';
import '../../../util/restaurant/restaurant_session.dart';

part 'restaurant_stock_take_store.g.dart';

class RestaurantStockTakeStore = _RestaurantStockTakeStore
    with _$RestaurantStockTakeStore;

/// Outcome of committing a stock take.
class RestaurantStockTakeCommitResult {
  final bool success;
  final String? errorMessage;
  final int appliedLines;
  final double netQty;
  final List<String> failedLines;

  const RestaurantStockTakeCommitResult({
    required this.success,
    this.errorMessage,
    this.appliedLines = 0,
    this.netQty = 0,
    this.failedLines = const [],
  });

  factory RestaurantStockTakeCommitResult.failure(String message) =>
      RestaurantStockTakeCommitResult(success: false, errorMessage: message);

  bool get isPartial => failedLines.isNotEmpty;
}

/// Owns the physical stock count lifecycle for raw materials/semi-finished
/// items: draft → counted → committed. Mirrors retail's `StockTakeStore`.
///
/// **This store never writes stock directly.** Committing walks the
/// variance lines and calls `StockAdjustService.adjustTo` for each, so a
/// counted correction produces exactly the same audit row and loss
/// treatment as a manual removal from `manage_Inventory.dart`.
abstract class _RestaurantStockTakeStore with Store {
  late final RestaurantStockTakeRepository _repository;
  final DocumentNumberService _numbers = DocumentNumberService();

  static const String _takePrefix = 'ST';

  /// Reason stamped on every line a stock take commits.
  static const String varianceReason = 'Stock take';

  @observable
  ObservableList<RestaurantStockTakeModel> takes =
      ObservableList<RestaurantStockTakeModel>();

  @observable
  ObservableList<RestaurantStockTakeItemModel> currentItems =
      ObservableList<RestaurantStockTakeItemModel>();

  @observable
  RestaurantStockTakeModel? currentTake;

  @observable
  bool isLoading = false;

  @observable
  bool isCommitting = false;

  @observable
  String? errorMessage;

  _RestaurantStockTakeStore() {
    _repository = RestaurantStockTakeRepository();
  }

  // ==================== DERIVED ====================

  @computed
  List<RestaurantStockTakeModel> get draftTakes =>
      takes.where((t) => t.isDraft).toList();

  @computed
  int get openDraftCount => draftTakes.length;

  /// Variance lines — in a draft, only those NOT yet applied (a partial commit
  /// leaves the rest here to finish); in a completed take, all of them, for
  /// review. Commit and its dialog read this, so an applied line can never be
  /// offered, or applied, twice. (Same rule as retail's StockTakeStore.)
  @computed
  List<RestaurantStockTakeItemModel> get varianceItems {
    final draft = currentTake?.isEditable ?? false;
    return currentItems
        .where((i) => i.hasVariance && (!draft || i.appliedQty == null))
        .toList();
  }

  @computed
  int get countedLineCount => currentItems.length;

  @computed
  int get varianceLineCount => varianceItems.length;

  @computed
  double get netVarianceQty =>
      varianceItems.fold(0.0, (sum, i) => sum + i.variance);

  @computed
  double get shortageQty => varianceItems
      .where((i) => i.isShortage)
      .fold(0.0, (sum, i) => sum + i.variance.abs());

  @computed
  double get excessQty => varianceItems
      .where((i) => !i.isShortage)
      .fold(0.0, (sum, i) => sum + i.variance);

  @computed
  double get netVarianceValue =>
      varianceItems.fold(0.0, (sum, i) => sum + i.varianceValue);

  // ==================== LOAD ====================

  @action
  Future<void> loadTakes() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = await _repository.getAll();
      takes = ObservableList.of(loaded);
    } catch (e) {
      errorMessage = 'Stock takes could not be loaded: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> openTake(String takeId) async {
    isLoading = true;
    errorMessage = null;
    try {
      currentTake = _repository.getById(takeId);
      final items = await _repository.getItems(takeId);
      currentItems = ObservableList.of(items);
    } catch (e) {
      errorMessage = 'Stock take could not be opened: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  void closeTake() {
    currentTake = null;
    currentItems.clear();
  }

  // ==================== LIFECYCLE ====================

  @action
  Future<RestaurantStockTakeModel?> startTake({String? scopeNote}) async {
    try {
      final number = await _numbers.next(
        _takePrefix,
        isTaken: (n) => takes.any((t) => t.takeNumber == n),
      );

      final take = RestaurantStockTakeModel.create(
        takeNumber: number,
        countedBy:
            RestaurantSession.staffName ?? RestaurantSession.effectiveRole,
        scopeNote: scopeNote,
      );

      await _repository.save(take);
      takes.insert(0, take);
      currentTake = take;
      currentItems.clear();
      return take;
    } catch (e) {
      errorMessage = 'Stock take could not be started: $e';
      return null;
    }
  }

  /// Records (or re-records) the counted quantity for one item (or variant).
  @action
  Future<bool> countItem({
    required Items item,
    ItemVariante? variant,
    required double countedQty,
  }) async {
    final take = currentTake;
    if (take == null || !take.isEditable) {
      errorMessage = 'This stock take is no longer editable.';
      return false;
    }
    if (countedQty < 0) {
      errorMessage = 'Counted quantity cannot be negative.';
      return false;
    }

    try {
      final systemQty =
          variant != null ? (variant.stockQuantity ?? 0) : item.stockQuantity;

      final existing = _repository.findLine(take.takeId, item.id);
      if (existing?.appliedQty != null) {
        errorMessage =
            'This line was already applied to stock. Correct it with a new count.';
        return false;
      }

      if (existing != null) {
        final updated = existing.copyWith(
          systemQty: systemQty,
          countedQty: countedQty,
          costPrice: item.lastPurchaseCost,
        );
        await _repository.saveItem(updated);
        final index =
            currentItems.indexWhere((i) => i.takeItemId == updated.takeItemId);
        if (index != -1) {
          currentItems[index] = updated;
        } else {
          currentItems.add(updated);
        }
      } else {
        final line = RestaurantStockTakeItemModel.create(
          takeId: take.takeId,
          itemId: item.id,
          itemName: item.name,
          systemQty: systemQty,
          countedQty: countedQty,
          costPrice: item.lastPurchaseCost,
        );
        await _repository.saveItem(line);
        currentItems.add(line);
      }

      await _touch(take);
      return true;
    } catch (e) {
      errorMessage = 'Count could not be saved: $e';
      return false;
    }
  }

  @action
  Future<bool> removeLine(String takeItemId) async {
    final take = currentTake;
    if (take == null || !take.isEditable) {
      errorMessage = 'This stock take is no longer editable.';
      return false;
    }

    final line =
        currentItems.where((i) => i.takeItemId == takeItemId).firstOrNull;
    if (line?.appliedQty != null) {
      errorMessage = 'An applied line is part of the stock record — it stays.';
      return false;
    }

    try {
      await _repository.deleteItem(takeItemId);
      currentItems.removeWhere((i) => i.takeItemId == takeItemId);
      await _touch(take);
      return true;
    } catch (e) {
      errorMessage = 'Line could not be removed: $e';
      return false;
    }
  }

  @action
  Future<bool> cancelTake(String takeId) async {
    final take = _repository.getById(takeId);
    if (take == null) return false;
    if (!take.isEditable) {
      errorMessage = 'A completed stock take cannot be cancelled.';
      return false;
    }
    // A partial commit already moved stock; deleting the take would orphan
    // those adjustments from the paperwork that explains them.
    if ((await _repository.getItems(takeId)).any((i) => i.appliedQty != null)) {
      errorMessage =
          'Part of this stock take is already applied. Commit the rest instead.';
      return false;
    }

    try {
      await _repository.deleteTakeWithItems(takeId);
      takes.removeWhere((t) => t.takeId == takeId);
      if (currentTake?.takeId == takeId) closeTake();
      return true;
    } catch (e) {
      errorMessage = 'Stock take could not be cancelled: $e';
      return false;
    }
  }

  // ==================== COMMIT ====================

  /// Applies every not-yet-applied variance line via
  /// `StockAdjustService.adjustTo`. **Resumable, never double-applied:** a line
  /// is marked `appliedQty` once its adjustment lands and its movement carries
  /// the id `st_<takeItemId>`, so a re-commit after a partial failure or a
  /// crash skips what is done. The take becomes `completed` (terminal) only
  /// when EVERY variance line is applied; until then it stays a draft with its
  /// applied lines locked. A wrong applied count is corrected by a new take.
  ///
  /// [shortageReason] is stamped on every line the count found *less* than
  /// the system expected — pick from `StockAdjustService.lossReasons` (e.g.
  /// 'Wastage / Spoilage') to also record the cost as an inventory loss, or
  /// 'Stock correction' to treat it as a bookkeeping fix with no cost impact.
  /// Lines with an *excess* always use 'Stock correction' — finding extra
  /// stock is never a loss.
  @action
  Future<RestaurantStockTakeCommitResult> commit({
    required String shortageReason,
    String? note,
  }) async {
    final take = currentTake;
    if (take == null) {
      return RestaurantStockTakeCommitResult.failure('No stock take is open.');
    }
    if (!take.isEditable) {
      return RestaurantStockTakeCommitResult.failure(
        'This stock take has already been committed.',
      );
    }

    final pending = varianceItems;
    if (pending.isEmpty) {
      return RestaurantStockTakeCommitResult.failure(
        'Nothing to apply — every counted line matches the system.',
      );
    }

    isCommitting = true;
    final failed = <String>[];
    var appliedLines = 0;
    var netQty = 0.0;

    try {
      for (final line in pending) {
        final item = itemStore.getItemById(line.itemId);
        if (item == null) {
          failed.add(line.itemName ?? line.itemId);
          continue;
        }

        // Delta, not absolute: stock may have moved legitimately since the
        // count (e.g. a production run). Applying the variance preserves
        // that; writing `countedQty` would erase it.
        final target = item.stockQuantity + line.variance;
        if (target < 0) {
          failed.add(line.itemName ?? line.itemId);
          continue;
        }

        final success = await StockAdjustService.adjustTo(
          item: item,
          newStock: target,
          reason: line.isShortage ? shortageReason : 'Stock correction',
          note: _lineNote(take, note),
          // A crash between the adjustment and the appliedQty save below
          // would otherwise re-apply this line on the next commit.
          movementId: 'st_${line.takeItemId}',
        );

        if (!success) {
          failed.add(line.itemName ?? line.itemId);
          continue;
        }

        await _repository.saveItem(line.copyWith(appliedQty: line.variance));
        appliedLines++;
        netQty += line.variance;
      }

      // Totals and status from the whole take, not this run — a take can be
      // committed in several passes.
      final allLines = await _repository.getItems(take.takeId);
      final applied = allLines.where((i) => i.appliedQty != null).toList();
      final outstanding =
          allLines.any((i) => i.hasVariance && i.appliedQty == null);
      final done = applied.isNotEmpty && !outstanding;

      final completed = take.copyWith(
        status: done
            ? RestaurantStockTakeStatus.completed.name
            : RestaurantStockTakeStatus.draft.name,
        varianceReason: varianceReason,
        note: note,
        completedAt: done ? DateTime.now().toIso8601String() : null,
        committedLineCount: applied.length,
        committedNetQty:
            applied.fold<double>(0.0, (s, i) => s + i.appliedQty!),
      );

      await _repository.save(completed);
      currentTake = completed;
      final index = takes.indexWhere((t) => t.takeId == take.takeId);
      if (index != -1) takes[index] = completed;
      currentItems = ObservableList.of(await _repository.getItems(take.takeId));

      return RestaurantStockTakeCommitResult(
        success: appliedLines > 0,
        errorMessage: appliedLines > 0
            ? null
            : 'No line could be applied. Check the failures and recount.',
        appliedLines: appliedLines,
        netQty: netQty,
        failedLines: failed,
      );
    } catch (e) {
      return RestaurantStockTakeCommitResult.failure('Commit failed: $e');
    } finally {
      isCommitting = false;
    }
  }

  String _lineNote(RestaurantStockTakeModel take, String? note) {
    final base = 'Stock take ${take.takeNumber}';
    final extra = note?.trim();
    return (extra == null || extra.isEmpty) ? base : '$base - $extra';
  }

  Future<void> _touch(RestaurantStockTakeModel take) async {
    final touched = take.copyWith();
    await _repository.save(touched);
    currentTake = touched;
    final index = takes.indexWhere((t) => t.takeId == take.takeId);
    if (index != -1) takes[index] = touched;
  }
}
