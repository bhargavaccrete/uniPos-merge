import 'package:flutter_test/flutter_test.dart';
import 'package:unipos/util/restaurant/restaurant_auth_helper.dart';
import 'package:unipos/data/models/restaurant/db/saved_printer_model.dart';

/// Unit tests for:
/// 1. RestaurantAuthHelper — password hashing, verification, migration
/// 2. Fiscal year calculation — bill number reset logic
/// 3. SavedPrinterModel — helper getters for printer type/role
///
/// These are all PURE functions — no Hive, no SharedPreferences, no Flutter.
void main() {
  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 1: Password Hashing
  //
  // SOURCE: lib/util/restaurant/restaurant_auth_helper.dart
  //
  // The auth system uses SHA-256 + salt for PIN storage.
  // Staff enters "123456" → stored as 64-char hex hash.
  //
  // WHY TEST THIS:
  //   - If hashing breaks, NO ONE can log in
  //   - If verification breaks, ANYONE can log in
  //   - If migration detection breaks, old staff get locked out
  // ════════════════════════════════════════════════════════════════════════

  group('Password hashing', () {
    // hashPassword() takes plaintext → returns 64-char hex SHA-256 hash
    // The salt "unipos_restaurant_salt_2024" is appended before hashing
    test('hashPassword returns 64-character hex string', () {
      final hash = RestaurantAuthHelper.hashPassword('123456');

      // SHA-256 always produces 64 hex characters
      expect(hash.length, equals(64));

      // Should only contain hex characters (0-9, a-f)
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('same password always produces same hash (deterministic)', () {
      // This is critical — if hash is random, login verification breaks
      final hash1 = RestaurantAuthHelper.hashPassword('123456');
      final hash2 = RestaurantAuthHelper.hashPassword('123456');
      expect(hash1, equals(hash2));
    });

    test('different passwords produce different hashes', () {
      final hash1 = RestaurantAuthHelper.hashPassword('123456');
      final hash2 = RestaurantAuthHelper.hashPassword('654321');
      expect(hash1, isNot(equals(hash2)));
    });

    test('empty password still produces valid hash', () {
      // Edge case: shouldn't crash on empty input
      final hash = RestaurantAuthHelper.hashPassword('');
      expect(hash.length, equals(64));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 2: Hash Detection (isHashed)
  //
  // SOURCE: RestaurantAuthHelper.isHashed()
  //   → SHA-256 = 64 hex chars. Anything else = plaintext.
  //
  // This is the MIGRATION bridge. Old PINs were stored as plaintext
  // ("123456"). New PINs are hashed. isHashed() tells which format
  // the stored value is in, so verifyPassword() knows how to compare.
  // ════════════════════════════════════════════════════════════════════════

  group('Hash detection — isHashed()', () {
    test('64-char hex string → is hashed', () {
      // A real SHA-256 hash
      final hash = RestaurantAuthHelper.hashPassword('test');
      expect(RestaurantAuthHelper.isHashed(hash), isTrue);
    });

    test('short plaintext PIN → not hashed', () {
      // Old-style plaintext PIN
      expect(RestaurantAuthHelper.isHashed('123456'), isFalse);
    });

    test('empty string → not hashed', () {
      expect(RestaurantAuthHelper.isHashed(''), isFalse);
    });

    test('63 chars → not hashed (must be exactly 64)', () {
      final almost = 'a' * 63;
      expect(RestaurantAuthHelper.isHashed(almost), isFalse);
    });

    test('65 chars → not hashed (must be exactly 64)', () {
      final tooLong = 'a' * 65;
      expect(RestaurantAuthHelper.isHashed(tooLong), isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 3: Password Verification
  //
  // SOURCE: RestaurantAuthHelper.verifyPassword(entered, stored)
  //
  // Two paths:
  //   stored is hashed (64 chars) → hash(entered) == stored
  //   stored is plaintext (old)   → entered == stored
  //
  // This handles migration: old staff with plaintext PINs can still
  // log in after the app adds hashing support.
  // ════════════════════════════════════════════════════════════════════════

  group('Password verification — verifyPassword()', () {
    test('correct password against hashed stored value → true', () {
      // Simulate: staff set PIN "123456", it was hashed and stored
      final stored = RestaurantAuthHelper.hashPassword('123456');

      // Login: staff enters "123456"
      expect(RestaurantAuthHelper.verifyPassword('123456', stored), isTrue);
    });

    test('wrong password against hashed stored value → false', () {
      final stored = RestaurantAuthHelper.hashPassword('123456');
      expect(RestaurantAuthHelper.verifyPassword('999999', stored), isFalse);
    });

    test('correct password against plaintext stored value → true (migration)', () {
      // Old staff record: PIN stored as plaintext "123456" (before hashing was added)
      const stored = '123456'; // plaintext, not hashed

      // Staff enters "123456" — should still work
      expect(RestaurantAuthHelper.verifyPassword('123456', stored), isTrue);
    });

    test('wrong password against plaintext stored value → false', () {
      const stored = '123456';
      expect(RestaurantAuthHelper.verifyPassword('999999', stored), isFalse);
    });

    test('empty password against empty stored → true (edge case)', () {
      // Shouldn't happen in production, but shouldn't crash
      expect(RestaurantAuthHelper.verifyPassword('', ''), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 4: Fiscal Year Calculation
  //
  // SOURCE: order_repository.dart line 98
  //   currentFiscalYearStartYear = today.month >= 4 ? today.year : today.year - 1
  //
  // Indian fiscal year: April 1 to March 31
  //   - March 2026 → FY 2025-26 (started April 2025)
  //   - April 2026 → FY 2026-27 (started April 2026)
  //
  // Bill numbers reset on April 1st. If this logic is wrong:
  //   - Bills might reset mid-year (duplicate bill numbers)
  //   - Or never reset (bill #50000 by year end)
  //   - GST compliance violation in both cases
  //
  // We extract and test the FORMULA, not the Hive counter.
  // ════════════════════════════════════════════════════════════════════════

  // Extracted from order_repository.dart line 98
  // Pure function: given a date, return the fiscal year start year
  int getFiscalYearStartYear(DateTime date) {
    return date.month >= 4 ? date.year : date.year - 1;
  }

  // Extracted: format date as "YYYY-MM-DD" for daily counter comparison
  String formatDateForCounter(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  group('Fiscal year calculation — bill number reset boundary', () {
    test('January 2026 → FY 2025 (started April 2025)', () {
      final date = DateTime(2026, 1, 15);
      expect(getFiscalYearStartYear(date), equals(2025));
    });

    test('March 31, 2026 → FY 2025 (last day before reset)', () {
      final date = DateTime(2026, 3, 31);
      expect(getFiscalYearStartYear(date), equals(2025));
    });

    test('April 1, 2026 → FY 2026 (reset day! new fiscal year)', () {
      // This is the critical boundary — bill numbers reset here
      final date = DateTime(2026, 4, 1);
      expect(getFiscalYearStartYear(date), equals(2026));
    });

    test('April 2, 2026 → FY 2026 (day after reset)', () {
      final date = DateTime(2026, 4, 2);
      expect(getFiscalYearStartYear(date), equals(2026));
    });

    test('December 2026 → FY 2026 (same FY as April)', () {
      final date = DateTime(2026, 12, 25);
      expect(getFiscalYearStartYear(date), equals(2026));
    });

    test('March 2027 → FY 2026 (still same FY until April 2027)', () {
      final date = DateTime(2027, 3, 15);
      expect(getFiscalYearStartYear(date), equals(2026));
    });

    // This test verifies that two dates in the SAME fiscal year
    // produce the SAME start year (so bill counter doesn't reset mid-FY)
    test('same FY: June 2026 and February 2027 → both FY 2026', () {
      final june = DateTime(2026, 6, 1);
      final feb = DateTime(2027, 2, 1);
      expect(getFiscalYearStartYear(june), equals(getFiscalYearStartYear(feb)));
    });

    // This test verifies that March 31 and April 1 are DIFFERENT FYs
    // (the reset boundary)
    test('different FY: March 31 and April 1 same year → different FY', () {
      final march31 = DateTime(2026, 3, 31);
      final april1 = DateTime(2026, 4, 1);
      expect(
        getFiscalYearStartYear(march31),
        isNot(equals(getFiscalYearStartYear(april1))),
      );
    });
  });

  group('Daily counter date format', () {
    // The daily reset (KOT#, Order#) compares date strings.
    // Format must be "YYYY-MM-DD" with zero-padded month/day.
    test('formats as YYYY-MM-DD', () {
      final date = DateTime(2026, 3, 5);
      expect(formatDateForCounter(date), equals('2026-03-05'));
    });

    test('zero-pads single-digit month', () {
      final date = DateTime(2026, 1, 15);
      expect(formatDateForCounter(date), equals('2026-01-15'));
    });

    test('zero-pads single-digit day', () {
      final date = DateTime(2026, 11, 3);
      expect(formatDateForCounter(date), equals('2026-11-03'));
    });

    test('same day same string (no time component)', () {
      // Morning and evening of same day should produce same string
      // (so counter doesn't reset mid-day)
      final morning = DateTime(2026, 3, 24, 9, 0);
      final evening = DateTime(2026, 3, 24, 21, 0);
      expect(
        formatDateForCounter(morning),
        equals(formatDateForCounter(evening)),
      );
    });

    test('different days produce different strings', () {
      final today = DateTime(2026, 3, 24);
      final tomorrow = DateTime(2026, 3, 25);
      expect(
        formatDateForCounter(today),
        isNot(equals(formatDateForCounter(tomorrow))),
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 5: SavedPrinterModel Helpers
  //
  // SOURCE: lib/data/models/restaurant/db/saved_printer_model.dart
  //
  // These getters determine routing: which printer gets KOT vs receipt.
  // If isKotPrinter returns false for a 'both' printer, KOTs go to PDF.
  // ════════════════════════════════════════════════════════════════════════

  group('SavedPrinterModel — type and role helpers', () {
    // Helper to create test printer
    SavedPrinterModel makePrinter({
      String type = 'wifi',
      String role = 'both',
    }) {
      return SavedPrinterModel(
        id: 'test-1',
        name: 'Test Printer',
        type: type,
        address: '192.168.1.100:9100',
        paperSize: 80,
        role: role,
      );
    }

    // ── Type getters ──
    test('wifi printer → isBluetooth=false, isWifi=true, isUsb=false', () {
      final p = makePrinter(type: 'wifi');
      expect(p.isBluetooth, isFalse);
      expect(p.isWifi, isTrue);
      expect(p.isUsb, isFalse);
    });

    test('bluetooth printer → isBluetooth=true, isWifi=false', () {
      final p = makePrinter(type: 'bluetooth');
      expect(p.isBluetooth, isTrue);
      expect(p.isWifi, isFalse);
    });

    test('usb printer → isUsb=true, others false', () {
      final p = makePrinter(type: 'usb');
      expect(p.isUsb, isTrue);
      expect(p.isBluetooth, isFalse);
      expect(p.isWifi, isFalse);
    });

    // ── Role getters ──
    // These determine whether a printer receives KOT, receipt, or both
    test('role=kot → isKotPrinter=true, isReceiptPrinter=false', () {
      final p = makePrinter(role: 'kot');
      expect(p.isKotPrinter, isTrue);
      expect(p.isReceiptPrinter, isFalse);
    });

    test('role=receipt → isKotPrinter=false, isReceiptPrinter=true', () {
      final p = makePrinter(role: 'receipt');
      expect(p.isKotPrinter, isFalse);
      expect(p.isReceiptPrinter, isTrue);
    });

    test('role=both → isKotPrinter=true AND isReceiptPrinter=true', () {
      // This is the most common case — one printer handles everything
      final p = makePrinter(role: 'both');
      expect(p.isKotPrinter, isTrue);
      expect(p.isReceiptPrinter, isTrue);
    });

    // ── copyWith ──
    test('copyWith preserves unchanged fields', () {
      final original = makePrinter(type: 'wifi', role: 'kot');
      final updated = original.copyWith(name: 'New Name');

      expect(updated.name, equals('New Name'));
      expect(updated.type, equals('wifi'));       // unchanged
      expect(updated.role, equals('kot'));         // unchanged
      expect(updated.address, equals(original.address)); // unchanged
    });

    test('copyWith can change role without affecting type', () {
      final original = makePrinter(type: 'bluetooth', role: 'kot');
      final updated = original.copyWith(role: 'both');

      expect(updated.role, equals('both'));
      expect(updated.type, equals('bluetooth')); // unchanged
      expect(updated.isKotPrinter, isTrue);
      expect(updated.isReceiptPrinter, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 6: EOD Cash Reconciliation Formula
  //
  // SOURCE: eod_service.dart cash reconciliation section
  //   Expected = Opening + CashSales + CashIn - CashOut - CashExpenses
  //   Difference = Actual - Expected
  //   Status = Balanced (0) | Overage (>0) | Shortage (<0)
  //
  // WHY TEST THIS: Wrong cash reconciliation = staff accused of theft
  // when the formula is wrong, or actual theft goes undetected.
  // ════════════════════════════════════════════════════════════════════════

  // Extracted formula from eod_service.dart
  double calculateExpectedCash({
    required double openingBalance,
    required double cashSales,
    required double cashIn,
    required double cashOut,
    required double cashExpenses,
  }) {
    return openingBalance + cashSales + cashIn - cashOut - cashExpenses;
  }

  String reconciliationStatus(double difference) {
    if (difference.abs() < 0.01) return 'Balanced';
    if (difference > 0) return 'Overage';
    return 'Shortage';
  }

  group('EOD cash reconciliation formula', () {
    test('basic: opening + sales - no movements', () {
      // Staff starts with ₹5000, sells ₹10000 in cash, no cash in/out
      final expected = calculateExpectedCash(
        openingBalance: 5000,
        cashSales: 10000,
        cashIn: 0,
        cashOut: 0,
        cashExpenses: 0,
      );
      expect(expected, equals(15000.0));
    });

    test('with cash movements: in and out', () {
      // Opening ₹5000, Sales ₹10000, Owner deposit ₹2000, Safe drop ₹8000
      final expected = calculateExpectedCash(
        openingBalance: 5000,
        cashSales: 10000,
        cashIn: 2000,
        cashOut: 8000,
        cashExpenses: 0,
      );
      // 5000 + 10000 + 2000 - 8000 - 0 = 9000
      expect(expected, equals(9000.0));
    });

    test('with cash expenses', () {
      // Opening ₹5000, Sales ₹10000, Petty cash expense ₹500
      final expected = calculateExpectedCash(
        openingBalance: 5000,
        cashSales: 10000,
        cashIn: 0,
        cashOut: 0,
        cashExpenses: 500,
      );
      // 5000 + 10000 + 0 - 0 - 500 = 14500
      expect(expected, equals(14500.0));
    });

    test('full day scenario', () {
      // Realistic day:
      // Opening: ₹5000
      // Cash sales: ₹14400 (60% of ₹24000 total sales)
      // Cash in: ₹2000 (owner deposit)
      // Cash out: ₹10000 (safe drop)
      // Cash expenses: ₹500 (petty cash for vegetables)
      final expected = calculateExpectedCash(
        openingBalance: 5000,
        cashSales: 14400,
        cashIn: 2000,
        cashOut: 10000,
        cashExpenses: 500,
      );
      // 5000 + 14400 + 2000 - 10000 - 500 = 10900
      expect(expected, equals(10900.0));
    });

    // ── Reconciliation status ──
    test('balanced: actual equals expected', () {
      expect(reconciliationStatus(0.0), equals('Balanced'));
    });

    test('overage: actual > expected (more cash than expected)', () {
      // Staff counted ₹11000, expected ₹10900 → +₹100 overage
      expect(reconciliationStatus(100.0), equals('Overage'));
    });

    test('shortage: actual < expected (less cash — investigate)', () {
      // Staff counted ₹10400, expected ₹10900 → -₹500 shortage
      expect(reconciliationStatus(-500.0), equals('Shortage'));
    });

    test('tiny floating-point difference → balanced (tolerance)', () {
      // 0.001 is less than 0.01 tolerance → still "Balanced"
      expect(reconciliationStatus(0.001), equals('Balanced'));
      expect(reconciliationStatus(-0.005), equals('Balanced'));
    });
  });
}
