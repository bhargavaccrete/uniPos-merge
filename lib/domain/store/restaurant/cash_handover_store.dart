import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/restaurant/db/cash_handover_model.dart';
import '../../../data/repositories/restaurant/cash_handover_repository.dart';

part 'cash_handover_store.g.dart';

/// MobX store for the 2-step async cash drawer handover.
///
/// LIFECYCLE:
///   1. Outgoing staff taps "End Shift" → [createHandover] → status = PENDING
///   2. Incoming staff logs in → [loadPendingHandover] → if found, show dialog
///   3. Incoming staff confirms → [receiveHandover] → status = MATCHED / DISCREPANCY
///
/// [pendingHandover] drives the HandoverReceiveDialog on the welcome screen.
class CashHandoverStore = _CashHandoverStore with _$CashHandoverStore;

abstract class _CashHandoverStore with Store {
  final CashHandoverRepository _repository;

  _CashHandoverStore(this._repository);

  // ── State ────────────────────────────────────────────────────────────────

  /// The current PENDING handover, or null if none.
  /// The welcome screen observes this to decide whether to show the dialog.
  @observable
  CashHandoverModel? pendingHandover;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Check if there is a PENDING handover waiting for the incoming staff.
  /// Call this in welcome_Admin.dart after shift starts.
  @action
  Future<void> loadPendingHandover() async {
    try {
      isLoading = true;
      errorMessage = null;
      pendingHandover = await _repository.getPendingHandover();
    } catch (e) {
      errorMessage = 'Failed to check handover: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Step 1 — Called when outgoing staff ends their shift and counts the cash.
  ///
  /// Creates a PENDING handover record. The incoming staff will complete
  /// Step 2 via [receiveHandover] when they log in.
  @action
  Future<bool> createHandover({
    required String closedBy,
    required double closedAmount,
    String? closedNote,
  }) async {
    try {
      final handover = CashHandoverModel(
        id: const Uuid().v4(),
        closedBy: closedBy,
        closedAt: DateTime.now(),
        closedAmount: closedAmount,
        closedNote: closedNote,
        status: 'PENDING',
      );
      await _repository.saveHandover(handover);
      // Update local state so the UI can react immediately if needed
      pendingHandover = handover;
      return true;
    } catch (e) {
      errorMessage = 'Failed to create handover: $e';
      return false;
    }
  }

  /// Step 2 — Called when incoming staff confirms how much cash they received.
  ///
  /// Calculates the variance:
  ///   variance = receivedAmount - closedAmount
  /// Sets status to MATCHED (|variance| ≤ 1) or DISCREPANCY (|variance| > 1).
  @action
  Future<CashHandoverModel?> receiveHandover({
    required String handoverId,
    required String receivedBy,
    required double receivedAmount,
    String? receivedNote,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;

      final existing = await _repository.getPendingHandover();
      if (existing == null || existing.id != handoverId) {
        errorMessage = 'Handover not found';
        return null;
      }

      final completed = existing.withReceived(
        receivedBy: receivedBy,
        receivedAt: DateTime.now(),
        receivedAmount: receivedAmount,
        receivedNote: receivedNote,
      );
      await _repository.updateHandover(completed);
      // Clear pending — dialog will dismiss
      pendingHandover = null;
      return completed;
    } catch (e) {
      errorMessage = 'Failed to complete handover: $e';
      return null;
    } finally {
      isLoading = false;
    }
  }
}
