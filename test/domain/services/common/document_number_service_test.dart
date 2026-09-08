import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:billberrylite/core/config/fiscal_year_rule.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/domain/services/common/document_number_service.dart';

/// Only needs the untyped `appCounters` box — no adapters, no DI. With the
/// locator unregistered, `FiscalYearRule` reads as India, so the boundary under
/// test is 1 April.
void main() {
  late Box counters;
  late DocumentNumberService service;

  setUpAll(() async {
    Hive.init('.dart_tool/test_hive_document_number');
    counters = await Hive.openBox(HiveBoxNames.appCounters);
  });

  setUp(() async {
    await counters.clear();
    service = DocumentNumberService();
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  group('format', () {
    test('starts at 1, zero-padded to five digits', () async {
      expect(await service.next('INV'), 'INV-00001');
    });

    test('counts consecutively within the year', () async {
      expect(await service.next('INV'), 'INV-00001');
      expect(await service.next('INV'), 'INV-00002');
      expect(await service.next('INV'), 'INV-00003');
    });

    test('grows past the padding rather than wrapping', () async {
      await service.setNext('INV', 99999);
      expect(await service.next('INV'), 'INV-99999');
      expect(await service.next('INV'), 'INV-100000');
    });

    test('each document type keeps its own series', () async {
      expect(await service.next('INV'), 'INV-00001');
      expect(await service.next('PO'), 'PO-00001');
      expect(await service.next('INV'), 'INV-00002');
      expect(await service.next('CRN'), 'CRN-00001');
    });
  });

  group('fiscal year reset', () {
    test('a stored year that is not the current one restarts at 1', () async {
      expect(await service.next('INV'), 'INV-00001');
      expect(await service.next('INV'), 'INV-00002');

      // What the turnover looks like from the counter's side: the stored token
      // no longer matches today's.
      await counters.put('INV_lastFy', '1999-00');

      expect(await service.next('INV'), 'INV-00001');
    });

    test('the current year is stamped alongside the sequence', () async {
      await service.next('INV');
      expect(counters.get('INV_lastFy'), FiscalYearRule.currentKey);
      expect(counters.get('INV_lastSeq'), 1);
    });

    test('a reset in one series leaves the others alone', () async {
      await service.next('INV');
      await service.next('PO');
      await counters.put('INV_lastFy', '1999-00');

      expect(await service.next('INV'), 'INV-00001');
      expect(await service.next('PO'), 'PO-00002');
    });
  });

  group('isTaken', () {
    test('walks past a number already in use', () async {
      final taken = {'INV-00001', 'INV-00002'};
      expect(await service.next('INV', isTaken: taken.contains), 'INV-00003');
    });

    test('is not consulted when absent', () async {
      expect(await service.next('INV'), 'INV-00001');
    });
  });

  group('configurable prefix and next number', () {
    test('setNext makes that number the very next one issued', () async {
      await service.setNext('INV', 1250);
      expect(await service.next('INV'), 'INV-01250');
      expect(await service.next('INV'), 'INV-01251');
    });

    test('setNext below 1 still yields 1', () async {
      await service.setNext('INV', 0);
      expect(await service.next('INV'), 'INV-00001');
    });

    test('setNext stamps the year, so the next mint does not reset it away',
        () async {
      await service.setNext('INV', 500);
      expect(counters.get('INV_lastFy'), FiscalYearRule.currentKey);
      expect(await service.next('INV'), 'INV-00500');
    });

    test('peekNext reports without consuming', () async {
      expect(service.peekNext('INV'), 1);
      await service.next('INV');
      expect(service.peekNext('INV'), 2);
      expect(service.peekNext('INV'), 2);
    });

    test('a renamed prefix re-labels the series without restarting it',
        () async {
      expect(await service.next('INV'), 'INV-00001');
      await service.setPrefix('INV', 'BILL');
      expect(await service.next('INV'), 'BILL-00002');
      // The counter still hangs off the document code, not the label.
      expect(counters.get('INV_lastSeq'), 2);
    });

    test('an empty override falls back to the document code', () async {
      await service.setPrefix('INV', '   ');
      expect(await service.next('INV'), 'INV-00001');
    });

    test('the prefix is stored upper-cased', () async {
      await service.setPrefix('INV', 'bill');
      expect(service.displayPrefix('INV'), 'BILL');
    });
  });
}
