import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/repositories/common/category_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/cart_repository.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/domain/store/common/category_store.dart';
import 'package:billberrylite/domain/store/restaurant/cart_store.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';

import '../helpers/test_helpers.dart';

/// Counts full Hive reads and can fail the next N of them.
class _CountingItemRepository extends ItemRepository {
  int reads = 0;
  int failNext = 0;
  Completer<void>? gate;

  @override
  Future<List<Items>> getAllItems() async {
    reads++;
    if (gate != null) await gate!.future;
    if (failNext > 0) {
      failNext--;
      throw StateError('simulated load failure');
    }
    return super.getAllItems();
  }
}

class _CountingCategoryRepository extends CategoryRepository {
  int reads = 0;
  int failNext = 0;
  Completer<void>? gate;

  @override
  Future<List<Category>> getAllCategories() async {
    reads++;
    if (gate != null) await gate!.future;
    if (failNext > 0) {
      failNext--;
      throw StateError('simulated load failure');
    }
    return super.getAllCategories();
  }
}

/// How the restaurant stores hydrate, which decides whether a caller's
/// `load*()` is load-bearing:
/// - ItemStore starts `loadItems()` in its constructor without awaiting it,
///   so a synchronous read right after creation sees an empty list.
/// - The cart store has no constructor load at all, so its list stays empty
///   until someone calls `loadCartItems()`.
/// - An empty list looks the same whether the store hasn't loaded yet or
///   there are genuinely no records, so `isEmpty` can't signal readiness.
/// - `ensureLoaded()` on ItemStore/CategoryStore is that signal: it waits for
///   the constructor's load without re-reading Hive, and retries if it failed.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('store_hydration_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<CartItem>(HiveBoxNames.restaurantCart);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('ItemStore constructor hydration', () {
    test('is empty synchronously after creation, full after a microtask',
        () async {
      await Hive.box<Items>(HiveBoxNames.restaurantItems)
          .put('tea', Items(id: 'tea', name: 'Tea'));

      final store = ItemStore(ItemRepository());
      expect(store.items, isEmpty,
          reason: 'a synchronous reader right after creation sees nothing');

      await Future<void>.delayed(Duration.zero);
      expect(store.items.map((i) => i.id), ['tea']);
    });

    test('an empty list cannot distinguish "not loaded" from "no items"',
        () async {
      final store = ItemStore(ItemRepository());
      final unloaded = store.items.isEmpty;
      await store.loadItems();
      final loadedButEmpty = store.items.isEmpty;

      expect(unloaded, isTrue);
      expect(loadedButEmpty, isTrue);
    });
  });

  group('ItemStore.ensureLoaded', () {
    setUp(() => Hive.box<Items>(HiveBoxNames.restaurantItems)
        .put('tea', Items(id: 'tea', name: 'Tea')));

    test('makes a cold store readable without a second Hive read', () async {
      final repo = _CountingItemRepository();
      final store = ItemStore(repo);

      await store.ensureLoaded();

      expect(store.items.map((i) => i.id), ['tea']);
      expect(repo.reads, 1, reason: 'awaits the constructor load, no re-read');

      await store.ensureLoaded();
      expect(repo.reads, 1, reason: 'already loaded: still no re-read');
    });

    test('waits for a slow initial load instead of returning early',
        () async {
      // With a truly async load, a bare `await` is not enough: ensureLoaded
      // must wait for the constructor's load itself.
      final repo = _CountingItemRepository()..gate = Completer<void>();
      final store = ItemStore(repo);
      var done = false;
      final wait = store.ensureLoaded().then((_) => done = true);

      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(store.items, isEmpty);

      repo.gate!.complete();
      await wait;
      expect(store.items.map((i) => i.id), ['tea']);
      expect(repo.reads, 1);
    });

    test('a failed initial load keeps its error and is retried', () async {
      final repo = _CountingItemRepository()..failNext = 1;
      final store = ItemStore(repo);
      await Future<void>.delayed(Duration.zero);
      expect(store.items, isEmpty);
      expect(store.errorMessage, contains('simulated load failure'));

      await store.ensureLoaded();

      expect(repo.reads, 2);
      expect(store.items.map((i) => i.id), ['tea']);
      expect(store.errorMessage, isNull);
    });
  });

  group('CategoryStore.ensureLoaded', () {
    setUp(() async {
      await AppConfig.init();
      await AppConfig.forceSetBusinessMode(BusinessMode.restaurant);
      await Hive.box<Category>(HiveBoxNames.category)
          .put('c1', Category(id: 'c1', name: 'Drinks'));
    });

    test('makes a cold store readable without a second Hive read', () async {
      final repo = _CountingCategoryRepository();
      final store = CategoryStore(repo);

      await store.ensureLoaded();

      expect(store.categories.map((c) => c.id), ['c1']);
      expect(repo.reads, 1);
      await store.ensureLoaded();
      expect(repo.reads, 1);
    });

    test('waits for a slow initial load instead of returning early',
        () async {
      final repo = _CountingCategoryRepository()..gate = Completer<void>();
      final store = CategoryStore(repo);
      var done = false;
      final wait = store.ensureLoaded().then((_) => done = true);

      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      repo.gate!.complete();
      await wait;
      expect(store.categories.map((c) => c.id), ['c1']);
      expect(repo.reads, 1);
    });

    test('a failed initial load keeps its error and is retried', () async {
      final repo = _CountingCategoryRepository()..failNext = 1;
      final store = CategoryStore(repo);
      await Future<void>.delayed(Duration.zero);
      expect(store.categories, isEmpty);
      expect(store.errorMessage, contains('simulated load failure'));

      await store.ensureLoaded();

      expect(repo.reads, 2);
      expect(store.categories.map((c) => c.id), ['c1']);
      expect(store.errorMessage, isNull);
    });
  });

  group('restaurant cart store', () {
    test('has no constructor load: a persisted cart stays invisible', () async {
      final line = makeCartItem(
          id: 'c1', productId: 'tea', title: 'Tea', price: 20, quantity: 2);
      await Hive.box<CartItem>(HiveBoxNames.restaurantCart).put(line.id, line);

      final store = CartStoreRes(CartRepository());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.cartItems, isEmpty,
          reason: 'only an explicit loadCartItems() hydrates the cart');

      await store.loadCartItems();
      expect(store.cartItems.map((c) => c.id), ['c1']);
    });
  });
}
