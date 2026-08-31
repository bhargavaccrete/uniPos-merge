import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';

/// NOTIFICATION STORE — the shared event pipeline, exercised as retail.
///
/// `raiseEvent` stores a **business fact**, not a UI row, and that is what
/// makes the rules everyone asks for fall out for free:
///
///  * identity is `(eventCode, subjectType, subjectId)` among UNRESOLVED rows,
///    so raising the same fact twice updates one record instead of adding one;
///  * `resolve()` retires a record rather than deleting it, so history survives
///    while `active`/`unreadCount` drop it.
///
/// Runs on the desktop test host, where `LocalNotificationService` is a silent
/// no-op — so the store can be tested without any OS seam or mocking library.
void main() {
  late Directory tempDir;
  late NotificationStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notif_store_');
    Hive.init(tempDir.path);
    // The adapter is registered by HiveInit._registerCommonAdapters() in the
    // app; tests bootstrap Hive directly, so register it here.
    if (!Hive.isAdapterRegistered(AppNotificationModelAdapter().typeId)) {
      Hive.registerAdapter(AppNotificationModelAdapter());
    }
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    // NotificationRepository resolves the box synchronously by name.
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);

    store = NotificationStore(NotificationRepository());
    await store.load();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> raiseLowStock({
    String variantId = 'v1',
    num remaining = 2,
    String name = 'Amul Milk',
  }) =>
      store.raiseEvent(
        eventCode: 'low_stock',
        subjectType: 'variant',
        subjectId: variantId,
        data: {'name': name, 'remaining': remaining, 'unit': 'piece'},
        fireOs: false,
      );

  test('an event is created, persisted, and appears in the list', () async {
    await raiseLowStock();

    expect(store.notifications, hasLength(1));
    expect(store.active, hasLength(1));

    final n = store.notifications.first;
    expect(n.eventCode, 'low_stock');
    expect(n.subjectId, 'v1');
    expect(n.dataMap['remaining'], 2);
    expect(n.isRead, isFalse);
    expect(n.isResolved, isFalse);

    // It really reached Hive, not just the observable list.
    final box = Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications);
    expect(box.values, hasLength(1));
    expect(box.get(n.id), isNotNull);
  });

  test('a reloaded store sees the persisted event (survives restart)',
      () async {
    await raiseLowStock();

    // Same box, a brand-new store — this is what a cold start does.
    final reloaded = NotificationStore(NotificationRepository());
    await reloaded.load();

    expect(reloaded.notifications, hasLength(1));
    expect(reloaded.unreadCount, 1);
    expect(reloaded.notifications.first.subjectId, 'v1');
  });

  test('unreadCount tracks markRead and markAllRead', () async {
    await raiseLowStock(variantId: 'v1');
    await raiseLowStock(variantId: 'v2');
    expect(store.unreadCount, 2);

    await store.markRead(store.notifications.first.id);
    expect(store.unreadCount, 1);

    await store.markAllRead();
    expect(store.unreadCount, 0);
    // Read is not resolved — the rows are still listed.
    expect(store.active, hasLength(2));
  });

  test('raising the same fact twice creates ONE record', () async {
    await raiseLowStock(remaining: 2);
    await raiseLowStock(remaining: 1);

    expect(store.notifications, hasLength(1));
    // The context is refreshed in place even on a same-day repeat.
    expect(store.notifications.first.dataMap['remaining'], 1);
    expect(
      Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications).values,
      hasLength(1),
    );
  });

  test('the same code for a DIFFERENT subject is a separate record', () async {
    await raiseLowStock(variantId: 'v1');
    await raiseLowStock(variantId: 'v2');
    expect(store.notifications, hasLength(2));
  });

  test('resolve retires the record without deleting it', () async {
    await raiseLowStock();
    await store.resolve('low_stock', 'variant', 'v1');

    expect(store.active, isEmpty);
    expect(store.unreadCount, 0);
    // Still on disk — resolution is bookkeeping, not a delete.
    expect(
      Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications).values,
      hasLength(1),
    );
    expect(store.notifications.first.isResolved, isTrue);
  });

  test('a resolved fact that recurs starts a NEW record', () async {
    await raiseLowStock();
    await store.resolve('low_stock', 'variant', 'v1');
    await raiseLowStock();

    // findActive only matches unresolved rows, so the resolved one is history
    // and the recurrence gets its own unread entry.
    expect(store.notifications, hasLength(2));
    expect(store.active, hasLength(1));
    expect(store.unreadCount, 1);
  });

  test('activeOf narrows by event code and subject type', () async {
    await raiseLowStock(variantId: 'v1');
    await store.raiseEvent(
      eventCode: 'expiry_alert',
      subjectType: 'variant',
      subjectId: 'v2',
      data: {'name': 'Curd', 'status': 'expired'},
      fireOs: false,
    );
    await store.raiseEvent(
      eventCode: 'low_stock',
      subjectType: 'item', // a restaurant-shaped event in the same box
      subjectId: 'i1',
      fireOs: false,
    );

    expect(store.activeOf('low_stock', subjectType: 'variant'), hasLength(1));
    expect(store.activeOf('low_stock'), hasLength(2));
    expect(store.activeOf('expiry_alert', subjectType: 'variant'), hasLength(1));

    // Resolved rows drop out.
    await store.resolve('low_stock', 'variant', 'v1');
    expect(store.activeOf('low_stock', subjectType: 'variant'), isEmpty);
  });

  test('clearAll empties the box', () async {
    await raiseLowStock(variantId: 'v1');
    await raiseLowStock(variantId: 'v2');
    await store.clearAll();

    expect(store.notifications, isEmpty);
    expect(store.unreadCount, 0);
    expect(
      Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications).values,
      isEmpty,
    );
  });
}
