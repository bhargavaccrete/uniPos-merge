import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../customer_model_125.dart';

class HiveCustomer {
  static const _boxName = HiveBoxNames.restaurantCustomer;

  /// Get the customer box (already opened in main.dart)
  static Box<RestaurantCustomer> getCustomerBox() {
    return Hive.box<RestaurantCustomer>(_boxName);
  }

  /// Add a new customer
  static Future<void> addCustomer(RestaurantCustomer customer) async {
    final box = getCustomerBox();
    await box.put(customer.customerId, customer);
  }

  /// Update an existing customer
  static Future<void> updateCustomer(RestaurantCustomer customer) async {
    final box = getCustomerBox();
    await box.put(customer.customerId, customer);
  }

  /// Delete a customer
  static Future<void> deleteCustomer(String customerId) async {
    final box = getCustomerBox();
    await box.delete(customerId);
  }

  /// Get all customers
  static List<RestaurantCustomer> getAllCustomers() {
    final box = getCustomerBox();
    return box.values.toList();
  }

  /// Get customer by ID
  static RestaurantCustomer? getCustomerById(String customerId) {
    final box = getCustomerBox();
    return box.get(customerId);
  }

  /// Search customers by name or phone
  static List<RestaurantCustomer> searchCustomers(String query) {
    final box = getCustomerBox();
    final lowerQuery = query.toLowerCase();

    return box.values.where((customer) {
      final name = customer.name?.toLowerCase() ?? '';
      final phone = customer.phone?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || phone.contains(lowerQuery);
    }).toList();
  }

  /// Get customers sorted by loyalty points (descending)
  static List<RestaurantCustomer> getTopCustomersByPoints({int limit = 10}) {
    final box = getCustomerBox();
    final customers = box.values.toList();
    customers.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
    return customers.take(limit).toList();
  }

  /// Get customers sorted by visit count (descending)
  static List<RestaurantCustomer> getFrequentCustomers({int limit = 10}) {
    final box = getCustomerBox();
    final customers = box.values.toList();
    customers.sort((a, b) => b.totalVisites.compareTo(a.totalVisites));
    return customers.take(limit).toList();
  }

  /// Get customer by phone number
  static RestaurantCustomer? getCustomerByPhone(String phone) {
    final box = getCustomerBox();
    try {
      return box.values.firstWhere(
        (customer) => customer.phone == phone,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update customer visit
  static Future<void> updateCustomerVisit({
    required String customerId,
    required String orderType,
    int pointsToAdd = 0,
  }) async {
    final customer = getCustomerById(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        totalVisites: customer.totalVisites + 1,
        lastVisitAt: DateTime.now().toIso8601String(),
        lastorderType: orderType,
        loyaltyPoints: customer.loyaltyPoints + pointsToAdd,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updatedCustomer);
    }
  }

  /// Add loyalty points to customer
  static Future<void> addLoyaltyPoints(String customerId, int points) async {
    final customer = getCustomerById(customerId);
    if (customer != null) {
      final updatedCustomer = customer.copyWith(
        loyaltyPoints: customer.loyaltyPoints + points,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await updateCustomer(updatedCustomer);
    }
  }

  /// Get total number of customers
  static int getCustomerCount() {
    final box = getCustomerBox();
    return box.length;
  }
}
