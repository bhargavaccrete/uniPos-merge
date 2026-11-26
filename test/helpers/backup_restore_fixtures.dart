import 'dart:io';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';

import 'backup_box_registry.dart';

/// Shared fixtures for the BLK-04 cross-mode restore tests.

/// A current-format backup of [mode] carrying one day session and the day
/// state pointing at it. Its appConfig would switch the device to [mode].
Map<String, dynamic> wrappedBackupOf(String mode,
        {String sessionId = 'sess-from-backup'}) =>
    {
      'version': '2.0.0',
      'exportDate': '2026-10-29T10:00:00.000',
      'appMode': mode,
      'data': <String, dynamic>{
        'appConfig': [
          {'businessMode': mode, 'isSetupComplete': true},
        ],
        'restaurantSessions': [
          RestaurantSessionModel(
            sessionId: sessionId,
            startTime: DateTime(2026, 10, 29, 9),
            openingCash: 750,
          ).toMap(),
        ],
        'dayManagement': [
          {'currentSessionId': sessionId, 'dayStarted': true},
        ],
      },
    };

/// A legacy backup (no `appMode`, no `data` wrapper) that the restore
/// recognises as [mode] only from its top-level keys.
Map<String, dynamic> legacyBackupOf(String mode) => mode == 'retail'
    ? <String, dynamic>{'products': [], 'suppliers': []}
    : <String, dynamic>{'items': [], 'tables': []};

/// One image entry as `_decodeEntries` hands it over. A rejected restore must
/// never get as far as writing it.
final List<Map<String, dynamic>> oneImageEntry = [
  {'name': 'prod_img_should_not_be_written.png', 'bytes': <int>[1, 2, 3]},
];

/// Everything a rejected restore must leave untouched: the contents of every
/// box this mode's backup carries, the raw AppConfig box (business mode,
/// setup flag) and the set of box files on disk.
Future<Map<String, dynamic>> deviceState(Directory dir) async {
  final data = await exportedBackupData();
  return {
    'data': data,
    'appConfig': {
      for (final k in AppConfig.box.keys) k.toString(): AppConfig.box.get(k),
    },
    'files': hiveFilesIn(dir).toList()..sort(),
  };
}
