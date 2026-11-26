import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';

import '../helpers/backup_box_registry.dart';

/// Batch 4a (BKP-1, BKP-4), through the real backup service: a Retail
/// sale's payment legs survive a restore and a rolled-back restore, an OLD
/// backup (legs only under `paymentList`) restores them too, and the
/// rollback's own comparison sees a changed leg.
///
/// Sales are compared as Hive objects (`paymentListJson` itself) — never
/// through `toMap`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  const split =
      '[{"method":"cash","amount":300.0},{"method":"upi","amount":200.0}]';
  const threeWay = '[{"method":"cash","amount":100.0},'
      '{"method":"card","amount":150.0},{"method":"upi","amount":250.0}]';

  Box<SaleModel> sales() => Hive.box<SaleModel>(HiveBoxNames.sales);
  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  SaleModel sale(String id, String? legs, {double total = 500}) => SaleModel(
        saleId: id,
        totalItems: 2,
        subtotal: total,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: total,
        paymentType: legs == null ? 'cash' : 'split',
        date: '2026-11-12T10:00:00.000',
        createdAt: '2026-11-12T10:00:00.000',
        updatedAt: '2026-11-12T10:00:00.000',
        paymentListJson: legs,
        isSplitPayment: legs != null,
        totalPaid: total,
      );

  Future<void> deviceHolds(List<SaleModel> held) async {
    await sales().clear();
    for (final s in held) {
      await sales().put(s.saleId, s);
    }
  }

  Future<Map<String, dynamic>> backupOf(List<SaleModel> held) async {
    await deviceHolds(held);
    return copy(await UnifiedBackupService.collectAllDataForTesting());
  }

  /// [backup] as an app from before BKP-1 wrote it: no `paymentListJson`.
  Map<String, dynamic> asOldBackup(Map<String, dynamic> backup) {
    final old = copy(backup);
    for (final s in ((old['data'] as Map)['sales'] as List)) {
      (s as Map).remove('paymentListJson');
    }
    return old;
  }

  String? legsOf(String id) => sales().get(id)!.paymentListJson;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_bkp4a_retail_');
    await openBoxesFor('retail', tempDir);
    await AppConfig.box.put('isSetupComplete', true);
  });

  setUp(() {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
  });

  tearDownAll(() async {
    UnifiedBackupService.failWritingKeyForTesting = null;
    UnifiedBackupService.failRollbackWritingKeyForTesting = null;
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a restore keeps split legs exactly; a single-payment sale stays so',
      () async {
    final backup = await backupOf(
        [sale('s-split', split), sale('s-3', threeWay), sale('s-cash', null)]);
    await deviceHolds([sale('s-device', null)]);

    await UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup));

    expect(sales().keys.toSet(), {'s-split', 's-3', 's-cash'});
    expect(legsOf('s-split'), split);
    expect(legsOf('s-3'), threeWay);
    expect(legsOf('s-cash'), isNull, reason: 'nothing invented');
    expect(sales().get('s-split')!.paymentList.map((l) => l['amount']),
        [300.0, 200.0]);
  });

  test('an OLD backup (legs only under "paymentList") restores the legs',
      () async {
    final backup = asOldBackup(
        await backupOf([sale('s-split', split), sale('s-cash', null)]));
    await deviceHolds([sale('s-device', null)]);

    await UnifiedBackupService.restoreDecodedBackupForTesting(backup);

    expect(legsOf('s-split'), split, reason: 'before BKP-1: null, one leg');
    // The old backup wrote the single-leg fallback; it comes back as that
    // same single leg.
    expect(sales().get('s-cash')!.paymentList, [
      {'method': 'cash', 'amount': 500.0},
    ]);
  });

  test('the backup still lists the legs under "paymentList" too', () async {
    final backup = await backupOf([sale('s-split', split)]);
    final saved = ((backup['data'] as Map)['sales'] as List).single as Map;
    expect(saved['paymentList'], [
      {'method': 'cash', 'amount': 300.0},
      {'method': 'upi', 'amount': 200.0},
    ]);
    expect(saved['paymentListJson'], split);
  });

  test('a failed restore rolls the device back WITH its split legs, verified',
      () async {
    final backup = await backupOf([sale('s-backup', null)]);
    await deviceHolds([sale('s-split', split), sale('s-cash', null)]);
    // grns is written after the sales.
    UnifiedBackupService.failWritingKeyForTesting = 'grns';

    await expectLater(
      UnifiedBackupService.restoreDecodedBackupForTesting(copy(backup)),
      throwsA(isA<RestoreFailedException>()
          .having((e) => e.rolledBack, 'rolledBack', isTrue)),
    );

    expect(sales().keys.toSet(), {'s-split', 's-cash'});
    expect(legsOf('s-split'), split);
    expect(legsOf('s-cash'), isNull);
  });

  test('the rollback comparison sees a changed or lost leg', () async {
    final export = await backupOf([sale('s-split', split)]);
    expect(UnifiedBackupService.sameBackedUpDataForTesting(export, copy(export)),
        isTrue);

    final cases = <String, void Function(Map s)>{
      'a leg amount': (s) {
        s['paymentListJson'] =
            '[{"method":"cash","amount":250.0},{"method":"upi","amount":250.0}]';
        (s['paymentList'] as List).first['amount'] = 250.0;
      },
      'the legs lost (one-leg fallback)': (s) {
        s['paymentListJson'] = null;
        s['paymentList'] = [
          {'method': 'split', 'amount': 500.0},
        ];
      },
      'only paymentListJson differs': (s) => s['paymentListJson'] = null,
    };
    for (final c in cases.entries) {
      final changed = copy(export);
      c.value(((changed['data'] as Map)['sales'] as List).single as Map);
      expect(
          UnifiedBackupService.sameBackedUpDataForTesting(export, changed),
          isFalse,
          reason: c.key);
    }
  });
}
