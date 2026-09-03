import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/common/attendance_model.dart';
import '../../../data/repositories/common/attendance_repository.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'shift_store.dart';

part 'attendance_store.g.dart';

class AttendanceStore = _AttendanceStore with _$AttendanceStore;

abstract class _AttendanceStore with Store {
  final AttendanceRepository _repository;

  _AttendanceStore(this._repository);

  static const _uuid = Uuid();

  @observable
  ObservableList<AttendanceModel> todayRecords = ObservableList();

  @observable
  bool isLoading = false;

  // ── Query Methods for Reports ──────────────────────────────────────────────

  Future<List<AttendanceModel>> getRecordsBetweenDates(DateTime start, DateTime end) async {
    return _repository.getRecordsBetweenDates(start, end);
  }

  // ── Load today's records ─────────────────────────────────────────────────

  @action
  Future<void> loadTodayRecords() async {
    isLoading = true;
    final todayKey = _todayKey();
    final all = await _repository.getRecordsByDate(todayKey);
    todayRecords = ObservableList.of(all);
    isLoading = false;
  }

  // ── Get open record for the current staff (null if not clocked in) ────────

  @action
  AttendanceModel? getActiveRecord(String staffName, {String? staffId}) {
    try {
      return todayRecords.firstWhere(
        (r) => (staffId != null && r.staffId == staffId && r.isOpen) ||
               (staffId == null && r.staffName == staffName && r.isOpen),
      );
    } catch (_) {
      try {
        return todayRecords.firstWhere(
          (r) => r.staffName == staffName && r.isOpen,
        );
      } catch (_) {
        return null;
      }
    }
  }

  // ── Clock In ─────────────────────────────────────────────────────────────

  @action
  Future<AttendanceModel> clockIn({
    required String staffName,
    required String staffRole,
    String? sessionId,
    String? staffId,
  }) async {
    final now = DateTime.now();
    final record = AttendanceModel(
      id: _uuid.v4(),
      staffName: staffName,
      staffRole: staffRole,
      clockIn: now,
      date: _todayKey(),
      sessionId: sessionId,
      staffId: staffId,
    );
    await _repository.addRecord(record);
    todayRecords.add(record);
    return record;
  }

  // ── Clock Out ────────────────────────────────────────────────────────────

  @action
  Future<void> clockOut(String recordId, {DateTime? clockOutTime}) async {
    final record = _repository.getRecordById(recordId);
    if (record == null) return;

    // Idempotency: if already clocked out, do nothing
    if (record.clockOut != null) return;

    // Auto-end break if they were on break
    if (record.isOnBreak) {
      await endBreak(recordId);
    }

    final outTime = clockOutTime ?? DateTime.now();
    record.clockOut = outTime;
    final grossMinutes = outTime.difference(record.clockIn).inMinutes;
    record.totalMinutes = grossMinutes - (record.breakTotalMinutes ?? 0);
    if (record.totalMinutes! < 0) record.totalMinutes = 0;
    await _repository.updateRecord(record);

    // Refresh list
    final idx = todayRecords.indexWhere((r) => r.id == recordId);
    if (idx != -1) {
      todayRecords[idx] = record;
    }
  }

  // ── Break Management ───────────────────────────────────────────────────────

  @action
  Future<void> startBreak(String recordId) async {
    final record = _repository.getRecordById(recordId);
    if (record == null || record.isOnBreak || !record.isOpen) return;

    record.breakStartTime = DateTime.now();
    await _repository.updateRecord(record);

    // Refresh list
    final idx = todayRecords.indexWhere((r) => r.id == recordId);
    if (idx != -1) {
      todayRecords[idx] = record;
    }
  }

  @action
  Future<void> endBreak(String recordId) async {
    final record = _repository.getRecordById(recordId);
    if (record == null || !record.isOnBreak || !record.isOpen) return;

    final now = DateTime.now();
    final breakDuration = now.difference(record.breakStartTime!).inMinutes;
    
    record.breakTotalMinutes = (record.breakTotalMinutes ?? 0) + breakDuration;
    record.breakStartTime = null;
    await _repository.updateRecord(record);

    // Refresh list
    final idx = todayRecords.indexWhere((r) => r.id == recordId);
    if (idx != -1) {
      todayRecords[idx] = record;
    }
  }

  // ── Manager Override ───────────────────────────────────────────────────────

  @action
  Future<void> addRecord(AttendanceModel record) async {
    await _repository.addRecord(record);
    if (record.date == _todayKey()) {
      todayRecords.add(record);
      todayRecords.sort((a, b) => a.clockIn.compareTo(b.clockIn));
    }
  }

  @action
  Future<void> deleteRecord(String recordId) async {
    // Capture the record BEFORE deleting so the Shift Report can be reconciled.
    final record = _repository.getRecordById(recordId);
    await _repository.deleteRecord(recordId);
    todayRecords.removeWhere((r) => r.id == recordId);
    // Reflect the deletion in the Shift Report (never wipes a shift's sales).
    // Guarded: shifts are a separate module, so a mode that omits ShiftStore
    // must still be able to correct an attendance record.
    if (record != null && locator.isRegistered<ShiftStore>()) {
      await shiftStore.reconcileShiftOnAttendanceDelete(record);
    }
  }

  @action
  Future<void> updateRecord({
    required String recordId,
    required DateTime newClockIn,
    DateTime? newClockOut,
  }) async {
    final record = _repository.getRecordById(recordId);
    if (record == null) return;

    record.clockIn = newClockIn;
    record.clockOut = newClockOut;
    
    if (newClockOut != null) {
      final grossMinutes = newClockOut.difference(newClockIn).inMinutes;
      record.totalMinutes = grossMinutes - (record.breakTotalMinutes ?? 0);
      if (record.totalMinutes! < 0) record.totalMinutes = 0;
    } else {
      record.totalMinutes = null;
    }
    
    await _repository.updateRecord(record);

    // Keep the Shift Report / Staff Performance aligned with the corrected
    // times. Guarded for the same reason as deleteRecord.
    if (locator.isRegistered<ShiftStore>()) {
      await shiftStore.syncShiftTimesFromAttendance(record);
    }

    // Refresh list if it's today's record
    final idx = todayRecords.indexWhere((r) => r.id == recordId);
    if (idx != -1) {
      todayRecords[idx] = record;
    }
  }

  @action
  Future<void> autoClockOutIfOpen(String staffName) async {
    final open = getActiveRecord(staffName);
    if (open != null) {
      await clockOut(open.id);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}