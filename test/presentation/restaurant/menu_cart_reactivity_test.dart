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
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cart_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/menu.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

/// The menu's item tiles no longer receive a cart snapshot from the screen —
/// each tile observes its OWN cart state (`CartStoreRes.cartStateFor`) so a
/// cart write repaints the tiles that changed instead of every category
/// section. These tests pin the behaviour that optimisation must not break:
/// the badge, the per-variant breakdown and the cart bar still update on the
/// very next frame after an add / quantity change / removal.
void main() {
  late Directory tempDir;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('menu_cart_reactivity_');
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async {
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
      await AppConfig.init();
      await AppConfig.box.put('businessMode', 'restaurant');
      await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
      await Hive.openBox<Category>(HiveBoxNames.category);
      await Hive.openBox<CartItem>(HiveBoxNames.restaurantCart);
      await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
      await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
      await Hive.openBox(HiveBoxNames.dayManagementBox);

      await Hive.box<Category>(HiveBoxNames.category)
          .put('cat1', Category(id: 'cat1', name: 'Starters'));
      await Hive.box<Items>(HiveBoxNames.restaurantItems).putAll({
        'i1': Items(
          id: 'i1',
          name: 'Paneer Tikka',
          categoryOfItem: 'cat1',
          price: 200,
          trackInventory: true,
          stockQuantity: 25,
        ),
        'i2': Items(
          id: 'i2',
          name: 'Veg Soup',
          categoryOfItem: 'cat1',
          price: 120,
        ),
      });

      locator
        ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
        ..registerLazySingleton<CategoryStore>(
            () => CategoryStore(CategoryRepository()))
        ..registerLazySingleton<CartStoreRes>(
            () => CartStoreRes(CartRepository()))
        ..registerLazySingleton<RecipeRepository>(() => RecipeRepository());

      // Sections start expanded, so the tiles are on screen without tapping.
      await AppSettings.updateSetting('Keep Categories Open', true);
      await itemStore.ensureLoaded();
      await categoryStore.ensureLoaded();
      // Warm-up write. Hive's first write to a box from inside
      // `tester.runAsync` (after the fake-async zone exists) never settles, so
      // the cart box is opened for writing here, while the harness is still in
      // the real zone. Test-harness plumbing only — no product behaviour.
      await restaurantCartStore.addToCart(CartItem(
        id: 'warmup',
        title: 'Paneer Tikka',
        price: 200,
        quantity: 1,
        productId: 'i1',
      ));
      await restaurantCartStore.clearCart();
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MenuScreen()));
    for (var i = 0; i < 8; i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// One frame is enough: the tile reacts, nothing has to be reloaded.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  CartItem line(String id, String productId, {int qty = 1, String? variant}) =>
      CartItem(
        id: id,
        title: 'Paneer Tikka',
        price: 200,
        quantity: qty,
        productId: productId,
        variantName: variant,
      );

  testWidgets('adding an item shows its in-cart badge and the cart bar',
      (tester) async {
    await boot(tester);
    expect(find.textContaining('in cart'), findsNothing);
    expect(find.text('View Cart'), findsNothing);
    await tester.runAsync(() => restaurantCartStore.addToCart(line('l1', 'i1')));
    await settle(tester);

    expect(find.text('1 in cart'), findsOneWidget);
    // Cart bar: count and total.
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('View Cart'), findsOneWidget);
    expect(find.textContaining('200'), findsWidgets);
  });

  testWidgets('quantity increase and decrease update the badge immediately',
      (tester) async {
    await boot(tester);
    await tester.runAsync(() => restaurantCartStore.addToCart(line('l1', 'i1')));
    await settle(tester);

    await tester
        .runAsync(() => restaurantCartStore.updateQuantity('l1', 3));
    await settle(tester);
    expect(find.text('3 in cart'), findsOneWidget);
    // Cart bar total, which is unique on screen — the "N items" count collides
    // with the category subtitle ("Starters · 2 items").
    expect(find.textContaining('600'), findsOneWidget);

    await tester
        .runAsync(() => restaurantCartStore.updateQuantity('l1', 2));
    await settle(tester);
    expect(find.text('2 in cart'), findsOneWidget);
    expect(find.textContaining('400'), findsOneWidget);
  });

  testWidgets('removing the line clears the badge and the cart bar',
      (tester) async {
    await boot(tester);
    await tester.runAsync(() => restaurantCartStore.addToCart(line('l1', 'i1')));
    await settle(tester);
    expect(find.text('1 in cart'), findsOneWidget);

    await tester.runAsync(() => restaurantCartStore.removeFromCart('l1'));
    await settle(tester);

    expect(find.textContaining('in cart'), findsNothing);
    expect(find.text('View Cart'), findsNothing);
  });

  testWidgets('a cart line with a variant shows the per-variant breakdown',
      (tester) async {
    await boot(tester);
    await tester.runAsync(() =>
        restaurantCartStore.addToCart(line('l1', 'i1', variant: 'Large')));
    await tester.runAsync(() => restaurantCartStore
        .addToCart(line('l2', 'i1', qty: 2, variant: 'Regular')));
    await settle(tester);

    expect(find.text('Large ×1, Regular ×2'), findsOneWidget);
  });

  testWidgets('one item changing leaves the other item\'s cart state identical',
      (tester) async {
    await boot(tester);
    // This is what keeps the optimisation honest: `cartStateFor` must produce
    // an EQUAL value for untouched items, or MobX would notify every tile and
    // the whole menu would rebuild again.
    final before = restaurantCartStore.cartStateFor('i2').value;
    await tester.runAsync(() => restaurantCartStore.addToCart(line('l1', 'i1')));
    await settle(tester);

    expect(restaurantCartStore.cartStateFor('i2').value, before);
    expect(restaurantCartStore.cartStateFor('i1').value.quantity, 1);
  });

  testWidgets('tapping the favourite star does not fall through to the tile',
      (tester) async {
    await boot(tester);
    // The star is a GestureDetector (not an InkWell). Its tap target must
    // still swallow the tap, including over its padding — if it fell through,
    // the tile's own onTap would add the item to the cart.
    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await settle(tester);

    expect(restaurantCartStore.cartItems, isEmpty);
    expect(find.textContaining('in cart'), findsNothing);
  });

  testWidgets('cart operations do not change item stock', (tester) async {
    await boot(tester);
    final stockBefore = itemStore.getItemById('i1')!.stockQuantity;

    await tester.runAsync(() => restaurantCartStore.addToCart(line('l1', 'i1')));
    await tester.runAsync(() => restaurantCartStore.updateQuantity('l1', 4));
    await tester.runAsync(() => restaurantCartStore.removeFromCart('l1'));
    await settle(tester);

    // Stock is deducted when the ORDER is placed, never by the cart itself.
    expect(itemStore.getItemById('i1')!.stockQuantity, stockBefore);
    expect(
      Hive.box<Items>(HiveBoxNames.restaurantItems).get('i1')!.stockQuantity,
      stockBefore,
    );
  });
}
