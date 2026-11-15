import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/data/repositories/common/notification_repository.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart';
import 'package:billberrylite/data/repositories/retail/sale_item_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/services/retail/checkout_customer_posting.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/domain/services/retail/retail_checkout_commit.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/common/notification_store.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/domain/store/retail/cart_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';

import '../../../helpers/open_retail_day_fixture.dart';

/// A process stopping at that exact point. Nothing after it runs; the test
/// then "restarts" (every box closed, locator reset, reopened from disk).
class _Crash implements Exception {}

class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// Stops just before / just after one variant's stock write.
class _CrashingProducts extends ProductStore {
  String? crashBeforeWrite;
  String? crashAfterWrite;

  @override
  Future<void> updateVariantStock(String variantId, double newStock) async {
    if (crashBeforeWrite == variantId) {
      crashBeforeWrite = null;
      throw _Crash();
    }
    await super.updateVariantStock(variantId, newStock);
    if (crashAfterWrite == variantId) {
      crashAfterWrite = null;
      throw _Crash();
    }
  }
}

/// Stops just before / just after one customer step's write.
class _CrashingCustomers extends CustomerStore {
  _CrashingCustomers() : super(CustomerRepository());
  String? crashBefore;
  String? crashAfter;

  Future<void> _around(String step, Future<void> Function() write) async {
    if (crashBefore == step) {
      crashBefore = null;
      throw _Crash();
    }
    await write();
    if (crashAfter == step) {
      crashAfter = null;
      throw _Crash();
    }
  }

  @override
  Future<void> updateAfterPurchase(String customerId, double amount, int points) =>
      _around('purchase', () => super.updateAfterPurchase(customerId, amount, points));

  @override
  Future<void> addCredit(String customerId, double amount) =>
      _around('credit', () => super.addCredit(customerId, amount));

  @override
  Future<void> updateAfterCreditSale(String customerId, double amount) =>
      _around('creditSale', () => super.updateAfterCreditSale(customerId, amount));

  @override
  Future<void> redeemCustomerPoints(String customerId, int points) =>
      _around('redeem', () => super.redeemCustomerPoints(customerId, points));
}

/// The header lands, then the in-memory part of the save throws.
class _StatsFailSales extends SaleStore {
  @override
  Future<void> addSaleWithItems(SaleModel sale, List<SaleItemModel> items) async {
    await super.addSaleWithItems(sale, items);
    throw StateError('stats reload failed');
  }
}

/// The lines land, then the header write fails.
class _HeaderFailSales extends SaleStore {
  @override
  Future<void> addSaleWithItems(SaleModel sale, List<SaleItemModel> items) async {
    await SaleItemRepository().addSaleItems(items);
    throw StateError('disk full');
  }
}

/// BLK-13B: a Retail sale saved but not finished is finished exactly once —
/// by a retry, or by startup recovery after a crash at ANY point — and a sale
/// that never landed charges nothing and keeps the cart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const now = '2026-01-01T00:00:00.000';

  late _CrashingProducts products;
  late _CrashingCustomers customers;

  Future<void> openWorld({SaleStore Function()? sales}) async {
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await AppConfig.init();
    await AppConfig.box.put('businessMode', 'retail');
    for (final open in [
      () => Hive.openBox<ProductModel>(HiveBoxNames.products),
      () => Hive.openBox<VarianteModel>(HiveBoxNames.variants),
      () => Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles),
      () => Hive.openBox<CartItemModel>(HiveBoxNames.cartItems),
      () => Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs),
      () => Hive.openBox<SaleModel>(HiveBoxNames.sales),
      () => Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems),
      () => Hive.openBox<Customer>(HiveBoxNames.customer),
      () => Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements),
      () => Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications),
      () => Hive.openBox<AttributeModel>(HiveBoxNames.attributes),
      () => Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues),
      () => Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes),
      () => Hive.openBox(HiveBoxNames.dayManagementBox),
      () => Hive.openBox(HiveBoxNames.appCounters),
      () => Hive.openBox(HiveBoxNames.retailCheckoutJournal),
    ]) {
      await open();
    }
    products = _CrashingProducts();
    customers = _CrashingCustomers();
    locator
      ..registerSingleton<ProductStore>(products)
      ..registerSingleton<BundleRepository>(BundleRepository())
      ..registerSingleton<AuthService>(AuthService())
      ..registerSingleton<CustomerStore>(customers)
      ..registerSingleton<GstService>(GstService())
      ..registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness())
      ..registerSingleton<AttributeStore>(AttributeStore())
      ..registerSingleton<SaleStore>(sales?.call() ?? SaleStore())
      ..registerSingleton<NotificationStore>(
          NotificationStore(NotificationRepository()))
      ..registerLazySingleton<CartStore>(() => CartStore(CartRepository()));
    await products.ensureLoaded();
  }

  /// A fresh app process: only what is on disk survives.
  Future<void> restart({SaleStore Function()? sales}) async {
    await locator.reset();
    await Hive.close();
    await openWorld(sales: sales);
  }

  CartItemModel line(String id, String variantId, String productId, double qty) =>
      CartItemModel(
        cartItemId: id,
        variantId: variantId,
        productId: productId,
        productName: productId,
        price: 100,
        qty: qty,
        total: 100 * qty,
        addedAt: now,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('retail_checkout_commit_');
    await openWorld();
    await openRetailDayForTest();

    Future<void> item(String id, double stock, {String? mode}) async {
      await products.addProduct(ProductModel(
          productId: 'p$id', productName: id, category: '', hasVariants: false,
          createdAt: now, updateAt: now, stockMode: mode));
      await products.addVariant(VarianteModel(
          varianteId: id, productId: 'p$id', stockQty: stock, createdAt: now,
          status: 'active'));
    }

    await item('v1', 10);
    await item('mug', 10);
    await item('tea', 10);
    await item('combo', 0, mode: 'bundle');
    await BundleRepository().saveBundle(RetailBundleModel(
      id: 'b1',
      productId: 'pcombo',
      variantId: 'combo',
      components: [
        BundleComponentModel(componentVariantId: 'mug', quantity: 1),
        BundleComponentModel(componentVariantId: 'tea', quantity: 2),
      ],
      createdAt: now,
      updatedAt: now,
    ));

    await Hive.box<Customer>(HiveBoxNames.customer).put(
      'C1',
      Customer(
        customerId: 'C1',
        name: 'Asha',
        phone: '9999999999',
        loyaltyPoints: 50,
        createdAt: now,
      ),
    );

    // Tab 1 holds the sale's lines; Tab 2 another customer's bill.
    final sold = [line('c1', 'v1', 'pv1', 2), line('c2', 'combo', 'pcombo', 1)];
    final other = [line('c9', 'v1', 'pv1', 1)];
    final tabs = Hive.box<BillingTabModel>(HiveBoxNames.billingTabs);
    await tabs.put('T1', BillingTabModel(
        id: 'T1', name: 'Tab 1', items: sold,
        createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    await tabs.put('T2', BillingTabModel(
        id: 'T2', name: 'Tab 2', items: other,
        createdAt: DateTime(2026), updatedAt: DateTime(2026)));
    for (final l in sold) {
      await Hive.box<CartItemModel>(HiveBoxNames.cartItems).put(l.cartItemId, l);
    }
    await restart();
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ── Reading the world ──────────────────────────────────────────────────

  double stock(String v) => Hive.box<VarianteModel>(HiveBoxNames.variants).get(v)!.stockQty;
  Customer asha() => Hive.box<Customer>(HiveBoxNames.customer).get('C1')!;
  /// This sale's rows only (seeding the catalogue logs opening stock).
  List<StockMovementModel> rows() =>
      Hive.box<StockMovementModel>(HiveBoxNames.restaurantStockMovements)
          .values
          .where((r) => r.id.startsWith('sale_S1_'))
          .toList();
  int journal() => Hive.box(HiveBoxNames.retailCheckoutJournal).length;
  List<String> tabLines(String tab) => [
        for (final l in Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).get(tab)!.items)
          l.cartItemId,
      ];
  int sales() => Hive.box<SaleModel>(HiveBoxNames.sales).length;
  int saleLines() => Hive.box<SaleItemModel>(HiveBoxNames.saleItems).length;
  int events(String code) => Hive.box<AppNotificationModel>(HiveBoxNames.appNotifications)
      .values
      .where((n) => n.eventCode == code)
      .length;

  String snapshot() => [
        stock('v1'), stock('mug'), stock('tea'),
        asha().creditBalance, asha().loyaltyPoints, asha().totalPointEarned,
        asha().totalPointRedeemed, asha().totalPurchaseAmount, asha().totalVisites,
        rows().length, journal(), tabLines('T1'), tabLines('T2'), sales(), saleLines(),
      ].join('|');

  // ── The sale ───────────────────────────────────────────────────────────

  List<CartItemModel> soldLines() =>
      Hive.box<BillingTabModel>(HiveBoxNames.billingTabs).get('T1')!.items.toList();

  SaleModel sale() => SaleModel.create(
        saleId: 'S1',
        customerId: 'C1',
        totalItems: 3,
        subtotal: 300,
        totalAmount: 300,
        paymentType: 'cash',
        grandTotal: 300,
      );

  List<SaleItemModel> saleItems() => [
        for (final l in soldLines())
          SaleItemModel.create(
            saleId: 'S1',
            varianteId: l.variantId,
            productId: l.productId,
            productName: l.productName,
            price: l.price,
            qty: l.qty,
          ),
      ];

  /// Part paid: 20 points spent, ₹100 on credit, ₹300 purchase, 3 earned.
  CheckoutCustomerPosting paidPosting() => CheckoutCustomerPosting.paidSale(
        customerId: 'C1',
        pointsRedeemed: 20,
        dueAmount: 100,
        grandTotal: 300,
        pointsEarned: 3,
      );

  /// What a finished sale leaves: v1 −2, the combo's mug −1 / tea −2, three
  /// rows, the customer posted once, Tab 1 empty, Tab 2 untouched.
  void expectFinishedOnce() {
    expect(stock('v1'), 8, reason: 'v1 deducted once');
    expect(stock('mug'), 9, reason: 'bundle component deducted once');
    expect(stock('tea'), 8, reason: 'bundle component deducted once');
    expect(rows(), hasLength(3), reason: 'one row per stock write');
    expect(asha().creditBalance, 100, reason: 'credit once');
    expect(asha().loyaltyPoints, 50 - 20 + 3, reason: 'points once');
    expect(asha().totalPointRedeemed, 20);
    expect(asha().totalPurchaseAmount, 300, reason: 'purchase once');
    expect(asha().totalVisites, 1, reason: 'visit once');
    expect(tabLines('T1'), isEmpty, reason: 'the sold cart cannot bill again');
    expect(tabLines('T2'), ['c9'], reason: 'another bill is untouched');
    expect(sales(), 1, reason: 'one sale');
    expect(journal(), 0, reason: 'nothing left to finish');
  }

  /// The screen's sequence, stopping wherever a test made a store crash.
  Future<RetailCheckoutEntry> checkout({
    Future<void> Function()? clearCart,
  }) async {
    final entry = await RetailCheckoutCommit.begin(
      saleId: 'S1',
      invoiceNumber: 'INV-00001',
      tabId: 'T1',
      lines: soldLines(),
      posting: paidPosting(),
    );
    await RetailCheckoutCommit.saveSale(entry, sale(), saleItems());
    await RetailCheckoutCommit.finish(entry,
        clearCart: clearCart ?? retailCartStore.clearCartAndSave);
    return entry;
  }

  /// Recovers three times, restarting in between: identical every time.
  Future<void> recoverThrice() async {
    await restart();
    expect(await RetailCheckoutCommit.recoverAll(), isEmpty);
    final once = snapshot();
    for (var i = 0; i < 2; i++) {
      await restart();
      await RetailCheckoutCommit.recoverAll();
      expect(snapshot(), once, reason: 'recovery run ${i + 2} changed nothing');
    }
  }

  test('no interruption: finished once, journal empty', () async {
    await checkout();
    expectFinishedOnce();
  });

  group('a crash at every point is finished exactly once by recovery', () {
    final points = <String, void Function()>{
      'customer: before the points write': () => customers.crashBefore = 'redeem',
      'customer: after the points write': () => customers.crashAfter = 'redeem',
      'customer: after the credit write': () => customers.crashAfter = 'credit',
      'customer: before the purchase write': () => customers.crashBefore = 'purchase',
      'customer: after the purchase write': () => customers.crashAfter = 'purchase',
      'stock: before a plain line write': () => products.crashBeforeWrite = 'v1',
      'stock: after a plain line write, before its row': () =>
          products.crashAfterWrite = 'v1',
      'stock: before a bundle component write': () =>
          products.crashBeforeWrite = 'tea',
      'stock: after a bundle component write, before its row': () =>
          products.crashAfterWrite = 'mug',
    };
    for (final point in points.entries) {
      test(point.key, () async {
        point.value();
        await expectLater(checkout(), throwsA(isA<_Crash>()));
        await recoverThrice();
        expectFinishedOnce();
        expect(events(RetailCheckoutCommit.recoveredEvent), 1,
            reason: 'the cashier is told once that the sale was finished');
      });
    }

    test('after the header, before any customer or stock work', () async {
      final entry = await RetailCheckoutCommit.begin(
        saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
        lines: soldLines(), posting: paidPosting());
      await RetailCheckoutCommit.saveSale(entry, sale(), saleItems());
      await recoverThrice();
      expectFinishedOnce();
    });

    test('before the cart was cleared', () async {
      await expectLater(
          checkout(clearCart: () async => throw _Crash()), throwsA(isA<_Crash>()));
      await recoverThrice();
      expectFinishedOnce();
    });

    test('after the cart was cleared, before the entry was removed', () async {
      await expectLater(
        checkout(clearCart: () async {
          await retailCartStore.clearCartAndSave();
          throw _Crash();
        }),
        throwsA(isA<_Crash>()),
      );
      await recoverThrice();
      expectFinishedOnce();
    });

    test('a retry in the same session after a failure finishes it once', () async {
      products.crashAfterWrite = 'v1';
      late RetailCheckoutEntry entry;
      final begun = await RetailCheckoutCommit.begin(
        saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
        lines: soldLines(), posting: paidPosting());
      await RetailCheckoutCommit.saveSale(begun, sale(), saleItems());
      entry = begun;
      await expectLater(
          RetailCheckoutCommit.finish(entry, clearCart: retailCartStore.clearCartAndSave),
          throwsA(isA<_Crash>()));
      await RetailCheckoutCommit.finish(entry, clearCart: retailCartStore.clearCartAndSave);
      expectFinishedOnce();
    });
  });

  group('a sale that never landed', () {
    test('entry only: discarded, nothing charged, the cart kept', () async {
      final before = snapshot();
      await RetailCheckoutCommit.begin(
        saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
        lines: soldLines(), posting: paidPosting());
      await restart();
      await RetailCheckoutCommit.recoverAll();
      expect(snapshot(), before);
      expect(tabLines('T1'), ['c1', 'c2'], reason: 'the cashier can still bill it');
    });

    test('lines written, header not: orphan lines removed, nothing charged', () async {
      await RetailCheckoutCommit.begin(
        saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
        lines: soldLines(), posting: paidPosting());
      await SaleItemRepository().addSaleItems(saleItems());
      expect(saleLines(), 2);
      await recoverThrice();
      expect(saleLines(), 0);
      expect(sales(), 0);
      expect(stock('v1'), 10);
      expect(asha().creditBalance, 0);
      expect(asha().totalVisites, 0);
      expect(tabLines('T1'), ['c1', 'c2']);
      expect(journal(), 0);
    });

    test('a header write that fails is rethrown; entry and lines removed', () async {
      await restart(sales: () => _HeaderFailSales());
      final entry = await RetailCheckoutCommit.begin(
        saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
        lines: soldLines(), posting: paidPosting());
      await expectLater(RetailCheckoutCommit.saveSale(entry, sale(), saleItems()),
          throwsA(isA<StateError>()));
      expect(journal(), 0);
      expect(saleLines(), 0);
      expect(sales(), 0);
    });

    test('a failure AFTER the header is not a lost sale: no second sale', () async {
      await restart(sales: () => _StatsFailSales());
      final entry = await RetailCheckoutCommit.begin(
        saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
        lines: soldLines(), posting: paidPosting());
      await RetailCheckoutCommit.saveSale(entry, sale(), saleItems());
      await RetailCheckoutCommit.finish(entry, clearCart: retailCartStore.clearCartAndSave);
      expectFinishedOnce();
    });
  });

  group('customer recovery: judged only by before / expected after', () {
    Future<void> crashAfterPurchaseWrite() async {
      customers.crashAfter = 'purchase';
      await expectLater(checkout(), throwsA(isA<_Crash>()));
    }

    Future<void> crashBeforePurchaseWrite() async {
      customers.crashBefore = 'purchase';
      await expectLater(checkout(), throwsA(isA<_Crash>()));
    }

    test('an unrelated edit (name, limit) after the write: not applied again', () async {
      await crashAfterPurchaseWrite();
      final c = asha();
      await Hive.box<Customer>(HiveBoxNames.customer)
          .put('C1', c.copyWith(name: 'Asha K', creditLimit: 5000));
      await recoverThrice();
      expectFinishedOnce();
      expect(events(RetailCheckoutCommit.customerCheckEvent), 0);
    });

    test('an unrelated edit before the write: applied once', () async {
      await crashBeforePurchaseWrite();
      final c = asha();
      await Hive.box<Customer>(HiveBoxNames.customer)
          .put('C1', c.copyWith(name: 'Asha K', phone: '8888888888'));
      await recoverThrice();
      expectFinishedOnce();
      expect(events(RetailCheckoutCommit.customerCheckEvent), 0);
    });

    test('a tracked field moved by something else: never guessed', () async {
      await crashBeforePurchaseWrite();
      // Another write moved the purchase total after the stop.
      final c = asha();
      await Hive.box<Customer>(HiveBoxNames.customer)
          .put('C1', c.copyWith(totalPurchaseAmount: c.totalPurchaseAmount + 999));
      final moved = asha();
      await recoverThrice();

      expect(asha().totalPurchaseAmount, moved.totalPurchaseAmount,
          reason: 'the step is not applied on top of an unknown change');
      expect(asha().totalVisites, moved.totalVisites);
      expect(asha().loyaltyPoints, moved.loyaltyPoints);
      expect(events(RetailCheckoutCommit.customerCheckEvent), 1,
          reason: 'reported once, for a person to check');
      expect(journal(), 1, reason: 'kept as the record of what to check');
      // Everything else still finished, so the cart cannot bill again.
      expect(stock('v1'), 8);
      expect(stock('mug'), 9);
      expect(tabLines('T1'), isEmpty);
      expect(sales(), 1);
    });

    test('a tracked field moved after the write: not treated as applied twice',
        () async {
      await crashAfterPurchaseWrite();
      final c = asha();
      await Hive.box<Customer>(HiveBoxNames.customer)
          .put('C1', c.copyWith(totalVisites: c.totalVisites + 1));
      final moved = asha();
      await recoverThrice();
      expect(asha().totalVisites, moved.totalVisites, reason: 'no second visit');
      expect(asha().totalPurchaseAmount, moved.totalPurchaseAmount);
      expect(events(RetailCheckoutCommit.customerCheckEvent), 1);
    });
  });

  test('stock moved by something else after a stop: reported, never written',
      () async {
    products.crashAfterWrite = 'v1';
    await expectLater(checkout(), throwsA(isA<_Crash>()));
    // v1 was written to 8; something else then sets it to 5.
    await products.updateVariantStock('v1', 5);
    await recoverThrice();
    expect(stock('v1'), 5, reason: 'not written again');
    expect(rows().where((r) => r.variantId == 'v1'), isEmpty,
        reason: 'no row for a write it could not confirm');
    expect(events('stock_check_needed'), 1);
    expect(stock('mug'), 9, reason: 'the rest still finished');
    expect(tabLines('T1'), isEmpty);
    expect(journal(), 1, reason: 'kept as the record of what to check');
  });

  test('recovery takes only the sold lines off the tab', () async {
    customers.crashAfter = 'purchase';
    await expectLater(checkout(), throwsA(isA<_Crash>()));
    // A line on the same tab that is NOT part of the saved sale.
    final tabs = Hive.box<BillingTabModel>(HiveBoxNames.billingTabs);
    final t1 = tabs.get('T1')!;
    await tabs.put('T1', t1.copyWith(items: [
      ...t1.items,
      line('c3', 'v1', 'pv1', 1),
    ]));
    await recoverThrice();
    expect(tabLines('T1'), ['c3'], reason: 'only what was sold is removed');
    expect(stock('v1'), 8, reason: 'c3 was never sold');
    expect(tabLines('T2'), ['c9']);
  });

  test('a successful sale leaves the journal entry format readable', () async {
    final entry = await RetailCheckoutCommit.begin(
      saleId: 'S1', invoiceNumber: 'INV-00001', tabId: 'T1',
      lines: soldLines(), posting: paidPosting());
    final read = RetailCheckoutCommit.pending().single;
    expect(read.toMap(), entry.toMap());
    expect(read.lines.map((l) => l.cartItemId), ['c1', 'c2']);
  });
}
