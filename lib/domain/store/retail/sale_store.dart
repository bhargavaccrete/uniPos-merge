import 'package:mobx/mobx.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';

import '../../../data/repositories/retail/sale_repository.dart';
import '../../../data/repositories/retail/sale_item_repository.dart';
import '../../services/common/document_number_service.dart';

part 'sale_store.g.dart';

class SaleStore = _SaleStore with _$SaleStore;

abstract class _SaleStore with Store {
  late final SaleRepository _saleRepository;

  /// A sale and its lines are one aggregate, so the store owns both
  /// repositories. Screens must not reach for `saleItemRepository` themselves.
  late final SaleItemRepository _saleItemRepository;

  @observable
  ObservableList<SaleModel> sales = ObservableList<SaleModel>();

  @observable
  Map<String, dynamic> salesStats = {};

  _SaleStore() {
    _saleRepository = SaleRepository();
    _saleItemRepository = SaleItemRepository();
    _init();
  }

  Future<void> _init() async {
    await loadSales();
    await loadSalesStats();
  }

  final DocumentNumberService _numbers = DocumentNumberService();

  /// The next invoice number — `INV-20260907-001`.
  ///
  /// Sales used to be keyed by a raw UUID, which is unique but unusable: a
  /// customer cannot quote `E7FE242F-1CB3` and staff cannot find it. Same
  /// dated-counter service the PO, GRN and exchange documents already use, so
  /// every document in the app reads alike.
  ///
  /// Call at SUBMIT, never when the checkout screen opens — the counter never
  /// goes backwards, so a number consumed by an abandoned form is a gap in the
  /// sequence. `exists` covers the one case the counter cannot: `appCounters`
  /// restored or wiped while the sales box was not.
  Future<String> nextInvoiceNumber() =>
      _numbers.next('INV', isTaken: _saleRepository.exists);

  // ==================== SALE OPERATIONS ====================

  @action
  Future<void> loadSales() async {
    final loadedSales = await _saleRepository.getAllSales();
    sales.clear();
    sales.addAll(loadedSales);
  }

  @action
  Future<void> addSale(SaleModel sale) async {
    // Save to database through repository
    await _saleRepository.addSale(sale);

    // Update UI state
    sales.insert(0, sale); // Add to beginning for recent-first ordering

    // Refresh stats
    await loadSalesStats();
  }

  /// Persist a completed sale together with its lines.
  ///
  /// This is the entry point checkout should use — writing the header and the
  /// lines through one action keeps them from drifting apart, and keeps
  /// `SaleItemRepository` out of the presentation layer.
  @action
  Future<void> addSaleWithItems(SaleModel sale, List<SaleItemModel> items) async {
    await _saleRepository.addSale(sale);
    await _saleItemRepository.addSaleItems(items);

    sales.insert(0, sale);
    await loadSalesStats();
  }

  /// Lines belonging to a settled sale. These are historical figures — render
  /// them as stored, never recompute them.
  @action
  Future<List<SaleItemModel>> getItemsForSale(String saleId) async {
    return _saleItemRepository.getItemsBySaleId(saleId);
  }

  @action
  Future<void> updateSale(SaleModel sale) async {
    // Update in database
    await _saleRepository.updateSale(sale);

    // Update UI state
    final index = sales.indexWhere((s) => s.saleId == sale.saleId);
    if (index != -1) {
      sales[index] = sale;
    }

    // Refresh stats
    await loadSalesStats();
  }

  @action
  Future<void> deleteSale(String saleId) async {
    // Delete from database
    await _saleRepository.deleteSale(saleId);

    // Update UI state
    sales.removeWhere((s) => s.saleId == saleId);

    // Refresh stats
    await loadSalesStats();
  }

  /// Get all sales
  @action
  Future<List<SaleModel>> getAllSales() async {
    return await _saleRepository.getAllSales();
  }

  /// Get sale by ID
  @action
  Future<SaleModel?> getSaleById(String saleId) async {
    return await _saleRepository.getSaleById(saleId);
  }

  /// Get today's sales
  @action
  Future<List<SaleModel>> getTodaySales() async {
    return await _saleRepository.getTodaySales();
  }

  /// Get sales by date range
  @action
  Future<List<SaleModel>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    return await _saleRepository.getSalesByDateRange(startDate, endDate);
  }

  /// Load sales statistics
  @action
  Future<void> loadSalesStats() async {
    salesStats = await _saleRepository.getSalesStats();
  }

  /// Get today's total revenue
  Future<double> getTodayRevenue() async {
    return await _saleRepository.getTodayTotalSales();
  }

  @action
  Future<void> clearAllSales() async {
    await _saleRepository.clearAll();
    sales.clear();
    salesStats = {};
  }

  @computed
  int get saleCount => sales.length;

  @computed
  double get totalRevenue {
    return sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  /// Get sales by customer ID
  @action
  Future<List<SaleModel>> getSalesByCustomerId(String customerId) async {
    return await _saleRepository.getSalesByCustomerId(customerId);
  }

  // ==================== CREDIT SALE OPERATIONS ====================

  /// Get all credit sales
  @action
  Future<List<SaleModel>> getCreditSales() async {
    return await _saleRepository.getCreditSales();
  }

  /// Get sales with due amount
  @action
  Future<List<SaleModel>> getSalesWithDue() async {
    return await _saleRepository.getSalesWithDue();
  }

  /// Get customer sales with due
  @action
  Future<List<SaleModel>> getCustomerSalesWithDue(String customerId) async {
    return await _saleRepository.getCustomerSalesWithDue(customerId);
  }

  /// Get total due amount
  Future<double> getTotalDueAmount() async {
    return await _saleRepository.getTotalDueAmount();
  }

  /// Get customer total due
  Future<double> getCustomerTotalDue(String customerId) async {
    return await _saleRepository.getCustomerTotalDue(customerId);
  }

  /// Get today's credit sales
  @action
  Future<List<SaleModel>> getTodayCreditSales() async {
    return await _saleRepository.getTodayCreditSales();
  }

  /// Get today's credit sales amount
  Future<double> getTodayCreditSalesAmount() async {
    return await _saleRepository.getTodayCreditSalesAmount();
  }

  /// Get credit sales by date range
  @action
  Future<List<SaleModel>> getCreditSalesByDateRange(DateTime start, DateTime end) async {
    return await _saleRepository.getCreditSalesByDateRange(start, end);
  }

  /// Get sales by status
  @action
  Future<List<SaleModel>> getSalesByStatus(String status) async {
    return await _saleRepository.getSalesByStatus(status);
  }

  /// Get sales summary by payment type for date range
  Future<Map<String, double>> getSalesByPaymentTypeInRange(DateTime start, DateTime end) async {
    return await _saleRepository.getSalesByPaymentTypeInRange(start, end);
  }

  /// Get outstanding report
  Future<Map<String, dynamic>> getOutstandingReport() async {
    return await _saleRepository.getOutstandingReport();
  }

  /// Get customers with due
  Future<List<String>> getCustomersWithDue() async {
    return await _saleRepository.getCustomersWithDue();
  }

  // ==================== COMPUTED VALUES ====================

  @computed
  int get creditSalesCount {
    return sales.where((s) => s.paymentType == 'credit').length;
  }

  @computed
  double get totalDueInSales {
    return sales.fold(0.0, (sum, sale) => sum + sale.dueAmount);
  }

  @computed
  int get dueInvoicesCount {
    return sales.where((s) => s.dueAmount > 0).length;
  }
}