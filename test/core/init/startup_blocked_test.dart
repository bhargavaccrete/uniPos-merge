import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/app_instance_lock.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';

class _FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDocuments(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// M4-PERSIST: startup stops at the storage step when any box cannot be
/// opened safely. Nothing that needs every box (service locator, recovery,
/// server, auto-backup, notifications) can run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String docs;

  String hashOf(File f) => sha256.convert(f.readAsBytesSync()).toString();
  File boxFile(String name) =>
      File(p.join(docs, '${name.toLowerCase()}.hive'));

  void damageSecondRecord(File f) {
    final b = f.readAsBytesSync();
    final second = ByteData.sublistView(b).getUint32(0, Endian.little);
    b[second + 12] ^= 0xFF;
    f.writeAsBytesSync(b);
  }

  Future<void> seed(String box, Map<String, Object> values) async {
    Hive.init(docs);
    final b = await Hive.openBox(box);
    await b.putAll(values);
    await b.close();
  }

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('startup_blocked_');
    docs = (Directory(p.join(root.path, 'documents'))..createSync()).path;
    PathProviderPlatform.instance = _FakeDocuments(docs);
    HivePreservation.appVersionLookup = () async => 'test';
  });

  setUp(() {
    HiveSafeOpen.resetForTesting();
    HivePreservation.resetForTesting();
    HivePreservation.appVersionLookup = () async => 'test';
  });

  tearDownAll(() async {
    await Hive.close();
    await AppInstanceLock.releaseForTesting();
    for (var i = 0; root.existsSync(); i++) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        if (i > 50) rethrow;
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test('main.dart opens all data through the gated step before any service',
      () {
    final code = File('lib/main.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final gate = code.indexOf('await HiveInit.openStartupBoxes();');
    expect(gate, greaterThan(0));
    for (final later in [
      'setupServiceLocator()',
      'loadCachedLicense()',
      'StockJournal.recoverAll()',
      'VoidOrderCommit.recoverAll()',
      'RetailCheckoutCommit.recoverAll()',
      'AutoBackupService.initialize()',
      'startServer()',
      'loadRetailStartupSettings()',
      'LocalNotificationService.instance.init()',
    ]) {
      final at = code.indexOf(later);
      expect(at, greaterThan(gate), reason: '$later must come after the gate');
    }
    for (final bypass in [
      'HiveInit.init()',
      'AppConfig.init()',
      'HiveInit.openCommonBoxes()',
      'HiveInit.initializeBusinessBoxes()',
    ]) {
      expect(code.contains(bypass), isFalse,
          reason: '$bypass would open data outside the gate');
    }
    expect(code, contains('runApp(ErrorApp(error: e.toString()))'));
  });

  test('a blocked start shows the Recovery screen; services start only after '
      'the data opened or recovery succeeded; an unfinished recovery is '
      'undone before Hive opens anything', () {
    final code = File('lib/main.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
        RegExp(r'on HiveStartupBlocked catch \(blocked\) \{\s*'
                r'(//[^\n]*\s*)*runApp\(StartupRecoveryApp\(')
            .hasMatch(code),
        isTrue);
    expect(code, contains('onRecovered: _startAfterRecovery'));
    final calls = RegExp(r'await _startServices\(\);').allMatches(code).length;
    expect(calls, 2, reason: 'in main after _openData(), and after recovery');
    final mainTry = code.indexOf('await _openData();\n      await _startServices();');
    expect(mainTry, greaterThan(0));
    final after = code.indexOf('Future<void> _startAfterRecovery()');
    expect(code.indexOf('await _startServices();', after), greaterThan(after));

    final init = File('lib/core/init/hive_init.dart').readAsStringSync();
    final resolve = init.indexOf('RecoveryJournal.resolvePendingAtStartup(dir)');
    final hive = init.indexOf('await Hive.initFlutter();');
    expect(resolve, greaterThan(0));
    expect(resolve, lessThan(hive));
  });

  test('a damaged AppConfig box stops startup before any business box opens',
      () async {
    await seed('appConfigBox', {
      'businessMode': 'restaurant',
      'isSetupComplete': true,
      'a': 'x' * 40,
      'b': 'y' * 40,
    });
    final f = boxFile('appConfigBox');
    damageSecondRecord(f);
    final before = hashOf(f);

    await expectLater(
      HiveInit.openStartupBoxes(),
      throwsA(isA<HiveStartupBlocked>()
          .having((e) => e.message, 'message', contains('appConfigBox'))),
    );
    expect(hashOf(f), before);
    expect(Hive.isBoxOpen(HiveBoxNames.restaurantOrders), isFalse);
    expect(Hive.isBoxOpen(HiveBoxNames.storeBox), isFalse);
    expect(locator.isRegistered<LicenseStore>(), isFalse);
    if (AppInstanceLock.appliesToThisPlatform) {
      expect(AppInstanceLock.isHeld, isTrue);
    }

    // Put the config back for the next test (the damaged file is preserved).
    await Hive.close();
    f.deleteSync();
  });

  test('12. a damaged restaurant box: blocked, preserved, no services',
      () async {
    await seed('appConfigBox',
        {'businessMode': 'restaurant', 'isSetupComplete': true});
    await seed(HiveBoxNames.restaurantStockJournal,
        {for (var i = 0; i < 5; i++) 'e$i': 'entry-$i-${'z' * 30}'});
    final f = boxFile(HiveBoxNames.restaurantStockJournal);
    damageSecondRecord(f);
    final before = hashOf(f);

    Object? error;
    try {
      await HiveInit.openStartupBoxes();
    } catch (e) {
      error = e;
    }
    expect(error, isA<HiveStartupBlocked>());
    final failure = (error as HiveStartupBlocked).failures.single;
    expect(failure.boxName, HiveBoxNames.restaurantStockJournal);
    expect(failure.kind, HiveBoxFailureKind.corrupted);
    expect(hashOf(f), before);
    expect(hashOf(File(failure.preserved!.path)), before);
    expect(p.isWithin(p.join(docs, HivePreservation.folderName),
        failure.preserved!.path), isTrue);
    expect(Hive.isBoxOpen(HiveBoxNames.restaurantStockJournal), isFalse);
    expect(HiveInit.areRestaurantBoxesOpen, isTrue,
        reason: 'every other box opened; only the damaged one is closed');
    expect(locator.isRegistered<LicenseStore>(), isFalse,
        reason: 'the service locator was never built');
  });
}
