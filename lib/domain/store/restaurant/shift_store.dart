import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../../data/models/restaurant/db/shift_model.dart';
import '../../../data/models/restaurant/db/attendance_model.dart';
import '../../../data/repositories/restaurant/shift_repository.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';

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
      shifts.where((s) => s.status.startsWith('closed')).toList();

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
                status != 'FULLY_REFUNDED';
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
            status != 'FULLY_REFUNDED';
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

  /// Auto-closes stale shift using latest business activity time, and clocks out attendance.
  @action
  Future<ShiftModel?> closeStaleShiftWithLatestActivity(String shiftId) async {
    try {
      isLoading = true;
      final shift = await _repository.getShiftById(shiftId);
      if (shift == null) {
        errorMessage = 'Shift not found';
        return null;
      }

      // Exit immediately if shift is already closed (Idempotency)
      if (shift.status.startsWith('closed')) {
        return shift;
      }

      // Calculate latest business activity timestamp using service layer
      final endTime = await DayManagementService.calculateLatestBusinessActivity(shift);
      
      final orders = await _repository.getOrdersForShift(shift);
      final validOrders = orders.where((o) {
        final status = (o.orderStatus ?? '').toUpperCase();
        return status != 'VOID' &&
            status != 'VOIDED' &&
            status != 'FULLY_REFUNDED';
      }).toList();
      final orderCount = validOrders.length;
      final totalSales = validOrders.fold<double>(
          0.0, (sum, o) => sum + (o.totalPrice - (o.refundAmount ?? 0.0)));

      final closed = shift.copyWith(
        endTime: endTime,
        status: 'closed:auto_closed:previous_day_detected:system',
        orderCount: orderCount,
        totalSales: totalSales,
      );
      await _repository.saveShift(closed);

      final idx = shifts.indexWhere((s) => s.id == shiftId);
      if (idx != -1) shifts[idx] = closed;
      if (activeShift?.id == shiftId) activeShift = null;

      // Clock out the staff's OPEN attendance at the same frozen time. Search
      // across ALL dates (via the box) — a forgotten session's clock-in is from
      // a PREVIOUS day, so it is NOT in today's records. If we miss it here, the
      // EOD auto-clock-out later closes it at DateTime.now(), inflating the shift
      // to ~24h+. clockOut is idempotent (skips already-closed).
      try {
        final box = Hive.box<AttendanceModel>(HiveBoxNames.restaurantAttendance);
        final open = box.values.firstWhere(
          (r) =>
              r.isOpen &&
              ((shift.staffId.isNotEmpty && r.staffId == shift.staffId) ||
                  ((r.staffId == null || r.staffId!.isEmpty) &&
                      r.staffName == shift.staffName)),
        );
        await attendanceStore.clockOut(open.id, clockOutTime: endTime);
      } catch (_) {
        // No open attendance for this staff — skip.
      }

      return closed;
    } catch (e) {
      errorMessage = 'Failed to close stale shift: $e';
      return null;
    } finally {
      isLoading = false;
    }
  }

  /// Freeze all OPEN shifts (and their attendance) at the latest business-activity
  /// time — called the moment the session goes stale (Force-EOD lock activates),
  /// so staff hours are finalized immediately rather than at EOD. Idempotent:
  /// `closeStaleShiftWithLatestActivity` skips already-closed shifts and
  /// `attendanceStore.clockOut` skips already-clocked-out records, so re-runs
  /// (or a later EOD) yield identical timestamps. Exits immediately when no open
  /// shift remains — so re-opening the locked dashboard does no extra work.
  Future<void> freezeStaleShiftsAndAttendance() async {
    try {
      await loadShifts();
      for (final s in shifts.where((s) => s.isOpen).toList()) {
        await closeStaleShiftWithLatestActivity(s.id);
      }
      // Clock out ANY remaining open attendance (orphans: the shift was already
      // closed but attendance was left open — e.g. legacy records from the old
      // today-only lookup) at the session's last activity, NEVER DateTime.now().
      final box = Hive.box<AttendanceModel>(HiveBoxNames.restaurantAttendance);
      final orphans = box.values.where((r) => r.isOpen).toList();
      if (orphans.isEmpty) return;
      final sessionEnd =
          await DayManagementService.calculateSessionLastActivity();
      for (final r in orphans) {
        final outAt = sessionEnd.isBefore(r.clockIn) ? r.clockIn : sessionEnd;
        await attendanceStore.clockOut(r.id, clockOutTime: outAt);
      }
    } catch (e) {
      debugPrint('Failed to freeze stale shifts/attendance: $e');
    }
  }

  // ── Attendance ↔ Shift alignment ───────────────────────────────────────────
  // Attendance and shifts live in separate boxes with no foreign key, but each
  // clock-in corresponds to a shift start. These keep the Shift Report / Staff
  // Performance in step when a manager edits or deletes an attendance record —
  // WITHOUT ever discarding a shift's sales (orderCount/totalSales feed EOD).

  /// Best-effort match: same staff (id, else name) + same calendar day as the
  /// clock-in, nearest start time. Mirrors the shift→attendance matching used by
  /// [closeStaleShiftWithLatestActivity]. Returns null when there's no match.
  ShiftModel? _findMatchingShift(AttendanceModel a) {
    final candidates = shifts.where((s) {
      final sameStaff = (a.staffId != null && a.staffId!.isNotEmpty)
          ? s.staffId == a.staffId
          : s.staffName == a.staffName;
      return sameStaff &&
          s.startTime.year == a.clockIn.year &&
          s.startTime.month == a.clockIn.month &&
          s.startTime.day == a.clockIn.day;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((x, y) => x.startTime
        .difference(a.clockIn)
        .abs()
        .compareTo(y.startTime.difference(a.clockIn).abs()));
    return candidates.first;
  }

  /// Mirror an EDITED attendance record onto its shift: start = clockIn,
  /// end = clockOut, status open/closed accordingly. Sales are preserved.
  Future<void> syncShiftTimesFromAttendance(AttendanceModel a) async {
    try {
      if (shifts.isEmpty) await loadShifts();
      final shift = _findMatchingShift(a);
      if (shift == null) return;
      final updated = ShiftModel(
        id: shift.id,
        staffId: shift.staffId,
        staffName: shift.staffName,
        startTime: a.clockIn,
        endTime: a.clockOut,
        status: a.clockOut != null ? 'closed' : 'open',
        orderCount: shift.orderCount,
        totalSales: shift.totalSales,
      );
      await _repository.saveShift(updated);
      await loadShifts(); // refresh the in-memory list for the report
    } catch (e) {
      debugPrint('Failed to align shift with attendance edit: $e');
    }
  }

  /// Reconcile the matching shift when an attendance record is DELETED.
  ///  • no sales  → delete the shift too (a phantom time entry).
  ///  • has sales → keep it (protect EOD revenue); if it's still open/runaway,
  ///                bound it by closing with the latest business-activity time.
  Future<void> reconcileShiftOnAttendanceDelete(AttendanceModel a) async {
    try {
      if (shifts.isEmpty) await loadShifts();
      final shift = _findMatchingShift(a);
      if (shift == null) return;
      final hasSales = shift.orderCount > 0 || shift.totalSales > 0.009;
      if (!hasSales) {
        await _repository.deleteShift(shift.id);
        await loadShifts();
      } else if (shift.isOpen) {
        await closeStaleShiftWithLatestActivity(shift.id);
      }
      // has sales + already closed → leave the real historical shift untouched.
    } catch (e) {
      debugPrint('Failed to reconcile shift on attendance delete: $e');
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