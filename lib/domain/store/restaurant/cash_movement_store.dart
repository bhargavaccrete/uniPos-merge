import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/restaurant/db/cash_movement_model.dart';
import '../../../data/repositories/restaurant/cash_movement_repository.dart';
import '../../../util/restaurant/restaurant_session.dart';

import '../../../domain/services/restaurant/day_management_service.dart';

part 'cash_movement_store.g.dart';

/// MobX store for cash movements (Cash In / Cash Out during the day).
///
/// Screens observe [movements] to rebuild the activity log automatically
/// whenever a new movement is added — no manual setState needed.
class CashMovementStore = _CashMovementStore with _$CashMovementStore;

abstract class _CashMovementStore with Store {
  final CashMovementRepository _repository;

  _CashMovementStore(this._repository);

  // ── State ────────────────────────────────────────────────────────────────

  /// Today's movements, sorted oldest-first for the activity log.
  @observable
  ObservableList<CashMovementModel> movements =
      ObservableList<CashMovementModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // ── Derived totals (auto-recomputed whenever movements changes) ───────────

  /// Total Cash In for the loaded period.
  @computed
  double get totalCashIn => movements
      .where((m) => m.type == 'in')
      .fold(0.0, (sum, m) => sum + m.amount);

  /// Total Cash Out for the loaded period.
  @computed
  double get totalCashOut => movements
      .where((m) => m.type == 'out')
      .fold(0.0, (sum, m) => sum + m.amount);

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Load all movements that happened on or after [dayStart].
  /// Call this whenever the Cash Drawer screen opens or resumes.
  @action
  Future<void> loadTodayMovements(DateTime dayStart) async {
    try {
      isLoading = true;
      errorMessage = null;
      final loaded = await _repository.getTodayMovements(dayStart);
      movements = ObservableList.of(loaded);
    } catch (e) {
      errorMessage = 'Failed to load movements: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Record a new Cash In or Cash Out movement.
  ///
  /// [type]      → 'in' or 'out'
  /// [amount]    → positive number
  /// [reason]    → selected from dropdown ('Owner deposit', 'Safe drop', etc.)
  /// [note]      → optional free text
  ///
  /// The staffName is read automatically from [RestaurantSession] so the
  /// caller never has to pass it — prevents spoofing.
  @action
  Future<bool> addMovement({
    required String type,
    required double amount,
    required String reason,
    String? note,
  }) async {
    try {
      final currentSessionId = await DayManagementService.getCurrentSessionId();
      
      final movement = CashMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        type: type,
        amount: amount,
        reason: reason,
        note: note,
        sessionId: currentSessionId,
        // Read from active session — cannot be overridden by caller
        staffName: RestaurantSession.effectiveRole == 'Admin'
            ? 'Admin'
            : (RestaurantSession.staffName ?? 'Staff'),
      );
      await _repository.saveMovement(movement);
      // Insert at the end (oldest-first sort) so the log stays in order
      movements.add(movement);
      return true;
    } catch (e) {
      errorMessage = 'Failed to save movement: $e';
      return false;
    }
  }

  /// Record a system-generated ADJUSTMENT entry (EOD discrepancy or opening
  /// balance modification). These do NOT affect cash-in/out totals — they
  /// are audit-only entries with type = 'adjustment'.
  ///
  /// [signedAmount] → positive = cash added/found, negative = cash missing/removed
  /// [staffName]    must be passed explicitly because the session may be
  ///                partially cleared at the time this is called.
  @action
  Future<void> addAdjustment({
    required double signedAmount,
    required String reason,
    required String note,
    required String staffName,
  }) async {
    try {
      final currentSessionId = await DayManagementService.getCurrentSessionId();
      
      final movement = CashMovementModel(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        type: 'adjustment',
        amount: signedAmount, // signed: negative = shortage/reduction
        reason: reason,
        note: note,
        staffName: staffName,
        sessionId: currentSessionId,
      );
      await _repository.saveMovement(movement);
      movements.add(movement);
    } catch (e) {
      errorMessage = 'Failed to save adjustment: $e';
    }
  }
}
