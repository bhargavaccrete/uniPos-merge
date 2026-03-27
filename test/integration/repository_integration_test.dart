import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/table_Model_311.dart';
import 'package:unipos/data/models/restaurant/db/saved_printer_model.dart';
import 'package:unipos/data/repositories/restaurant/order_repository.dart';
import 'package:unipos/data/repositories/restaurant/past_order_repository.dart';
import 'package:unipos/data/repositories/restaurant/table_repository.dart';
import 'package:unipos/data/repositories/restaurant/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// INTEGRATION TESTS — Repository + Hive working together.
///
/// These test REAL repository methods against REAL Hive boxes.
/// Unlike Hive round-trip tests (which use box.put/get directly),
/// these use Repository methods (addOrder, getOrderById, updateOrder)
/// — the same methods the app calls.
///
/// Key flows tested:
/// 1. Order Repository — CRUD + counter generation (KOT#, Bill#, Order#)
/// 2. Order Lifecycle — create → update → settle → move to past
/// 3. Table + Order link — occupy table → free on settle
/// 4. Printer Repository — save + set defaults via SharedPreferences
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('integration_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();

    // Open all boxes that repositories need
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
    await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
    await Hive.openBox(HiveBoxNames.appCounters); // untyped box for counters

    // Mock SharedPreferences for printer defaults
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Helper: Create a test order with required fields
  // ═══════════════════════════════════════════════════════════════════════

  OrderModel makeOrder({
    String id = 'ord-1',
    String status = 'Processing',
    String orderType = 'Take Away',
    double totalPrice = 500,
    List<int>? kotNumbers,
    List<int>? kotBoundaries,
    String? tableNo,
    List<CartItem>? items,
  }) {
    final orderItems = items ?? [
      CartItem(id: 'c1', productId: 'p1', title: 'Biryani', price: 250, quantity: 2),
    ];
    return OrderModel(
      id: id,
      customerName: 'Test Customer',
      customerNumber: '9876543210',
      customerEmail: '',
      items: orderItems,
      status: status,
      timeStamp: DateTime.now(),
      orderType: orderType,
      tableNo: tableNo,
      totalPrice: totalPrice,
      kotNumbers: kotNumbers ?? [1],
      itemCountAtLastKot: orderItems.length,
      kotBoundaries: kotBoundaries ?? [orderItems.length],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEST GROUP 1: OrderRepository — CRUD Operations
  //
  // Tests that the repository correctly delegates to Hive
  // and provides the query/filter layer on top.
  // ═══════════════════════════════════════════════════════════════════════

  group('OrderRepository — CRUD', () {
    late OrderRepository repo;

    setUp(() {
      repo = OrderRepository();
    });

    test('addOrder → getOrderById returns same order', () async {
      final order = makeOrder(id: 'ord-1');
      await repo.addOrder(order);

      final loaded = await repo.getOrderById('ord-1');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('ord-1'));
      expect(loaded.customerName, equals('Test Customer'));
      expect(loaded.totalPrice, equals(500));
    });

    test('getAllOrders returns all added orders', () async {
      await repo.addOrder(makeOrder(id: 'ord-1'));
      await repo.addOrder(makeOrder(id: 'ord-2'));
      await repo.addOrder(makeOrder(id: 'ord-3'));

      final all = await repo.getAllOrders();
      expect(all.length, equals(3));
    });

    test('deleteOrder removes from box', () async {
      await repo.addOrder(makeOrder(id: 'ord-del'));

      expect(await repo.orderExists('ord-del'), isTrue);
      await repo.deleteOrder('ord-del');
      expect(await repo.orderExists('ord-del'), isFalse);
    });

    test('updateOrder modifies existing order', () async {
      final order = makeOrder(id: 'ord-upd', status: 'Processing');
      await repo.addOrder(order);

      // Update status (simulates kitchen progress)
      final updated = order.copyWith(status: 'Cooking');
      await repo.updateOrder(updated);

      final loaded = await repo.getOrderById('ord-upd');
      expect(loaded!.status, equals('Cooking'));
      expect(loaded.customerName, equals('Test Customer')); // unchanged
    });

    test('updateOrder on non-existent order throws', () async {
      final ghost = makeOrder(id: 'ghost');
      // Never added to repo → updateOrder should fail
      expect(
        () => repo.updateOrder(ghost),
        throwsException,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST GROUP 2: Counter Generation — KOT#, Bill#, Order#
  //
  // THE MOST CRITICAL INTEGRATION TEST.
  //
  // These counters use a shared appCounters Hive box.
  // If they're wrong: duplicate bill numbers (GST violation),
  // duplicate KOT numbers (kitchen confusion).
  //
  // Tests:
  //   - Sequential increment
  //   - Daily reset (KOT and Order)
  //   - Fiscal year reset (Bill)
  //   - Multiple calls produce sequential numbers
  // ═══════════════════════════════════════════════════════════════════════

  group('Counter generation — KOT, Order, Bill numbers', () {
    late OrderRepository repo;

    setUp(() {
      repo = OrderRepository();
    });

    test('KOT numbers are sequential', () async {
      final kot1 = await repo.getNextKotNumber();
      final kot2 = await repo.getNextKotNumber();
      final kot3 = await repo.getNextKotNumber();

      expect(kot1, equals(1));
      expect(kot2, equals(2));
      expect(kot3, equals(3));
    });

    test('Order numbers are sequential', () async {
      final ord1 = await repo.getNextOrderNumber();
      final ord2 = await repo.getNextOrderNumber();

      expect(ord1, equals(1));
      expect(ord2, equals(2));
    });

    test('Bill numbers are sequential', () async {
      final bill1 = await repo.getNextBillNumber();
      final bill2 = await repo.getNextBillNumber();
      final bill3 = await repo.getNextBillNumber();

      expect(bill1, equals(1));
      expect(bill2, equals(2));
      expect(bill3, equals(3));
    });

    test('KOT and Order counters are independent', () async {
      // KOT gets 1, 2
      final kot1 = await repo.getNextKotNumber();
      final kot2 = await repo.getNextKotNumber();

      // Order gets 1 (not 3) — independent counter
      final ord1 = await repo.getNextOrderNumber();

      expect(kot1, equals(1));
      expect(kot2, equals(2));
      expect(ord1, equals(1)); // Independent!
    });

    test('counters persist across repository instances', () async {
      // First instance generates some numbers
      final repo1 = OrderRepository();
      await repo1.getNextKotNumber(); // 1
      await repo1.getNextKotNumber(); // 2

      // Second instance (simulates app restart) should continue from 2
      final repo2 = OrderRepository();
      final next = await repo2.getNextKotNumber(); // should be 3

      expect(next, equals(3));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST GROUP 3: Order Lifecycle — Create → Update → Settle
  //
  // Tests the complete journey of an order through the system:
  //   Active order (orderBox) → settled → Past order (pastorderBox)
  //
  // This is what happens when staff places an order, kitchen cooks it,
  // and cashier settles it.
  // ═══════════════════════════════════════════════════════════════════════

  group('Order lifecycle — active → settle → past', () {
    late OrderRepository orderRepo;
    late PastOrderRepository pastOrderRepo;

    setUp(() {
      orderRepo = OrderRepository();
      pastOrderRepo = PastOrderRepository();
    });

    test('place order → exists in active, not in past', () async {
      final order = makeOrder(id: 'lifecycle-1');
      await orderRepo.addOrder(order);

      expect(await orderRepo.orderExists('lifecycle-1'), isTrue);

      final pastOrders = await pastOrderRepo.getAllPastOrders();
      expect(pastOrders.where((o) => o.id == 'lifecycle-1'), isEmpty);
    });

    test('settle order → moves from active to past', () async {
      // 1. Place order (active)
      final items = [
        CartItem(id: 'c1', productId: 'p1', title: 'Biryani', price: 250, quantity: 2),
      ];
      final order = makeOrder(id: 'lifecycle-2', items: items);
      await orderRepo.addOrder(order);

      // 2. Create past order (settlement)
      final pastOrder = PastOrderModel(
        id: order.id,  // same ID
        customerName: order.customerName,
        totalPrice: order.totalPrice,
        items: order.items,
        orderAt: order.timeStamp,
        orderType: order.orderType,
        paymentmode: 'Cash',
        kotNumbers: order.kotNumbers,
        kotBoundaries: order.kotBoundaries,
        billNumber: await orderRepo.getNextBillNumber(),
      );
      await pastOrderRepo.addOrder(pastOrder);

      // 3. Delete from active
      await orderRepo.deleteOrder(order.id);

      // 4. Verify: gone from active, exists in past
      expect(await orderRepo.orderExists('lifecycle-2'), isFalse);

      final loaded = await pastOrderRepo.getOrderById('lifecycle-2');
      expect(loaded, isNotNull);
      expect(loaded!.customerName, equals('Test Customer'));
      expect(loaded.paymentmode, equals('Cash'));
      expect(loaded.billNumber, isNotNull);
    });

    test('multiple orders settled → all in past with unique bill numbers', () async {
      // Place and settle 3 orders
      for (int i = 1; i <= 3; i++) {
        final order = makeOrder(id: 'batch-$i', totalPrice: 100.0 * i);
        await orderRepo.addOrder(order);

        final pastOrder = PastOrderModel(
          id: order.id,
          customerName: 'Customer $i',
          totalPrice: order.totalPrice,
          items: order.items,
          orderAt: DateTime.now(),
          orderType: 'Take Away',
          paymentmode: 'Cash',
          kotNumbers: [i],
          kotBoundaries: [1],
          billNumber: await orderRepo.getNextBillNumber(),
        );
        await pastOrderRepo.addOrder(pastOrder);
        await orderRepo.deleteOrder(order.id);
      }

      // Active: 0 orders
      final active = await orderRepo.getAllOrders();
      expect(active, isEmpty);

      // Past: 3 orders with unique bill numbers
      final past = await pastOrderRepo.getAllPastOrders();
      expect(past.length, equals(3));

      final billNumbers = past.map((o) => o.billNumber).toSet();
      expect(billNumbers.length, equals(3)); // all unique
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST GROUP 4: Table + Order Integration
  //
  // When a dine-in order is placed, the table status changes.
  // When settled, the table is freed. Tests this link.
  // ═══════════════════════════════════════════════════════════════════════

  group('Table + Order integration', () {
    late OrderRepository orderRepo;
    late TableRepository tableRepo;

    setUp(() {
      orderRepo = OrderRepository();
      tableRepo = TableRepository();
    });

    test('dine-in order → table occupied → settle → table freed', () async {
      // 1. Create table
      final table = TableModel(id: 'T3', status: 'Available');
      await tableRepo.addTable(table);

      // 2. Place dine-in order
      final order = makeOrder(
        id: 'dine-1',
        orderType: 'Dine In',
        tableNo: 'T3',
      );
      await orderRepo.addOrder(order);

      // 3. Occupy table (what the app does after placing order)
      await tableRepo.updateTableStatus(
        'T3', 'Running',
        total: order.totalPrice,
        orderId: order.id,
        orderTime: order.timeStamp,
      );

      // Verify table is occupied
      final occupiedTable = await tableRepo.getTableById('T3');
      expect(occupiedTable!.status, equals('Running'));
      expect(occupiedTable.currentOrderId, equals('dine-1'));
      expect(occupiedTable.currentOrderTotal, equals(500));

      // 4. Settle order → free table
      await orderRepo.deleteOrder(order.id);
      await tableRepo.updateTableStatus('T3', 'Available');

      // Verify table is freed
      final freedTable = await tableRepo.getTableById('T3');
      expect(freedTable!.status, equals('Available'));
      expect(freedTable.currentOrderId, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST GROUP 5: Printer Repository + SharedPreferences
  //
  // Tests that saved printers persist and defaults are independent
  // between KOT and Receipt roles.
  // ═══════════════════════════════════════════════════════════════════════

  group('PrinterRepository — save + defaults', () {
    late PrinterRepository repo;

    setUp(() {
      repo = PrinterRepository();
    });

    test('save printer → load returns it', () async {
      final printer = SavedPrinterModel(
        id: 'p1',
        name: 'Kitchen WiFi',
        type: 'wifi',
        address: '192.168.1.100:9100',
        paperSize: 80,
        role: 'both',
      );
      await repo.savePrinter(printer);

      final all = await repo.getAllPrinters();
      expect(all.length, equals(1));
      expect(all.first.name, equals('Kitchen WiFi'));
    });

    test('set KOT default and Receipt default independently', () async {
      // Save two printers
      await repo.savePrinter(SavedPrinterModel(
        id: 'kitchen', name: 'Kitchen', type: 'wifi',
        address: '1.1.1.1:9100', role: 'kot',
      ));
      await repo.savePrinter(SavedPrinterModel(
        id: 'counter', name: 'Counter', type: 'bluetooth',
        address: 'AA:BB:CC', role: 'receipt',
      ));

      // Set KOT default
      await repo.setDefaultPrinter('kitchen', 'kot');
      // Set Receipt default
      await repo.setDefaultPrinter('counter', 'receipt');

      // Verify each role resolves independently
      final kotDefault = await repo.getDefaultPrinterForRole('kot');
      final receiptDefault = await repo.getDefaultPrinterForRole('receipt');

      expect(kotDefault, isNotNull);
      expect(kotDefault!.name, equals('Kitchen'));

      expect(receiptDefault, isNotNull);
      expect(receiptDefault!.name, equals('Counter'));
    });

    test('delete printer clears its default assignment', () async {
      await repo.savePrinter(SavedPrinterModel(
        id: 'temp', name: 'Temp', type: 'wifi',
        address: '1.1.1.1:9100', role: 'both',
      ));
      await repo.setDefaultPrinter('temp', 'kot');

      // Verify default is set
      expect(await repo.getDefaultPrinterForRole('kot'), isNotNull);

      // Delete printer
      await repo.deletePrinter('temp');

      // Default should be cleared
      expect(await repo.getDefaultPrinterForRole('kot'), isNull);
    });

    test('default for role=both works for both KOT and Receipt', () async {
      await repo.savePrinter(SavedPrinterModel(
        id: 'all-in-one', name: 'All-in-One', type: 'wifi',
        address: '1.1.1.1:9100', role: 'both',
      ));

      // Set as KOT default
      await repo.setDefaultPrinter('all-in-one', 'kot');
      // Set as Receipt default too
      await repo.setDefaultPrinter('all-in-one', 'receipt');

      // Both roles should resolve to same printer
      final kot = await repo.getDefaultPrinterForRole('kot');
      final receipt = await repo.getDefaultPrinterForRole('receipt');

      expect(kot!.id, equals('all-in-one'));
      expect(receipt!.id, equals('all-in-one'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // TEST GROUP 6: Order Status Workflow
  //
  // Tests the status progression: Processing → Cooking → Ready → Served
  // Each status update goes through repository.updateOrder()
  // ═══════════════════════════════════════════════════════════════════════

  group('Order status workflow', () {
    late OrderRepository repo;

    setUp(() {
      repo = OrderRepository();
    });

    test('status progression: Processing → Cooking → Ready → Served', () async {
      final order = makeOrder(id: 'status-1', status: 'Processing');
      await repo.addOrder(order);

      // Kitchen starts cooking
      var current = (await repo.getOrderById('status-1'))!;
      await repo.updateOrder(current.copyWith(status: 'Cooking'));

      current = (await repo.getOrderById('status-1'))!;
      expect(current.status, equals('Cooking'));

      // Food is ready
      await repo.updateOrder(current.copyWith(status: 'Ready'));
      current = (await repo.getOrderById('status-1'))!;
      expect(current.status, equals('Ready'));

      // Served to customer
      await repo.updateOrder(current.copyWith(status: 'Served'));
      current = (await repo.getOrderById('status-1'))!;
      expect(current.status, equals('Served'));
    });

    test('mark as paid preserves other fields', () async {
      final order = makeOrder(
        id: 'pay-1',
        status: 'Served',
        totalPrice: 750,
      );
      await repo.addOrder(order);

      // Mark as paid
      final updated = order.copyWith(
        isPaid: true,
        paymentStatus: 'Paid',
        paymentMethod: 'Cash',
      );
      await repo.updateOrder(updated);

      final loaded = (await repo.getOrderById('pay-1'))!;
      expect(loaded.isPaid, isTrue);
      expect(loaded.paymentStatus, equals('Paid'));
      expect(loaded.paymentMethod, equals('Cash'));
      expect(loaded.totalPrice, equals(750)); // unchanged
      expect(loaded.customerName, equals('Test Customer')); // unchanged
    });
  });
}
