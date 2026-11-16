import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';

import '../helpers/startup_recovery_suite.dart';

/// M4 startup recovery, Restaurant: the damaged box is Day Management (a
/// BKP-9 critical section).
void main() {
  Box day() => Hive.box(HiveBoxNames.dayManagementBox);
  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);

  startupRecoverySuite(
    mode: 'restaurant',
    damagedBox: HiveBoxNames.dayManagementBox,
    criticalSectionToDrop: 'dayManagement',
    seedBackupData: () async {
      for (var i = 0; i < 4; i++) {
        await day().put('k$i', 'backup-$i-${'x' * 20}');
      }
      await categories().put('cat-1', Category(id: 'cat-1', name: 'Starters'));
    },
    changeDeviceData: () async {
      for (var i = 0; i < 4; i++) {
        await day().put('k$i', 'device-$i-${'y' * 20}');
      }
      await categories().put('cat-2', Category(id: 'cat-2', name: 'Device only'));
    },
    expectBackupData: () {
      expect(day().get('k0'), startsWith('backup-0'));
      expect(categories().get('cat-1')?.name, 'Starters');
      expect(categories().containsKey('cat-2'), isFalse);
    },
    expectDeviceData: () {
      expect(categories().get('cat-2')?.name, 'Device only',
          reason: 'rolled back to this device\'s data');
    },
  );
}
