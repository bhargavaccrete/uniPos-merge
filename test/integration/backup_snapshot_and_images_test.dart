import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

/// SB-1d: the encrypted pre-restore snapshot (only with a backup password,
/// never plaintext, importable like any backup) and image-file safety (a
/// failed restore puts overwritten images back and removes new ones).
class _FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDocuments(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory docs;
  late Map<String, dynamic> backup;

  Directory productImages() => Directory(p.join(docs.path, 'product_images'));
  Directory snapshots() => Directory(p.join(docs.path, 'restore_snapshots'));
  Directory imageUndo() => Directory(p.join(docs.path, 'restore_image_undo'));
  Box<RestaurantSessionModel> sessions() =>
      Hive.box<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  Future<void> usePassword(String? password) async {
    FlutterSecureStorage.setMockInitialValues({});
    if (password != null) await BackupEncryptionService.setPassword(password);
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_snapshot_');
    docs = Directory(p.join(tempDir.path, 'documents'))..createSync();
    PathProviderPlatform.instance = _FakeDocuments(docs.path);

    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await sessions().put(
      'sess-backup',
      RestaurantSessionModel(
        sessionId: 'sess-backup',
        startTime: DateTime(2026, 10, 28, 9),
        openingCash: 1000,
      ),
    );
    backup = copy(await UnifiedBackupService.collectAllDataForTesting());
  });

  setUp(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await sessions().clear();
    await sessions().put(
      'sess-device',
      RestaurantSessionModel(
        sessionId: 'sess-device',
        startTime: DateTime(2026, 10, 29, 18),
        openingCash: 300,
      ),
    );
    if (productImages().existsSync()) productImages().deleteSync(recursive: true);
    productImages().createSync(recursive: true);
    File(p.join(productImages().path, 'shirt.png')).writeAsBytesSync([1, 2, 3]);
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('encrypted snapshot', () {
    test('is written only with a password, encrypted, and importable',
        () async {
      await usePassword('snap-pass');
      final expected = await exportedBackupData();

      final path = await UnifiedBackupService.takeSnapshotFileForTesting();

      expect(path, isNotNull);
      expect(p.dirname(path!), snapshots().path,
          reason: 'app-private restore_snapshots folder');
      final raw = latin1.decode(File(path).readAsBytesSync());
      expect(raw.contains('sess-device'), isFalse,
          reason: 'no readable data in the file');

      await expectLater(
        UnifiedBackupService.readBackupFileForTesting(path, 'wrong-pass'),
        throwsA(anything),
      );
      final restored =
          await UnifiedBackupService.readBackupFileForTesting(path, 'snap-pass');
      final data = restored['data'] as Map<String, dynamic>;
      for (final key in retailBackedUp.values) {
        expect(data[key], unorderedEquals(expected[key] as List),
            reason: '$key is in the snapshot exactly as on the device');
      }
    });

    test('keeps only the newest snapshot', () async {
      await usePassword('snap-pass');
      await UnifiedBackupService.takeSnapshotFileForTesting();
      await Future<void>.delayed(const Duration(seconds: 1));
      final newest = await UnifiedBackupService.takeSnapshotFileForTesting();

      final files = snapshots().listSync().whereType<File>().toList();
      expect(files.map((f) => p.normalize(f.path)), [p.normalize(newest!)]);
    });

    test('without a password no snapshot file is written', () async {
      if (snapshots().existsSync()) snapshots().deleteSync(recursive: true);
      await usePassword(null);

      final path = await UnifiedBackupService.takeSnapshotFileForTesting();

      expect(path, isNull);
      expect(
          snapshots().existsSync() &&
              snapshots().listSync().whereType<File>().isNotEmpty,
          isFalse);
    });

    test('a failed restore reports the snapshot it saved', () async {
      await usePassword('snap-pass');
      UnifiedBackupService.failWritingKeyForTesting = 'grns';

      Object? failure;
      try {
        await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));
      } catch (e) {
        failure = e;
      }

      expect(failure, isA<RestoreFailedException>());
      final e = failure as RestoreFailedException;
      expect(e.rolledBack, isTrue);
      expect(e.snapshotPath, isNotNull);
      expect(File(e.snapshotPath!).existsSync(), isTrue);
      expect(sessions().keys, ['sess-device']);
    });
  });

  group('image files', () {
    final images = [
      {'name': 'prod_img_shirt.png', 'bytes': <int>[7, 7, 7]},
      {'name': 'prod_img_cap.png', 'bytes': <int>[5]},
    ];

    test('a failed restore puts overwritten images back and removes new ones',
        () async {
      await usePassword(null);
      UnifiedBackupService.failWritingKeyForTesting = 'grns';

      await expectLater(
        UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
            images: images),
        throwsA(isA<RestoreFailedException>()
            .having((e) => e.rolledBack, 'rolledBack', isTrue)),
      );

      expect(File(p.join(productImages().path, 'shirt.png')).readAsBytesSync(),
          [1, 2, 3]);
      expect(File(p.join(productImages().path, 'cap.png')).existsSync(),
          isFalse);
      expect(imageUndo().existsSync(), isFalse);
    });

    test('a successful restore keeps the backup images and no undo copies',
        () async {
      await usePassword(null);

      await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup),
          images: images);

      expect(File(p.join(productImages().path, 'shirt.png')).readAsBytesSync(),
          [7, 7, 7]);
      expect(File(p.join(productImages().path, 'cap.png')).readAsBytesSync(),
          [5]);
      expect(imageUndo().existsSync(), isFalse);
    });
  });
}
