import 'package:mobx/mobx.dart';
import 'package:unipos/data/repositories/payment_method_repository.dart';
import 'package:unipos/models/payment_method.dart';
import 'package:uuid/uuid.dart';

part 'payment_method_store.g.dart';

class PaymentMethodStore = _PaymentMethodStore with _$PaymentMethodStore;

abstract class _PaymentMethodStore with Store {
  final PaymentMethodRepository _repository;

  _PaymentMethodStore(this._repository);

  @observable
  ObservableList<PaymentMethod> paymentMethods = ObservableList<PaymentMethod>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  List<PaymentMethod> get enabledMethods =>
      paymentMethods.where((method) => method.isEnabled).toList();

  @computed
  int get enabledCount => enabledMethods.length;

  /// Initialize repository and load payment methods
  @action
  Future<void> init() async {
    print('💳 PaymentMethodStore: init() called');
    isLoading = true;
    try {
      print('💳 PaymentMethodStore: Initializing repository...');
      await _repository.init();
      print('💳 PaymentMethodStore: Repository initialized');
      await loadPaymentMethods();
      print('💳 PaymentMethodStore: init() complete, loaded ${paymentMethods.length} methods');
    } catch (e) {
      print('❌ PaymentMethodStore: Error in init(): $e');
      errorMessage = 'Failed to initialize: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Load all payment methods from repository
  @action
  Future<void> loadPaymentMethods() async {
    print('💳 PaymentMethodStore: loadPaymentMethods() called');
    isLoading = true;
    errorMessage = null;
    try {
      final methods = _repository.getAll();
      print('💳 PaymentMethodStore: Got ${methods.length} methods from repository');
      paymentMethods.clear();
      paymentMethods.addAll(methods);
      print('💳 PaymentMethodStore: Observable list now has ${paymentMethods.length} methods');
    } catch (e) {
      print('❌ PaymentMethodStore: Error loading methods: $e');
      errorMessage = 'Failed to load payment methods: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Add a new payment method
  @action
  Future<void> addPaymentMethod({
    required String name,
    required String value,
    required String iconName,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final newMethod = PaymentMethod(
        id: const Uuid().v4(),
        name: name,
        value: value.toLowerCase().replaceAll(' ', '_'),
        iconName: iconName,
        isEnabled: true,
        sortOrder: paymentMethods.length + 1,
      );
      await _repository.add(newMethod);
      await loadPaymentMethods();
    } catch (e) {
      errorMessage = 'Failed to add payment method: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Toggle payment method enabled/disabled
  @action
  Future<void> togglePaymentMethod(String id) async {
    try {
      await _repository.toggleEnabled(id);
      await loadPaymentMethods();
    } catch (e) {
      errorMessage = 'Failed to toggle payment method: $e';
    }
  }

  /// Delete a payment method
  @action
  Future<void> deletePaymentMethod(String id) async {
    isLoading = true;
    errorMessage = null;
    try {
      await _repository.delete(id);
      await loadPaymentMethods();
    } catch (e) {
      errorMessage = 'Failed to delete payment method: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Update a payment method
  @action
  Future<void> updatePaymentMethod(PaymentMethod method) async {
    isLoading = true;
    errorMessage = null;
    try {
      await _repository.update(method);
      await loadPaymentMethods();
    } catch (e) {
      errorMessage = 'Failed to update payment method: $e';
    } finally {
      isLoading = false;
    }
  }

  /// Clear error message
  @action
  void clearError() {
    errorMessage = null;
  }
}