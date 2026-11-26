import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';

/// M4-PERSIST: Retail's open bills (`billingTabs`, a BKP-9 critical section)
/// used to be deleted from disk and recreated empty on ANY open error. Now a
/// failed box is preserved and left closed, and Retail does not start.
class _Thing {
  _Thing();
}

class _ThingAdapter extends TypeAdapter<_Thing> {
  @override
  final int typeId = 99;
  @override
  _Thing read(BinaryReader r) => _Thing();
  @override
  void write(BinaryWriter w, _Thing t) => w.writeString('x');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  String hashOf(File f) => sha256.convert(f.readAsBytesSync()).toString();
  File tabsFile() =>
      File(p.join(dir.path, '${HiveBoxNames.billingTabs.toLowerCase()}.hive'));

  BillingTabModel tab(int i) => BillingTabModel(
        id: 'tab$i',
        name: 'Bill $i',
        items: const [],
        createdAt: DateTime(2026, 11, 16, 9, i),
        updatedAt: DateTime(2026, 11, 16, 9, i),
        customerName: 'Customer $i',
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_tabs_');
    Hive.init(dir.path);
    await HiveInit.registerRetailAdapters();
    HiveSafeOpen.resetForTesting();
    HiveSafeOpen.hiveDirectory = dir.path;
    HivePreservation.resetForTesting();
    HivePreservation.appVersionLookup = () async => 'test';
  });

  tearDown(() async {
    await Hive.close();
    for (var i = 0; dir.existsSync(); i++) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        if (i > 50) rethrow;
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  Future<void> expectPreservedNotDeleted(String originalHash) async {
    Object? error;
    try {
      await HiveInit.openRetailBoxes();
    } catch (e) {
      error = e;
    }
    expect(error, isA<HiveStartupBlocked>(),
        reason: 'Retail must not start with billingTabs missing');
    final failure = (error as HiveStartupBlocked).failures.single;
    expect(failure.boxName, HiveBoxNames.billingTabs);
    expect(error.message, contains(HiveBoxNames.billingTabs));

    expect(tabsFile().existsSync(), isTrue, reason: 'never deleted');
    expect(hashOf(tabsFile()), originalHash, reason: 'never recreated empty');
    expect(Hive.isBoxOpen(HiveBoxNames.billingTabs), isFalse);
    expect(hashOf(File(failure.preserved!.path)), originalHash);
    expect(HiveInit.areRetailBoxesOpen, isTrue,
        reason: 'the other boxes opened; only the damaged one is closed');
  }

  test('11a. damaged open bills are preserved, never deleted or recreated',
      () async {
    final box = await Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs);
    for (var i = 0; i < 4; i++) {
      await box.put('tab$i', tab(i));
    }
    await box.close();
    final b = tabsFile().readAsBytesSync();
    final second = ByteData.sublistView(b).getUint32(0, Endian.little);
    b[second + 12] ^= 0xFF; // inside the 2nd of 4 records
    tabsFile().writeAsBytesSync(b);

    await expectPreservedNotDeleted(hashOf(tabsFile()));
    expect(HiveSafeOpen.failures.single.kind, HiveBoxFailureKind.corrupted);
  });

  test('11b. an unknown typeId in open bills (the old "typeId 252" case) is '
      'preserved, never deleted', () async {
    Hive.registerAdapter(_ThingAdapter());
    // Only the stray record: resetAdapters below also drops Hive's built-in
    // DateTime adapter, which a real tab would need.
    final box = await Hive.openBox(HiveBoxNames.billingTabs);
    await box.put('odd', _Thing());
    await box.close();
    await Hive.close();
    Hive.resetAdapters();
    Hive.init(dir.path);
    await HiveInit.registerRetailAdapters();

    await expectPreservedNotDeleted(hashOf(tabsFile()));
    expect(HiveSafeOpen.failures.single.kind, HiveBoxFailureKind.unreadable);
    expect(HiveSafeOpen.failures.single.error, contains('unknown typeId: 131'));
  });
}
