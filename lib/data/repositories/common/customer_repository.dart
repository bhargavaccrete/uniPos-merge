import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/common/customer_model_125.dart';

/// Repository layer for Customer data access.
///
/// Shared between Restaurant and Retail — both business modes use the same
/// `Customer` model AND the same physical box. A device only ever runs one
/// business mode for its whole lifetime, so there's never a moment where
/// restaurant and retail customers would need to be told apart in storage.
class CustomerRepository {
  late Box<Customer> _customerBox;

  CustomerRepository() {
    _customerBox = Hive.box<Customer>(HiveBoxNames.customer);
  }

  /// Add a new customer
  Future<void> addCustomer(Customer customer) async {
    await _customerBox.put(customer.customerId, customer);
  }

  /// Get all customers from Hive
  Future<List<Customer>> getAllCustomers() async {
    return _customerBox.values.toList();
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String customerId) async {
    return _customerBox.get(customerId);
  }

  /// Get customer by phone (exact match)
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      return _customerBox.values.firstWhere(
        (customer) => customer.phone == phone,
      );
    } catch (e) {
      return null;
    }
  }

  /// Alias for getCustomerByPhone (retail's original method name)
  Future<Customer?> findByPhone(String phone) => getCustomerByPhone(phone);

  /// Check if phone number already exists (for validation)
  Future<bool> phoneExists(String phone, {String? excludeCustomerId}) async {
    return _customerBox.values.any((customer) =>
        customer.phone == phone &&
        (excludeCustomerId == null || customer.customerId != excludeCustomerId));
  }

  /// Update customer
  Future<void> updateCustomer(Customer customer) async {
    await _customerBox.put(customer.customerId, customer);
  }

  /// Delete customer
  Future<void> deleteCustomer(String customerId) async {
    await _customerBox.delete(customerId);
  }

  /// Search customers by name or phone. Empty query returns all customers.
  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return getAllCustomers();

    final lowerQuery = query.toLowerCase();
    return _customerBox.values.where((customer) {
      final name = customer.name?.toLowerCase() ?? '';
      final phone = customer.phone?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || phone.contains(lowerQuery);
    }).toList();
  }

  /// Get top customers by loyalty points
  Future<List<Customer>> getTopCustomersByPoints({int limit = 10}) async {
    final customers = _customerBox.values.toList();
    customers.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
    return customers.take(limit).toList();
  }

  /// Get frequent customers by visit count
  Future<List<Customer>> getFrequentCustomers({int limit = 10}) async {
    final customers = _customerBox.values.toList();
    customers.sort((a, b) => b.totalVisites.compareTo(a.totalVisites));
    return customers.take(limit).toList();
  }

  /// Get top customers by total purchase amount (retail)
  Future<List<Customer>> getTopCustomers({int limit = 10}) async {
    final customers = _customerBox.values.toList();
    customers.sort((a, b) => b.totalPurchaseAmount.compareTo(a.totalPurchaseAmount));
    return customers.take(limit).toList();
  }

  /// Update customer visit (restaurant — also records order type)
  Future<void> updateCustomerVisit({
    required String customerId,
    required String orderType,
    int pointsToAdd = 0,
  }) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        totalVisites: customer.totalVisites + 1,
        lastVisitAt: DateTime.now().toIso8601String(),
        lastorderType: orderType,
        loyaltyPoints: customer.loyaltyPoints + pointsToAdd,
        totalPointEarned: customer.totalPointEarned + (pointsToAdd > 0 ? pointsToAdd : 0),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updatedCustomer);
    }
  }

  /// Increment visit count (retail — no order type/points involved)
  Future<void> incrementVisitCount(String customerId) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final now = DateTime.now().toIso8601String();
      final updated = customer.copyWith(
        totalVisites: customer.totalVisites + 1,
        lastVisitAt: now,
        updatedAt: now,
      );
      await _customerBox.put(customerId, updated);
    }
  }

  /// Update customer's total purchase amount (retail)
  Future<void> updatePurchaseAmount(String customerId, double amount) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        totalPurchaseAmount: customer.totalPurchaseAmount + amount,
        lastVisitAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updated);
    }
  }

  /// Add loyalty points — increases both current balance and lifetime earned.
  Future<void> addLoyaltyPoints(String customerId, int points) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        loyaltyPoints: customer.loyaltyPoints + points,
        totalPointEarned: customer.totalPointEarned + points,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updatedCustomer);
    }
  }

  /// Alias for addLoyaltyPoints (retail's original method name)
  Future<void> updatePoints(String customerId, int points) => addLoyaltyPoints(customerId, points);

  /// Redeem loyalty points — guarded against redeeming more than the balance.
  Future<void> redeemPoints(String customerId, int points) async {
    final customer = _customerBox.get(customerId);
    if (customer != null && customer.loyaltyPoints >= points) {
      final now = DateTime.now().toIso8601String();
      final updated = customer.copyWith(
        loyaltyPoints: customer.loyaltyPoints - points,
        totalPointRedeemed: customer.totalPointRedeemed + points,
        updatedAt: now,
      );
      await _customerBox.put(customerId, updated);
    }
  }

  // ---------------- CREDIT SYSTEM (retail only — restaurant has no credit) ----------------

  /// Update customer's credit balance (positive to add debt, negative to reduce)
  Future<void> updateCredit(String customerId, double credit) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        creditBalance: customer.creditBalance + credit,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updated);
    }
  }

  /// Update credit limit
  Future<void> updateCreditLimit(String customerId, double creditLimit) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        creditLimit: creditLimit,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updated);
    }
  }

  /// Get customers with outstanding credit balance (debtors), sorted desc
  Future<List<Customer>> getCustomersWithCredit() async {
    return _customerBox.values
        .where((customer) => customer.creditBalance > 0)
        .toList()
      // Largest debt first, then the customer id. A balance is not a total
      // order and `List.sort` is not stable, so customers owing the same
      // amount reordered between loads.
      ..sort((a, b) {
        final byBalance = b.creditBalance.compareTo(a.creditBalance);
        if (byBalance != 0) return byBalance;
        return a.customerId.compareTo(b.customerId);
      });
  }

  /// Update GST number
  Future<void> updateGst(String customerId, String gstNumber) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updated = customer.copyWith(
        gstNumber: gstNumber,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updated);
    }
  }

  /// Get customer count
  Future<int> getCustomerCount() async {
    return _customerBox.length;
  }

  /// Check if customer exists
  Future<bool> customerExists(String customerId) async {
    return _customerBox.containsKey(customerId);
  }

  /// Clear all customers
  Future<void> clearAll() async {
    await _customerBox.clear();
  }
}
