import 'package:hive/hive.dart';
import '../../models/retail/hive_model/customer_model_208.dart';

/// Repository layer for Customer data access
/// Handles all Hive database operations for customers
class CustomerRepository {
  late Box<CustomerModel> _customerBox;

  CustomerRepository() {
    _customerBox = Hive.box<CustomerModel>('customers');
  }

  /// Get all customers from Hive
  Future<List<CustomerModel>> getAllCustomers() async {
    return _customerBox.values.toList();
  }

  /// Get a customer by ID
  Future<CustomerModel?> getCustomerById(String customerId) async {
    return _customerBox.get(customerId);
  }

  /// Add a new customer to Hive
  Future<void> addCustomer(CustomerModel customer) async {
    await _customerBox.put(customer.customerId, customer);
  }

  /// Update an existing customer in Hive
  Future<void> updateCustomer(CustomerModel customer) async {
    await _customerBox.put(customer.customerId, customer);
  }

  /// Delete a customer
  Future<void> deleteCustomer(String customerId) async {
    await _customerBox.delete(customerId);
  }

  /// Search customers by name or phone
  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();

    return _customerBox.values.where((customer) {
      final nameMatch = customer.name.toLowerCase().contains(lowercaseQuery);
      final phoneMatch = customer.phone.contains(query);
      return nameMatch || phoneMatch;
    }).toList();
  }

  /// Find customer by exact phone number
  Future<CustomerModel?> findByPhone(String phone) async {
    try {
      return _customerBox.values.firstWhere(
        (customer) => customer.phone == phone,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if phone number already exists (for validation)
  Future<bool> phoneExists(String phone, {String? excludeCustomerId}) async {
    return _customerBox.values.any((customer) =>
        customer.phone == phone &&
        (excludeCustomerId == null || customer.customerId != excludeCustomerId));
  }

  /// Check if customer exists
  Future<bool> customerExists(String customerId) async {
    return _customerBox.containsKey(customerId);
  }

  /// Update customer's total purchase amount
  Future<void> updatePurchaseAmount(String customerId, double amount) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        totalPurchaseAmount: customer.totalPurchaseAmount + amount,
        lastVisited: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updated);
    }
  }

  // ---------------- LOYALTY POINTS ----------------
  Future<void> updatePoints(String customerId, int points) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        pointsBalance: customer.pointsBalance + points,
        totalPointEarned: customer.totalPointEarned + points,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updated);
    }
  }


  // Redeem Points
  Future<void>redeemPoints(String customerId, int points)async{
    final customer = await getCustomerById(customerId);
    if(customer != null && customer.pointsBalance >= points){
      final now = DateTime.now().toIso8601String();
      final updated = customer.copyWith(
        pointsBalance: customer.pointsBalance - points,
        totalPointRedeemed: customer.totalPointRedeemed + points,
        updatedAt:now,
      );
      await updateCustomer(updated);

    }
  }

  // ---------------- CREDIT SYSTEM ----------------
  /// Update customer's credit balance
  Future<void> updateCredit(String customerId, double credit) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        creditBalance: customer.creditBalance + credit,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updated);
    }
  }


  // Update Visit Count
  Future<void>incrementVisitCount(String customerId)async{
    final customer = await getCustomerById(customerId);
    if(customer != null){
      final now = DateTime.now().toIso8601String();
      final updated = customer.copyWith(
        visitCount: customer.visitCount + 1,
        lastVisited: now,
        updatedAt: now,
      );
      await updateCustomer(updated);
    }
  }

  /// Get top customers by purchase amount
  Future<List<CustomerModel>> getTopCustomers({int limit = 10}) async {
    final customers = _customerBox.values.toList();
    customers.sort((a, b) => b.totalPurchaseAmount.compareTo(a.totalPurchaseAmount));
    return customers.take(limit).toList();
  }

  // Update Gst
  Future<void> updateGst(String customerId, String gstNumber) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        gstNumber: gstNumber,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updated);
    }
  }

  /// Update credit limit
  Future<void> updateCreditLimit(String customerId, double creditLimit) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        creditLimit: creditLimit,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updated);
    }
  }

  /// Get customers with credit balance (debtors)
  Future<List<CustomerModel>> getCustomersWithCredit() async {
    return _customerBox.values
        .where((customer) => customer.creditBalance > 0)
        .toList()
      ..sort((a, b) => b.creditBalance.compareTo(a.creditBalance));
  }

  /// Clear all customers
  Future<void> clearAll() async {
    await _customerBox.clear();
  }

  /// Get total customer count
  int getCustomerCount() {
    return _customerBox.length;
  }
}