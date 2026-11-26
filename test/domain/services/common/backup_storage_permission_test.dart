import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/backup_storage_permission.dart';

/// Backups go to the public Download folder. Android 11+ needs no permission
/// for that; Android 7–10 (API 24–29) do, and only they may be asked.
void main() {
  var asked = 0;

  void device({
    required bool android,
    int sdk = 30,
    bool granted = false,
    bool grantOnAsk = true,
  }) {
    asked = 0;
    BackupStoragePermission.isAndroidOverride = android;
    BackupStoragePermission.sdkIntOverride = () async => sdk;
    BackupStoragePermission.isGrantedOverride = () async => granted;
    BackupStoragePermission.requestOverride = () async {
      asked++;
      return grantOnAsk;
    };
  }

  tearDown(BackupStoragePermission.resetForTesting);

  test('Android 11+ never asks and is always allowed', () async {
    for (final sdk in [30, 33, 35]) {
      device(android: true, sdk: sdk);
      expect(await BackupStoragePermission.isRequired(), isFalse);
      expect(await BackupStoragePermission.isGranted(), isTrue);
      expect(await BackupStoragePermission.ensure(), isTrue);
      expect(asked, 0, reason: 'API $sdk');
    }
  });

  test('Android 10 and older: asked when not yet granted', () async {
    for (final sdk in [24, 28, 29]) {
      device(android: true, sdk: sdk);
      expect(await BackupStoragePermission.isRequired(), isTrue);
      expect(await BackupStoragePermission.isGranted(), isFalse);
      expect(await BackupStoragePermission.ensure(), isTrue);
      expect(asked, 1, reason: 'API $sdk');
    }
  });

  test('Android 10 and older: already granted is not asked again', () async {
    device(android: true, sdk: 29, granted: true);
    expect(await BackupStoragePermission.ensure(), isTrue);
    expect(asked, 0);
  });

  test('Android 10 and older: refused stays refused', () async {
    device(android: true, sdk: 28, grantOnAsk: false);
    expect(await BackupStoragePermission.ensure(), isFalse);
    expect(asked, 1);
  });

  test('not Android: nothing to ask', () async {
    device(android: false, sdk: 1);
    expect(await BackupStoragePermission.isRequired(), isFalse);
    expect(await BackupStoragePermission.ensure(), isTrue);
    expect(asked, 0);
  });

  test('a failing permission check counts as not granted', () async {
    device(android: true, sdk: 28);
    BackupStoragePermission.isGrantedOverride = () async => throw Exception();
    BackupStoragePermission.requestOverride = () async => throw Exception();
    expect(await BackupStoragePermission.isGranted(), isFalse);
    expect(await BackupStoragePermission.ensure(), isFalse);
  });
}
