import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/stock_take_item_model_181.dart';
import '../../../data/models/retail/hive_model/stock_take_model_180.dart';
import '../../../data/models/retail/hive_model/variante_model_201.dart';
import '../../../data/repositories/retail/stock_take_repository.dart';
import '../../services/common/document_number_service.dart';
import '../../services/retail/stock_adjustment_reason.dart';
import '../../services/retail/stock_adjustment_service.dart';

part 'stock_take_store.g.dart';

class StockTakeStore = _StockTakeStore with _$StockTakeStore;

/// Outcome of committing a stock take.
class StockTakeCommitResult {
  final bool success;
  final String? errorMessage;

  /// Lines that moved stock.
  final int appliedLines;

  /// Net units applied — negative when the count found less than the books.
  final int netQty;

  /// Lines whose adjustment failed. Non-empty means a partial commit.
  final List<String> failedLines;

  const StockTakeCommitResult({
    required this.success,
    this.errorMessage,
    this.appliedLines = 0,
    this.netQty = 0,
    this.failedLines = const [],
  });

  factory StockTakeCommitResult.failure(String message) =>
      StockTakeCommitResult(success: false, errorMessage: message);

  bool get isPartial => failedLines.isNotEmpty;
}

/// Owns the physical stock count lifecycle: draft → counted → committed.
///
/// **This store never writes stock.** Committing walks the variance lines and
/// calls `StockAdjustmentService.adjust` for each, so a counted correction
/// produces exactly the same audit row, reason semantics and loss treatment as
/// a single-variant adjustment. That keeps one write path rather than two that
/// can drift apart.
///
/// **Variance applies as a delta, never as the absolute counted figure.** The
/// line stores the system quantity as it was when counted; by commit time a
/// sale may have moved stock. Writing the counted figure would erase that sale,
/// so commit re-reads current stock and applies `variance` to it. See
/// [StockTakeItemModel] for the worked example.
abstract class _StockTakeStore with Store {
  late final StockTakeRepository _repository;
  final DocumentNumberService _numbers = DocumentNumberService();

  static const String _takePrefix = 'ST';

  @observable
  ObservableList<StockTakeModel> takes = ObservableList<StockTakeModel>();

  /// Lines of the take currently open on the count screen.
  @observable
  ObservableList<StockTakeItemModel> currentItems =
      ObservableList<StockTakeItemModel>();

  @observable
  StockTakeModel? currentTake;

  @observable
  bool isLoading = false;

  @observable
  bool isCommitting = false;

  @observable
  String? errorMessage;

  _StockTakeStore() {
    _repository = StockTakeRepository();
  }

  // ==================== DERIVED ====================

  @computed
  List<StockTakeModel> get draftTakes =>
      takes.where((t) => t.isDraft).toList();

  @computed
  int get openDraftCount => draftTakes.length;

  /// Lines whose count differs from what the system claimed.
  @computed
  List<StockTakeItemModel> get varianceItems =>
      currentItems.where((i) => i.hasVariance).toList();

  @computed
  int get countedLineCount => currentItems.length;

  @computed
  int get varianceLineCount => varianceItems.length;

  /// Net units the commit would apply. Negative is a shortage.
  @computed
  int get netVarianceQty =>
      varianceItems.fold(0, (sum, i) => sum + i.variance);

  @computed
  int get shortageQty => varianceItems
      .where((i) => i.isShortage)
      .fold(0, (sum, i) => sum + i.variance.abs());

  @computed
  int get excessQty => varianceItems
      .where((i) => !i.isShortage)
      .fold(0, (sum, i) => sum + i.variance);

  /// Value of the net variance at count-time cost. Negative is a loss.
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

  /// Opens a take for counting or review and loads its lines.
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

  /// Drops the open take so a stale count can't leak into the next screen.
  @action
  void closeTake() {
    currentTake = null;
    currentItems.clear();
  }

  // ==================== LIFECYCLE ====================

  /// Starts a new draft count and opens it. Returns null on failure.
  @action
  Future<StockTakeModel?> startTake({String? scopeNote}) async {
    if (!StockAdjustmentService.canAdjust) {
      errorMessage = 'Only the admin can run a stock take.';
      return null;
    }

    try {
      final number = await _numbers.next(
        _takePrefix,
        isTaken: (n) => takes.any((t) => t.takeNumber == n),
      );

      final take = StockTakeModel.create(
        takeNumber: number,
        countedBy: authService.currentUsername ?? 'Admin',
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

  /// Records (or re-records) the counted quantity for one variant.
  ///
  /// Re-counting the same variant updates its line rather than adding a second
  /// one, and re-snapshots `systemQty` — a recount is a fresh observation, so
  /// pinning it to the original snapshot would compute variance against a
  /// number the counter never saw.
  @action
  Future<bool> countVariant({
    required VarianteModel variant,
    required int countedQty,
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
      final product = productStore.products
          .where((p) => p.productId == variant.productId)
          .firstOrNull;

      final existing = _repository.findLine(take.takeId, variant.varianteId);

      if (existing != null) {
        final updated = existing.copyWith(
          systemQty: variant.stockQty,
          countedQty: countedQty,
          costPrice: variant.costPrice,
        );
        await _repository.saveItem(updated);
        final index = currentItems
            .indexWhere((i) => i.takeItemId == updated.takeItemId);
        if (index != -1) {
          currentItems[index] = updated;
        } else {
          currentItems.add(updated);
        }
      } else {
        final line = StockTakeItemModel.create(
          takeId: take.takeId,
          variantId: variant.varianteId,
          productId: variant.productId,
          productName: product?.productName,
          variantInfo:
              variant.hasAttributes ? variant.variantDescription : null,
          systemQty: variant.stockQty,
          countedQty: countedQty,
          costPrice: variant.costPrice,
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

  /// Removes a counted line from a draft.
  @action
  Future<bool> removeLine(String takeItemId) async {
    final take = currentTake;
    if (take == null || !take.isEditable) {
      errorMessage = 'This stock take is no longer editable.';
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

  /// Abandons a draft without touching stock. Lines go with it — an uncommitted
  /// count is not evidence of anything.
  @action
  Future<bool> cancelTake(String takeId) async {
    final take = _repository.getById(takeId);
    if (take == null) return false;
    if (!take.isEditable) {
      errorMessage = 'A completed stock take cannot be cancelled.';
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

  /// Applies every variance line as a stock adjustment.
  ///
  /// **Terminal.** The adjustments it writes are facts in the movement log, so
  /// there is no re-open — re-committing would double-apply them. A wrong count
  /// is corrected by a new take.
  ///
  /// Each line goes through `StockAdjustmentService.adjust` with [reason], and
  /// a loss-bearing reason on a shortage records an inventory loss exactly as a
  /// single-variant adjustment would. Lines with no variance are skipped rather
  /// than written as no-op adjustments.
  ///
  /// A line whose variant has since vanished, or whose adjustment fails, is
  /// collected into [StockTakeCommitResult.failedLines] and the rest still
  /// commit — stopping halfway would leave the take neither counted nor
  /// applied, which is worse than a reported partial.
  @action
  Future<StockTakeCommitResult> commit({
    required StockAdjustmentReason reason,
    String? note,
  }) async {
    final take = currentTake;
    if (take == null) {
      return StockTakeCommitResult.failure('No stock take is open.');
    }
    if (!take.isEditable) {
      return StockTakeCommitResult.failure(
        'This stock take has already been committed.',
      );
    }
    if (!StockAdjustmentService.canAdjust) {
      return StockTakeCommitResult.failure(
        'Only the admin can commit a stock take.',
      );
    }

    final pending = varianceItems;
    if (pending.isEmpty) {
      return StockTakeCommitResult.failure(
        'Nothing to apply — every counted line matches the system.',
      );
    }

    isCommitting = true;
    final failed = <String>[];
    var appliedLines = 0;
    var netQty = 0;

    try {
      for (final line in pending) {
        final variant = productStore.variants
            .where((v) => v.varianteId == line.variantId)
            .firstOrNull;

        if (variant == null) {
          failed.add(line.productName ?? line.variantId);
          continue;
        }

        // Delta, not absolute: stock may have moved legitimately since the
        // count. Applying the variance preserves those movements; writing
        // `countedQty` would erase them.
        final target = variant.stockQty + line.variance;
        if (target < 0) {
          // The shortage is larger than what is left on hand, which means the
          // count is stale beyond repair for this line. Refuse it rather than
          // clamp to zero and silently under-apply.
          failed.add(line.productName ?? line.variantId);
          continue;
        }

        final result = await StockAdjustmentService.adjust(
          variant: variant,
          newStock: target,
          reason: reason,
          note: _lineNote(take, note),
        );

        if (!result.success) {
          failed.add(line.productName ?? line.variantId);
          continue;
        }

        await _repository.saveItem(line.copyWith(appliedQty: line.variance));
        appliedLines++;
        netQty += line.variance;
      }

      final completed = take.copyWith(
        status: appliedLines > 0
            ? StockTakeStatus.completed.name
            : StockTakeStatus.draft.name,
        varianceReason: reason.code,
        note: note,
        completedAt:
            appliedLines > 0 ? DateTime.now().toIso8601String() : null,
        committedLineCount: appliedLines,
        committedNetQty: netQty,
      );

      await _repository.save(completed);
      currentTake = completed;
      final index = takes.indexWhere((t) => t.takeId == take.takeId);
      if (index != -1) takes[index] = completed;
      currentItems = ObservableList.of(
        await _repository.getItems(take.takeId),
      );

      return StockTakeCommitResult(
        success: appliedLines > 0,
        errorMessage: appliedLines > 0
            ? null
            : 'No line could be applied. Check the failures and recount.',
        appliedLines: appliedLines,
        netQty: netQty,
        failedLines: failed,
      );
    } catch (e) {
      return StockTakeCommitResult.failure('Commit failed: $e');
    } finally {
      isCommitting = false;
    }
  }

  /// Ties every adjustment back to the take that produced it, so the stock
  /// adjustment report can explain a batch of same-timestamp rows.
  String _lineNote(StockTakeModel take, String? note) {
    final base = 'Stock take ${take.takeNumber}';
    final extra = note?.trim();
    return (extra == null || extra.isEmpty) ? base : '$base - $extra';
  }

  /// Keeps `updatedAt` honest as lines are counted, so the list screen can sort
  /// drafts by recent activity rather than by when they were opened.
  Future<void> _touch(StockTakeModel take) async {
    final touched = take.copyWith();
    await _repository.save(touched);
    currentTake = touched;
    final index = takes.indexWhere((t) => t.takeId == take.takeId);
    if (index != -1) takes[index] = touched;
  }
}
