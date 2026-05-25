import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/restaurant/db/attendance_model.dart';
import '../../../data/repositories/restaurant/attendance_repository.dart';

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
  AttendanceModel? getActiveRecord(String staffName) {
    try {
      return todayRecords.firstWhere(
        (r) => r.staffName == staffName && r.isOpen,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Clock In ─────────────────────────────────────────────────────────────

  @action
  Future<AttendanceModel> clockIn({
    required String staffName,
    required String staffRole,
    String? sessionId,
  }) async {
    final now = DateTime.now();
    final record = AttendanceModel(
      id: _uuid.v4(),
      staffName: staffName,
      staffRole: staffRole,
      clockIn: now,
      date: _todayKey(),
      sessionId: sessionId,
    );
    await _repository.addRecord(record);
    todayRecords.add(record);
    return record;
  }

  // ── Clock Out ────────────────────────────────────────────────────────────

  @action
  Future<void> clockOut(String recordId) async {
    final record = _repository.getRecordById(recordId);
    if (record == null) return;

    // Auto-end break if they were on break
    if (record.isOnBreak) {
      await endBreak(recordId);
    }

    final now = DateTime.now();
    record.clockOut = now;
    final grossMinutes = now.difference(record.clockIn).inMinutes;
    record.totalMinutes = grossMinutes - (record.breakTotalMinutes ?? 0);
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
    await _repository.deleteRecord(recordId);
    todayRecords.removeWhere((r) => r.id == recordId);
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