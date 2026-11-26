import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/past_order_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/table_repository.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/restaurant/order_store.dart';
import 'package:billberrylite/domain/store/restaurant/past_order_store.dart';
import 'package:billberrylite/domain/store/restaurant/table_store.dart';
import 'package:billberrylite/core/routes/notification_routes.dart';
import 'package:billberrylite/presentation/screens/restaurant/start%20order/startorder.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/activeorder.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/pastorder.dart';

/// An order notification (Captain placed / added items) opened the bare
/// Active Orders body: no app bar, no Past Orders switch, no Menu/Tables tabs.
/// It must open the full Start Order screen on its Orders tab.
void main() {
  late Directory tempDir;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('start_order_orders_');
  });

  tearDown(() async {
    await locator.reset();
    await Future.any<void>([
      Hive.close(),
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async {
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
      await AppConfig.init();
      await AppConfig.box.put('businessMode', 'restaurant');
      await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);
      await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
      await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
      await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);
      await Hive.openBox(HiveBoxNames.appCounters);
      await Hive.openBox(HiveBoxNames.dayManagementBox);
      locator
        ..registerLazySingleton<NotificationStore>(
            () => NotificationStore(NotificationRepository()))
        ..registerLazySingleton<PastOrderRepository>(() => PastOrderRepository())
        ..registerLazySingleton<PastOrderStore>(
            () => PastOrderStore(locator<PastOrderRepository>()))
        ..registerLazySingleton<OrderRepository>(() => OrderRepository())
        ..registerLazySingleton<OrderStore>(
            () => OrderStore(locator<OrderRepository>()))
        ..registerLazySingleton<TableStore>(() => TableStore(TableRepository()))
        ..registerLazySingleton<LicenseStore>(
            () => LicenseStore(LicenseApiService())..licenseBypassed = true);
    });
    tester.view.devicePixelRatio = 1;
    // The test font draws every letter as a full square, far wider than
    // Poppins; at phone width the Active/Past labels overflow in tests only.
    tester.view.physicalSize = const Size(1024, 1366);
    addTearDown(tester.view.reset);
  }

  testWidgets('opened on the Orders tab: Start Order tabs and the '
      'Active/Past switch are all there', (tester) async {
    await boot(tester);
    await tester.pumpWidget(const MaterialApp(
        home: Startorder(initialTab: Startorder.ordersTab)));
    await settle(tester);

    expect(find.text('Menu'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Active Orders'), findsOneWidget);
    expect(find.text('Past Orders'), findsOneWidget);
  });

  testWidgets('notification while Start Order is showing: no second copy, '
      'switches to Active Orders', (tester) async {
    await boot(tester);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: const Startorder(initialTab: Startorder.ordersTab),
      onGenerateRoute: (s) => MaterialPageRoute(
          settings: s, builder: (_) => const Text('second start order')),
    ));
    await settle(tester);
    await tester.tap(find.text('Past Orders'));
    await settle(tester);
    expect(find.byType(Pastorder), findsOneWidget);

    NotificationRoutes.open(key.currentState!, RouteNames.restaurantActiveOrders);
    await settle(tester);

    expect(find.text('second start order'), findsNothing);
    expect(find.byType(Startorder), findsOneWidget);
    expect(find.byType(Activeorder), findsOneWidget);
    expect(find.byType(Pastorder), findsNothing);
  });

  testWidgets('notification while a screen is open above Start Order: that '
      'screen is kept, Orders opens on top', (tester) async {
    await boot(tester);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: const Startorder(initialTab: Startorder.ordersTab),
      onGenerateRoute: (s) => MaterialPageRoute(
          settings: s,
          builder: (_) => Text(s.name == 'cart' ? 'cart' : 'orders on top')),
    ));
    await settle(tester);
    key.currentState!.pushNamed('cart');
    await settle(tester);

    NotificationRoutes.open(key.currentState!, RouteNames.restaurantActiveOrders);
    await settle(tester);
    expect(find.text('orders on top'), findsOneWidget);

    key.currentState!.pop();
    await settle(tester);
    expect(find.text('cart'), findsOneWidget, reason: 'not popped away');
  });

  testWidgets('returnToStartOrder comes back to a Start Order opened from a '
      'notification', (tester) async {
    late BuildContext top;
    await tester.pumpWidget(MaterialApp(
      home: const Text('dashboard'),
      onGenerateRoute: (s) => MaterialPageRoute(
        settings: s,
        builder: (c) {
          if (s.name == 'cart') {
            top = c;
            return const Text('cart');
          }
          return const Text('orders from notification');
        },
      ),
    ));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed(RouteNames.restaurantActiveOrders);
    await tester.pumpAndSettle();
    nav.pushNamed('cart');
    await tester.pumpAndSettle();

    returnToStartOrder(top);
    await tester.pumpAndSettle();

    expect(find.text('orders from notification'), findsOneWidget);
    expect(find.text('cart'), findsNothing);
  });
}
