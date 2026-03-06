import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/restaurant/db/shift_model.dart';
import '../../../data/repositories/restaurant/shift_repository.dart';

part 'shift_store.g.dart';

class ShiftStore = _ShiftStore with _$ShiftStore;

abstract class _ShiftStore with Store {
  final ShiftRepository _repository;

  _ShiftStore(this._repository);

  @observable
  ObservableList<ShiftModel> shifts = ObservableList<ShiftModel>();

  @observable
  ShiftModel? activeShift;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // ── Filter & Search ──────────────────────────────────────────────────────
  @observable
  String filterPeriod = 'All'; // 'All' | 'Today' | 'Week' | 'Month' | 'Custom'

  @observable
  String searchQuery = '';

  @observable
  DateTime? customStart;

  @observable
  DateTime? customEnd;

  @computed
  bool get hasOpenShift => activeShift != null && activeShift!.isOpen;

  @computed
  List<ShiftModel> get closedShifts =>
      shifts.where((s) => s.status == 'closed').toList();

  /// Filtered + searched shifts used by the report screen.
  @computed
  List<ShiftModel> get filteredShifts {
    final now = DateTime.now();
    List<ShiftModel> result = shifts.toList();

    // 1. Apply date period filter
    switch (filterPeriod) {
      case 'Today':
        result = result.where((s) {
          final d = s.startTime;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
        break;
      case 'Week':
        // FIX 4: Use calendar week (Monday start) not a rolling 7-day window.
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeek = DateTime(monday.year, monday.month, monday.day);
        result = result.where((s) => !s.startTime.isBefore(startOfWeek)).toList();
        break;
      case 'Month':
        result = result
            .where((s) =>
                s.startTime.year == now.year &&
                s.startTime.month == now.month)
            .toList();
        break;
      case 'Custom':
        if (customStart != null) {
          result = result
              .where((s) =>
                  s.startTime
                      .isAfter(customStart!.subtract(const Duration(seconds: 1))) &&
                  (customEnd == null ||
                      s.startTime.isBefore(
                          customEnd!.add(const Duration(days: 1)))))
              .toList();
        }
        break;
      default: // 'All' — no filter
        break;
    }

    // 2. Apply staff name search (case-insensitive)
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((s) => s.staffName.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  /// Load all shifts (for report screen).
  @action
  Future<void> loadShifts() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loaded = await _repository.getAllShifts();
      // Enrich open shifts with live order counts (closed shifts already have these stored)
      final enriched = <ShiftModel>[];
      for (final s in loaded) {
        if (s.isOpen) {
          final orders = await _repository.getOrdersForShift(s);
          final validOrders = orders.where((o) {
            final status = (o.orderStatus ?? '').toUpperCase();
            return status != 'VOID' &&
                status != 'VOIDED' &&
                status != 'FULLY_REFUNDED' &&
                status != 'PARTIALLY_REFUNDED';
          }).toList();
          enriched.add(s.copyWith(
            orderCount: validOrders.length,
            totalSales: validOrders.fold<double>(
                0.0, (sum, o) => sum + (o.totalPrice - (o.refundAmount ?? 0.0))),
          ));
        } else {
          enriched.add(s);
        }
      }
      shifts = ObservableList.of(enriched);
    } catch (e) {
      errorMessage = 'Failed to load shifts: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Restores the open shift for this staff member from Hive on login.
  @action
  Future<void> loadActiveShiftForStaff(String staffId) async {
    try {
      activeShift = await _repository.getOpenShiftForStaff(staffId);
    } catch (e) {
      errorMessage = 'Failed to load active shift: $e';
    }
  }

  /// Auto-starts a shift for the given staff. Returns true on success.
  @action
  Future<bool> startShift({
    required String staffId,
    required String staffName,
  }) async {
    try {
      final existing = await _repository.getOpenShiftForStaff(staffId);
      if (existing != null) {
        activeShift = existing;
        return true;
      }

      final shift = ShiftModel(
        id: const Uuid().v4(),
        staffId: staffId,
        staffName: staffName,
        startTime: DateTime.now(),
      );
      await _repository.saveShift(shift);
      shifts.insert(0, shift);
      activeShift = shift;
      return true;
    } catch (e) {
      errorMessage = 'Failed to start shift: $e';
      return false;
    }
  }

  /// Closes the given shift, computing order count and sales from pastorderBox.
  @action
  Future<ShiftModel?> closeShift(String shiftId) async {
    try {
      isLoading = true;
      final shift = await _repository.getShiftById(shiftId);
      if (shift == null) {
        errorMessage = 'Shift not found';
        return null;
      }

      final orders = await _repository.getOrdersForShift(shift);
      final validOrders = orders.where((o) {
        final status = (o.orderStatus ?? '').toUpperCase();
        return status != 'VOID' &&
            status != 'VOIDED' &&
            status != 'FULLY_REFUNDED' &&
            status != 'PARTIALLY_REFUNDED';
      }).toList();
      final orderCount = validOrders.length;
      final totalSales = validOrders.fold<double>(
          0.0, (sum, o) => sum + (o.totalPrice - (o.refundAmount ?? 0.0)));

      final closed = shift.copyWith(
        endTime: DateTime.now(),
        status: 'closed',
        orderCount: orderCount,
        totalSales: totalSales,
      );
      await _repository.saveShift(closed);

      final idx = shifts.indexWhere((s) => s.id == shiftId);
      if (idx != -1) shifts[idx] = closed;
      if (activeShift?.id == shiftId) activeShift = null;

      return closed;
    } catch (e) {
      errorMessage = 'Failed to close shift: $e';
      return null;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadShifts();
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void setFilter(String period, {DateTime? start, DateTime? end}) {
    filterPeriod = period;
    if (period == 'Custom') {
      customStart = start;
      customEnd = end;
    } else {
      customStart = null;
      customEnd = null;
    }
  }

  @action
  void setSearch(String query) {
    searchQuery = query;
  }
}