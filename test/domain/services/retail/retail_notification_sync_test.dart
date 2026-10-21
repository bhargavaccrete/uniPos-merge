import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';

import 'package:billberrylite/domain/services/retail/report_service.dart';
import 'package:billberrylite/domain/services/retail/retail_notification_sync_service.dart';
import 'package:billberrylite/domain/services/common/license_api_service.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/stock_alert_store.dart';

/// RETAIL NOTIFICATION SYNC — derived alerts become persisted events.
///
/// The service is **reconciling**, not event-driven: it recomputes the whole
/// alerting set on every run, raises one event per alerting variant, and
/// resolves everything it raised before that is no longer true. Restaurant
/// can hook `deductStockForOrder` because it knows which item moved; retail's
/// low-stock and expiry states are derived, so there is no such moment.
///
/// That design is exactly what these tests pin: repeated runs never duplicate,
/// a restocked or re-dated variant corrects itself, and a cleared expiry drops
/// out — without the service storing any alert state of its own.
void main() {
  late Directory tempDir;

  const kSync = RetailNotificationSyncService.subjectVariant;
  const kLowStock = RetailNotificationSyncService.lowStockEvent;
  const kExpiry = RetailNotificationSyncService.expiryEvent;

  /// Everything on disk, resolved rows included.
  List<AppNotificationModel> stored() =>
      Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications)
          .values
          .toList();

  setUp(() async {
    await locator.reset();
    // Global reorder point. A variant's own minStock overrides it (group C).
    SharedPreferences.setMockInitialValues({
      'stock_alert_threshold': 10,
      'stock_alerts_enabled': true,
    });

    tempDir = await Directory.systemTemp.createTemp('retail_notif_sync_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    if (!Hive.isAdapterRegistered(AppNotificationModelAdapter().typeId)) {
      Hive.registerAdapter(AppNotificationModelAdapter());
    }

    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<Tax>(HiveBoxNames.tax);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox(HiveBoxNames.appCounters);
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);

    // ReportService's constructor reaches ReportHistoryWindow -> PlanEnforce,
    // which resolves LicenseStore. No manifest + retail is what PlanEnforce
    // treats as "not licensed yet, stay open".
    locator.registerLazySingleton<LicenseStore>(
      () => LicenseStore(LicenseApiService()),
    );
    locator<LicenseStore>().licenseBypassed = true;
    locator.registerLazySingleton<AttributeStore>(() => AttributeStore());
    locator.registerLazySingleton<ReportService>(() => ReportService());
    locator.registerLazySingleton<ProductStore>(() => ProductStore());
    locator.registerLazySingleton<StockAlertStore>(() => StockAlertStore());
    locator.registerLazySingleton<NotificationRepository>(
        () => NotificationRepository());
    locator.registerLazySingleton<NotificationStore>(
        () => NotificationStore(locator<NotificationRepository>()));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ---- fixtures -----------------------------------------------------------

  /// Writes a product + one variant straight to Hive, then rehydrates the
  /// store — the same order the app sees on a cold start.
  Future<void> seed({
    String productId = 'p1',
    String variantId = 'v1',
    String name = 'Amul Milk',
    double stock = 50,
    double? minStock,
    DateTime? expiry,
  }) async {
    final now = DateTime.now().toIso8601String();
    await Hive.box<ProductModel>(HiveBoxNames.products).put(
      productId,
      ProductModel(
        productId: productId,
        productName: name,
        category: 'Dairy',
        hasVariants: false,
        createdAt: now,
        updateAt: now,
      ),
    );
    await Hive.box<VarianteModel>(HiveBoxNames.variants).put(
      variantId,
      VarianteModel(
        varianteId: variantId,
        productId: productId,
        createdAt: now,
        stockQty: stock,
        minStock: minStock,
        expiryDate: expiry?.toIso8601String(),
      ),
    );
    await productStore.loadProducts();
    await productStore.loadVariants();
  }

  Future<void> setStock(String variantId, double qty) async {
    final box = Hive.box<VarianteModel>(HiveBoxNames.variants);
    await box.put(variantId, box.get(variantId)!.copyWith(stockQty: qty));
    await productStore.loadVariants();
  }

  Future<void> setExpiry(String variantId, DateTime? expiry) async {
    final box = Hive.box<VarianteModel>(HiveBoxNames.variants);
    final v = box.get(variantId)!;
    await box.put(
      variantId,
      expiry == null
          ? v.copyWith(clearExpiryDate: true)
          : v.copyWith(expiryDate: expiry.toIso8601String()),
    );
    await productStore.loadVariants();
  }

  Future<void> sync({DateTime? asOf}) =>
      RetailNotificationSyncService.runStartupChecks(asOf: asOf);

  List<AppNotificationModel> active(String code) =>
      notificationStore.activeOf(code, subjectType: kSync);

  // ==================== A. LOW STOCK ====================

  group('A. low stock', () {
    test('a variant below its reorder point raises one notification', () async {
      await seed(stock: 3); // global threshold is 10
      await sync();

      final rows = active(kLowStock);
      expect(rows, hasLength(1));
      expect(rows.first.subjectId, 'v1');
      expect(rows.first.dataMap['name'], 'Amul Milk');
      expect(rows.first.dataMap['remaining'], 3);
      // Restaurant's presenter interpolates the unit unguarded, so retail
      // must always supply one.
      expect(rows.first.dataMap['unit'], isNotEmpty);
      expect(notificationStore.unreadCount, 1);
    });

    test('a well-stocked variant raises nothing', () async {
      await seed(stock: 50);
      await sync();
      expect(active(kLowStock), isEmpty);
      expect(stored(), isEmpty);
    });

    test('running the sync twice does NOT duplicate', () async {
      await seed(stock: 3);
      await sync();
      await sync();
      await sync();

      expect(active(kLowStock), hasLength(1));
      expect(stored(), hasLength(1));
    });

    test('restocking above the reorder point resolves it', () async {
      await seed(stock: 3);
      await sync();
      expect(active(kLowStock), hasLength(1));

      await setStock('v1', 40);
      await sync();

      expect(active(kLowStock), isEmpty);
      expect(notificationStore.unreadCount, 0);
      // Resolved, not deleted.
      expect(stored(), hasLength(1));
      expect(stored().first.isResolved, isTrue);
    });

    test('falling stock updates the same record in place', () async {
      await seed(stock: 8);
      await sync();
      await setStock('v1', 2);
      await sync();

      final rows = active(kLowStock);
      expect(rows, hasLength(1));
      expect(rows.first.dataMap['remaining'], 2);
    });

    test('each low variant gets its own record', () async {
      await seed(productId: 'p1', variantId: 'v1', name: 'Milk', stock: 2);
      await seed(productId: 'p2', variantId: 'v2', name: 'Bread', stock: 1);
      await sync();

      expect(active(kLowStock), hasLength(2));
      expect(
        active(kLowStock).map((n) => n.subjectId).toSet(),
        {'v1', 'v2'},
      );
    });
  });

  // ==================== B. EXPIRY ====================

  group('B. expiry', () {
    final asOf = DateTime(2026, 6, 15);

    test('a variant expiring in 3 days raises one notification', () async {
      await seed(stock: 50, expiry: DateTime(2026, 6, 18));
      await sync(asOf: asOf);

      final rows = active(kExpiry);
      expect(rows, hasLength(1));
      expect(rows.first.subjectId, 'v1');
      expect(rows.first.dataMap['status'], 'expiringSoon');
      expect(rows.first.dataMap['daysUntil'], 3);
    });

    test('a variant well inside its shelf life raises nothing', () async {
      await seed(stock: 50, expiry: DateTime(2026, 12, 31));
      await sync(asOf: asOf);
      expect(active(kExpiry), isEmpty);
    });

    test('a variant with no expiry date raises nothing', () async {
      await seed(stock: 50);
      await sync(asOf: asOf);
      expect(active(kExpiry), isEmpty);
    });

    test('an already-expired variant is flagged expired', () async {
      await seed(stock: 50, expiry: DateTime(2026, 6, 1));
      await sync(asOf: asOf);

      final rows = active(kExpiry);
      expect(rows, hasLength(1));
      expect(rows.first.dataMap['status'], 'expired');
    });

    test('repeated checks do not duplicate', () async {
      await seed(stock: 50, expiry: DateTime(2026, 6, 18));
      await sync(asOf: asOf);
      await sync(asOf: asOf);
      await sync(asOf: asOf);

      expect(active(kExpiry), hasLength(1));
      expect(stored(), hasLength(1));
    });

    test('pushing the expiry date out resolves the notification', () async {
      await seed(stock: 50, expiry: DateTime(2026, 6, 18));
      await sync(asOf: asOf);
      expect(active(kExpiry), hasLength(1));

      await setExpiry('v1', DateTime(2027, 1, 1));
      await sync(asOf: asOf);

      expect(active(kExpiry), isEmpty);
      expect(notificationStore.unreadCount, 0);
    });

    test('clearing the expiry date resolves the notification', () async {
      await seed(stock: 50, expiry: DateTime(2026, 6, 18));
      await sync(asOf: asOf);
      expect(active(kExpiry), hasLength(1));

      await setExpiry('v1', null);
      await sync(asOf: asOf);

      expect(active(kExpiry), isEmpty);
    });

    test('expiringSoon that tips over to expired upgrades in place', () async {
      await seed(stock: 50, expiry: DateTime(2026, 6, 18));
      await sync(asOf: asOf);
      expect(active(kExpiry).first.dataMap['status'], 'expiringSoon');

      // Same variant, later date of observation — one record, new severity.
      await sync(asOf: DateTime(2026, 6, 20));

      final rows = active(kExpiry);
      expect(rows, hasLength(1));
      expect(rows.first.dataMap['status'], 'expired');
      expect(stored(), hasLength(1));
    });
  });

  // ==================== C. THE TWO EVENTS TOGETHER ====================

  group('C. interaction and existing rules', () {
    test('low stock and expiry coexist as separate records', () async {
      await seed(stock: 2, expiry: DateTime(2026, 6, 16));
      await sync(asOf: DateTime(2026, 6, 15));

      expect(active(kLowStock), hasLength(1));
      expect(active(kExpiry), hasLength(1));
      expect(notificationStore.unreadCount, 2);
      // Same subject, different event codes — the identity triple keeps them
      // apart without any extra bookkeeping.
      expect(stored().map((n) => n.subjectId).toSet(), {'v1'});
    });

    test("a variant's own minStock beats the global threshold", () async {
      // 12 is above the global 10, but below this variant's own reorder point.
      await seed(stock: 12, minStock: 20);
      await sync();
      expect(active(kLowStock), hasLength(1));

      // And the reverse: 8 is below the global 10 but fine for this variant.
      await setStock('v1', 8);
      final box = Hive.box<VarianteModel>(HiveBoxNames.variants);
      await box.put('v1', box.get('v1')!.copyWith(minStock: 5));
      await productStore.loadVariants();
      await sync();

      expect(active(kLowStock), isEmpty);
    });

    test('disabling stock alerts resolves low stock but not expiry', () async {
      await seed(stock: 2, expiry: DateTime(2026, 6, 16));
      await sync(asOf: DateTime(2026, 6, 15));
      expect(active(kLowStock), hasLength(1));

      await stockAlertStore.setEnabled(false);
      await sync(asOf: DateTime(2026, 6, 15));

      expect(active(kLowStock), isEmpty);
      expect(active(kExpiry), hasLength(1));
    });

    test('read state survives a re-sync', () async {
      await seed(stock: 2);
      await sync();
      await notificationStore.markAllRead();
      expect(notificationStore.unreadCount, 0);

      // Same fact, same day → the throttle must not reset it to unread.
      await sync();
      expect(notificationStore.unreadCount, 0);
      expect(active(kLowStock), hasLength(1));
    });
  });
}
