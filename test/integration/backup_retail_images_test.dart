import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

class _FakeDocuments extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDocuments(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

/// AND-07: retail product images travel as `retail_img_{productId}` binary
/// ZIP entries, not as number lists inside data.json. Old backups (images in
/// data.json) still restore, and a failed restore puts the images back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const password = 'and07-pass';
  const now = '2026-01-01T00:00:00.000';

  final deviceImage = Uint8List.fromList(List.generate(300, (i) => i % 251));
  final backupImage = Uint8List.fromList(List.generate(200, (i) => 250 - i % 250));

  Box<ProductModel> products() => Hive.box<ProductModel>(HiveBoxNames.products);

  ProductModel shirt({Uint8List? image}) => ProductModel(
        productId: 'p1',
        productName: 'Shirt',
        category: '',
        hasVariants: false,
        createdAt: now,
        updateAt: now,
        imageBytes: image,
      );

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  List<Map<String, dynamic>> productMaps(Map<String, dynamic> backup) =>
      ((backup['data'] as Map)['products'] as List)
          .cast<Map<String, dynamic>>();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_retail_images_');
    PathProviderPlatform.instance = _FakeDocuments(
        (Directory(p.join(tempDir.path, 'documents'))..createSync()).path);
    FlutterSecureStorage.setMockInitialValues({});
    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
    await BackupEncryptionService.setPassword(password);
  });

  setUp(() async {
    UnifiedBackupService.beforeArchiveForTesting = null;
    UnifiedBackupService.failWritingKeyForTesting = null;
    await products().clear();
    await products().put('p1', shirt(image: deviceImage));
  });

  tearDownAll(() async {
    UnifiedBackupService.beforeArchiveForTesting = null;
    UnifiedBackupService.failWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a backup carries the image as its own entry, not inside data.json',
      () async {
    List<Map<String, dynamic>>? entries;
    UnifiedBackupService.beforeArchiveForTesting = (e) => entries = e;
    final out = Directory(p.join(tempDir.path, 'out_1'))..createSync();

    final path = await UnifiedBackupService.createBackupFileForTesting(out);

    expect(path, isNotNull, reason: 'the backup was written and verified');
    final imageEntry = entries!.singleWhere(
        (e) => e['name'] == '${UnifiedBackupService.retailImagePrefix}p1');
    expect(imageEntry['bytes'], deviceImage);

    final data = await UnifiedBackupService.readBackupFileForTesting(
        path!, password);
    final saved = productMaps(data).single;
    expect(saved['productId'], 'p1');
    expect(saved.containsKey('imageBytes'), isFalse,
        reason: 'no image numbers in data.json');
  });

  test('restoring a new-format backup brings the image back', () async {
    final backup = copy(await UnifiedBackupService.collectAllDataForTesting());
    // The device loses the image after the backup was taken.
    await products().put('p1', shirt());

    await UnifiedBackupService.restoreDecodedBackupForTesting(backup, images: [
      {
        'name': '${UnifiedBackupService.retailImagePrefix}p1',
        'bytes': backupImage.toList(),
      },
    ]);

    expect(products().get('p1')!.imageBytes, backupImage);
  });

  test('an old backup with the image inside data.json still restores it',
      () async {
    final backup = copy(await UnifiedBackupService.collectAllDataForTesting());
    productMaps(backup).single['imageBytes'] = backupImage.toList();
    await products().put('p1', shirt());

    await UnifiedBackupService.restoreDecodedBackupForTesting(backup);

    expect(products().get('p1')!.imageBytes, backupImage);
  });

  test('a failed restore rolls back and keeps the device image', () async {
    final backup = copy(await UnifiedBackupService.collectAllDataForTesting());
    // grns is written after products, so the backup image is already in.
    UnifiedBackupService.failWritingKeyForTesting = 'grns';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(backup, images: [
        {
          'name': '${UnifiedBackupService.retailImagePrefix}p1',
          'bytes': backupImage.toList(),
        },
      ]),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(products().get('p1')!.imageBytes, deviceImage);
  });
}
