import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/services/restaurant/order_close.dart';
import 'package:billberrylite/domain/services/restaurant/settle_new_order.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';

import '../../../helpers/test_helpers.dart';

class _Past extends PastOrderStore {
  _Past(super.repository);
  bool refuse = false;
  int writes = 0;
  @override
  Future<bool> addOrder(PastOrderModel pastOrder) async {
    if (refuse) return false;
    writes++;
    return super.addOrder(pastOrder);
  }
}

class _Orders extends OrderStore {
  _Orders(super.repository);
  bool refuseDelete = false;
  @override
  Future<bool> deleteOrder(String orderId) async =>
      refuseDelete ? false : super.deleteOrder(orderId);
}

/// SALE-4: Settle, serve and End of Day "Complete" deleted the active order
/// without checking the past-order save — a failed save lost the bill and
/// its payment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late _Past past;
  late _Orders orders;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('order_close_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    past = _Past(PastOrderRepository());
    orders = _Orders(OrderRepository());
    locator
      ..registerSingleton<PastOrderStore>(past)
      ..registerSingleton<OrderStore>(orders)
      ..registerSingleton<TableStore>(TableStore(TableRepository()));
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put('o1', OrderModel(
      id: 'o1', customerName: '', customerNumber: '', customerEmail: '',
      items: [makeCartItem(id: 'l1', title: 'Tea', price: 20, quantity: 1)],
      status: 'Served', timeStamp: DateTime.now(), orderType: 'Dine In',
      tableNo: 'T1', totalPrice: 20, kotNumbers: [1], itemCountAtLastKot: 1,
      kotBoundaries: [1], isPaid: true, totalPaid: 20));
    await Hive.box<TableModel>(HiveBoxNames.restaurantTables)
        .put('T1', TableModel(id: 'T1', status: 'Running', currentOrderId: 'o1'));
    await orders.loadOrders();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  PastOrderModel record() => PastOrderModel(
        id: 'o1', customerName: '', totalPrice: 20,
        items: [makeCartItem(id: 'l1', title: 'Tea', price: 20, quantity: 1)],
        orderAt: DateTime.now(), orderType: 'Dine In', paymentmode: 'Cash',
        subTotal: 20, gstRate: 0, gstAmount: 0, kotNumbers: [1],
        kotBoundaries: [1], totalPaid: 20);

  bool active() => Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).containsKey('o1');
  bool saved() => Hive.box<PastOrderModel>(HiveBoxNames.restaurantPastOrders).containsKey('o1');
  String table() => Hive.box<TableModel>(HiveBoxNames.restaurantTables).get('T1')!.status;

  test('saved → moved, table freed', () async {
    await OrderClose.moveToPast(record(), orderId: 'o1', tableNo: 'T1');
    expect(saved(), isTrue);
    expect(active(), isFalse);
    expect(table(), 'Available');
  });

  test('save fails → throws; the order stays active and its table busy', () async {
    past.refuse = true;
    await expectLater(OrderClose.moveToPast(record(), orderId: 'o1', tableNo: 'T1'),
        throwsA(isA<OrderSaveFailedException>()));
    expect(active(), isTrue, reason: 'nothing lost');
    expect(saved(), isFalse);
    expect(table(), 'Running');
  });

  test('removal fails → throws; a retry does not write the record again', () async {
    orders.refuseDelete = true;
    await expectLater(OrderClose.moveToPast(record(), orderId: 'o1', tableNo: 'T1'),
        throwsA(isA<OrderSaveFailedException>()));
    expect(saved(), isTrue);
    expect(active(), isTrue);

    orders.refuseDelete = false;
    await OrderClose.moveToPast(record(), orderId: 'o1', tableNo: 'T1');
    expect(past.writes, 1, reason: 'the saved record is not written twice');
    expect(active(), isFalse);
  });

  group('SALE-11: pay-first save', () {
    test('a failed update is reported, not swallowed', () async {
      final refusing = _RefusingUpdate(OrderRepository());
      await locator.unregister<OrderStore>();
      locator.registerSingleton<OrderStore>(refusing);
      final o = Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!;
      await expectLater(OrderClose.saveActive(o.copyWith(billNumber: 7)),
          throwsA(isA<OrderSaveFailedException>()));
    });

    test('a successful update returns normally', () async {
      final o = Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!;
      await OrderClose.saveActive(o.copyWith(billNumber: 7));
      expect(Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!.billNumber, 7);
    });
  });
}

class _RefusingUpdate extends OrderStore {
  _RefusingUpdate(super.repository);
  @override
  Future<bool> updateOrder(OrderModel order) async => false;
}
