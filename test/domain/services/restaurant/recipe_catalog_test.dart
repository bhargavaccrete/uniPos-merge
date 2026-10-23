import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/repositories/restaurant/recipe_repository.dart';
import 'package:billberrylite/domain/services/restaurant/recipe_catalog.dart';

/// Phase 1.5 — recipes are managed separately from product types: one recipe
/// per item, created for a Finished or Semi-Finished item, made only of Raw
/// Materials and Semi-Finished items (never a Trade Item).
void main() {
  Items item(String id, String? type, {String? prep}) =>
      Items(id: id, name: id, productType: type, prepMode: prep);
  RecipeModel recipe(String id, String itemId) => RecipeModel(
        id: id,
        itemId: itemId,
        ingredients: [RecipeIngredientModel(ingredientItemId: 'flour', quantity: 1)],
      );

  final items = [
    item('pizza', ProductType.finishedGood, prep: ProductType.madeToOrder),
    item('burger', 'recipeBased'), // legacy
    item('cake', ProductType.finishedGood, prep: ProductType.madeInAdvance),
    item('dough', ProductType.semiFinished),
    item('flour', ProductType.rawMaterial),
    item('coke', ProductType.tradeItem),
    item('tea', null), // legacy Finished, no recipe
  ];

  group('RecipeCatalog (pure)', () {
    test('Create Recipe offers Finished and Semi-Finished items without one',
        () {
      final ids = RecipeCatalog.itemsNeedingRecipe(
              items, [recipe('r1', 'burger'), recipe('r2', 'dough')])
          .map((i) => i.id);
      expect(ids, unorderedEquals(['pizza', 'cake', 'tea']));
    });

    test('the Recipes list shows each recipe once, for an item that can have '
        'one, by name', () {
      final entries = RecipeCatalog.entries(items, [
        recipe('r1', 'pizza'),
        recipe('r2', 'dough'),
        recipe('r3', 'coke'), // kept after a type change to Trade — hidden
        recipe('r4', 'ghost'), // item deleted — hidden
      ]);
      expect(entries.map((e) => e.item.id), ['dough', 'pizza']);
    });

    test('ingredients: Raw Material and Semi-Finished only — never a Trade '
        'Item or a Finished item, never itself', () {
      final ids = RecipeCatalog.ingredientCandidates(items, forItemId: 'dough')
          .map((i) => i.id);
      expect(ids, ['flour']);
      final forPizza = RecipeCatalog.ingredientCandidates(items, forItemId: 'pizza')
          .map((i) => i.id);
      expect(forPizza, unorderedEquals(['dough', 'flour']));
    });
  });

  group('RecipeRepository — one recipe per item', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recipe_catalog_');
      Hive.init(tempDir.path);
      await HiveInit.registerRestaurantAdapters();
      await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    });
    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('saving a second recipe for the same item replaces the first', () async {
      final repo = RecipeRepository();
      await repo.saveForItem(recipe('r1', 'pizza'));
      await repo.saveForItem(recipe('r2', 'pizza').copyWith(yieldQty: 2));

      final all = repo.getAllRecipes();
      expect(all.length, 1);
      expect(all.single.id, 'r1', reason: 'the existing row is kept');
      expect(all.single.yieldQty, 2, reason: 'with the new content');
    });

    test('recipes for different items stay separate', () async {
      final repo = RecipeRepository();
      await repo.saveForItem(recipe('r1', 'pizza'));
      await repo.saveForItem(recipe('r2', 'dough'));
      expect(repo.getAllRecipes().length, 2);
    });
  });
}
