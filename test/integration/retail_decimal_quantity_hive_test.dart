import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';

/// HIVE ROUND-TRIP — decimal quantities on retail variants.
///
/// Two things are pinned here:
///
///  1. A fractional stock level (10.5 kg) survives a real Hive write/read,
///     along with the unit-of-measure fields that make it meaningful.
///  2. A variant written as a PIECE product still reads back correctly and
///     behaves exactly as before — including a whole stock level, which must
///     come back as a whole double and never as 19.999…
///
/// **Known breaking change, deliberately not worked around.** Hive persists a
/// type tag per field (`FrameValueType.intT` vs `doubleT`) and the generated
/// adapter casts hard (`fields[9] as double`). A record written while
/// `stockQty` was an `int` therefore throws on read now. The app is
/// pre-release, so that data is disposable; a JSON backup taken beforehand
/// restores cleanly because `fromMap` coerces via `as num`. That coercion is
/// what the last test here covers.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_decimal_qty_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('a fractional stock level survives a Hive write/read', () async {
    final box = await Hive.openBox<VarianteModel>('test_variants_decimal');

    await box.put(
      'v-potato',
      VarianteModel(
        varianteId: 'v-potato',
        productId: 'p-potato',
        createdAt: DateTime.now().toIso8601String(),
        stockQty: 10.5,
        minStock: 2.5,
        sellingPrice: 40,
        isDecimalQuantity: true,
        unit: 'kg',
      ),
    );

    final read = box.get('v-potato')!;
    expect(read.stockQty, equals(10.5));
    expect(read.minStock, equals(2.5));
    expect(read.isDecimalQuantity, isTrue);
    expect(read.unit, equals('kg'));
    expect(read.effectiveUnit, equals('kg'));
  });

  test('the full decimal chain persists exactly: 10.5 → 13.5', () async {
    final box = await Hive.openBox<VarianteModel>('test_variants_chain');
    const id = 'v-potato';

    Future<void> writeStock(double qty) async {
      final current = box.get(id);
      await box.put(
        id,
        (current ??
                VarianteModel(
                  varianteId: id,
                  productId: 'p-potato',
                  createdAt: DateTime.now().toIso8601String(),
                  isDecimalQuantity: true,
                  unit: 'kg',
                ))
            .copyWith(stockQty: qty),
      );
    }

    await writeStock(10.50); // opening
    await writeStock(box.get(id)!.stockQty + 5.25); // GRN
    await writeStock(box.get(id)!.stockQty - 1.75); // sale
    await writeStock(box.get(id)!.stockQty - 0.50); // loss

    expect(box.get(id)!.stockQty, closeTo(13.50, 1e-9));
  });

  test('a piece variant round-trips with whole, exact stock', () async {
    final box = await Hive.openBox<VarianteModel>('test_variants_pieces');

    await box.put(
      'v-coke',
      VarianteModel(
        varianteId: 'v-coke',
        productId: 'p-coke',
        createdAt: DateTime.now().toIso8601String(),
        stockQty: 20,
        sellingPrice: 20,
      ),
    );

    final read = box.get('v-coke')!;
    expect(read.stockQty, equals(20.0));
    expect(read.stockQty % 1, equals(0));
    // Absent flag = piece product, so no backfill was ever needed.
    expect(read.isDecimalQuantity, isFalse);
    expect(read.unit, isNull);
    expect(read.effectiveUnit, equals('piece'));

    // The piece sale still lands exactly on 17.
    await box.put('v-coke', read.copyWith(stockQty: read.stockQty - 3));
    expect(box.get('v-coke')!.stockQty, equals(17.0));
  });

  test('a JSON backup written with INTEGER quantities restores cleanly', () {
    // This is the documented escape hatch for the Hive breaking change: the
    // backup path coerces with `as num`, so pre-change data restores fine.
    final legacyBackupRow = <String, dynamic>{
      'varianteId': 'v-legacy',
      'productId': 'p-legacy',
      'createdAt': DateTime.now().toIso8601String(),
      'stockQty': 20, // int, as older backups stored it
      'minStock': 5, // int
      'sellingPrice': 20.0,
    };

    final restored = VarianteModel.fromMap(legacyBackupRow);
    expect(restored.stockQty, equals(20.0));
    expect(restored.minStock, equals(5.0));
    expect(restored.isDecimalQuantity, isFalse);
    expect(restored.effectiveUnit, equals('piece'));
  });
}
