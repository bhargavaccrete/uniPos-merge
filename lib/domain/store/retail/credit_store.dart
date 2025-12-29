import 'package:mobx/mobx.dart';
import 'package:unipos/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:unipos/data/repositories/retail/credit_payment_repository.dart';
import 'package:unipos/data/repositories/retail/customer_repository.dart';
import 'package:unipos/data/repositories/retail/sale_repository.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/retail/hive_model/sale_model_203.dart';

part 'credit_store.g.dart';

/// Result of credit payment operation
class CreditPaymentResult {
  final bool success;
  final String? errorMessage;
  final double? remainingDue;
  final List<String>? closedInvoices;
  final List<String>? partialInvoices;

  CreditPaymentResult({
    required this.success,
    this.errorMessage,
    this.remainingDue,
    this.closedInvoices,
    this.partialInvoices,
  });

  factory CreditPaymentResult.success({
    double? remainingDue,
    List<String>? closedInvoices,
    List<String>? partialInvoices,
  }) =>
      CreditPaymentResult(
        success: true,
        remainingDue: remainingDue,
        closedInvoices: closedInvoices,
        partialInvoices: partialInvoices,
      );

  factory CreditPaymentResult.failure(String message) => CreditPaymentResult(
        success: false,
        errorMessage: message,
      );
}

/// Ledger entry type
enum LedgerEntryType { creditSale, payment, writeOff }

/// Ledger entry for timeline display
class LedgerEntry {
  final String id;
  final String date;
  final LedgerEntryType type;
  final String description;
  final double amount;
  final double runningBalance;
  final String? saleId;
  final String? paymentId;

  LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.runningBalance,
    this.saleId,
    this.paymentId,
  });
}

class CreditStore = _CreditStore with _$CreditStore;

abstract class _CreditStore with Store {
  late final CreditPaymentRepository _paymentRepository;
  late final SaleRepository _saleRepository;
  late final CustomerRepository _customerRepository;

  @observable
  ObservableList<CreditPaymentModel> payments = ObservableList<CreditPaymentModel>();

  @observable
  ObservableList<SaleModel> salesWithDue = ObservableList<SaleModel>();

  @observable
  double totalOutstanding = 0.0;

  @observable
  int customersWithDue = 0;

  @observable
  bool isLoading = false;

  _CreditStore() {
    _paymentRepository = CreditPaymentRepository();
    _saleRepository = SaleRepository();
    _customerRepository = CustomerRepository();
    _init();
  }

  Future<void> _init() async {
    _paymentRepository.init(); // No await - init() is now synchronous
    await loadData();
  }

  // ==================== DATA LOADING ====================

  @action
  Future<void> loadData() async {
    isLoading = true;
    try {
      final loadedPayments = await _paymentRepository.getAllPayments();
      payments.clear();
      payments.addAll(loadedPayments);

      final loadedSalesWithDue = await _saleRepository.getSalesWithDue();
      salesWithDue.clear();
      salesWithDue.addAll(loadedSalesWithDue);

      totalOutstanding = await _saleRepository.getTotalDueAmount();

      final customerIds = await _saleRepository.getCustomersWithDue();
      customersWithDue = customerIds.length;
    } finally {
      isLoading = false;
    }
  }

  // ==================== RECEIVE PAYMENT ====================

  /// Receive payment from customer (FIFO - oldest invoices first)
  @action
  Future<CreditPaymentResult> receivePayment({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceId,
    String? note,
  }) async {
    if (amount <= 0) {
      return CreditPaymentResult.failure('Invalid payment amount');
    }

    // Get customer
    final customer = await _customerRepository.getCustomerById(customerId);
    if (customer == null) {
      return CreditPaymentResult.failure('Customer not found');
    }

    if (customer.creditBalance <= 0) {
      return CreditPaymentResult.failure('Customer has no outstanding balance');
    }

    // Get sales with due (FIFO - oldest first)
    final salesWithDue = await _saleRepository.getCustomerSalesWithDue(customerId);
    if (salesWithDue.isEmpty) {
      return CreditPaymentResult.failure('No invoices with due amount found');
    }

    double remainingPayment = amount;
    final closedInvoices = <String>[];
    final partialInvoices = <String>[];
    final balanceBefore = customer.creditBalance;

    // Apply payment to invoices (FIFO)
    for (var sale in salesWithDue) {
      if (remainingPayment <= 0) break;

      final invoiceDue = sale.dueAmount;
      final paymentForInvoice = remainingPayment >= invoiceDue ? invoiceDue : remainingPayment;

      // Create payment record for this invoice
      final paymentId = const Uuid().v4();
      final balanceAfter = balanceBefore - paymentForInvoice;

      final payment = CreditPaymentModel.create(
        paymentId: paymentId,
        customerId: customerId,
        saleId: sale.saleId,
        amount: paymentForInvoice,
        paymentMode: paymentMode,
        referenceId: referenceId,
        note: note,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
      );

      await _paymentRepository.addPayment(payment);

      // Update sale
      final newPaidAmount = sale.paidAmount + paymentForInvoice;
      final newDueAmount = sale.dueAmount - paymentForInvoice;
      final newStatus = SaleModel.calculateStatus(newPaidAmount, newDueAmount);

      final updatedSale = sale.copyWith(
        paidAmount: newPaidAmount,
        dueAmount: newDueAmount,
        status: newStatus,
      );

      await _saleRepository.updateSale(updatedSale);

      if (newDueAmount <= 0) {
        closedInvoices.add(sale.saleId);
      } else {
        partialInvoices.add(sale.saleId);
      }

      remainingPayment -= paymentForInvoice;
    }

    // Update customer credit balance
    final newCreditBalance = customer.creditBalance - (amount - remainingPayment);
    await _customerRepository.updateCredit(
      customerId,
      -(amount - remainingPayment), // Negative to decrease balance
    );

    // Reload data
    await loadData();

    return CreditPaymentResult.success(
      remainingDue: newCreditBalance,
      closedInvoices: closedInvoices,
      partialInvoices: partialInvoices,
    );
  }

  // ==================== DEBT WRITE-OFF ====================

  /// Write off debt for a specific sale
  @action
  Future<CreditPaymentResult> writeOffDebt({
    required String customerId,
    required String saleId,
    double? amount, // If null, write off entire due
    String? note,
  }) async {
    final sale = await _saleRepository.getSaleById(saleId);
    if (sale == null) {
      return CreditPaymentResult.failure('Sale not found');
    }

    if (sale.dueAmount <= 0) {
      return CreditPaymentResult.failure('No due amount to write off');
    }

    final customer = await _customerRepository.getCustomerById(customerId);
    if (customer == null) {
      return CreditPaymentResult.failure('Customer not found');
    }

    final writeOffAmount = amount ?? sale.dueAmount;
    if (writeOffAmount > sale.dueAmount) {
      return CreditPaymentResult.failure('Write-off amount exceeds due amount');
    }

    // Create write-off payment record
    final paymentId = const Uuid().v4();
    final balanceBefore = customer.creditBalance;
    final balanceAfter = balanceBefore - writeOffAmount;

    final writeOff = CreditPaymentModel.create(
      paymentId: paymentId,
      customerId: customerId,
      saleId: saleId,
      amount: writeOffAmount,
      paymentMode: 'write_off',
      note: note ?? 'Debt Write-Off',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      isWriteOff: true,
    );

    await _paymentRepository.addPayment(writeOff);

    // Update sale
    final newPaidAmount = sale.paidAmount + writeOffAmount;
    final newDueAmount = sale.dueAmount - writeOffAmount;
    final newStatus = SaleModel.calculateStatus(newPaidAmount, newDueAmount);

    final updatedSale = sale.copyWith(
      paidAmount: newPaidAmount,
      dueAmount: newDueAmount,
      status: newStatus,
    );

    await _saleRepository.updateSale(updatedSale);

    // Update customer credit balance
    await _customerRepository.updateCredit(customerId, -writeOffAmount);

    // Reload data
    await loadData();

    return CreditPaymentResult.success(
      remainingDue: newDueAmount,
      closedInvoices: newDueAmount <= 0 ? [saleId] : null,
    );
  }

  // ==================== LEDGER ====================

  /// Get ledger entries for a customer
  @action
  Future<List<LedgerEntry>> getCustomerLedger(String customerId) async {
    final entries = <LedgerEntry>[];

    // Get all credit sales for customer
    final sales = await _saleRepository.getSalesByCustomerId(customerId);
    final creditSales = sales.where((s) => s.paymentType == 'credit' || s.hasDue).toList();

    // Get all payments for customer
    final customerPayments = await _paymentRepository.getPaymentsByCustomerId(customerId);

    // Combine and sort by date
    final allItems = <Map<String, dynamic>>[];

    for (var sale in creditSales) {
      allItems.add({
        'type': 'sale',
        'date': sale.date,
        'item': sale,
      });
    }

    for (var payment in customerPayments) {
      allItems.add({
        'type': 'payment',
        'date': payment.date,
        'item': payment,
      });
    }

    // Sort by date ascending
    allItems.sort((a, b) => a['date'].compareTo(b['date']));

    // Calculate running balance
    double runningBalance = 0.0;

    for (var item in allItems) {
      if (item['type'] == 'sale') {
        final sale = item['item'] as SaleModel;
        // Only add to balance if it was a credit sale initially
        if (sale.paymentType == 'credit') {
          runningBalance += sale.totalAmount;
          entries.add(LedgerEntry(
            id: sale.saleId,
            date: sale.date,
            type: LedgerEntryType.creditSale,
            description: 'Credit Sale (INV-${sale.saleId.substring(0, 8).toUpperCase()})',
            amount: sale.totalAmount,
            runningBalance: runningBalance,
            saleId: sale.saleId,
          ));
        }
      } else {
        final payment = item['item'] as CreditPaymentModel;
        runningBalance -= payment.amount;
        entries.add(LedgerEntry(
          id: payment.paymentId,
          date: payment.date,
          type: payment.isDebtWriteOff ? LedgerEntryType.writeOff : LedgerEntryType.payment,
          description: payment.isDebtWriteOff
              ? 'Debt Write-Off'
              : 'Payment Received (${payment.paymentModeDisplayText})',
          amount: -payment.amount,
          runningBalance: runningBalance,
          paymentId: payment.paymentId,
          saleId: payment.saleId,
        ));
      }
    }

    return entries;
  }

  // ==================== REPORTS ====================

  /// Get today's collection summary
  Future<Map<String, double>> getTodayCollectionSummary() async {
    return await _paymentRepository.getTodayCollectionByMode();
  }

  /// Get collection summary by date range
  Future<Map<String, double>> getCollectionSummary(DateTime start, DateTime end) async {
    return await _paymentRepository.getCollectionByModeInRange(start, end);
  }

  /// Get outstanding report
  Future<Map<String, dynamic>> getOutstandingReport() async {
    return await _saleRepository.getOutstandingReport();
  }

  /// Get customer payment history
  Future<List<CreditPaymentModel>> getCustomerPayments(String customerId) async {
    return await _paymentRepository.getPaymentsByCustomerId(customerId);
  }

  /// Get payments for a specific sale
  Future<List<CreditPaymentModel>> getSalePayments(String saleId) async {
    return await _paymentRepository.getPaymentsBySaleId(saleId);
  }

  // ==================== COMPUTED VALUES ====================

  @computed
  int get totalDueInvoices => salesWithDue.length;

  @computed
  double get todayCollection {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return payments
        .where((p) => p.date.startsWith(todayStr) && !(p.isWriteOff ?? false))
        .fold<double>(0.0, (sum, p) => sum + p.amount);
  }
}