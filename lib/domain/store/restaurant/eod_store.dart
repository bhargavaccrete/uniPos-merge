import 'package:mobx/mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../data/repositories/restaurant/eod_repository.dart';

part 'eod_store.g.dart';

class EodStore = _EodStore with _$EodStore;

abstract class _EodStore with Store {
  final EodRepository _eodRepository = locator<EodRepository>();

  final ObservableList<EndOfDayReport> reports =
      ObservableList<EndOfDayReport>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  EndOfDayReport? latestReport;

  _EodStore() {
    _init();
  }

  Future<void> _init() async {
    await loadReports();
  }

  @computed
  int get totalReportCount => reports.length;

  @action
  Future<void> loadReports() async {
    isLoading = true;
    errorMessage = null;
    try {
      final loaded = _eodRepository.getAllReports();
      reports.clear();
      reports.addAll(loaded);
      latestReport = _eodRepository.getLatestReport();
    } catch (e) {
      errorMessage = 'Failed to load reports: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> addReport(EndOfDayReport report) async {
    try {
      await _eodRepository.addReport(report);
      reports.insert(0, report); // Insert at beginning (newest first)
      latestReport = report;
    } catch (e) {
      errorMessage = 'Failed to add report: $e';
      rethrow;
    }
  }

  @action
  Future<void> updateReport(EndOfDayReport report) async {
    try {
      await _eodRepository.updateReport(report);
      final index = reports.indexWhere((r) => r.reportId == report.reportId);
      if (index != -1) {
        reports[index] = report;
      }
      if (latestReport?.reportId == report.reportId) {
        latestReport = report;
      }
    } catch (e) {
      errorMessage = 'Failed to update report: $e';
      rethrow;
    }
  }

  @action
  Future<void> deleteReport(String reportId) async {
    try {
      await _eodRepository.deleteReport(reportId);
      reports.removeWhere((report) => report.reportId == reportId);
      if (latestReport?.reportId == reportId) {
        latestReport = _eodRepository.getLatestReport();
      }
    } catch (e) {
      errorMessage = 'Failed to delete report: $e';
      rethrow;
    }
  }

  EndOfDayReport? getReportById(String reportId) {
    try {
      return reports.firstWhere((report) => report.reportId == reportId);
    } catch (e) {
      return null;
    }
  }

  EndOfDayReport? getReportByDate(DateTime date) {
    try {
      return reports.firstWhere(
        (report) =>
            report.date.year == date.year &&
            report.date.month == date.month &&
            report.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  List<EndOfDayReport> getReportsByDateRange(DateTime start, DateTime end) {
    return reports.where((report) {
      return report.date.isAfter(start) && report.date.isBefore(end);
    }).toList();
  }
}