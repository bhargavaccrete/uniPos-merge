// TEMPORARY benchmark for the POS-2 step series. Delete when POS-2 ends.
// 1,000 items / 40 categories, Keep Categories Open ON, return-to-menu path.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
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

const int kN = int.fromEnvironment('N', defaultValue: 1000);
const int kC = int.fromEnvironment('C', defaultValue: 40);

void main() {
  late Directory tempDir;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('step_');
  });

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('return to menu with Keep Categories Open ON', (tester) async {
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

      final cats = Hive.box<Category>(HiveBoxNames.category);
      for (var c = 0; c < kC; c++) {
        await cats.put('cat$c', Category(id: 'cat$c', name: 'Cat $c'));
      }
      final map = <String, Items>{};
      for (var i = 0; i < 60; i++) {
        map['raw$i'] = Items(
            id: 'raw$i',
            name: 'Raw $i',
            categoryOfItem: 'cat0',
            productType: ProductType.rawMaterial,
            trackInventory: true,
            stockQuantity: 500);
      }
      for (var i = 0; i < kN; i++) {
        final isRecipe = i % 10 == 9;
        final hasVariants = !isRecipe && i % 10 < 3;
        map['item$i'] = Items(
          id: 'item$i',
          name: 'Paneer Butter Masala $i',
          categoryOfItem: 'cat${i % kC}',
          price: hasVariants ? null : 100.0 + i,
          imageBytes: Uint8List(64),
          isVeg: i.isEven ? 'veg' : 'non-veg',
          itemCode: i.isEven ? '${1000 + i}' : null,
          trackInventory: !isRecipe && i % 3 == 0,
          stockQuantity: 50,
          allowOrderWhenOutOfStock: false,
          isFavorite: i % 7 == 0,
          productType: isRecipe ? ProductType.recipeBased : null,
          variant: hasVariants
              ? [
                  ItemVariante(variantId: 'v1', price: 100, stockQuantity: 10),
                  ItemVariante(variantId: 'v2', price: 150, stockQuantity: 0),
                ]
              : const [],
        );
        if (isRecipe) {
          await Hive.box<RecipeModel>(HiveBoxNames.restaurantRecipes).put(
            'rec$i',
            RecipeModel(id: 'rec$i', itemId: 'item$i', ingredients: [
              for (var k = 0; k < 5; k++)
                RecipeIngredientModel(
                    ingredientItemId: 'raw${(i + k) % 60}', quantity: 1),
            ]),
          );
        }
      }
      await Hive.box<Items>(HiveBoxNames.restaurantItems).putAll(map);

      locator
        ..registerLazySingleton<ItemStore>(() => ItemStore(ItemRepository()))
        ..registerLazySingleton<CategoryStore>(
            () => CategoryStore(CategoryRepository()))
        ..registerLazySingleton<CartStoreRes>(
            () => CartStoreRes(CartRepository()))
        ..registerLazySingleton<RecipeRepository>(() => RecipeRepository());
      await AppSettings.updateSetting(
          'Keep Categories Open', const bool.fromEnvironment('OPEN_AT_MOUNT'));
      await itemStore.ensureLoaded();
      await categoryStore.ensureLoaded();
      await restaurantCartStore.addToCart(CartItem(
          id: 'line0', title: 'x', price: 100, quantity: 1, productId: 'item1'));
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final mountSw = Stopwatch()..start();
    await tester.pumpWidget(const MaterialApp(home: MenuScreen()));
    final mountFrame = mountSw.elapsedMicroseconds / 1000.0;
    for (var i = 0; i < 10; i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    if (const bool.fromEnvironment('OPEN_AT_MOUNT')) {
      // Fresh open with the setting already ON — no toggle, no covering route.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      var settle = 0.0;
      final sw2 = Stopwatch();
      for (var i = 0; i < 40; i++) {
        sw2..reset()..start();
        await tester.pump(const Duration(milliseconds: 16));
        settle += sw2.elapsedMicroseconds / 1000.0;
      }
      print('STEP | freshOpen mountFrame=${mountFrame.toStringAsFixed(0)}ms '
          'settleCpu=${settle.toStringAsFixed(0)}ms '
          'tiles=${find.byType(GestureDetector).evaluate().length}');
      await tester.pump(const Duration(seconds: 11));
      return;
    }
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('customization')))));
    await tester.pumpAndSettle();
    await AppSettings.updateSetting('Keep Categories Open', true);
    await tester.pumpAndSettle();

    var widgets = 0;
    final prev = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (e, builtOnce) => widgets++;

    var build = 0.0, layout = 0.0, rest = 0.0, worst = 0.0, frames = 0;
    final firstFrames = <double>[];
    final sw = Stopwatch();
    nav.pop();
    var first = true;
    while (frames < 300 && (first || tester.binding.hasScheduledFrame)) {
      first = false;
      sw
        ..reset()
        ..start();
      await tester.pump(const Duration(milliseconds: 16), EnginePhase.build);
      final b = sw.elapsedMicroseconds / 1000.0;
      sw
        ..reset()
        ..start();
      await tester.pump(Duration.zero, EnginePhase.layout);
      final l = sw.elapsedMicroseconds / 1000.0;
      sw
        ..reset()
        ..start();
      await tester.pump(Duration.zero);
      final r = sw.elapsedMicroseconds / 1000.0;
      build += b;
      layout += l;
      rest += r;
      if (b + l + r > worst) worst = b + l + r;
      firstFrames.add(b + l + r);
      frames++;
    }
    debugOnRebuildDirtyWidget = prev;

    final firstBuild = firstFrames.isEmpty ? 0.0 : firstFrames.first;
    print('STEP | firstFrame=${firstBuild.toStringAsFixed(0)}ms widgets=$widgets frames=$frames '
        'build=${build.toStringAsFixed(0)}ms layout=${layout.toStringAsFixed(0)}ms '
        'rest=${rest.toStringAsFixed(0)}ms '
        'total=${(build + layout + rest).toStringAsFixed(0)}ms '
        'worstFrame=${worst.toStringAsFixed(0)}ms');

    // Does the staged drain finish? Settle fully, then count what is on screen.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    print('STEP | afterSettle tilesOnScreen='
        '${find.byType(GestureDetector).evaluate().length}');
    await tester.pump(const Duration(seconds: 11));
  });
}
