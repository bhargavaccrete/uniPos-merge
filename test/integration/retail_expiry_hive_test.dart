import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/expiry_status.dart';

/// HIVE ROUND-TRIP — optional expiry date on a retail variant.
///
/// The point of these is the **compatibility** claim: `expiryDate` is a NEW
/// NULLABLE field at index 24, so unlike the earlier int→double quantity
/// change it needs no migration. A record written without it must still read
/// back cleanly, with `expiryDate == null`.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retail_expiry_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  VarianteModel build({
    String id = 'v1',
    String? expiryDate,
    double stock = 0,
    bool decimal = false,
    String? unit,
  }) =>
      VarianteModel(
        varianteId: id,
        productId: 'p1',
        createdAt: DateTime.now().toIso8601String(),
        stockQty: stock,
        isDecimalQuantity: decimal,
        unit: unit,
        expiryDate: expiryDate,
      );

  test('an expiry date survives a Hive write/read', () async {
    final box = await Hive.openBox<VarianteModel>('test_expiry');
    final expiry = DateTime(2026, 8, 30);

    await box.put('v1', build(expiryDate: expiry.toIso8601String()));

    final read = box.get('v1')!;
    expect(read.expiryDateTime, equals(expiry));
    expect(read.hasExpiry, isTrue);
  });

  test('a variant saved WITHOUT an expiry reads back null', () async {
    final box = await Hive.openBox<VarianteModel>('test_no_expiry');

    // This is the shape of every pre-existing variant: field 24 absent.
    await box.put('v1', build(stock: 20));

    final read = box.get('v1')!;
    expect(read.expiryDate, isNull);
    expect(read.hasExpiry, isFalse);
    expect(
      expiryStatusFor(read.expiryDateTime),
      RetailExpiryStatus.noExpiry,
    );
    // The decimal-quantity behaviour alongside it is untouched.
    expect(read.stockQty, equals(20.0));
    expect(read.isDecimalQuantity, isFalse);
    expect(read.effectiveUnit, equals('piece'));
  });

  test('clearing an expiry persists as null', () async {
    final box = await Hive.openBox<VarianteModel>('test_clear_expiry');

    await box.put(
      'v1',
      build(expiryDate: DateTime(2026, 9, 1).toIso8601String()),
    );
    expect(box.get('v1')!.hasExpiry, isTrue);

    // The clear flag is the only way to write null back.
    await box.put('v1', box.get('v1')!.copyWith(clearExpiryDate: true));

    final read = box.get('v1')!;
    expect(read.expiryDate, isNull);
    expect(read.hasExpiry, isFalse);
  });

  test('changing an expiry overwrites cleanly, leaving no trace of the old',
      () async {
    final box = await Hive.openBox<VarianteModel>('test_change_expiry');
    final oldDate = DateTime(2026, 8, 27);
    final newDate = DateTime(2027, 1, 15);

    await box.put('v1', build(expiryDate: oldDate.toIso8601String()));
    await box.put(
      'v1',
      box.get('v1')!.copyWith(expiryDate: newDate.toIso8601String()),
    );

    final read = box.get('v1')!;
    expect(read.expiryDateTime, equals(newDate));
    expect(read.expiryDateTime, isNot(equals(oldDate)));
  });

  test('a decimal variant persists BOTH its fractional stock and its expiry',
      () async {
    final box = await Hive.openBox<VarianteModel>('test_decimal_expiry');
    final expiry = DateTime(2026, 8, 30);

    // Milk: 10.50 litre, expiring.
    await box.put(
      'milk',
      build(
        id: 'milk',
        expiryDate: expiry.toIso8601String(),
        stock: 10.50,
        decimal: true,
        unit: 'liter',
      ),
    );

    final read = box.get('milk')!;
    expect(read.stockQty, equals(10.50));
    expect(read.isDecimalQuantity, isTrue);
    expect(read.effectiveUnit, equals('liter'));
    expect(read.expiryDateTime, equals(expiry));
  });

  test('a pcs variant with an expiry keeps whole-number stock', () async {
    final box = await Hive.openBox<VarianteModel>('test_pcs_expiry');

    // Biscuit: 20 pcs, already expired.
    await box.put(
      'biscuit',
      build(
        id: 'biscuit',
        expiryDate: DateTime(2020, 1, 1).toIso8601String(),
        stock: 20,
      ),
    );

    final read = box.get('biscuit')!;
    expect(read.stockQty, equals(20.0));
    expect(read.stockQty % 1, equals(0));
    expect(read.isDecimalQuantity, isFalse);
    expect(expiryStatusFor(read.expiryDateTime), RetailExpiryStatus.expired);
  });

  test('backup round-trip (toMap/fromMap) preserves expiry', () async {
    final expiry = DateTime(2026, 8, 30);
    final original = build(
      expiryDate: expiry.toIso8601String(),
      stock: 10.50,
      decimal: true,
      unit: 'liter',
    );

    // What unified_backup_service does: toMap -> JSON -> fromMap.
    final restored = VarianteModel.fromMap(original.toMap());

    expect(restored.expiryDateTime, equals(expiry));
    expect(restored.stockQty, equals(10.50));
    expect(restored.unit, equals('liter'));
  });
}
