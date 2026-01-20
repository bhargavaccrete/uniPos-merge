import 'package:hive/hive.dart';
import 'package:unipos/core/config/app_config.dart';
import '../../models/restaurant/db/eodmodel_317.dart';

/// Repository layer for End of Day (EOD) data access (Restaurant)
/// Handles all Hive database operations for EOD reports
class EodRepository {
  late Box<EndOfDayReport> _eodBox;

  EodRepository() {
    final boxName =
        AppConfig.isRetail ? 'eodBox' : 'restaurant_eodBox';
    _eodBox = Hive.box<EndOfDayReport>(boxName);
  }

  /// Add a new EOD report
  Future<void> addEODReport(EndOfDayReport report) async {
    await _eodBox.put(report.reportId, report);
  }

  /// Get all EOD reports
  Future<List<EndOfDayReport>> getAllEODReports() async {
    final reports = _eodBox.values.toList();
    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  /// Get EOD report by date
  Future<EndOfDayReport?> getEODByDate(DateTime date) async {
    final reports = _eodBox.values.where((report) =>
        report.date.year == date.year &&
        report.date.month == date.month &&
        report.date.day == date.day);
    return reports.isNotEmpty ? reports.first : null;
  }

  /// Get latest EOD report
  Future<EndOfDayReport?> getLatestEOD() async {
    if (_eodBox.isEmpty) return null;
    final reports = _eodBox.values.toList();
    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports.first;
  }

  /// Delete EOD report
  Future<void> deleteEODReport(String reportId) async {
    await _eodBox.delete(reportId);
  }

  /// Update EOD report
  Future<void> updateEODReport(EndOfDayReport report) async {
    await _eodBox.put(report.reportId, report);
  }

  /// Get EOD reports by date range
  Future<List<EndOfDayReport>> getEODReportsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _eodBox.values
        .where((report) =>
            report.date.isAfter(startDate.subtract(Duration(days: 1))) &&
            report.date.isBefore(endDate.add(Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get total EOD reports count
  Future<int> getEODCount() async {
    return _eodBox.length;
  }
}