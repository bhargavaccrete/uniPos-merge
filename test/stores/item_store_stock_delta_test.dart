import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/repositories/restaurant/item_repository.dart';
import 'package:billberrylite/domain/store/restaurant/item_store.dart';

/// Real Hive-backed repository whose writes can be held open or made to fail,
/// so interleavings and persistence failures are deterministic.
class _ControllableRepository extends ItemRepository {
  int writes = 0;
  int failNextWrites = 0;
  Completer<void>? gate;

  @override
  Future<void> updateItem(Items item) async {
    writes++;
    final g = gate;
    if (g != null) await g.future;
    if (failNextWrites > 0) {
      failNextWrites--;
      throw StateError('simulated write failure');
    }
    return super.updateItem(item);
  }
}

/// Lets queued microtasks reach their first real await.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory tempDir;
  late Box<Items> box;
  late _ControllableRepository repo;
  late ItemStore store;

  Future<void> seed(List<Items> seeded) async {
    for (final item in seeded) {
      await box.put(item.id, item);
    }
    repo = _ControllableRepository();
    store = ItemStore(repo);
    await store.loadItems();
  }

  double stockOf(String id) => store.getItemById(id)!.stockQuantity;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('item_store_stock_');
    Hive.init(tempDir.path);
    await HiveInit.registerRestaurantAdapters();
    box = await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Category>(HiveBoxNames.category);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('item-level stock', () {
    test('deduction replaces the observable entry and persists', () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 10),
      ]);
      final before = store.getItemById('tea');

      final balance = await store.applyStockDelta(itemId: 'tea', delta: -2);

      expect(balance, 8);
      expect(identical(store.getItemById('tea'), before), isFalse,
          reason: 'a new instance is what makes MobX observe the change');
      expect(stockOf('tea'), 8);
      expect(box.get('tea')!.stockQuantity, 8);
    });

    test('restoration adds back and persists', () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 3),
      ]);

      final balance = await store.applyStockDelta(itemId: 'tea', delta: 4);

      expect(balance, 7);
      expect(box.get('tea')!.stockQuantity, 7);
    });

    test('lastPurchaseCost is written in the same single update', () async {
      await seed([
        Items(id: 'flour', name: 'Flour', trackInventory: true,
            stockQuantity: 5, lastPurchaseCost: 30),
      ]);

      final balance = await store.applyStockDelta(
          itemId: 'flour', delta: 10, lastPurchaseCost: 42);

      expect(balance, 15);
      expect(repo.writes, 1);
      final stored = box.get('flour')!;
      expect(stored.stockQuantity, 15);
      expect(stored.lastPurchaseCost, 42);
    });

    test('omitting lastPurchaseCost keeps the existing cost', () async {
      await seed([
        Items(id: 'flour', name: 'Flour', trackInventory: true,
            stockQuantity: 5, lastPurchaseCost: 30),
      ]);

      await store.applyStockDelta(itemId: 'flour', delta: -1);

      expect(box.get('flour')!.lastPurchaseCost, 30);
    });

    test('unknown item returns 0 and writes nothing', () async {
      await seed([]);

      final balance = await store.applyStockDelta(itemId: 'nope', delta: -1);

      expect(balance, 0);
      expect(repo.writes, 0);
    });
  });

  group('variant stock', () {
    Items pizza() => Items(
          id: 'pizza',
          name: 'Pizza',
          trackInventory: true,
          variant: [
            ItemVariante(
                variantId: 'small', price: 100,
                trackInventory: true, stockQuantity: 5),
            ItemVariante(
                variantId: 'large', price: 150,
                trackInventory: false, stockQuantity: 7),
          ],
        );

    test('deduction changes only the matched variant and keeps every field',
        () async {
      await seed([pizza()]);

      final balance = await store.applyStockDelta(
          itemId: 'pizza', variantId: 'small', delta: -2);

      expect(balance, 3);
      final variants = box.get('pizza')!.variant!;
      final small = variants.firstWhere((v) => v.variantId == 'small');
      final large = variants.firstWhere((v) => v.variantId == 'large');
      expect(small.stockQuantity, 3);
      expect(small.price, 100);
      expect(small.trackInventory, isTrue);
      expect(large.stockQuantity, 7);
      expect(large.price, 150);
      expect(large.trackInventory, isFalse);
    });

    test('restoration updates the matched variant', () async {
      await seed([pizza()]);

      final balance = await store.applyStockDelta(
          itemId: 'pizza', variantId: 'large', delta: 3);

      expect(balance, 10);
      final large = store.getItemById('pizza')!.variant!
          .firstWhere((v) => v.variantId == 'large');
      expect(large.stockQuantity, 10);
      expect(large.trackInventory, isFalse);
    });

    test('unknown variant returns 0 and writes nothing', () async {
      await seed([pizza()]);

      final balance = await store.applyStockDelta(
          itemId: 'pizza', variantId: 'medium', delta: -1);

      expect(balance, 0);
      expect(repo.writes, 0);
    });
  });

  group('concurrency', () {
    test('overlapping deductions on one item both apply', () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 10),
      ]);
      repo.gate = Completer<void>();

      // Both start before either write completes — the lost-update window.
      final first = store.applyStockDelta(itemId: 'tea', delta: -2);
      final second = store.applyStockDelta(itemId: 'tea', delta: -3);
      await _settle();
      repo.gate!.complete();

      expect(await first, 8);
      expect(await second, 5);
      expect(stockOf('tea'), 5);
      expect(box.get('tea')!.stockQuantity, 5);
    });

    test('overlapping updates to two variants of one item both survive',
        () async {
      await seed([
        Items(id: 'pizza', name: 'Pizza', trackInventory: true, variant: [
          ItemVariante(variantId: 'small', price: 100,
              trackInventory: true, stockQuantity: 5),
          ItemVariante(variantId: 'large', price: 150,
              trackInventory: true, stockQuantity: 7),
        ]),
      ]);
      repo.gate = Completer<void>();

      // Each rebuilds the whole variant list; unsequenced, the second would
      // overwrite the first variant with its stale value.
      final small = store.applyStockDelta(
          itemId: 'pizza', variantId: 'small', delta: -1);
      final large = store.applyStockDelta(
          itemId: 'pizza', variantId: 'large', delta: -2);
      await _settle();
      repo.gate!.complete();
      await Future.wait([small, large]);

      final stored = box.get('pizza')!.variant!;
      expect(stored.firstWhere((v) => v.variantId == 'small').stockQuantity, 4);
      expect(stored.firstWhere((v) => v.variantId == 'large').stockQuantity, 5);
    });

    test('many interleaved deltas net out exactly', () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 50),
      ]);

      await Future.wait([
        for (var i = 0; i < 20; i++)
          store.applyStockDelta(itemId: 'tea', delta: i.isEven ? -3 : 1),
      ]);

      expect(stockOf('tea'), 50 - 30 + 10);
      expect(box.get('tea')!.stockQuantity, 30);
    });
  });

  group('persistence failure', () {
    test('rethrows and leaves memory and storage unchanged', () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 10),
      ]);
      repo.failNextWrites = 1;

      await expectLater(
        store.applyStockDelta(itemId: 'tea', delta: -2),
        throwsA(isA<StateError>()),
      );

      expect(stockOf('tea'), 10);
      expect(box.get('tea')!.stockQuantity, 10);
    });

    test('a failure does not block the next mutation', () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 10),
      ]);
      repo.failNextWrites = 1;
      await expectLater(
        store.applyStockDelta(itemId: 'tea', delta: -2),
        throwsA(isA<StateError>()),
      );

      final balance = await store.applyStockDelta(itemId: 'tea', delta: -1);

      expect(balance, 9);
      expect(box.get('tea')!.stockQuantity, 9);
    });

    test('a mutation queued behind a failure builds on the stored balance',
        () async {
      await seed([
        Items(id: 'tea', name: 'Tea', trackInventory: true, stockQuantity: 10),
      ]);
      repo.failNextWrites = 1;
      repo.gate = Completer<void>();

      final failing = store.applyStockDelta(itemId: 'tea', delta: -2);
      final queued = store.applyStockDelta(itemId: 'tea', delta: -3);
      await _settle();
      repo.gate!.complete();

      await expectLater(failing, throwsA(isA<StateError>()));
      expect(await queued, 7);
      expect(box.get('tea')!.stockQuantity, 7);
    });
  });
}
