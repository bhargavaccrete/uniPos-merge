import 'package:hive/hive.dart';
import '../../models/retail/hive_model/sale_model_203.dart';
import '../../../util/retail/sale_created_at_prefilter.dart';

/// Repository layer for Sale data access
/// Handles all Hive database operations for sales
class SaleRepository {
  late Box<SaleModel> _saleBox;

  SaleRepository() {
    _saleBox = Hive.box<SaleModel>('sales');
  }

  /// Get all sales from Hive
  Future<List<SaleModel>> getAllSales() async {
    return _saleBox.values.toList();
  }

  /// Every sale in box order, without copying the box. Same order as
  /// [getAllSales]; iterate synchronously — a write mid-iteration is unsafe.
  Iterable<SaleModel> salesInStorageOrder() => _saleBox.values;

  /// The sale stored under [saleId], synchronously. Every writer (`addSale`,
  /// `updateSale`, backup restore) keys a sale by its own `saleId`, so this is
  /// the one sale carrying that id — or null.
  SaleModel? saleInStorage(String saleId) => _saleBox.get(saleId);

  /// Add a new sale to Hive
  Future<void> addSale(SaleModel sale) async {
    await _saleBox.put(sale.saleId, sale);
  }

  /// Update a sale in Hive
  Future<void> updateSale(SaleModel sale) async {
    await _saleBox.put(sale.saleId, sale);
  }

  /// Get a sale by ID
  Future<SaleModel?> getSaleById(String saleId) async {
    return _saleBox.get(saleId);
  }


  /// Sales in a window: inclusive start, **exclusive** end, filtered on
  /// `createdAt`.
  ///
  /// Exclusive end matches `ReportService._inWindow`. They used to disagree —
  /// this was inclusive on both ends and callers bounded the day at 23:59:59,
  /// so a sale rung up in that final second landed in the Daily Sales report
  /// but not in EOD or the dashboard's "Today's Sales".
  ///
  /// An unparseable `createdAt` is skipped rather than thrown, so one bad row
  /// can't take out the whole query.
  Future<List<SaleModel>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    // Skips the parse only for sales provably outside the range.
    final prefilter = SaleCreatedAtPrefilter.forWindow(startDate, endDate);
    return _saleBox.values.where((sale) {
      if (prefilter.isDefinitelyOutside(sale.createdAt)) return false;
      final saleCreatedAt = DateTime.tryParse(sale.createdAt);
      if (saleCreatedAt == null) return false;
      return !saleCreatedAt.isBefore(startDate) && saleCreatedAt.isBefore(endDate);
    }).toList();
  }

  /// Get sales by payment type
  Future<List<SaleModel>> getSalesByPaymentType(String paymentType) async {
    return _saleBox.values.where((sale) => sale.paymentType == paymentType).toList();
  }

  /// Get today's sales
  Future<List<SaleModel>> getTodaySales() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    // Start of tomorrow, not 23:59:59 — the range is exclusive at the end, and
    // the old bound silently dropped the last second of the day.
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  /// Get total sales amount for a date range
  Future<double> getTotalSalesAmount(DateTime startDate, DateTime endDate) async {
    final sales = await getSalesByDateRange(startDate, endDate);
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  /// Get today's total sales amount
  Future<double> getTodayTotalSales() async {
    final todaySales = await getTodaySales();
    return todaySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  /// Delete a sale
  Future<void> deleteSale(String saleId) async {
    await _saleBox.delete(saleId);
  }

  /// Clear all sales
  Future<void> clearAll() async {
    await _saleBox.clear();
  }

  /// Get total sale count
  int getSaleCount() {
    return _saleBox.length;
  }

  /// Get sales by customer ID
  Future<List<SaleModel>> getSalesByCustomerId(String customerId) async {
    return _saleBox.values
        .where((sale) => sale.customerId == customerId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
  }

  /// Get sales statistics
  Future<Map<String, dynamic>> getSalesStats() async {
    final allSales = await getAllSales();
    final todaySales = await getTodaySales();

    return {
      'totalSales': allSales.length,
      'todaySales': todaySales.length,
      'totalRevenue': allSales.fold(0.0, (sum, sale) => sum + sale.totalAmount),
      'todayRevenue': todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount),
      'cashSales': allSales.where((s) => s.paymentType == 'cash').length,
      'cardSales': allSales.where((s) => s.paymentType == 'card').length,
      'upiSales': allSales.where((s) => s.paymentType == 'upi').length,
      'creditSales': allSales.where((s) => s.paymentType == 'credit').length,
    };
  }

  // ==================== CREDIT SALE METHODS ====================

  /// Get all credit sales (pay later)
  /// Newest first, then the sale id.
  ///
  /// A date is not a total order — two sales in the same second reordered
  /// between loads, because `List.sort` is not stable.
  static int _newestSaleFirst(SaleModel a, SaleModel b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.saleId.compareTo(b.saleId);
  }

  Future<List<SaleModel>> getCreditSales() async {
    return _saleBox.values
        .where((sale) => sale.paymentType == 'credit')
        .toList()
      ..sort(_newestSaleFirst);
  }

  /// Get all sales with due amount
  Future<List<SaleModel>> getSalesWithDue() async {
    return _saleBox.values
        .where((sale) => sale.dueAmount > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get sales with due amount for a customer
  Future<List<SaleModel>> getCustomerSalesWithDue(String customerId) async {
    return _saleBox.values
        .where((sale) => sale.customerId == customerId && sale.dueAmount > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // FIFO - oldest first
  }

  /// Get total due amount for all customers
  Future<double> getTotalDueAmount() async {
    final salesWithDue = await getSalesWithDue();
    return salesWithDue.fold<double>(0.0, (sum, sale) => sum + sale.dueAmount);
  }

  /// Get total due amount for a customer
  Future<double> getCustomerTotalDue(String customerId) async {
    final customerSales = await getCustomerSalesWithDue(customerId);
    return customerSales.fold<double>(0.0, (sum, sale) => sum + sale.dueAmount);
  }

  /// Get today's credit sales
  Future<List<SaleModel>> getTodayCreditSales() async {
    final todaySales = await getTodaySales();
    return todaySales.where((sale) => sale.paymentType == 'credit').toList();
  }

  /// Get today's credit sales amount
  Future<double> getTodayCreditSalesAmount() async {
    final creditSales = await getTodayCreditSales();
    return creditSales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  /// Get credit sales by date range
  Future<List<SaleModel>> getCreditSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getSalesByDateRange(startDate, endDate);
    // Sorted like the unfiltered list above — this used to come back in Hive
    // key order, so applying a date filter changed the ORDER of the Credit
    // Sales tab as well as its contents.
    return sales.where((sale) => sale.paymentType == 'credit').toList()
      ..sort(_newestSaleFirst);
  }

  /// Get sales by status
  Future<List<SaleModel>> getSalesByStatus(String status) async {
    return _saleBox.values
        .where((sale) => sale.status == status)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get customers with outstanding balance
  Future<List<String>> getCustomersWithDue() async {
    final salesWithDue = await getSalesWithDue();
    final customerIds = salesWithDue
        .where((sale) => sale.customerId != null)
        .map((sale) => sale.customerId!)
        .toSet()
        .toList();
    return customerIds;
  }

  /// Get sales summary by payment type for a date range
  Future<Map<String, double>> getSalesByPaymentTypeInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getSalesByDateRange(startDate, endDate);
    final result = <String, double>{
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
      'credit': 0.0,
      'split': 0.0,
      'total': 0.0,
    };

    for (var sale in sales) {
      if (sale.isReturn != true) {
        final type = sale.paymentType.toLowerCase();
        if (result.containsKey(type)) {
          result[type] = result[type]! + sale.totalAmount;
        }
        result['total'] = result['total']! + sale.totalAmount;
      }
    }

    return result;
  }

  /// Get outstanding report data
  Future<Map<String, dynamic>> getOutstandingReport() async {
    final salesWithDue = await getSalesWithDue();
    final customerDues = <String, double>{};
    double totalOutstanding = 0.0;

    for (var sale in salesWithDue) {
      if (sale.customerId != null) {
        customerDues[sale.customerId!] =
            (customerDues[sale.customerId!] ?? 0.0) + sale.dueAmount;
        totalOutstanding += sale.dueAmount;
      }
    }

    return {
      'totalOutstanding': totalOutstanding,
      'customerCount': customerDues.length,
      'invoiceCount': salesWithDue.length,
      'customerDues': customerDues,
    };
  }
}