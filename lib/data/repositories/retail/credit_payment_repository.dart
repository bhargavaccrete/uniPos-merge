import 'package:hive/hive.dart';
import '../../models/retail/hive_model/credit_payment_model_218.dart';

/// Repository layer for Credit Payment data access
/// Handles all Hive database operations for credit payments
class CreditPaymentRepository {
  late Box<CreditPaymentModel> _paymentBox;

  CreditPaymentRepository() {
    _paymentBox = Hive.box<CreditPaymentModel>('credit_payments');
  }

  /// Initialize the repository (ensure box is open)
  void init() {
    // Box is already opened during app startup in HiveInit
    _paymentBox = Hive.box<CreditPaymentModel>('credit_payments');
  }

  /// Get all credit payments
  Future<List<CreditPaymentModel>> getAllPayments() async {
    return _paymentBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
  }

  /// Add a new credit payment
  Future<void> addPayment(CreditPaymentModel payment) async {
    await _paymentBox.put(payment.paymentId, payment);
  }

  /// Get payment by ID
  Future<CreditPaymentModel?> getPaymentById(String paymentId) async {
    return _paymentBox.get(paymentId);
  }

  /// Get payments by customer ID
  Future<List<CreditPaymentModel>> getPaymentsByCustomerId(String customerId) async {
    return _paymentBox.values
        .where((payment) => payment.customerId == customerId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get payments by sale ID
  Future<List<CreditPaymentModel>> getPaymentsBySaleId(String saleId) async {
    return _paymentBox.values
        .where((payment) => payment.saleId == saleId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get payments by date range
  Future<List<CreditPaymentModel>> getPaymentsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _paymentBox.values.where((payment) {
      final paymentDate = DateTime.parse(payment.date);
      return paymentDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          paymentDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get today's payments
  Future<List<CreditPaymentModel>> getTodayPayments() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getPaymentsByDateRange(startOfDay, endOfDay);
  }

  /// Get total amount collected today
  Future<double> getTodayTotalCollection() async {
    final todayPayments = await getTodayPayments();
    return todayPayments
        .where((p) => !(p.isWriteOff ?? false))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Get today's collection by payment mode
  Future<Map<String, double>> getTodayCollectionByMode() async {
    final todayPayments = await getTodayPayments();
    final result = <String, double>{
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
    };

    for (var payment in todayPayments) {
      if (!(payment.isWriteOff ?? false)) {
        final mode = payment.paymentMode.toLowerCase();
        if (result.containsKey(mode)) {
          result[mode] = result[mode]! + payment.amount;
        }
      }
    }

    return result;
  }

  /// Get collection by date range grouped by mode
  Future<Map<String, double>> getCollectionByModeInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final payments = await getPaymentsByDateRange(startDate, endDate);
    final result = <String, double>{
      'cash': 0.0,
      'card': 0.0,
      'upi': 0.0,
      'total': 0.0,
    };

    for (var payment in payments) {
      if (!(payment.isWriteOff ?? false)) {
        final mode = payment.paymentMode.toLowerCase();
        if (result.containsKey(mode)) {
          result[mode] = result[mode]! + payment.amount;
        }
        result['total'] = result['total']! + payment.amount;
      }
    }

    return result;
  }

  /// Get total amount collected for a customer
  Future<double> getTotalCollectedFromCustomer(String customerId) async {
    final payments = await getPaymentsByCustomerId(customerId);
    return payments
        .where((p) => !(p.isWriteOff ?? false))
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Get total write-offs
  Future<double> getTotalWriteOffs() async {
    final allPayments = await getAllPayments();
    return allPayments
        .where((p) => p.isWriteOff ?? false)
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
  }

  /// Delete a payment
  Future<void> deletePayment(String paymentId) async {
    await _paymentBox.delete(paymentId);
  }

  /// Clear all payments
  Future<void> clearAll() async {
    await _paymentBox.clear();
  }

  /// Get payment count
  int getPaymentCount() {
    return _paymentBox.length;
  }

  /// Get payments summary for a customer (for ledger)
  Future<Map<String, dynamic>> getCustomerPaymentsSummary(String customerId) async {
    final payments = await getPaymentsByCustomerId(customerId);

    double totalPaid = 0.0;
    double totalWriteOff = 0.0;
    int paymentCount = 0;

    for (var payment in payments) {
      if (payment.isWriteOff ?? false) {
        totalWriteOff += payment.amount;
      } else {
        totalPaid += payment.amount;
        paymentCount++;
      }
    }

    return {
      'totalPaid': totalPaid,
      'totalWriteOff': totalWriteOff,
      'paymentCount': paymentCount,
      'payments': payments,
    };
  }
}