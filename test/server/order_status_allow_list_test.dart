import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shelf/shelf.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/restaurant/db/database/hive_order.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';
import 'package:billberrylite/server/handlers/captain_handler.dart';
import 'package:billberrylite/server/handlers/kds_handler.dart';

import '../helpers/test_helpers.dart';

/// CAP-3 / N1 — order-status updates from Captain and KDS.
///
/// * Captain "Request Bill" used to save status "Bill Requested", which no
///   active list knows, so the order vanished from Active Orders after a
///   reload and the next Captain send opened a second order on the table.
///   It is now a notification; the order keeps its kitchen status.
/// * Every status endpoint used to save any string it was sent ("Completed"
///   dropped an unpaid order with no payment or void record). They now accept
///   an explicit allow-list only.
///
/// Order o1: Dine In, table T1, unpaid, status Cooking, KOTs 1 and 2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('order_status_');
    Hive.init(tempDir.path);
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'restaurant');
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);

    locator
      ..registerLazySingleton<NotificationStore>(
          () => NotificationStore(NotificationRepository()))
      ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
      ..registerLazySingleton<PastOrderStore>(
          () => PastOrderStore(locator<PastOrderRepository>()))
      ..registerLazySingleton<OrderRepository>(() => OrderRepository())
      ..registerLazySingleton<OrderStore>(
          () => OrderStore(locator<OrderRepository>()))
      ..registerLazySingleton<TableStore>(
          () => TableStore(TableRepository()));

    await Hive.box<TableModel>(HiveBoxNames.restaurantTables).put(
      'T1',
      TableModel(id: 'T1', status: 'Cooking', currentOrderId: 'o1'),
    );
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> persist({String status = 'Cooking', String? tableNo = 'T1'}) async {
    final o = OrderModel(
      id: 'o1',
      customerName: '',
      customerNumber: '',
      customerEmail: '',
      items: [
        makeCartItem(id: 'a', productId: 'p', title: 'Paneer', price: 100),
      ],
      status: status,
      timeStamp: DateTime(2026, 11, 16, 12),
      orderType: tableNo == null ? 'Take Away' : 'Dine In',
      tableNo: tableNo,
      totalPrice: 100,
      kotNumbers: const [1, 2],
      itemCountAtLastKot: 1,
      kotBoundaries: const [1, 1],
      kotStatuses: const {1: 'Cooking', 2: 'Cooking'},
      orderNumber: 7,
      isPaid: false,
    );
    await Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).put(o.id, o);
    await orderStore.loadOrders();
  }

  OrderModel saved() =>
      Hive.box<OrderModel>(HiveBoxNames.restaurantOrders).get('o1')!;
  String tableStatus() =>
      Hive.box<TableModel>(HiveBoxNames.restaurantTables).get('T1')!.status;
  List<AppNotificationModel> billRequests() =>
      Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications)
          .values
          .where((n) => n.eventCode == 'bill_requested')
          .toList();

  /// Still open everywhere the POS looks: the Hive active query (Captain's
  /// Active Orders, table lookup) and the POS Active Orders tab after reload.
  Future<void> expectStillActive() async {
    final hiveActive = await HiveOrders.getAllActiveOrders();
    expect(hiveActive.map((o) => o.id), contains('o1'));
    expect((await HiveOrders.getActiveOrderByTableId('T1'))?.id, 'o1');
    await orderStore.loadOrders();
    expect(orderStore.activeOrders.map((o) => o.id), contains('o1'));
  }

  Future<(int, Map<String, dynamic>)> captain(
    Object? status, {
    String orderId = 'o1',
  }) async {
    final response = await captainUpdateOrderStatusHandler(
      Request(
        'PUT',
        Uri.parse('http://localhost/captain/orders/$orderId/status'),
        body: jsonEncode(status == null ? {} : {'status': status}),
      ),
      orderId,
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<(int, Map<String, dynamic>)> kdsOrder(String status) async {
    final response = await updateKdsStatusHandler(
      Request(
        'PUT',
        Uri.parse('http://localhost/kds/orders/o1/status'),
        body: jsonEncode({'status': status}),
      ),
      'o1',
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<(int, Map<String, dynamic>)> kdsKot(int kot, String status) async {
    final response = await updateKotStatusHandler(
      Request(
        'PUT',
        Uri.parse('http://localhost/kds/orders/o1/kot/$kot/status'),
        body: jsonEncode({'status': status}),
      ),
      'o1',
      '$kot',
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, dynamic>,
    );
  }

  group('Captain Request Bill', () {
    test('keeps the order active with its status; raises a notification',
        () async {
      await persist();

      final (code, body) = await captain('Bill Requested');

      expect(code, 200);
      expect(body['success'], isTrue);
      expect(body['billRequested'], isTrue);
      expect(body['status'], 'Cooking');
      expect(saved().status, 'Cooking');
      expect(saved().isPaid, isFalse);
      expect(tableStatus(), 'Cooking');
      await expectStillActive();

      final requests = billRequests();
      expect(requests, hasLength(1));
      expect(requests.single.subjectType, 'order');
      expect(requests.single.subjectId, 'o1');
      expect(requests.single.dataMap['location'], 'Table T1');
      expect(requests.single.dataMap['orderNumber'], 7);
    });

    test('a repeated request updates the same notification', () async {
      await persist();

      await captain('Bill Requested');
      final (code, _) = await captain('Bill Requested');

      expect(code, 200);
      expect(billRequests(), hasLength(1));
      expect(saved().status, 'Cooking');
    });

    test('works on a Served order and on a Take Away order', () async {
      await persist(status: 'Served', tableNo: null);

      final (code, _) = await captain('Bill Requested');

      expect(code, 200);
      expect(saved().status, 'Served');
      expect(billRequests().single.dataMap['location'], 'Take Away');
      await orderStore.loadOrders();
      expect(orderStore.activeOrders.map((o) => o.id), contains('o1'));
    });
  });

  group('Captain Served (existing workflow)', () {
    test('marks the order Served and the table Running', () async {
      await persist();

      final (code, body) = await captain('Served');

      expect(code, 200);
      expect(body['status'], 'Served');
      expect(saved().status, 'Served');
      expect(tableStatus(), 'Running');
      expect(billRequests(), isEmpty);
      await expectStillActive();
    });
  });

  group('Captain refuses statuses outside the allow-list', () {
    for (final status in [
      'Completed',
      'Cancelled',
      'VOID',
      'Paid',
      'Running',
      'Processing',
      'served',
      '',
    ]) {
      test('"$status" → 400, unpaid order untouched and still active',
          () async {
        await persist();

        final (code, body) = await captain(status);

        expect(code, 400);
        expect(body['success'], isFalse);
        expect(saved().status, 'Cooking');
        expect(saved().isPaid, isFalse);
        expect(tableStatus(), 'Cooking');
        expect(billRequests(), isEmpty);
        await expectStillActive();
      });
    }

    test('missing status → 400', () async {
      await persist();
      final (code, _) = await captain(null);
      expect(code, 400);
      expect(saved().status, 'Cooking');
    });
  });

  group('Captain refuses orders that are no longer open', () {
    for (final status in ['Served', 'Bill Requested']) {
      test('"$status" on a Completed order → 409, nothing changes', () async {
        await persist(status: 'Completed');

        final (code, body) = await captain(status);

        expect(code, 409);
        expect(body['success'], isFalse);
        expect(saved().status, 'Completed');
        expect(tableStatus(), 'Cooking');
        expect(billRequests(), isEmpty);
      });
    }

    test('unknown order → 404', () async {
      await persist();
      final (code, _) = await captain('Served', orderId: 'nope');
      expect(code, 404);
    });
  });

  group('KDS whole-order status (legacy endpoint)', () {
    const mapped = {
      'newOrder': 'Processing',
      'accepted': 'Cooking',
      'preparing': 'Cooking',
      'ready': 'Ready',
      'served': 'Served',
      'Processing': 'Processing',
      'Cooking': 'Cooking',
      'Ready': 'Ready',
      'Served': 'Served',
    };
    mapped.forEach((sent, stored) {
      test('"$sent" → $stored', () async {
        await persist();
        final (code, body) = await kdsOrder(sent);
        expect(code, 200);
        expect(body['newStatus'], stored);
        expect(saved().status, stored);
      });
    });

    for (final status in ['Completed', 'Cancelled', 'Bill Requested', 'done']) {
      test('"$status" → 400, unpaid order untouched and still active',
          () async {
        await persist();

        final (code, body) = await kdsOrder(status);

        expect(code, 400);
        expect(body['success'], isFalse);
        expect(saved().status, 'Cooking');
        expect(saved().isPaid, isFalse);
        await expectStillActive();
      });
    }
  });

  group('KDS per-KOT status', () {
    test('valid KOT statuses still drive the overall status', () async {
      await persist();

      var (code, body) = await kdsKot(1, 'ready');
      expect(code, 200);
      expect(body['newKotStatus'], 'Ready');
      expect(saved().kotStatuses, {1: 'Ready', 2: 'Cooking'});
      expect(saved().status, 'Cooking');

      (code, body) = await kdsKot(2, 'ready');
      expect(code, 200);
      expect(saved().status, 'Ready');

      (code, body) = await kdsKot(1, 'served');
      (code, body) = await kdsKot(2, 'Served');
      expect(code, 200);
      expect(saved().kotStatuses, {1: 'Served', 2: 'Served'});
      expect(saved().status, 'Served');
      await expectStillActive();
    });

    for (final status in ['Completed', 'Cancelled', 'Bill Requested']) {
      test('"$status" → 400, KOT statuses untouched', () async {
        await persist();

        final (code, body) = await kdsKot(1, status);

        expect(code, 400);
        expect(body['success'], isFalse);
        expect(saved().kotStatuses, {1: 'Cooking', 2: 'Cooking'});
        expect(saved().status, 'Cooking');
        await expectStillActive();
      });
    }
  });
}
