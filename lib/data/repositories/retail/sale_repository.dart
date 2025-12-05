import 'package:hive/hive.dart';
import '../../models/retail/hive_model/sale_model_203.dart';

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

  /// Get sales by date range
  Future<List<SaleModel>> getSalesByDateRange(DateTime startDate, DateTime endDate) async {
    return _saleBox.values.where((sale) {
      final saleDate = DateTime.parse(sale.date);
      return saleDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          saleDate.isBefore(endDate.add(const Duration(days: 1)));
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
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
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
  Future<List<SaleModel>> getCreditSales() async {
    return _saleBox.values
        .where((sale) => sale.paymentType == 'credit')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
    return sales.where((sale) => sale.paymentType == 'credit').toList();
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