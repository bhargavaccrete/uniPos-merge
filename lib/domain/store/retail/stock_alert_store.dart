import 'package:mobx/mobx.dart';
import 'package:unipos/domain/services/retail/stock_alert_service.dart';

part 'stock_alert_store.g.dart';

class StockAlertStore = _StockAlertStore with _$StockAlertStore;

abstract class _StockAlertStore with Store {
  final StockAlertService _alertService = StockAlertService();

  @observable
  ObservableList<Map<String, dynamic>> lowStockItems = ObservableList<Map<String, dynamic>>();

  @observable
  int threshold = 10;

  @observable
  bool isEnabled = true;

  @observable
  bool isLoading = false;

  @observable
  int totalAlerts = 0;

  @observable
  int criticalCount = 0;

  @observable
  int warningCount = 0;

  @observable
  int outOfStockCount = 0;

  _StockAlertStore() {
    _init();
  }

  Future<void> _init() async {
    await loadSettings();
    await loadLowStockItems();
  }

  @action
  Future<void> loadSettings() async {
    threshold = await _alertService.getThreshold();
    isEnabled = await _alertService.isEnabled();
  }

  @action
  Future<void> loadLowStockItems() async {
    isLoading = true;
    try {
      final summary = await _alertService.getAlertSummary();
      lowStockItems.clear();
      lowStockItems.addAll(List<Map<String, dynamic>>.from(summary['items'] as List));
      totalAlerts = summary['totalAlerts'] as int;
      criticalCount = summary['criticalCount'] as int;
      warningCount = summary['warningCount'] as int;
      outOfStockCount = summary['outOfStockCount'] as int;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> setThreshold(int newThreshold) async {
    await _alertService.setThreshold(newThreshold);
    threshold = newThreshold;
    await loadLowStockItems();
  }

  @action
  Future<void> setEnabled(bool enabled) async {
    await _alertService.setEnabled(enabled);
    isEnabled = enabled;
  }

  @action
  Future<void> refresh() async {
    await loadLowStockItems();
  }

  @computed
  List<Map<String, dynamic>> get criticalItems {
    return lowStockItems.where((item) => (item['currentStock'] as int) <= 3).toList();
  }

  @computed
  List<Map<String, dynamic>> get warningItems {
    return lowStockItems.where((item) => (item['currentStock'] as int) > 3).toList();
  }

  @computed
  List<Map<String, dynamic>> get outOfStockItems {
    return lowStockItems.where((item) => (item['currentStock'] as int) == 0).toList();
  }

  @computed
  bool get hasAlerts => totalAlerts > 0;

  @computed
  bool get hasCriticalAlerts => criticalCount > 0;
}