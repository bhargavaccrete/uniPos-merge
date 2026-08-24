import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';
import 'package:billberrylite/data/repositories/retail/bundle_repository.dart';
import 'package:billberrylite/data/repositories/retail/kit_assembly_repository.dart';

/// INTEGRATION TESTS — [BundleRepository] and [KitAssemblyRepository]
/// against real Hive boxes, using the actual box names the app opens
/// (`HiveBoxNames.bundles` / `HiveBoxNames.kitAssemblies`), the way
/// `test/integration/repository_integration_test.dart` exercises the
/// restaurant repositories.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_bundle_kit_repo_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();

    await Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles);
    await Hive.openBox<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  RetailBundleModel makeBundle({
    String id = 'bundle-1',
    String productId = 'prod-1',
    String variantId = 'variant-1',
    List<BundleComponentModel>? components,
  }) =>
      RetailBundleModel(
        id: id,
        productId: productId,
        variantId: variantId,
        components: components ??
            [BundleComponentModel(componentVariantId: 'comp-1', quantity: 2)],
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      );

  RetailKitAssemblyModel makeAssembly({
    String id = 'assembly-1',
    String bundleId = 'bundle-1',
    String variantId = 'variant-1',
    int batchQty = 5,
    DateTime? assembledTime,
    bool isReversal = false,
  }) =>
      RetailKitAssemblyModel(
        id: id,
        bundleId: bundleId,
        variantId: variantId,
        productName: 'Kit Product',
        batchQty: batchQty,
        assembledTime: assembledTime ?? DateTime.now(),
        movementIds: const ['m1'],
        isReversal: isReversal,
      );

  group('BundleRepository', () {
    late BundleRepository repo;

    setUp(() {
      repo = BundleRepository();
    });

    test('saveBundle → getBundleById returns the saved bundle', () async {
      final bundle = makeBundle(id: 'b1');
      await repo.saveBundle(bundle);

      final loaded = repo.getBundleById('b1');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'b1');
      expect(loaded.variantId, 'variant-1');
      expect(loaded.components, hasLength(1));
    });

    test('getBundleById returns null for an unknown id', () {
      expect(repo.getBundleById('does-not-exist'), isNull);
    });

    test('getAllBundles returns every saved bundle', () async {
      await repo.saveBundle(makeBundle(id: 'b1', variantId: 'v1'));
      await repo.saveBundle(makeBundle(id: 'b2', variantId: 'v2'));
      await repo.saveBundle(makeBundle(id: 'b3', variantId: 'v3'));

      expect(repo.getAllBundles(), hasLength(3));
    });

    test('getBundleForVariant finds the bundle keyed to that variant', () async {
      await repo.saveBundle(makeBundle(id: 'b1', variantId: 'v1'));
      await repo.saveBundle(makeBundle(id: 'b2', variantId: 'v2'));

      final found = repo.getBundleForVariant('v2');
      expect(found, isNotNull);
      expect(found!.id, 'b2');
    });

    test('getBundleForVariant returns null when no bundle is configured for that variant', () async {
      await repo.saveBundle(makeBundle(id: 'b1', variantId: 'v1'));

      expect(repo.getBundleForVariant('no-such-variant'), isNull);
    });

    test('multi-variant support: two bundles for the same product, different variants, coexist', () async {
      // This session removed the single-bundle-per-product restriction — a
      // bundle/repack product can now have one RetailBundleModel per variant.
      await repo.saveBundle(makeBundle(id: 'b1', productId: 'prod-1', variantId: 'v-small'));
      await repo.saveBundle(makeBundle(id: 'b2', productId: 'prod-1', variantId: 'v-large'));

      final small = repo.getBundleForVariant('v-small');
      final large = repo.getBundleForVariant('v-large');
      expect(small!.id, 'b1');
      expect(large!.id, 'b2');
      expect(small.productId, large.productId, reason: 'same product, independent bundle rows');
    });

    test('saveBundle upserts — saving with the same id overwrites the previous row', () async {
      await repo.saveBundle(makeBundle(id: 'b1', variantId: 'v1'));
      await repo.saveBundle(makeBundle(
        id: 'b1',
        variantId: 'v1',
        components: [BundleComponentModel(componentVariantId: 'comp-2', quantity: 9)],
      ));

      expect(repo.getAllBundles(), hasLength(1));
      expect(repo.getBundleById('b1')!.components.single.componentVariantId, 'comp-2');
    });

    test('deleteBundle removes it by id', () async {
      await repo.saveBundle(makeBundle(id: 'b1'));
      await repo.deleteBundle('b1');

      expect(repo.getBundleById('b1'), isNull);
    });

    test('deleteBundleForVariant removes the bundle configured for that variant', () async {
      await repo.saveBundle(makeBundle(id: 'b1', variantId: 'v1'));
      await repo.saveBundle(makeBundle(id: 'b2', variantId: 'v2'));

      await repo.deleteBundleForVariant('v1');

      expect(repo.getBundleForVariant('v1'), isNull);
      expect(repo.getBundleForVariant('v2'), isNotNull);
    });

    test('deleteBundleForVariant on a variant with no bundle is a no-op', () async {
      await repo.saveBundle(makeBundle(id: 'b1', variantId: 'v1'));

      await repo.deleteBundleForVariant('no-such-variant');

      expect(repo.getAllBundles(), hasLength(1));
    });
  });

  group('KitAssemblyRepository', () {
    late KitAssemblyRepository repo;

    setUp(() {
      repo = KitAssemblyRepository();
    });

    test('saveAssembly persists a row retrievable via getAllAssemblies', () async {
      await repo.saveAssembly(makeAssembly(id: 'a1'));

      final all = repo.getAllAssemblies();
      expect(all, hasLength(1));
      expect(all.single.id, 'a1');
    });

    test('getAllAssemblies sorts newest first', () async {
      await repo.saveAssembly(makeAssembly(id: 'a-old', assembledTime: DateTime(2026, 1, 1)));
      await repo.saveAssembly(makeAssembly(id: 'a-new', assembledTime: DateTime(2026, 3, 1)));
      await repo.saveAssembly(makeAssembly(id: 'a-mid', assembledTime: DateTime(2026, 2, 1)));

      final all = repo.getAllAssemblies();
      expect(all.map((a) => a.id).toList(), ['a-new', 'a-mid', 'a-old']);
    });

    test('getAssembliesForVariant filters to only that variant', () async {
      await repo.saveAssembly(makeAssembly(id: 'a1', variantId: 'v1'));
      await repo.saveAssembly(makeAssembly(id: 'a2', variantId: 'v2'));
      await repo.saveAssembly(makeAssembly(id: 'a3', variantId: 'v1'));

      final forV1 = repo.getAssembliesForVariant('v1');
      expect(forV1.map((a) => a.id).toSet(), {'a1', 'a3'});
    });

    test('getAssembliesForVariant returns forward and reversal rows together, time-sorted', () async {
      // Mirrors how assemble_kit_screen.dart renders one combined history —
      // a disassembly must show up alongside forward assemblies for the same
      // variant, not in a separate list.
      await repo.saveAssembly(makeAssembly(
        id: 'forward-1',
        variantId: 'v1',
        assembledTime: DateTime(2026, 1, 1),
        isReversal: false,
      ));
      await repo.saveAssembly(makeAssembly(
        id: 'reversal-1',
        variantId: 'v1',
        assembledTime: DateTime(2026, 1, 15),
        isReversal: true,
      ));
      await repo.saveAssembly(makeAssembly(
        id: 'forward-2',
        variantId: 'v1',
        assembledTime: DateTime(2026, 2, 1),
        isReversal: false,
      ));

      final history = repo.getAssembliesForVariant('v1');

      expect(history, hasLength(3));
      expect(history.map((a) => a.id).toList(), ['forward-2', 'reversal-1', 'forward-1']);
      expect(history.where((a) => a.isReversal).map((a) => a.id).toList(), ['reversal-1']);
      expect(history.where((a) => !a.isReversal).length, 2);
    });

    test('getAssembliesForVariant is empty for a variant with no history', () async {
      await repo.saveAssembly(makeAssembly(id: 'a1', variantId: 'v1'));

      expect(repo.getAssembliesForVariant('no-history'), isEmpty);
    });
  });
}
