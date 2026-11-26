import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/init/hive_preservation.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/core/init/startup_recovery.dart';

/// E3 (Android: Downloads, then the Save dialog) and E4 (desktop: the Save
/// dialog, free names, rename retries). After every test the preserved
/// files are checked: saved, cancelled or failed, they never change.
void main() {
  const pin = '123456';
  late Directory root;
  late Directory hive;
  late Map<String, String> preservedBefore;

  String hashOf(List<int> b) => sha256.convert(b).toString();
  Map<String, String> preservedHashes() => {
        for (final f in Directory(p.join(hive.path, HivePreservation.folderName))
            .listSync(recursive: true)
            .whereType<File>())
          f.path: hashOf(f.readAsBytesSync())
      };
  List<String> filesIn(Directory d) => d.existsSync()
      ? d.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
      : <String>[];

  void expectHoldsPreserved(List<int> bytes) {
    final entries = StartupRecovery.readExport(bytes, pin);
    expect(entries.keys.toSet(),
        {'s1/orders.hive', 's1/orders.hive.manifest.json'});
    expect(entries['s1/orders.hive'], [1, 2, 3, 4, 5]);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('export_platform_');
    hive = Directory(p.join(root.path, 'hive'))..createSync();
    final s = Directory(p.join(hive.path, HivePreservation.folderName, 's1'))
      ..createSync(recursive: true);
    File(p.join(s.path, 'orders.hive')).writeAsBytesSync([1, 2, 3, 4, 5]);
    File(p.join(s.path, 'orders.hive.manifest.json')).writeAsStringSync('{}');
    HiveSafeOpen.hiveDirectory = hive.path;
    StartupRecovery.afterExportWriteForTesting = null;
    StartupRecovery.renameForTesting = null;
    StartupRecovery.renameRetryDelays = const [
      Duration(milliseconds: 5),
      Duration(milliseconds: 5),
      Duration(milliseconds: 5),
      Duration(milliseconds: 5),
    ];
    preservedBefore = preservedHashes();
  });

  tearDown(() {
    expect(preservedHashes(), preservedBefore,
        reason: 'the preserved files must never change or disappear');
    StartupRecovery.afterExportWriteForTesting = null;
    StartupRecovery.renameForTesting = null;
    HiveSafeOpen.hiveDirectory = null;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {/* Windows may hold a handle briefly */}
  });

  /// A Downloads path that cannot be written: its parent is a file.
  String blockedDownloads() {
    final f = File(p.join(root.path, 'not_a_folder'))..writeAsStringSync('x');
    return p.join(f.path, 'Download');
  }

  group('E3 Android', () {
    test('Downloads works: saved there, no Save dialog', () async {
      final downloads = Directory(p.join(root.path, 'Download'));
      var dialog = false;
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: true,
        downloadsDirectory: () async => downloads.path,
        saveAsWithBytes: (_, _) async {
          dialog = true;
          return 'x';
        },
      );
      expect(out.kind, ExportOutcomeKind.savedToFolder);
      expect(dialog, isFalse);
      expect(p.isWithin(downloads.path, out.location!), isTrue);
      expectHoldsPreserved(File(out.location!).readAsBytesSync());
      expect(filesIn(downloads).where((n) => n.endsWith('.part')), isEmpty);
    });

    test('Downloads not writable: the Save dialog gets verified bytes',
        () async {
      String? name;
      Uint8List? given;
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: true,
        downloadsDirectory: () async => blockedDownloads(),
        saveAsWithBytes: (n, b) async {
          name = n;
          given = b;
          return '/document/primary:Download/$n';
        },
      );
      expect(out.kind, ExportOutcomeKind.savedViaDialog);
      expect(out.location, contains(name!));
      expect(name, endsWith(StartupRecovery.exportExtension));
      expectHoldsPreserved(given!);
    });

    test('Downloads not writable and the dialog cancelled: not saved, clear '
        'note', () async {
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: true,
        downloadsDirectory: () async => blockedDownloads(),
        saveAsWithBytes: (_, _) async => null,
      );
      expect(out.kind, ExportOutcomeKind.cancelled);
      expect(out.location, isNull);
      expect(out.note, contains('Downloads folder is not available'));
    });

    test('both fail: one clear error naming both', () async {
      await expectLater(
        StartupRecovery.exportForThisPlatform(
          password: pin,
          android: true,
          downloadsDirectory: () async => blockedDownloads(),
          saveAsWithBytes: (_, _) async => throw PlatformException(
              code: 'error', message: 'Error while saving file'),
        ),
        throwsA(isA<ExportFailed>().having(
            (e) => e.message,
            'message',
            allOf(contains('Downloads'), contains('Save dialog'),
                contains('Error while saving file')))),
      );
    });

    test('a Downloads copy that reads back wrong is an error, not a reason '
        'to try elsewhere', () async {
      final downloads = Directory(p.join(root.path, 'Download'));
      var dialog = false;
      StartupRecovery.afterExportWriteForTesting = (part) async {
        final b = part.readAsBytesSync();
        b[b.length - 20] ^= 0xFF;
        part.writeAsBytesSync(b);
      };
      await expectLater(
        StartupRecovery.exportForThisPlatform(
          password: pin,
          android: true,
          downloadsDirectory: () async => downloads.path,
          saveAsWithBytes: (_, _) async {
            dialog = true;
            return 'x';
          },
        ),
        throwsA(isNot(isA<FileSystemException>())),
      );
      expect(dialog, isFalse);
      expect(filesIn(downloads), isEmpty, reason: 'no partial file left');
    });
  });

  group('E4 desktop', () {
    test('the Save dialog path is written, verified and decrypts', () async {
      final downloads = Directory(p.join(root.path, 'Downloads'))..createSync();
      final chosen = p.join(root.path, 'picked', 'support.bblsupport');
      String? offeredName;
      String? offeredDir;
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: false,
        desktopInitialDirectory: () async => downloads.path,
        pickSavePath: (n, d) async {
          offeredName = n;
          offeredDir = d;
          return chosen;
        },
      );
      expect(out.kind, ExportOutcomeKind.savedToFolder);
      expect(out.location, chosen);
      expect(out.note, isNull);
      expect(offeredDir, downloads.path);
      expect(offeredName, startsWith(StartupRecovery.exportPrefix));
      expectHoldsPreserved(File(chosen).readAsBytesSync());
      expect(filesIn(Directory(p.dirname(chosen))), ['support.bblsupport']);
    });

    test('an existing file at the chosen path is never overwritten',
        () async {
      final dir = Directory(p.join(root.path, 'picked'))..createSync();
      final existing = File(p.join(dir.path, 'support.bblsupport'))
        ..writeAsStringSync('an earlier export');
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: false,
        desktopInitialDirectory: () async => null,
        pickSavePath: (_, _) async => existing.path,
      );
      expect(existing.readAsStringSync(), 'an earlier export');
      expect(p.basename(out.location!), 'support-1.bblsupport');
      expect(out.note, contains('already exists'));
      expectHoldsPreserved(File(out.location!).readAsBytesSync());
    });

    test('cancel writes nothing; no Documents fallback', () async {
      final downloads = Directory(p.join(root.path, 'Downloads'))..createSync();
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: false,
        desktopInitialDirectory: () async => downloads.path,
        pickSavePath: (_, _) async => null,
      );
      expect(out.kind, ExportOutcomeKind.cancelled);
      expect(out.note, 'Export cancelled.');
      expect(filesIn(downloads), isEmpty);
      expect(filesIn(hive), isEmpty, reason: 'nothing next to the data');
    });

    test('no Downloads folder known: the dialog opens at its own default',
        () async {
      String? offeredDir = 'unset';
      await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: false,
        desktopInitialDirectory: () async => null,
        pickSavePath: (_, d) async {
          offeredDir = d;
          return null;
        },
      );
      expect(offeredDir, isNull);
    });

    test('a chosen name without the extension gets it', () async {
      final chosen = p.join(root.path, 'picked', 'for-support');
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: false,
        desktopInitialDirectory: () async => null,
        pickSavePath: (_, _) async => chosen,
      );
      expect(out.location, '$chosen${StartupRecovery.exportExtension}');
    });

    test('a briefly locked rename is retried and succeeds', () async {
      final chosen = p.join(root.path, 'picked', 'support.bblsupport');
      var attempts = 0;
      StartupRecovery.renameForTesting = (part, target) async {
        attempts++;
        if (attempts <= 2) {
          throw FileSystemException('locked by another process', target);
        }
        await part.rename(target);
      };
      final out = await StartupRecovery.exportForThisPlatform(
        password: pin,
        android: false,
        desktopInitialDirectory: () async => null,
        pickSavePath: (_, _) async => chosen,
      );
      expect(attempts, 3);
      expect(out.location, chosen);
      expectHoldsPreserved(File(chosen).readAsBytesSync());
    });

    test('a rename that stays locked fails cleanly after the limited retries',
        () async {
      final dir = Directory(p.join(root.path, 'picked'))..createSync();
      var attempts = 0;
      StartupRecovery.renameForTesting = (part, target) async {
        attempts++;
        throw FileSystemException('locked by another process', target);
      };
      await expectLater(
        StartupRecovery.exportForThisPlatform(
          password: pin,
          android: false,
          desktopInitialDirectory: () async => null,
          pickSavePath: (_, _) async => p.join(dir.path, 'support.bblsupport'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(attempts, StartupRecovery.renameRetryDelays.length + 1);
      expect(filesIn(dir), isEmpty, reason: 'own .part removed, nothing saved');
      expect(filesIn(hive), isEmpty, reason: 'no fallback next to the data');
    });
  });

  test('writeExport never overwrites an existing file', () async {
    final built = await StartupRecovery.buildExport(pin);
    final dir = Directory(p.join(root.path, 'out'))..createSync();
    final taken = File(p.join(dir.path, built.fileName))..writeAsStringSync('old');
    final saved = await StartupRecovery.writeExport(built, pin, taken);
    expect(taken.readAsStringSync(), 'old');
    expect(p.basename(saved),
        '${p.basenameWithoutExtension(built.fileName)}-1${StartupRecovery.exportExtension}');
    expectHoldsPreserved(File(saved).readAsBytesSync());
  });
}
