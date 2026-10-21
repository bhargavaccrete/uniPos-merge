import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/domain/store/retail/attribute_store.dart';
import 'package:billberrylite/data/repositories/common/customer_repository.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/cart_repository.dart';
import 'package:billberrylite/domain/services/retail/auth_service.dart';
import 'package:billberrylite/domain/store/retail/cart_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';

/// Same fake as cart_calculation_service_test: tax off, no Hive box needed.
class _NoTaxBusiness extends BusinessDetailsRepository {
  @override
  bool get isTaxEnabled => false;
}

/// R-15 in docs/modules/retail_inventory.md: each open bill saw the whole
/// shelf, and checkout never re-checked, so two tabs (or a bundle and its own
/// component) could sell the same units.
void main() {
  late Directory tempDir;
  late ProductStore products;
  late BundleRepository bundles;
  late CartStore cart;
  const now = '2026-01-01T00:00:00.000';

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('cart_stock_check_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    for (final open in [
      () => Hive.openBox<ProductModel>(HiveBoxNames.products),
      () => Hive.openBox<VarianteModel>(HiveBoxNames.variants),
      () => Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles),
      () => Hive.openBox<CartItemModel>(HiveBoxNames.cartItems),
      () => Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs),
      () => Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements),
      () => Hive.openBox(HiveBoxNames.dayManagementBox),
      () => Hive.openBox<Customer>(HiveBoxNames.customer),
      () => Hive.openBox<AttributeModel>(HiveBoxNames.attributes),
      () => Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues),
      () => Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes),
    ]) {
      await open();
    }

    await locator.reset();
    products = ProductStore();
    bundles = BundleRepository();
    locator.registerSingleton<ProductStore>(products);
    locator.registerSingleton<BundleRepository>(bundles);
    locator.registerSingleton<AuthService>(AuthService());
    // The cart drops the attached customer when it resets a bill.
    locator.registerSingleton<CustomerStore>(CustomerStore(CustomerRepository()));
    locator.registerSingleton<GstService>(GstService()); // tax mode, from prefs
    // A successful add resolves tax through TaxFeature → this repository.
    locator.registerSingleton<BusinessDetailsRepository>(_NoTaxBusiness());
    // …and resolves the line's descriptors through the attribute catalogue.
    locator.registerSingleton<AttributeStore>(AttributeStore());
    cart = CartStore(CartRepository());

    Future<void> item(String id, double stock, {String? mode, bool allow = false}) async {
      await products.addProduct(ProductModel(
          productId: 'p$id', productName: id, category: '', hasVariants: false,
          createdAt: now, updateAt: now, stockMode: mode,
          allowOrderWhenOutOfStock: allow));
      await products.addVariant(VarianteModel(
          varianteId: id, productId: 'p$id', stockQty: stock, createdAt: now,
          status: 'active'));
    }

    await item('mug', 3);
    await item('tea', 10);
    await item('loose', 0, allow: true);
    await item('combo', 0, mode: 'bundle');
    await bundles.saveBundle(RetailBundleModel(
      id: 'b', productId: 'pcombo', variantId: 'combo',
      components: [BundleComponentModel(componentVariantId: 'mug', quantity: 1)],
      createdAt: now, updatedAt: now,
    ));
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CartItemModel line(String id, double qty) => CartItemModel.create(
      cartItemId: 'c-$id-$qty', variantId: id, productId: 'p$id',
      productName: id, price: 10, qty: qty);

  group('cart gate sees other open bills', () {
    test('another tab holding every unit refuses the add here', () async {
      cart.tabs.add(BillingTabModel(
          id: 'other', name: 'Tab 2', items: [line('mug', 3)],
          createdAt: DateTime.now(), updatedAt: DateTime.now()));

      final r = await cart.addItem(
          products.getProductById('pmug')!, (await products.getVariantById('mug'))!);

      expect(r.success, isFalse);
      expect(cart.items, isEmpty);
    });

    test('another tab holding 2 of 3 leaves 1 addable, not 2', () async {
      cart.tabs.add(BillingTabModel(
          id: 'other', name: 'Tab 2', items: [line('mug', 2)],
          createdAt: DateTime.now(), updatedAt: DateTime.now()));

      final r = await cart.addItem(products.getProductById('pmug')!,
          (await products.getVariantById('mug'))!, qty: 2);

      expect(r.success, isFalse);
      expect(r.availableStock, 1);
    });
  });

  group('R-16 restoring a parked sale', () {
    test('ignoreStock brings a short line back instead of dropping it', () async {
      // Parked 3 mugs; 2 have sold since.
      await products.updateVariantStock('mug', 1);

      final r = await cart.addItem(products.getProductById('pmug')!,
          (await products.getVariantById('mug'))!, qty: 3, ignoreStock: true);

      expect(r.success, isTrue);
      expect(cart.items.single.qty, 3);
      // …and checkout, not restore, is where the shortfall is enforced.
      expect((await cart.checkoutShortfalls()).single,
          contains('need 3, 1 in stock'));
    });

    test('ignoreStock still refuses a bundle with no components', () async {
      await products.addProduct(ProductModel(
          productId: 'pempty', productName: 'empty', category: '',
          hasVariants: false, createdAt: now, updateAt: now,
          stockMode: 'bundle'));
      await products.addVariant(VarianteModel(
          varianteId: 'empty', productId: 'pempty', stockQty: 0,
          createdAt: now, status: 'active'));

      final r = await cart.addItem(products.getProductById('pempty')!,
          (await products.getVariantById('empty'))!, ignoreStock: true);

      expect(r.success, isFalse);
    });
  });

  group('R-28 deleting what a bundle uses', () {
    test('a variant used as a component is reported by name', () {
      expect(products.bundlesUsing(['mug']), ['combo']);
      expect(products.bundlesUsing(['tea']), isEmpty);
    });

    test('deleting a bundle product drops its own recipe row', () async {
      expect(bundles.getBundleForVariant('combo'), isNotNull);

      await products.deleteProduct('pcombo');

      expect(bundles.getBundleForVariant('combo'), isNull);
      expect(products.bundlesUsing(['mug']), isEmpty,
          reason: 'mug is free to delete once its only bundle is gone');
    });

    test('deleting a variant drops its own recipe row', () async {
      await products.deleteVariant('combo');
      expect(bundles.getBundleForVariant('combo'), isNull);
    });
  });

  group('R-31 in-memory variant matches what was saved', () {
    test('a minted barcode reaches memory and survives a save from memory',
        () async {
      await Hive.openBox(HiveBoxNames.appCounters); // barcode sequence
      await products.addProduct(ProductModel(
          productId: 'pnew', productName: 'New', category: '',
          hasVariants: false, createdAt: now, updateAt: now));
      await products.addVariant(VarianteModel(
          varianteId: 'new', productId: 'pnew', stockQty: 0, createdAt: now,
          status: 'active')); // no barcode → the repository mints one

      final inMemory =
          products.variants.firstWhere((v) => v.varianteId == 'new');
      final minted = inMemory.barcode;
      expect(minted, isNotNull, reason: 'memory holds the minted code');

      // A save built from the in-memory copy (what Apply Tax does).
      await products.updateVariant(inMemory.copyWith(taxRate: 5));

      expect((await products.getVariantById('new'))!.barcode, minted,
          reason: 'the barcode is not written away');
    });
  });

  group('checkoutShortfalls', () {
    test('a cart within stock checks out', () async {
      cart.items.addAll([line('mug', 3), line('tea', 5)]);
      expect(await cart.checkoutShortfalls(), isEmpty);
    });

    test('stock sold by another bill since the add is caught', () async {
      cart.items.add(line('mug', 3));
      await products.updateVariantStock('mug', 1); // tab B checked out first

      final s = await cart.checkoutShortfalls();
      expect(s, hasLength(1));
      expect(s.single, contains('need 3, 1 in stock'));
    });

    test('a bundle and its own component are summed', () async {
      // 2 combos (2 mugs) + 2 loose mugs = 4 mugs against 3.
      cart.items.addAll([line('combo', 2), line('mug', 2)]);
      final s = await cart.checkoutShortfalls();
      expect(s.single, contains('need 4, 3 in stock'));
    });

    test('allow-when-out products are exempt', () async {
      cart.items.add(line('loose', 5));
      expect(await cart.checkoutShortfalls(), isEmpty);
    });

    test('quick items need no stock', () async {
      cart.items.add(CartItemModel.create(
          cartItemId: 'q', variantId: 'QUICK-1', productId: 'QUICK-1',
          productName: 'Misc', price: 5, qty: 9));
      expect(await cart.checkoutShortfalls(), isEmpty);
    });
  });
}
