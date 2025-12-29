
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';

class HiveEOD {
  static const String _boxName = 'eodBox';
  static Box<EndOfDayReport>? _box;

  static Box<EndOfDayReport> _getEODBox() {
    // Box is already opened during app startup in HiveInit
    if (_box == null || !_box!.isOpen) {
      _box = Hive.box<EndOfDayReport>(_boxName);
    }
    return _box!;
  }

  static Future<void> addEODReport(EndOfDayReport report) async {
    final box = _getEODBox();
    await box.put(report.reportId, report);
  }

  static Future<List<EndOfDayReport>> getAllEODReports() async {
    final box = _getEODBox();
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<EndOfDayReport?> getEODByDate(DateTime date) async {
    final box = _getEODBox();
    final reports = box.values.where((report) =>
        report.date.year == date.year &&
        report.date.month == date.month &&
        report.date.day == date.day);
    return reports.isNotEmpty ? reports.first : null;
  }

  static Future<EndOfDayReport?> getLatestEOD() async {
    final box = _getEODBox();
    if (box.isEmpty) return null;
    final reports = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return reports.first;
  }

  static Future<void> deleteEODReport(String reportId) async {
    final box = _getEODBox();
    await box.delete(reportId);
  }

  static Future<void> updateEODReport(EndOfDayReport report) async {
    final box = _getEODBox();
    await box.put(report.reportId, report);
  }
}