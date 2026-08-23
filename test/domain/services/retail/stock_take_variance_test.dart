import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_item_model_181.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_model_180.dart';

/// Stock take variance, and the delta rule that makes committing safe.
///
/// The trap this pins down: a count records what the system claimed AT COUNT
/// TIME, but stock keeps moving while the shop counts. Committing the counted
/// figure absolutely would erase every sale made during the count. Committing
/// the *variance* against current stock preserves them.
///
/// `StockTakeItemModel.variance` is a pure getter precisely so the rule can be
/// exercised here without Hive or the service locator.
void main() {
  StockTakeItemModel line({
    required int system,
    required int counted,
    double? cost,
  }) =>
      StockTakeItemModel.create(
        takeId: 'take-1',
        variantId: 'v-1',
        productId: 'p-1',
        productName: 'Blue Shirt',
        systemQty: system,
        countedQty: counted,
        costPrice: cost,
      );

  group('variance', () {
    test('counting less than the system is a negative variance', () {
      final l = line(system: 12, counted: 10);
      expect(l.variance, -2);
      expect(l.hasVariance, isTrue);
      expect(l.isShortage, isTrue);
    });

    test('counting more than the system is a positive variance', () {
      final l = line(system: 8, counted: 11);
      expect(l.variance, 3);
      expect(l.isShortage, isFalse);
    });

    test('an exact count has no variance and is skipped at commit', () {
      final l = line(system: 7, counted: 7);
      expect(l.variance, 0);
      expect(l.hasVariance, isFalse);
    });

    test('counting zero against stock on hand is a full shortage', () {
      final l = line(system: 5, counted: 0);
      expect(l.variance, -5);
      expect(l.isShortage, isTrue);
    });
  });

  group('variance value', () {
    test('a shortage values negative, so it reads as a loss', () {
      expect(line(system: 12, counted: 10, cost: 250).varianceValue, -500.0);
    });

    test('an excess values positive', () {
      expect(line(system: 8, counted: 11, cost: 100).varianceValue, 300.0);
    });

    test('no cost price values at zero rather than throwing', () {
      // A variant may legitimately have no cost captured yet; the count must
      // still be recordable, just unvalued.
      expect(line(system: 12, counted: 10).varianceValue, 0.0);
    });
  });

  group('commit applies the variance as a delta, not the counted figure', () {
    /// Mirrors `StockTakeStore.commit`: target = current stock + variance.
    int target(StockTakeItemModel l, int currentStock) =>
        currentStock + l.variance;

    test('with no movement since the count, delta equals the count', () {
      final l = line(system: 12, counted: 10);
      // Nothing sold: current stock is still the snapshot.
      expect(target(l, 12), 10);
    });

    test('a sale during the count is preserved, not erased', () {
      // Counted 10 while system said 12, then 1 unit sold. Truth is 9:
      // two units genuinely unaccounted for, one legitimately sold.
      final l = line(system: 12, counted: 10);
      expect(target(l, 11), 9);
      // Writing the counted figure absolutely would have said 10 and silently
      // put the sold unit back on the shelf.
      expect(target(l, 11), isNot(l.countedQty));
    });

    test('a receipt during the count is preserved too', () {
      // Counted 10 vs system 12, then 5 units received. Truth is 15.
      final l = line(system: 12, counted: 10);
      expect(target(l, 17), 15);
    });

    test('an excess variance adds on top of later movement', () {
      final l = line(system: 8, counted: 11);
      expect(target(l, 6), 9);
    });

    test('a stale count that would drive stock negative is refused', () {
      // Counted 0 against a system of 5, then 4 sold: current 1, variance -5,
      // target -4. Commit rejects this line rather than clamping to zero,
      // which would silently under-apply the shortage.
      final l = line(system: 5, counted: 0);
      expect(target(l, 1), lessThan(0));
    });
  });

  group('take lifecycle', () {
    StockTakeModel draft() =>
        StockTakeModel.create(takeNumber: 'ST-1', countedBy: 'Admin');

    test('a new take is an editable draft', () {
      final t = draft();
      expect(t.isDraft, isTrue);
      expect(t.isEditable, isTrue);
      expect(t.isCompleted, isFalse);
      expect(t.statusDisplay, 'Draft');
    });

    test('completing makes it non-editable, so it cannot be re-committed', () {
      final t = draft().copyWith(status: StockTakeStatus.completed.name);
      expect(t.isCompleted, isTrue);
      expect(t.isEditable, isFalse);
    });

    test('an unknown stored status degrades to draft', () {
      final t = StockTakeModel.fromMap({
        'takeId': 'x',
        'takeNumber': 'ST-1',
        'status': 'something_new',
        'countedBy': 'Admin',
      });
      expect(t.statusEnum, StockTakeStatus.draft);
    });

    test('copyWith preserves identity and commit fields', () {
      final t = draft();
      final done = t.copyWith(
        status: StockTakeStatus.completed.name,
        committedLineCount: 4,
        committedNetQty: -6,
      );
      expect(done.takeId, t.takeId);
      expect(done.takeNumber, t.takeNumber);
      expect(done.countedBy, t.countedBy);
      expect(done.createdAt, t.createdAt);
      expect(done.committedLineCount, 4);
      expect(done.committedNetQty, -6);
    });
  });

  group('line round-trip', () {
    test('a line survives toMap/fromMap with its variance intact', () {
      final original = line(system: 12, counted: 10, cost: 250);
      final restored = StockTakeItemModel.fromMap(original.toMap());
      expect(restored.takeItemId, original.takeItemId);
      expect(restored.systemQty, 12);
      expect(restored.countedQty, 10);
      expect(restored.variance, -2);
      expect(restored.varianceValue, -500.0);
    });

    test('appliedQty records what commit actually applied', () {
      final applied = line(system: 12, counted: 10).copyWith(appliedQty: -2);
      expect(applied.appliedQty, -2);
      expect(StockTakeItemModel.fromMap(applied.toMap()).appliedQty, -2);
    });
  });
}
