import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/customer_model_125.dart';

/// Repository layer for Customer data access (Restaurant)
/// Handles all Hive database operations for customers
class CustomerRepositoryRes {
  late Box<RestaurantCustomer> _customerBox;

  CustomerRepositoryRes() {
    _customerBox = Hive.box<RestaurantCustomer>(HiveBoxNames.restaurantCustomer);
  }

  /// Add a new customer
  Future<void> addCustomer(RestaurantCustomer customer) async {
    await _customerBox.put(customer.customerId, customer);
  }

  /// Get all customers
  Future<List<RestaurantCustomer>> getAllCustomers() async {
    return _customerBox.values.toList();
  }

  /// Get customer by ID
  Future<RestaurantCustomer?> getCustomerById(String customerId) async {
    return _customerBox.get(customerId);
  }

  /// Get customer by phone
  Future<RestaurantCustomer?> getCustomerByPhone(String phone) async {
    try {
      return _customerBox.values.firstWhere(
        (customer) => customer.phone == phone,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update customer
  Future<void> updateCustomer(RestaurantCustomer customer) async {
    await _customerBox.put(customer.customerId, customer);
  }

  /// Delete customer
  Future<void> deleteCustomer(String customerId) async {
    await _customerBox.delete(customerId);
  }

  /// Search customers by name or phone
  Future<List<RestaurantCustomer>> searchCustomers(String query) async {
    if (query.isEmpty) return getAllCustomers();

    final lowerQuery = query.toLowerCase();
    return _customerBox.values.where((customer) {
      final name = customer.name?.toLowerCase() ?? '';
      final phone = customer.phone?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || phone.contains(lowerQuery);
    }).toList();
  }

  /// Get top customers by loyalty points
  Future<List<RestaurantCustomer>> getTopCustomersByPoints({int limit = 10}) async {
    final customers = _customerBox.values.toList();
    customers.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
    return customers.take(limit).toList();
  }

  /// Get frequent customers by visit count
  Future<List<RestaurantCustomer>> getFrequentCustomers({int limit = 10}) async {
    final customers = _customerBox.values.toList();
    customers.sort((a, b) => b.totalVisites.compareTo(a.totalVisites));
    return customers.take(limit).toList();
  }

  /// Update customer visit
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
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updatedCustomer);
    }
  }

  /// Add loyalty points
  Future<void> addLoyaltyPoints(String customerId, int points) async {
    final customer = _customerBox.get(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        loyaltyPoints: customer.loyaltyPoints + points,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _customerBox.put(customerId, updatedCustomer);
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
}