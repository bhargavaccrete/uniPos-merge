import 'package:mobx/mobx.dart';
import '../../../core/config/app_config.dart';
import '../../../core/plan/entitlement_keys.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../data/models/common/customer_model_125.dart';
import '../../../data/repositories/common/customer_repository.dart';

part 'customer_store.g.dart';

class CustomerStore = _CustomerStore with _$CustomerStore;

abstract class _CustomerStore with Store {
  final CustomerRepository _repository;

  _CustomerStore(this._repository);

  @observable
  ObservableList<Customer> customers = ObservableList<Customer>();

  @observable
  ObservableList<Customer> searchResults = ObservableList<Customer>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  @observable
  Customer? selectedCustomer;

  // ==================== COMPUTED ====================

  @computed
  List<Customer> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    final lowerQuery = searchQuery.toLowerCase();
    return customers.where((customer) {
      final name = customer.name?.toLowerCase() ?? '';
      final phone = customer.phone?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || phone.contains(lowerQuery);
    }).toList();
  }

  @computed
  int get totalCustomers => customers.length;

  @computed
  int get customerCount => customers.length;

  @computed
  bool get hasSelection => selectedCustomer != null;

  @computed
  List<Customer> get topCustomersByPoints {
    final sorted = customers.toList();
    sorted.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
    return sorted.take(10).toList();
  }

  @computed
  List<Customer> get frequentCustomers {
    final sorted = customers.toList();
    sorted.sort((a, b) => b.totalVisites.compareTo(a.totalVisites));
    return sorted.take(10).toList();
  }

  @computed
  double get totalOutstandingCredit {
    return customers.fold(0.0, (sum, c) => sum + c.creditBalance);
  }

  @computed
  int get customersWithCreditCount {
    return customers.where((c) => c.creditBalance > 0).length;
  }

  // ==================== CUSTOMER OPERATIONS ====================

  @action
  Future<void> loadCustomers() async {
    try {
      isLoading = true;
      errorMessage = null;
      final loadedCustomers = await _repository.getAllCustomers();
      customers = ObservableList.of(loadedCustomers);
    } catch (e) {
      errorMessage = 'Failed to load customers: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    await loadCustomers();
  }

  @action
  Future<bool> addCustomer(Customer customer) async {
    try {
      // Plan gate — customer module + cap (also covers on-the-fly creation at
      // checkout). Availability = module flag; the cap only bites when positive.
      // PlanEnforce itself bypasses retail (no entitlement system yet), so
      // this only ever blocks restaurant.
      if (!PlanEnforce.allows(EntKeys.customers)) {
        errorMessage = 'Your plan doesn’t include saved customers.';
        return false;
      }
      if (!PlanEnforce.withinLimit(EntKeys.customersMax, customers.length)) {
        final max = PlanEnforce.limit(EntKeys.customersMax);
        errorMessage = 'Customer limit reached (max $max). Upgrade to add more.';
        return false;
      }
      await _repository.addCustomer(customer);
      // Retail shows newest-first, restaurant appends — preserve each side's
      // existing list order.
      if (AppConfig.isRetail) {
        customers.insert(0, customer);
      } else {
        customers.add(customer);
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to add customer: $e';
      return false;
    }
  }

  @action
  Future<Customer?> getCustomerById(String customerId) async {
    try {
      return await _repository.getCustomerById(customerId);
    } catch (e) {
      errorMessage = 'Failed to get customer: $e';
      return null;
    }
  }

  @action
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      return await _repository.getCustomerByPhone(phone);
    } catch (e) {
      errorMessage = 'Failed to get customer by phone: $e';
      return null;
    }
  }

  /// Alias for getCustomerByPhone (retail's original method name)
  Future<Customer?> findByPhone(String phone) => getCustomerByPhone(phone);

  @action
  Future<bool> updateCustomer(Customer updatedCustomer) async {
    try {
      await _repository.updateCustomer(updatedCustomer);
      final index = customers.indexWhere((c) => c.customerId == updatedCustomer.customerId);
      if (index != -1) {
        customers[index] = updatedCustomer;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to update customer: $e';
      return false;
    }
  }

  @action
  Future<bool> deleteCustomer(String customerId) async {
    try {
      await _repository.deleteCustomer(customerId);
      customers.removeWhere((c) => c.customerId == customerId);
      if (selectedCustomer?.customerId == customerId) {
        selectedCustomer = null;
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete customer: $e';
      return false;
    }
  }

  @action
  Future<bool> updateCustomerVisit({
    required String customerId,
    required String orderType,
    int pointsToAdd = 0,
  }) async {
    try {
      await _repository.updateCustomerVisit(
        customerId: customerId,
        orderType: orderType,
        pointsToAdd: pointsToAdd,
      );
      await loadCustomers(); // Reload to reflect changes
      return true;
    } catch (e) {
      errorMessage = 'Failed to update customer visit: $e';
      return false;
    }
  }

  /// Update customer's purchase data after a sale (retail)
  @action
  Future<void> updateAfterPurchase(String customerId, double amount, int points) async {
    await _repository.updatePurchaseAmount(customerId, amount);
    await _repository.addLoyaltyPoints(customerId, points);
    await _repository.incrementVisitCount(customerId);
    await loadCustomers();
  }

  @action
  Future<bool> addLoyaltyPoints(String customerId, int points) async {
    try {
      await _repository.addLoyaltyPoints(customerId, points);
      await loadCustomers(); // Reload to reflect changes
      return true;
    } catch (e) {
      errorMessage = 'Failed to add loyalty points: $e';
      return false;
    }
  }

  @action
  Future<void> redeemCustomerPoints(String customerId, int points) async {
    await _repository.redeemPoints(customerId, points);
    await loadCustomers();
  }

  @action
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      searchQuery = query;
      if (query.isEmpty) {
        searchResults.clear();
        return await _repository.getAllCustomers();
      }
      final results = await _repository.searchCustomers(query);
      searchResults.clear();
      searchResults.addAll(results);
      return results;
    } catch (e) {
      errorMessage = 'Failed to search customers: $e';
      return [];
    }
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void selectCustomer(Customer? customer) {
    selectedCustomer = customer;
  }

  @action
  void clearSelection() {
    selectedCustomer = null;
    searchResults.clear();
    searchQuery = '';
  }

  @action
  Future<void> clearAllCustomers() async {
    await _repository.clearAll();
    customers.clear();
    searchResults.clear();
    selectedCustomer = null;
  }

  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    return await _repository.getTopCustomers(limit: limit);
  }

  @action
  Future<void> updateCustomerGST(String customerId, String gstNumber) async {
    await _repository.updateGst(customerId, gstNumber);
    await loadCustomers();
  }

  @action
  Future<void> updateCustomerCredit(String customerId, double credit) async {
    await _repository.updateCredit(customerId, credit);
    await loadCustomers();
  }

  // ==================== CREDIT SYSTEM (retail only) ====================

  /// Update customer after a credit sale
  @action
  Future<void> updateAfterCreditSale(String customerId, double amount) async {
    await _repository.updateCredit(customerId, amount);
    await _repository.updatePurchaseAmount(customerId, amount);
    await _repository.incrementVisitCount(customerId);
    await loadCustomers();
  }

  /// Check if customer can make a credit purchase (within credit limit)
  Future<bool> canMakeCreditPurchase(String customerId, double amount) async {
    final customer = await _repository.getCustomerById(customerId);
    if (customer == null) return false;
    if (customer.creditLimit <= 0) return true;
    final newBalance = customer.creditBalance + amount;
    return newBalance <= customer.creditLimit;
  }

  /// Get available credit for a customer
  Future<double> getAvailableCredit(String customerId) async {
    final customer = await _repository.getCustomerById(customerId);
    if (customer == null) return 0;
    if (customer.creditLimit <= 0) return double.infinity;
    final available = customer.creditLimit - customer.creditBalance;
    return available > 0 ? available : 0;
  }

  /// Get customers with outstanding credit balance
  @action
  Future<List<Customer>> getCustomersWithCredit() async {
    return await _repository.getCustomersWithCredit();
  }

  /// Update credit limit for a customer
  @action
  Future<void> updateCreditLimit(String customerId, double creditLimit) async {
    await _repository.updateCreditLimit(customerId, creditLimit);
    await loadCustomers();
  }

  /// Reduce customer credit balance after payment
  @action
  Future<void> reduceCredit(String customerId, double amount) async {
    await _repository.updateCredit(customerId, -amount);
    await loadCustomers();
  }
}
