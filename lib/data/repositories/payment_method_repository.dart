import 'package:hive/hive.dart';
import 'package:unipos/models/payment_method.dart';
import 'package:uuid/uuid.dart';

class PaymentMethodRepository {
  static const String _boxName = 'paymentMethodsBox';
  Box<PaymentMethod>? _box;

  Future<void> init() async {
    print('🗄️  PaymentMethodRepository: init() called');
    if (!Hive.isBoxOpen(_boxName)) {
      print('🗄️  PaymentMethodRepository: Opening box $_boxName');
      _box = await Hive.openBox<PaymentMethod>(_boxName);
      print('🗄️  PaymentMethodRepository: Box opened successfully');
    } else {
      print('🗄️  PaymentMethodRepository: Box already open');
      _box = Hive.box<PaymentMethod>(_boxName);
    }

    print('🗄️  PaymentMethodRepository: Box has ${_box!.length} items');

    // Initialize with default payment methods if box is empty
    if (_box!.isEmpty) {
      print('🗄️  PaymentMethodRepository: Box is empty, initializing default methods');
      await _initializeDefaultMethods();
      print('🗄️  PaymentMethodRepository: Default methods created, box now has ${_box!.length} items');
    } else {
      print('🗄️  PaymentMethodRepository: Box already has data, skipping initialization');
    }
  }

  /// Initialize default payment methods
  Future<void> _initializeDefaultMethods() async {
    print('🗄️  PaymentMethodRepository: Creating 6 default payment methods...');
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
      print('🗄️  PaymentMethodRepository: Adding ${method.name}...');
      await _box!.add(method);
    }
    print('🗄️  PaymentMethodRepository: All default methods added');
  }

  /// Get all payment methods
  List<PaymentMethod> getAll() {
    // Try to get the box if not already set
    if (_box == null || !_box!.isOpen) {
      print('🗄️  PaymentMethodRepository.getAll(): Box not initialized, attempting to get it');
      if (Hive.isBoxOpen(_boxName)) {
        print('🗄️  PaymentMethodRepository.getAll(): Box is open in Hive, getting reference');
        _box = Hive.box<PaymentMethod>(_boxName);
      } else {
        print('⚠️  PaymentMethodRepository.getAll(): Box is not open in Hive, returning empty list');
        return [];
      }
    }
    final items = _box!.values.toList();
    print('🗄️  PaymentMethodRepository.getAll(): Returning ${items.length} items');
    return items..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Get only enabled payment methods
  List<PaymentMethod> getEnabled() {
    return getAll().where((method) => method.isEnabled).toList();
  }

  /// Ensure box is initialized
  void _ensureBox() {
    if (_box == null || !_box!.isOpen) {
      if (Hive.isBoxOpen(_boxName)) {
        _box = Hive.box<PaymentMethod>(_boxName);
      } else {
        throw Exception('Payment methods box is not open. Call init() first.');
      }
    }
  }

  /// Add a new payment method
  Future<void> add(PaymentMethod method) async {
    _ensureBox();
    await _box!.add(method);
  }

  /// Update an existing payment method
  Future<void> update(PaymentMethod method) async {
    _ensureBox();
    final index = _box!.values.toList().indexWhere((m) => m.id == method.id);
    if (index != -1) {
      await _box!.putAt(index, method);
    }
  }

  /// Delete a payment method
  Future<void> delete(String id) async {
    _ensureBox();
    final index = _box!.values.toList().indexWhere((m) => m.id == id);
    if (index != -1) {
      await _box!.deleteAt(index);
    }
  }

  /// Toggle payment method enabled status
  Future<void> toggleEnabled(String id) async {
    _ensureBox();
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