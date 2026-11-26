import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/repositories/restaurant/cash_movement_repository.dart';
import 'package:billberrylite/domain/store/restaurant/cash_movement_store.dart';

import '../../../helpers/open_retail_day_fixture.dart';

/// WF-4: a retail Cash In / Cash Out made with no day open was saved with no
/// session and fell outside every End of Day. It now needs an open day — the
/// End-of-Day close itself excepted — and restaurant behaves as before.
void main() {
  late Directory tempDir;

  Future<void> open(String mode) async {
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('cash_movement_gate_');
    Hive.init(tempDir.path);
    await HiveInit.registerRetailAdapters();
    await AppConfig.init();
    await AppConfig.box.put('businessMode', mode);
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);
    await Hive.openBox(HiveBoxNames.dayManagementBox);
    locator.registerSingleton<CashMovementStore>(
        CashMovementStore(CashMovementRepository()));
  }

  tearDown(() async {
    await locator.reset();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  int rows() => Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements).length;

  test('retail, no day open: Cash In refused, nothing saved', () async {
    await open('retail');
    final ok = await locator<CashMovementStore>()
        .addMovement(type: 'in', amount: 500, reason: 'Owner deposit');
    expect(ok, isFalse);
    expect(locator<CashMovementStore>().errorMessage, 'Start the day first.');
    expect(rows(), 0);
  });

  test('retail, day open: saved with its session', () async {
    await open('retail');
    await openRetailDayForTest();
    final ok = await locator<CashMovementStore>()
        .addMovement(type: 'out', amount: 200, reason: 'Petty cash');
    expect(ok, isTrue);
    expect(Hive.box<CashMovementModel>(HiveBoxNames.restaurantCashMovements)
        .values.single.sessionId, isNotNull);
  });

  test('retail End-of-Day safe drop is never blocked', () async {
    await open('retail');
    final ok = await locator<CashMovementStore>().addMovement(
        type: 'out', amount: 300, reason: 'Safe drop - End of Day', systemClose: true);
    expect(ok, isTrue);
  });

  test('restaurant is unaffected', () async {
    await open('restaurant');
    final ok = await locator<CashMovementStore>()
        .addMovement(type: 'in', amount: 100, reason: 'Change fund');
    expect(ok, isTrue);
  });
}
