import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_reason.dart';

/// The rule that decides whether a stock correction costs money.
///
/// Both a theft and a miscount remove the same units, so the reason is the only
/// thing that tells them apart: one is an expense that must reach the loss and
/// profit reports, the other is pure bookkeeping. Getting this wrong either
/// hides real shrinkage or invents losses that never happened, which is why the
/// vocabulary is pinned here rather than trusted to the dropdown.
void main() {
  group('loss-bearing classification', () {
    test('shrinkage-style reasons are losses', () {
      expect(StockAdjustmentReason.damaged.isLoss, isTrue);
      expect(StockAdjustmentReason.expired.isLoss, isTrue);
      expect(StockAdjustmentReason.theft.isLoss, isTrue);
      expect(StockAdjustmentReason.internalUse.isLoss, isTrue);
      expect(StockAdjustmentReason.sample.isLoss, isTrue);
    });

    test('bookkeeping reasons are not losses', () {
      expect(StockAdjustmentReason.stockCount.isLoss, isFalse);
      expect(StockAdjustmentReason.foundExtra.isLoss, isFalse);
      expect(StockAdjustmentReason.dataEntryError.isLoss, isFalse);
    });
  });

  group('direction-appropriate options', () {
    test('an increase offers no loss-bearing reason', () {
      // Gaining units cannot cost money, so offering "Theft" on an increase
      // would let a user book a loss while stock went UP.
      expect(
        StockAdjustmentReason.increaseReasons.where((r) => r.isLoss),
        isEmpty,
      );
    });

    test('an increase still allows corrections and found stock', () {
      final codes =
          StockAdjustmentReason.increaseReasons.map((r) => r.code).toSet();
      expect(codes, contains(StockAdjustmentReason.foundExtra.code));
      expect(codes, contains(StockAdjustmentReason.stockCount.code));
      expect(codes, contains(StockAdjustmentReason.dataEntryError.code));
    });

    test('a decrease excludes "found extra" but keeps every loss reason', () {
      final codes =
          StockAdjustmentReason.decreaseReasons.map((r) => r.code).toSet();
      expect(codes, isNot(contains(StockAdjustmentReason.foundExtra.code)));
      expect(codes, contains(StockAdjustmentReason.theft.code));
      expect(codes, contains(StockAdjustmentReason.damaged.code));
    });

    test('both directions are non-empty subsets of the full list', () {
      // Guards against a future edit that filters everything out and leaves the
      // dropdown empty, which would make adjustment impossible rather than
      // merely wrong.
      expect(StockAdjustmentReason.increaseReasons, isNotEmpty);
      expect(StockAdjustmentReason.decreaseReasons, isNotEmpty);
      for (final r in StockAdjustmentReason.increaseReasons) {
        expect(StockAdjustmentReason.all, contains(r));
      }
      for (final r in StockAdjustmentReason.decreaseReasons) {
        expect(StockAdjustmentReason.all, contains(r));
      }
    });
  });

  group('note requirement', () {
    test('only "data entry error" forces a note', () {
      final forced =
          StockAdjustmentReason.all.where((r) => r.requiresNote).toList();
      expect(forced, hasLength(1));
      expect(forced.single.code, StockAdjustmentReason.dataEntryError.code);
    });
  });

  group('code round-trip', () {
    test('every reason is resolvable by its code', () {
      for (final r in StockAdjustmentReason.all) {
        expect(StockAdjustmentReason.byCode(r.code), same(r));
      }
    });

    test('codes are unique', () {
      final codes = StockAdjustmentReason.all.map((r) => r.code).toSet();
      expect(codes, hasLength(StockAdjustmentReason.all.length));
    });

    test('an unknown code resolves to null, and its label falls through', () {
      expect(StockAdjustmentReason.byCode('nonsense'), isNull);
      // History rows store the label, so an unrecognised value must be shown
      // as-is rather than replaced with 'Unknown'.
      expect(StockAdjustmentReason.labelFor('Legacy reason'), 'Legacy reason');
    });

    test('a known code maps to its label', () {
      expect(
        StockAdjustmentReason.labelFor(StockAdjustmentReason.theft.code),
        StockAdjustmentReason.theft.label,
      );
    });
  });
}
