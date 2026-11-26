import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';

import '../helpers/startup_recovery_suite.dart';

/// M4 startup recovery, Retail: the damaged box is the open bills
/// (`billingTabs`, a BKP-9 critical section that used to be deleted and
/// recreated empty).
void main() {
  Box<BillingTabModel> tabs() =>
      Hive.box<BillingTabModel>(HiveBoxNames.billingTabs);
  Box<Category> categories() => Hive.box<Category>(HiveBoxNames.category);

  BillingTabModel tab(int i, String name) => BillingTabModel(
        id: 'tab$i',
        name: name,
        items: const [],
        createdAt: DateTime(2026, 11, 16, 9, i),
        updatedAt: DateTime(2026, 11, 16, 9, i),
      );

  startupRecoverySuite(
    mode: 'retail',
    damagedBox: HiveBoxNames.billingTabs,
    criticalSectionToDrop: 'billingTabs',
    seedBackupData: () async {
      for (var i = 0; i < 4; i++) {
        await tabs().put('tab$i', tab(i, 'Backup $i'));
      }
      await categories().put('cat-1', Category(id: 'cat-1', name: 'Grocery'));
    },
    changeDeviceData: () async {
      for (var i = 0; i < 4; i++) {
        await tabs().put('tab$i', tab(i, 'Device $i'));
      }
      await categories().put('cat-2', Category(id: 'cat-2', name: 'Device only'));
    },
    expectBackupData: () {
      expect(tabs().get('tab0')?.name, 'Backup 0');
      expect(tabs().length, 4);
      expect(categories().get('cat-1')?.name, 'Grocery');
      expect(categories().containsKey('cat-2'), isFalse);
    },
    expectDeviceData: () {
      expect(categories().get('cat-2')?.name, 'Device only',
          reason: 'rolled back to this device\'s data');
    },
  );
}
