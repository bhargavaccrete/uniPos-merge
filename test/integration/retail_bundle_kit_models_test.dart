import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// Use HiveInit to register adapters exactly as the app does.
import 'package:billberrylite/core/init/hive_init.dart';

import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';

/// HIVE ROUND-TRIP TESTS — bundle/repack-kit models added this session.
///
/// Create → save to Hive → read from Hive → verify ALL fields match.
/// Also pins down the `isReversal` backward-compatibility contract: a
/// [RetailKitAssemblyModel] written before that field existed must
/// deserialize with `isReversal == false`.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_bundle_kit_models_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Hive: RetailBundleModel', () {
    test('save and read a bundle with components — all fields survive', () async {
      final box = await Hive.openBox<RetailBundleModel>('test_bundles');

      final original = RetailBundleModel(
        id: 'bundle-1',
        productId: 'prod-1',
        variantId: 'variant-1',
        components: [
          BundleComponentModel(componentVariantId: 'comp-1', quantity: 2, note: 'core'),
          BundleComponentModel(componentVariantId: 'comp-2', quantity: 1),
        ],
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-02T00:00:00.000',
      );

      await box.put(original.id, original);
      final loaded = box.get('bundle-1');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'bundle-1');
      expect(loaded.productId, 'prod-1');
      expect(loaded.variantId, 'variant-1');
      expect(loaded.createdAt, '2026-01-01T00:00:00.000');
      expect(loaded.updatedAt, '2026-01-02T00:00:00.000');
      expect(loaded.components, hasLength(2));
      expect(loaded.components[0].componentVariantId, 'comp-1');
      expect(loaded.components[0].quantity, 2);
      expect(loaded.components[0].note, 'core');
      expect(loaded.components[1].componentVariantId, 'comp-2');
      expect(loaded.components[1].quantity, 1);
      expect(loaded.components[1].note, isNull);
      expect(loaded.hasComponents, isTrue);
    });

    test('a bundle with no components round-trips as empty, not null', () async {
      final box = await Hive.openBox<RetailBundleModel>('test_bundles_empty');

      final original = RetailBundleModel(
        id: 'bundle-empty',
        productId: 'prod-1',
        variantId: 'variant-1',
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      );

      await box.put(original.id, original);
      final loaded = box.get('bundle-empty');

      expect(loaded!.components, isEmpty);
      expect(loaded.hasComponents, isFalse);
    });

    test('estimatedCost sums componentVariant cost × quantity', () async {
      final bundle = RetailBundleModel(
        id: 'bundle-cost',
        productId: 'prod-1',
        variantId: 'variant-1',
        components: [
          BundleComponentModel(componentVariantId: 'comp-1', quantity: 2),
          BundleComponentModel(componentVariantId: 'comp-2', quantity: 3),
        ],
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      );

      final costs = {'comp-1': 10.0, 'comp-2': 5.0};
      expect(bundle.estimatedCost((id) => costs[id] ?? 0), 2 * 10.0 + 3 * 5.0);
    });

    test('toMap/fromMap round-trip matches direct construction', () {
      final original = RetailBundleModel(
        id: 'bundle-map',
        productId: 'prod-1',
        variantId: 'variant-1',
        components: [
          BundleComponentModel(componentVariantId: 'comp-1', quantity: 4, note: 'n'),
        ],
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      );

      final restored = RetailBundleModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.productId, original.productId);
      expect(restored.variantId, original.variantId);
      expect(restored.components.single.componentVariantId, 'comp-1');
      expect(restored.components.single.quantity, 4);
      expect(restored.components.single.note, 'n');
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('copyWith overrides only the given fields and bumps updatedAt when omitted', () {
      final original = RetailBundleModel(
        id: 'bundle-1',
        productId: 'prod-1',
        variantId: 'variant-1',
        components: const [],
        createdAt: '2026-01-01T00:00:00.000',
        updatedAt: '2026-01-01T00:00:00.000',
      );

      final copy = original.copyWith(variantId: 'variant-2');

      expect(copy.id, original.id);
      expect(copy.productId, original.productId);
      expect(copy.variantId, 'variant-2');
      expect(copy.createdAt, original.createdAt);
      // updatedAt is refreshed to "now" when not explicitly passed.
      expect(copy.updatedAt, isNot(original.updatedAt));
    });
  });

  group('BundleComponentModel', () {
    test('copyWith overrides only the given fields', () {
      final original = BundleComponentModel(
        componentVariantId: 'comp-1',
        quantity: 2,
        note: 'original note',
      );

      final copy = original.copyWith(quantity: 5);

      expect(copy.componentVariantId, 'comp-1');
      expect(copy.quantity, 5);
      expect(copy.note, 'original note');
    });

    test('copyWith with no args returns an identical copy', () {
      final original = BundleComponentModel(componentVariantId: 'comp-1', quantity: 3);
      final copy = original.copyWith();

      expect(copy.componentVariantId, original.componentVariantId);
      expect(copy.quantity, original.quantity);
      expect(copy.note, original.note);
    });

    test('toMap/fromMap round-trip, including a null note', () {
      final original = BundleComponentModel(componentVariantId: 'comp-1', quantity: 7);
      final restored = BundleComponentModel.fromMap(original.toMap());

      expect(restored.componentVariantId, 'comp-1');
      expect(restored.quantity, 7);
      expect(restored.note, isNull);
    });
  });

  group('Hive: RetailKitAssemblyModel', () {
    test('round-trip with isReversal: true (disassembly record)', () async {
      final box = await Hive.openBox<RetailKitAssemblyModel>('test_kit_assembly_reversal');

      final original = RetailKitAssemblyModel(
        id: 'assembly-1',
        bundleId: 'bundle-1',
        variantId: 'variant-1',
        productName: '12-Pack',
        batchQty: 5,
        assembledTime: DateTime(2026, 3, 1, 10, 30),
        assembledBy: 'Admin',
        movementIds: const ['m1', 'm2', 'm3'],
        isReversal: true,
      );

      await box.put(original.id, original);
      final loaded = box.get('assembly-1');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'assembly-1');
      expect(loaded.bundleId, 'bundle-1');
      expect(loaded.variantId, 'variant-1');
      expect(loaded.productName, '12-Pack');
      expect(loaded.batchQty, 5);
      expect(loaded.assembledTime, DateTime(2026, 3, 1, 10, 30));
      expect(loaded.assembledBy, 'Admin');
      expect(loaded.movementIds, ['m1', 'm2', 'm3']);
      expect(loaded.isReversal, isTrue);
    });

    test('round-trip with isReversal: false (forward assembly, explicit)', () async {
      final box = await Hive.openBox<RetailKitAssemblyModel>('test_kit_assembly_forward');

      final original = RetailKitAssemblyModel(
        id: 'assembly-2',
        bundleId: 'bundle-1',
        variantId: 'variant-1',
        productName: '12-Pack',
        batchQty: 10,
        assembledTime: DateTime(2026, 3, 2, 9, 0),
        movementIds: const ['m4'],
        isReversal: false,
      );

      await box.put(original.id, original);
      final loaded = box.get('assembly-2');

      expect(loaded!.isReversal, isFalse);
      expect(loaded.assembledBy, isNull);
      expect(loaded.batchQty, 10);
    });

    test('a model constructed without isReversal defaults to false (pre-existing-data compatibility)', () async {
      final box = await Hive.openBox<RetailKitAssemblyModel>('test_kit_assembly_default');

      // Simulates a row written by code from before `isReversal` existed —
      // the constructor call simply never mentions the field.
      final legacy = RetailKitAssemblyModel(
        id: 'assembly-legacy',
        bundleId: 'bundle-1',
        variantId: 'variant-1',
        productName: '12-Pack',
        batchQty: 3,
        assembledTime: DateTime(2025, 12, 1),
        movementIds: const ['m5'],
      );

      // Sanity: the in-memory default is false before it ever touches Hive.
      expect(legacy.isReversal, isFalse);

      await box.put(legacy.id, legacy);
      final loaded = box.get('assembly-legacy');

      expect(loaded!.isReversal, isFalse);
    });

    test('toMap/fromMap round-trip preserves isReversal in both directions', () {
      RetailKitAssemblyModel make(bool isReversal) => RetailKitAssemblyModel(
            id: 'a1',
            bundleId: 'b1',
            variantId: 'v1',
            productName: 'Kit',
            batchQty: 2,
            assembledTime: DateTime(2026, 1, 1),
            isReversal: isReversal,
          );

      expect(RetailKitAssemblyModel.fromMap(make(true).toMap()).isReversal, isTrue);
      expect(RetailKitAssemblyModel.fromMap(make(false).toMap()).isReversal, isFalse);
    });

    test('fromMap with no isReversal key defaults to false', () {
      final map = {
        'id': 'a2',
        'bundleId': 'b1',
        'variantId': 'v1',
        'productName': 'Kit',
        'batchQty': 4,
        'assembledTime': DateTime(2026, 1, 1).toIso8601String(),
        'assembledBy': null,
        'movementIds': <String>[],
        // 'isReversal' intentionally omitted
      };

      expect(RetailKitAssemblyModel.fromMap(map).isReversal, isFalse);
    });
  });
}
