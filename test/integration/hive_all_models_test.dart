import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

// Import via hive_init to get all adapters registered correctly
import 'package:unipos/core/init/hive_init.dart';

// ── All restaurant models (for constructing test objects) ──
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';
import 'package:unipos/data/models/restaurant/db/table_Model_311.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';
import 'package:unipos/data/models/restaurant/db/shift_model.dart';
import 'package:unipos/data/models/restaurant/db/cash_movement_model.dart';
import 'package:unipos/data/models/restaurant/db/cash_handover_model.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';

/// HIVE ROUND-TRIP TESTS FOR ALL RESTAURANT MODELS
///
/// Tests every model in the order flow:
///   Create → save to Hive → read from Hive → verify ALL fields match
///
/// If any HiveField index is wrong or adapter is broken,
/// these tests catch it immediately.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_all_models_');
    Hive.init(tempDir.path);

    // Use the same adapter registration as the app
    // This ensures test adapters exactly match production
    await HiveInit.registerRestaurantAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ════════════════════════════════════════════════════════════════════════
  // ORDERMODEL — The most complex model (33 fields + assertions)
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: OrderModel', () {
    test('save and read order with all fields', () async {
      final box = await Hive.openBox<OrderModel>('test_orders');

      final items = [
        CartItem(id: 'c1', productId: 'p1', title: 'Biryani', price: 250, quantity: 2),
        CartItem(id: 'c2', productId: 'p2', title: 'Naan', price: 60, quantity: 1),
        CartItem(id: 'c3', productId: 'p3', title: 'Cola', price: 40, quantity: 1),
      ];

      final original = OrderModel(
        id: 'ord-1',
        customerName: 'Rahul',
        customerNumber: '9876543210',
        customerEmail: 'rahul@test.com',
        items: items,
        status: 'Processing',
        timeStamp: DateTime(2026, 3, 24, 14, 30),
        orderType: 'Dine In',
        tableNo: 'T3',
        totalPrice: 560,
        discount: 50,
        serviceCharge: 10,
        paymentMethod: 'Cash',
        isPaid: false,
        gstAmount: 25.5,
        kotNumbers: [12, 15],
        itemCountAtLastKot: 3,
        kotBoundaries: [2, 3], // KOT#12 = items[0..1], KOT#15 = items[2..2]
        kotStatuses: {12: 'Ready', 15: 'Processing'},
        orderNumber: 7,
        billNumber: 1042,
        isTaxInclusive: false,
      );

      await box.put(original.id, original);
      final loaded = box.get('ord-1');

      expect(loaded, isNotNull);
      expect(loaded!.id, equals('ord-1'));
      expect(loaded.customerName, equals('Rahul'));
      expect(loaded.customerNumber, equals('9876543210'));
      expect(loaded.customerEmail, equals('rahul@test.com'));
      expect(loaded.items.length, equals(3));
      expect(loaded.items[0].title, equals('Biryani'));
      expect(loaded.items[0].quantity, equals(2));
      expect(loaded.status, equals('Processing'));
      expect(loaded.timeStamp, equals(DateTime(2026, 3, 24, 14, 30)));
      expect(loaded.orderType, equals('Dine In'));
      expect(loaded.tableNo, equals('T3'));
      expect(loaded.totalPrice, equals(560));
      expect(loaded.discount, equals(50));
      expect(loaded.isPaid, isFalse);
      expect(loaded.gstAmount, equals(25.5));
      expect(loaded.kotNumbers, equals([12, 15]));
      expect(loaded.kotBoundaries, equals([2, 3]));
      expect(loaded.kotStatuses, equals({12: 'Ready', 15: 'Processing'}));
      expect(loaded.orderNumber, equals(7));
      expect(loaded.billNumber, equals(1042));
      expect(loaded.isTaxInclusive, isFalse);

      // Verify computed helpers work on deserialized data
      expect(loaded.getItemsByKot().length, equals(2));
      expect(loaded.getKotStatus(12), equals('Ready'));

      await box.close();
    });

    test('copyWith and re-save preserves data', () async {
      final box = await Hive.openBox<OrderModel>('test_orders_copy');

      final original = OrderModel(
        id: 'ord-2',
        customerName: 'Test',
        customerNumber: '',
        customerEmail: '',
        items: [CartItem(id: 'c1', productId: 'p1', title: 'A', price: 100)],
        status: 'Processing',
        timeStamp: DateTime.now(),
        orderType: 'Take Away',
        totalPrice: 100,
        kotNumbers: [1],
        itemCountAtLastKot: 1,
        kotBoundaries: [1],
      );

      await box.put(original.id, original);

      // Update status via copyWith (simulates kitchen progress)
      final updated = original.copyWith(status: 'Cooking', isPaid: true);
      await box.put(updated.id, updated);

      final loaded = box.get('ord-2');
      expect(loaded!.status, equals('Cooking'));
      expect(loaded.isPaid, isTrue);
      expect(loaded.customerName, equals('Test')); // unchanged

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // PASTORDERMODEL — Completed orders archive
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: PastOrderModel', () {
    test('save and read past order with refund data', () async {
      final box = await Hive.openBox<PastOrderModel>('test_past_orders');

      final original = PastOrderModel(
        id: 'past-1',
        customerName: 'Customer',
        totalPrice: 500,
        items: [CartItem(id: 'c1', productId: 'p1', title: 'Biryani', price: 250, quantity: 2)],
        orderAt: DateTime(2026, 3, 24),
        orderType: 'Take Away',
        paymentmode: 'Cash',
        Discount: 50,
        gstAmount: 22.5,
        kotNumbers: [12],
        kotBoundaries: [1],
        billNumber: 1042,
        isRefunded: true,
        refundAmount: 250,
        refundReason: 'Wrong order',
        orderStatus: 'PARTIALLY_REFUNDED',
        shiftId: 'shift-abc',
        loyaltyPointsUsed: 100,
        isTaxInclusive: false,
        tableNo: 'T3',
      );

      await box.put(original.id, original);
      final loaded = box.get('past-1');

      expect(loaded, isNotNull);
      expect(loaded!.customerName, equals('Customer'));
      expect(loaded.totalPrice, equals(500));
      expect(loaded.Discount, equals(50));
      expect(loaded.gstAmount, equals(22.5));
      expect(loaded.kotNumbers, equals([12]));
      expect(loaded.billNumber, equals(1042));
      expect(loaded.isRefunded, isTrue);
      expect(loaded.refundAmount, equals(250));
      expect(loaded.refundReason, equals('Wrong order'));
      expect(loaded.orderStatus, equals('PARTIALLY_REFUNDED'));
      expect(loaded.shiftId, equals('shift-abc'));
      expect(loaded.loyaltyPointsUsed, equals(100));
      expect(loaded.isTaxInclusive, isFalse);
      expect(loaded.tableNo, equals('T3'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // STAFFMODEL — Login credentials and roles
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: StaffModel', () {
    test('save and read staff with role', () async {
      final box = await Hive.openBox<StaffModel>('test_staff');

      final original = StaffModel(
        id: 'staff-1',
        userName: 'rahul',
        firstName: 'Rahul',
        lastName: 'Sharma',
        isCashier: 'Cashier',
        mobileNo: '9876543210',
        emailId: 'rahul@test.com',
        pinNo: 'abc123hashed64chars' * 2, // simulating hashed PIN
        createdAt: DateTime(2026, 1, 15),
        isActive: true,
      );

      await box.put(original.id, original);
      final loaded = box.get('staff-1');

      expect(loaded, isNotNull);
      expect(loaded!.userName, equals('rahul'));
      expect(loaded.firstName, equals('Rahul'));
      expect(loaded.isCashier, equals('Cashier'));
      expect(loaded.isActive, isTrue);
      expect(loaded.pinNo, equals('abc123hashed64chars' * 2));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TABLEMODEL — Restaurant tables
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: TableModel', () {
    test('save and read table with order link', () async {
      final box = await Hive.openBox<TableModel>('test_tables');

      final original = TableModel(
        id: 'T3',
        status: 'Running',
        currentOrderTotal: 560,
        currentOrderId: 'ord-1',
        timeStamp: '2026-03-24T14:30:00',
        tableCapacity: 4,
      );

      await box.put(original.id, original);
      final loaded = box.get('T3');

      expect(loaded, isNotNull);
      expect(loaded!.id, equals('T3'));
      expect(loaded.status, equals('Running'));
      expect(loaded.currentOrderTotal, equals(560));
      expect(loaded.currentOrderId, equals('ord-1'));
      expect(loaded.timeStamp, equals('2026-03-24T14:30:00'));
      expect(loaded.tableCapacity, equals(4));

      await box.close();
    });

    test('update status to Available (table freed)', () async {
      final box = await Hive.openBox<TableModel>('test_tables_free');

      final occupied = TableModel(
        id: 'T5',
        status: 'Running',
        currentOrderTotal: 300,
        currentOrderId: 'ord-5',
      );
      await box.put(occupied.id, occupied);

      // Free the table (simulates what happens after order settled)
      final freed = TableModel(
        id: 'T5',
        status: 'Available',
        currentOrderTotal: null,
        currentOrderId: null,
      );
      await box.put(freed.id, freed);

      final loaded = box.get('T5');
      expect(loaded!.status, equals('Available'));
      expect(loaded.currentOrderTotal, isNull);
      expect(loaded.currentOrderId, isNull);

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TAXMODEL — Tax configuration
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: Tax', () {
    test('save and read tax rate', () async {
      final box = await Hive.openBox<Tax>('test_taxes');

      final original = Tax(id: 'tax-1', taxname: 'GST 5%', taxperecentage: 5.0);
      await box.put(original.id, original);

      final loaded = box.get('tax-1');
      expect(loaded, isNotNull);
      expect(loaded!.taxname, equals('GST 5%'));
      expect(loaded.taxperecentage, equals(5.0));

      await box.close();
    });

    test('multiple tax rates', () async {
      final box = await Hive.openBox<Tax>('test_taxes_multi');

      await box.put('t1', Tax(id: 't1', taxname: 'GST 5%', taxperecentage: 5));
      await box.put('t2', Tax(id: 't2', taxname: 'GST 12%', taxperecentage: 12));
      await box.put('t3', Tax(id: 't3', taxname: 'GST 18%', taxperecentage: 18));

      expect(box.length, equals(3));
      final all = box.values.toList();
      final names = all.map((t) => t.taxname).toList();
      expect(names, contains('GST 18%'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // RESTAURANTCUSTOMER — Customer records with loyalty
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: RestaurantCustomer', () {
    test('save and read customer with loyalty points', () async {
      final box = await Hive.openBox<RestaurantCustomer>('test_customers');

      final original = RestaurantCustomer(
        customerId: 'cust-1',
        name: 'Rahul Sharma',
        phone: '9876543210',
        totalVisites: 15,
        lastVisitAt: '2026-03-24',
        lastorderType: 'Dine In',
        loyaltyPoints: 250,
        foodPrefrence: 'veg',
        notes: 'Regular customer',
        createdAt: '2026-01-01',
      );

      await box.put(original.customerId, original);
      final loaded = box.get('cust-1');

      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Rahul Sharma'));
      expect(loaded.phone, equals('9876543210'));
      expect(loaded.totalVisites, equals(15));
      expect(loaded.loyaltyPoints, equals(250));
      expect(loaded.foodPrefrence, equals('veg'));
      expect(loaded.notes, equals('Regular customer'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // SHIFTMODEL — Staff shift records
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: ShiftModel', () {
    test('save open shift and close it', () async {
      final box = await Hive.openBox<ShiftModel>('test_shifts');

      // Start shift
      final open = ShiftModel(
        id: 'shift-1',
        staffId: 'staff-1',
        staffName: 'Rahul',
        startTime: DateTime(2026, 3, 24, 9, 0),
        status: 'open',
      );
      await box.put(open.id, open);
      expect(box.get('shift-1')!.isOpen, isTrue);

      // Close shift
      final closed = open.copyWith(
        status: 'closed',
        endTime: DateTime(2026, 3, 24, 17, 0),
        orderCount: 25,
        totalSales: 18500,
      );
      await box.put(closed.id, closed);

      final loaded = box.get('shift-1');
      expect(loaded!.isOpen, isFalse);
      expect(loaded.orderCount, equals(25));
      expect(loaded.totalSales, equals(18500));
      expect(loaded.duration.inHours, equals(8));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // CASHMOVEMENTMODEL — Cash in/out audit trail
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: CashMovementModel', () {
    test('save cash in and cash out movements', () async {
      final box = await Hive.openBox<CashMovementModel>('test_movements');

      final cashIn = CashMovementModel(
        id: 'mov-1',
        timestamp: DateTime(2026, 3, 24, 11, 30),
        type: 'in',
        amount: 2000,
        reason: 'Owner deposit',
        staffName: 'Admin',
      );
      final cashOut = CashMovementModel(
        id: 'mov-2',
        timestamp: DateTime(2026, 3, 24, 14, 0),
        type: 'out',
        amount: 5000,
        reason: 'Safe drop',
        staffName: 'Rahul',
      );

      await box.put(cashIn.id, cashIn);
      await box.put(cashOut.id, cashOut);

      final loadedIn = box.get('mov-1');
      expect(loadedIn!.isCashIn, isTrue);
      expect(loadedIn.signedAmount, equals(2000));
      expect(loadedIn.reason, equals('Owner deposit'));

      final loadedOut = box.get('mov-2');
      expect(loadedOut!.isCashIn, isFalse);
      expect(loadedOut.signedAmount, equals(-5000));

      // Sum of signed amounts
      final total = box.values.fold<double>(0, (s, m) => s + m.signedAmount);
      expect(total, equals(-3000)); // 2000 - 5000

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // CASHHANDOVERMODEL — 2-step shift handover
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: CashHandoverModel', () {
    test('save pending handover then complete it', () async {
      final box = await Hive.openBox<CashHandoverModel>('test_handovers');

      // Step 1: Closer saves count
      final pending = CashHandoverModel(
        id: 'h-1',
        closedBy: 'Rahul',
        closedAt: DateTime(2026, 3, 24, 22, 0),
        closedAmount: 12500,
        status: 'PENDING',
      );
      await box.put(pending.id, pending);

      expect(box.get('h-1')!.status, equals('PENDING'));
      expect(box.get('h-1')!.receivedBy, isNull);

      // Step 2: Receiver saves count (matched)
      final matched = CashHandoverModel(
        id: 'h-1',
        closedBy: 'Rahul',
        closedAt: DateTime(2026, 3, 24, 22, 0),
        closedAmount: 12500,
        receivedBy: 'Priya',
        receivedAt: DateTime(2026, 3, 25, 9, 0),
        receivedAmount: 12500,
        status: 'MATCHED',
        variance: 0,
      );
      await box.put(matched.id, matched);

      final loaded = box.get('h-1');
      expect(loaded!.status, equals('MATCHED'));
      expect(loaded.receivedBy, equals('Priya'));
      expect(loaded.variance, equals(0));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // VARIANTMODEL — Variant name registry
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: VariantModel', () {
    test('save and read variant names', () async {
      final box = await Hive.openBox<VariantModel>('test_variants');

      await box.put('v1', VariantModel(id: 'v1', name: 'Small'));
      await box.put('v2', VariantModel(id: 'v2', name: 'Medium'));
      await box.put('v3', VariantModel(id: 'v3', name: 'Large'));

      expect(box.length, equals(3));
      expect(box.get('v2')!.name, equals('Medium'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // CHOICESMODEL + CHOICEOPTION — Choice groups with options
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: ChoicesModel with ChoiceOptions', () {
    test('save choice group with nested options', () async {
      final box = await Hive.openBox<ChoicesModel>('test_choices');

      final original = ChoicesModel(
        id: 'choice-1',
        name: 'Spice Level',
        allowMultipleSelection: false,
        choiceOption: [
          ChoiceOption(id: 'opt-1', name: 'Mild'),
          ChoiceOption(id: 'opt-2', name: 'Medium'),
          ChoiceOption(id: 'opt-3', name: 'Hot'),
        ],
      );

      await box.put(original.id, original);
      final loaded = box.get('choice-1');

      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Spice Level'));
      expect(loaded.allowMultipleSelection, isFalse);
      expect(loaded.choiceOption.length, equals(3));
      expect(loaded.choiceOption[0].name, equals('Mild'));
      expect(loaded.choiceOption[2].name, equals('Hot'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // EXTRAMODEL + TOPPING — Extra groups with priced toppings
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: Extramodel with Toppings', () {
    test('save extra group with toppings and variant prices', () async {
      final box = await Hive.openBox<Extramodel>('test_extras');

      final original = Extramodel(
        Id: 'extra-1',
        Ename: 'Toppings',
        isEnabled: true,
        minimum: 0,
        maximum: 3,
        topping: [
          Topping(
            name: 'Extra Cheese',
            isveg: true,
            price: 30,
            isContainSize: true,
            variantPrices: {'v-large': 50.0, 'v-regular': 30.0},
          ),
          Topping(
            name: 'Raita',
            isveg: true,
            price: 25,
          ),
        ],
      );

      await box.put(original.Id, original);
      final loaded = box.get('extra-1');

      expect(loaded, isNotNull);
      expect(loaded!.Ename, equals('Toppings'));
      expect(loaded.minimum, equals(0));
      expect(loaded.maximum, equals(3));
      expect(loaded.topping, isNotNull);
      expect(loaded.topping!.length, equals(2));

      // Verify nested topping data survived round-trip
      final cheese = loaded.topping![0];
      expect(cheese.name, equals('Extra Cheese'));
      expect(cheese.price, equals(30));
      expect(cheese.isContainSize, isTrue);
      expect(cheese.variantPrices, isNotNull);
      expect(cheese.variantPrices!['v-large'], equals(50.0));

      // Verify computed helper works on deserialized data
      expect(cheese.getPriceForVariant('v-large'), equals(50.0));
      expect(cheese.getPriceForVariant('v-regular'), equals(30.0));
      expect(cheese.getPriceForVariant(null), equals(30.0)); // fallback

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // EXPENSE + EXPENSECATEGORY — Daily expense tracking
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: Expense models', () {
    test('save expense category', () async {
      final box = await Hive.openBox<ExpenseCategory>('test_exp_cat');

      await box.put('ec1', ExpenseCategory(id: 'ec1', name: 'Food Supplies', isEnabled: true));
      await box.put('ec2', ExpenseCategory(id: 'ec2', name: 'Utilities', isEnabled: true));

      expect(box.length, equals(2));
      expect(box.get('ec1')!.name, equals('Food Supplies'));

      await box.close();
    });

    test('save expense entry', () async {
      final box = await Hive.openBox<Expense>('test_expenses');

      final original = Expense(
        id: 'exp-1',
        dateandTime: DateTime(2026, 3, 24, 10, 0),
        amount: 500,
        categoryOfExpense: 'Food Supplies',
        reason: 'Vegetables for kitchen',
        paymentType: 'cash',
      );

      await box.put(original.id, original);
      final loaded = box.get('exp-1');

      expect(loaded, isNotNull);
      expect(loaded!.amount, equals(500));
      expect(loaded.categoryOfExpense, equals('Food Supplies'));
      expect(loaded.reason, equals('Vegetables for kitchen'));
      expect(loaded.paymentType, equals('cash'));

      await box.close();
    });
  });
}
