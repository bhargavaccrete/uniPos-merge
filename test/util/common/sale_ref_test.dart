import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/util/common/short_ref.dart';

/// Pure string handling — no Hive, no prefs.
void main() {
  group('saleRef', () {
    test('an invoice number survives whole', () {
      // Trimming to 13 would cut the sequence off and make every sale of the
      // same day render identically.
      expect(saleRef('INV-20260907-001'), 'INV-20260907-001');
      expect(saleRef('INV-20260907-1234'), 'INV-20260907-1234');
    });

    test('a legacy UUID sale is still trimmed to a readable prefix', () {
      expect(saleRef('e7fe242f-1cb3-4a0e-9f11-2b7c5d8e0a91'), 'E7FE242F-1CB3');
    });

    test('a return id is trimmed', () {
      expect(
        saleRef('RTN_80c2687f-a490-4a4e-bdf7-b6166c4e861f'),
        'RTN_80C2687F-',
      );
    });

    test('an empty id renders as a dash, not a crash', () {
      expect(saleRef(null), '—');
      expect(saleRef(''), '—');
    });
  });
}
