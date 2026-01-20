import 'package:mobx/mobx.dart';
import '../../../data/models/restaurant/db/customer_model_125.dart';
import '../../../data/repositories/restaurant/customer_repository.dart';

part 'customer_store.g.dart';

class CustomerStoreRes = _CustomerStore with _$CustomerStoreRes;

abstract class _CustomerStore with Store {
  final CustomerRepositoryRes _repository;

  _CustomerStore(this._repository);

  @observable
  ObservableList<RestaurantCustomer> customers = ObservableList<RestaurantCustomer>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String searchQuery = '';

  // Computed properties
  @computed
  List<RestaurantCustomer> get filteredCustomers {
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
  List<RestaurantCustomer> get topCustomersByPoints {
    final sorted = customers.toList();
    sorted.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
    return sorted.take(10).toList();
  }

  @computed
  List<RestaurantCustomer> get frequentCustomers {
    final sorted = customers.toList();
    sorted.sort((a, b) => b.totalVisites.compareTo(a.totalVisites));
    return sorted.take(10).toList();
  }

  // Actions
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
  Future<bool> addCustomer(RestaurantCustomer customer) async {
    try {
      await _repository.addCustomer(customer);
      customers.add(customer);
      return true;
    } catch (e) {
      errorMessage = 'Failed to add customer: $e';
      return false;
    }
  }

  @action
  Future<RestaurantCustomer?> getCustomerById(String customerId) async {
    try {
      return await _repository.getCustomerById(customerId);
    } catch (e) {
      errorMessage = 'Failed to get customer: $e';
      return null;
    }
  }

  @action
  Future<RestaurantCustomer?> getCustomerByPhone(String phone) async {
    try {
      return await _repository.getCustomerByPhone(phone);
    } catch (e) {
      errorMessage = 'Failed to get customer by phone: $e';
      return null;
    }
  }

  @action
  Future<bool> updateCustomer(RestaurantCustomer updatedCustomer) async {
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
  Future<List<RestaurantCustomer>> searchCustomers(String query) async {
    try {
      return await _repository.searchCustomers(query);
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
}