import 'package:hive/hive.dart';

import '../../models/restaurant/db/eodmodel_317.dart';

/// Repository layer for End of Day Report data access
class EodRepository {
  static const String _boxName = 'eodBox';
  late Box<EndOfDayReport> _eodBox;

  EodRepository() {
    _eodBox = Hive.box<EndOfDayReport>(_boxName);
  }

  List<EndOfDayReport> getAllReports() {
    return _eodBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addReport(EndOfDayReport report) async {
    await _eodBox.put(report.reportId, report);
  }

  Future<void> updateReport(EndOfDayReport report) async {
    await _eodBox.put(report.reportId, report);
  }

  Future<void> deleteReport(String reportId) async {
    await _eodBox.delete(reportId);
  }

  EndOfDayReport? getReportById(String reportId) {
    return _eodBox.get(reportId);
  }

  EndOfDayReport? getReportByDate(DateTime date) {
    try {
      return _eodBox.values.firstWhere(
        (report) =>
            report.date.year == date.year &&
            report.date.month == date.month &&
            report.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  EndOfDayReport? getLatestReport() {
    if (_eodBox.isEmpty) return null;
    final reports = _eodBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return reports.first;
  }

  List<EndOfDayReport> getReportsByDateRange(DateTime start, DateTime end) {
    return _eodBox.values.where((report) {
      return report.date.isAfter(start) && report.date.isBefore(end);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int getReportCount() {
    return _eodBox.length;
  }

  Future<void> clearAll() async {
    await _eodBox.clear();
  }
}