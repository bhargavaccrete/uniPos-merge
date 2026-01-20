import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/eodmodel_317.dart';
import '../../../data/repositories/restaurant/eod_repository.dart';

part 'eod_store.g.dart';

class EodStore = _EodStore with _$EodStore;

abstract class _EodStore with Store {
  final EodRepository _repository;

  _EodStore(this._repository);

  @observable
  ObservableList<EndOfDayReport> eodReports = ObservableList<EndOfDayReport>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  DateTime? startDate;

  @observable
  DateTime? endDate;

  // Computed properties
  @computed
  List<EndOfDayReport> get filteredReports {
    if (startDate == null || endDate == null) return eodReports;

    return eodReports
        .where((report) =>
            report.date.isAfter(startDate!.subtract(Duration(days: 1))) &&
            report.date.isBefore(endDate!.add(Duration(days: 1))))
        .toList();
  }

  @computed
  int get totalReports => eodReports.length;

  @computed
  double get totalRevenue => eodReports.fold<double>(
      0.0, (double sum, report) => sum + report.totalSales);

  // Actions
  @action
  Future<void> loadEODReports() async {
    try {
      isLoading = true;
      errorMessage = null;
      final reports = await _repository.getAllEODReports();
      eodReports = ObservableList.of(reports);
    } catch (e) {
      errorMessage = 'Failed to load EOD reports: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadEODReports();
  }

  @action
  Future<bool> addEODReport(EndOfDayReport report) async {
    try {
      await _repository.addEODReport(report);
      eodReports.insert(0, report); // Add to beginning (most recent)
      return true;
    } catch (e) {
      errorMessage = 'Failed to add EOD report: $e';
      return false;
    }
  }

  @action
  Future<EndOfDayReport?> getEODByDate(DateTime date) async {
    try {
      return await _repository.getEODByDate(date);
    } catch (e) {
      errorMessage = 'Failed to get EOD by date: $e';
      return null;
    }
  }

  @action
  Future<EndOfDayReport?> getLatestEOD() async {
    try {
      return await _repository.getLatestEOD();
    } catch (e) {
      errorMessage = 'Failed to get latest EOD: $e';
      return null;
    }
  }

  @action
  Future<bool> updateEODReport(EndOfDayReport updatedReport) async {
    try {
      await _repository.updateEODReport(updatedReport);
      final index =
          eodReports.indexWhere((r) => r.reportId == updatedReport.reportId);
      if (index != -1) {
        eodReports[index] = updatedReport;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update EOD report: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteEODReport(String reportId) async {
    try {
      await _repository.deleteEODReport(reportId);
      eodReports.removeWhere((r) => r.reportId == reportId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete EOD report: $e';
      return false;
    }
  }

  @action
  void setDateRange(DateTime? start, DateTime? end) {
    startDate = start;
    endDate = end;
  }

  @action
  void clearFilters() {
    startDate = null;
    endDate = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}