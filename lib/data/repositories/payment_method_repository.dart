import 'package:hive/hive.dart';
import 'package:unipos/models/payment_method.dart';
import 'package:uuid/uuid.dart';

class PaymentMethodRepository {
  static const String _boxName = 'paymentMethodsBox';
  Box<PaymentMethod>? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<PaymentMethod>(_boxName);
    } else {
      _box = Hive.box<PaymentMethod>(_boxName);
    }

    // Initialize with default payment methods if box is empty
    if (_box!.isEmpty) {
      await _initializeDefaultMethods();
    }
  }

  /// Initialize default payment methods
  Future<void> _initializeDefaultMethods() async {
    final defaultMethods = [
      PaymentMethod(
        id: const Uuid().v4(),
        name: 'Cash',
        value: 'cash',
        iconName: 'money',
        isEnabled: true,
        sortOrder: 1,
      ),
      PaymentMethod(
        id: const Uuid().v4(),
        name: 'Card',
        value: 'card',
        iconName: 'credit_card',
        isEnabled: true,
        sortOrder: 2,
      ),
      PaymentMethod(
        id: const Uuid().v4(),
        name: 'UPI',
        value: 'upi',
        iconName: 'qr_code_2',
        isEnabled: true,
        sortOrder: 3,
      ),
      PaymentMethod(
        id: const Uuid().v4(),
        name: 'Wallet',
        value: 'wallet',
        iconName: 'account_balance_wallet',
        isEnabled: false,
        sortOrder: 4,
      ),
      PaymentMethod(
        id: const Uuid().v4(),
        name: 'Credit',
        value: 'credit',
        iconName: 'receipt_long',
        isEnabled: false,
        sortOrder: 5,
      ),
      PaymentMethod(
        id: const Uuid().v4(),
        name: 'Other',
        value: 'other',
        iconName: 'more_horiz',
        isEnabled: false,
        sortOrder: 6,
      ),
    ];

    for (var method in defaultMethods) {
      await _box!.add(method);
    }
  }

  /// Get all payment methods
  List<PaymentMethod> getAll() {
    if (_box == null || !_box!.isOpen) {
      return [];
    }
    return _box!.values.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get only enabled payment methods
  List<PaymentMethod> getEnabled() {
    return getAll().where((method) => method.isEnabled).toList();
  }

  /// Add a new payment method
  Future<void> add(PaymentMethod method) async {
    await _box!.add(method);
  }

  /// Update an existing payment method
  Future<void> update(PaymentMethod method) async {
    final index = _box!.values.toList().indexWhere((m) => m.id == method.id);
    if (index != -1) {
      await _box!.putAt(index, method);
    }
  }

  /// Delete a payment method
  Future<void> delete(String id) async {
    final index = _box!.values.toList().indexWhere((m) => m.id == id);
    if (index != -1) {
      await _box!.deleteAt(index);
    }
  }

  /// Toggle payment method enabled status
  Future<void> toggleEnabled(String id) async {
    final methods = _box!.values.toList();
    final index = methods.indexWhere((m) => m.id == id);
    if (index != -1) {
      final method = methods[index];
      final updated = method.copyWith(isEnabled: !method.isEnabled);
      await _box!.putAt(index, updated);
    }
  }

  /// Clear all payment methods
  Future<void> clearAll() async {
    await _box!.clear();
  }
}