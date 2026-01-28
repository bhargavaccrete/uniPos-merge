import 'package:mobx/mobx.dart';

import '../../../data/models/retail/hive_model/customer_model_208.dart';
import '../../../data/repositories/retail/customer_repository.dart';

part 'customer_store.g.dart';

class CustomerStoreRetail = _CustomerStore with _$CustomerStoreRetail;

abstract class _CustomerStore with Store {
  late final CustomerRepository _customerRepository;

  @observable
  ObservableList<CustomerModel> customers = ObservableList<CustomerModel>();

  @observable
  ObservableList<CustomerModel> searchResults = ObservableList<CustomerModel>();

  @observable
  String searchQuery = '';

  @observable
  CustomerModel? selectedCustomer;

  _CustomerStore() {
    _customerRepository = CustomerRepository();
    _init();
  }

  Future<void> _init() async {
    await loadCustomers();
  }

  // ==================== CUSTOMER OPERATIONS ====================

  @action
  Future<void> loadCustomers() async {
    final loadedCustomers = await _customerRepository.getAllCustomers();
    customers.clear();
    customers.addAll(loadedCustomers);
  }

  @action
  Future<void> addCustomer(CustomerModel customer) async {
    // Save to database through repository
    await _customerRepository.addCustomer(customer);

    // Update UI state
    customers.insert(0, customer);
  }

  @action
  Future<void> updateCustomer(CustomerModel customer) async {
    // Update in database
    await _customerRepository.updateCustomer(customer);

    // Update UI state
    final index = customers.indexWhere((c) => c.customerId == customer.customerId);
    if (index != -1) {
      customers[index] = customer;
    }
  }

  @action
  Future<void> deleteCustomer(String customerId) async {
    // Delete from database
    await _customerRepository.deleteCustomer(customerId);

    // Update UI state
    customers.removeWhere((c) => c.customerId == customerId);

    // Clear selection if deleted customer was selected
    if (selectedCustomer?.customerId == customerId) {
      selectedCustomer = null;
    }
  }

  @action
  Future<void> searchCustomers(String query) async {
    searchQuery = query;

    if (query.isEmpty) {
      searchResults.clear();
      return;
    }

    final results = await _customerRepository.searchCustomers(query);
    searchResults.clear();
    searchResults.addAll(results);
  }

  @action
  void selectCustomer(CustomerModel? customer) {
    selectedCustomer = customer;
  }

  @action
  void clearSelection() {
    selectedCustomer = null;
    searchResults.clear();
    searchQuery = '';
  }

  /// Get customer by ID
  Future<CustomerModel?> getCustomerById(String customerId) async {
    return await _customerRepository.getCustomerById(customerId);
  }

  /// Find customer by phone
  Future<CustomerModel?> findByPhone(String phone) async {
    return await _customerRepository.findByPhone(phone);
  }

  /// Update customer's purchase data after a sale
  @action
  Future<void> updateAfterPurchase(String customerId, double amount, int points) async {
    // update total amount spent+last visited+points earned
    await _customerRepository.updatePurchaseAmount(customerId, amount);

    // Add points
    await _customerRepository.updatePoints(customerId, points);
    // Increse Visit Count
    await _customerRepository.incrementVisitCount(customerId);

    // Reload Customer for ui
    await loadCustomers();
  }

  /// Get top customers
  Future<List<CustomerModel>> getTopCustomers({int limit = 10}) async {
    return await _customerRepository.getTopCustomers(limit: limit);
  }

  @action
  Future<void> clearAllCustomers() async {
    await _customerRepository.clearAll();
    customers.clear();
    searchResults.clear();
    selectedCustomer = null;
  }


  @action
  Future<void> redeemCustomerPoints(String customerId ,int points)async{
    await _customerRepository.redeemPoints(customerId, points);
    await loadCustomers();
  }


  @action
  Future<void>updateCustomerGST(String customerId,String gstNumber)async{
    await _customerRepository.updateGst(customerId,gstNumber);
    await loadCustomers();
  }


  @action
  Future<void>updateCustomerCredit(String customerId,double credit)async{
  await _customerRepository.updateCredit(customerId, credit);
  await loadCustomers();
  }

  // ==================== CREDIT SYSTEM OPERATIONS ====================

  /// Update customer after a credit sale
  @action
  Future<void> updateAfterCreditSale(String customerId, double amount) async {
    // Increase credit balance (amount due)
    await _customerRepository.updateCredit(customerId, amount);
    // Update total purchase and visit count
    await _customerRepository.updatePurchaseAmount(customerId, amount);
    await _customerRepository.incrementVisitCount(customerId);
    // Reload customers for UI
    await loadCustomers();
  }

  /// Check if customer can make a credit purchase (within credit limit)
  Future<bool> canMakeCreditPurchase(String customerId, double amount) async {
    final customer = await _customerRepository.getCustomerById(customerId);
    if (customer == null) return false;

    // If no credit limit set (0), allow unlimited credit
    if (customer.creditLimit <= 0) return true;

    // Check if new total would exceed limit
    final newBalance = customer.creditBalance + amount;
    return newBalance <= customer.creditLimit;
  }

  /// Get available credit for a customer
  Future<double> getAvailableCredit(String customerId) async {
    final customer = await _customerRepository.getCustomerById(customerId);
    if (customer == null) return 0;

    // If no credit limit set, return large value
    if (customer.creditLimit <= 0) return double.infinity;

    final available = customer.creditLimit - customer.creditBalance;
    return available > 0 ? available : 0;
  }

  /// Get customers with outstanding credit balance
  @action
  Future<List<CustomerModel>> getCustomersWithCredit() async {
    return await _customerRepository.getCustomersWithCredit();
  }

  /// Update credit limit for a customer
  @action
  Future<void> updateCreditLimit(String customerId, double creditLimit) async {
    await _customerRepository.updateCreditLimit(customerId, creditLimit);
    await loadCustomers();
  }

  /// Reduce customer credit balance after payment
  @action
  Future<void> reduceCredit(String customerId, double amount) async {
    await _customerRepository.updateCredit(customerId, -amount);
    await loadCustomers();
  }

  // ==================== COMPUTED VALUES ====================

  @computed
  int get customerCount => customers.length;

  @computed
  bool get hasSelection => selectedCustomer != null;

  @computed
  double get totalOutstandingCredit {
    return customers.fold(0.0, (sum, c) => sum + c.creditBalance);
  }

  @computed
  int get customersWithCreditCount {
    return customers.where((c) => c.creditBalance > 0).length;
  }
}