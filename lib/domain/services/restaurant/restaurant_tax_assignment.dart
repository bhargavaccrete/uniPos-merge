import '../../../data/models/common/taxmodel_314.dart';
import '../../../data/models/restaurant/db/itemmodel_302.dart';

/// What [RestaurantTaxAssignment.planApply] decided.
enum TaxApplyOutcome {
  /// The tax was added and its rate added to the item's total.
  applied,

  /// The item already charged exactly this rate with no tax linked (an
  /// imported item); the tax is now linked and the rate is unchanged.
  linked,

  /// The tax is already on the item. Nothing changes.
  alreadyApplied,

  /// The item already carries [RestaurantTaxAssignment.maxTaxesPerItem] taxes.
  atLimit,

  /// The item charges a rate with no tax linked, and no tax has that rate.
  /// Nothing changes; the item needs fixing in Edit Item.
  unlinkedRate,
}

enum TaxReviewReason {
  /// A linked tax no longer exists.
  missingTax,

  /// A rate is charged but no tax is linked.
  rateWithoutTax,

  /// The charged rate is not the sum of the linked taxes.
  rateMismatch,

  /// Two or more taxes that are not a CGST + SGST pair, where bills print
  /// CGST/SGST (India).
  unpairedComponents,
}

class TaxReviewIssue {
  final Items item;
  final TaxReviewReason reason;

  const TaxReviewIssue(this.item, this.reason);

  String get message => switch (reason) {
        TaxReviewReason.missingTax => 'Linked tax was deleted',
        TaxReviewReason.rateWithoutTax => 'Tax rate with no tax linked',
        TaxReviewReason.rateMismatch =>
          'Tax rate does not match its taxes',
        TaxReviewReason.unpairedComponents =>
          'More than one tax (not a CGST + SGST pair)',
      };
}

/// Rules for how restaurant items carry taxes: `taxIds` names the taxes,
/// `taxRate` is their summed decimal rate, and the two must agree — bills
/// read only `taxRate`.
///
/// PURE: nothing here reads stores or writes Hive. Country-neutral except
/// [review]'s `splitsIntoComponents` check, which the caller passes in.
class RestaurantTaxAssignment {
  RestaurantTaxAssignment._();

  static const int maxTaxesPerItem = 2;

  /// Rates closer than this are the same rate (decimal, so 1e-9 of 100%).
  static const double _eps = 1e-9;

  /// Tax id → decimal rate (5% → 0.05). Taxes without a percentage are left
  /// out, so they read as unknown.
  static Map<String, double> ratesById(Iterable<Tax> taxes) => {
        for (final t in taxes)
          if (t.taxperecentage != null) t.id: t.taxperecentage! / 100.0,
      };

  /// Sum of [ids]' rates, or null when any id is not in [rates].
  static double? summedRate(List<String> ids, Map<String, double> rates) {
    var sum = 0.0;
    for (final id in ids) {
      final r = rates[id];
      if (r == null) return null;
      sum += r;
    }
    return sum;
  }

  /// The first tax whose rate equals [rate], or null.
  static String? taxWithRate(double rate, Map<String, double> rates) {
    for (final e in rates.entries) {
      if ((e.value - rate).abs() < _eps) return e.key;
    }
    return null;
  }

  /// Adding tax [taxId] at decimal [taxRate] to an item holding
  /// [currentIds] / [currentRate]. [ids] and [rate] are what to store when
  /// the outcome is [TaxApplyOutcome.applied] or [TaxApplyOutcome.linked].
  ///
  /// An item with a rate but no linked tax (an import before taxIds were
  /// saved) is first linked to the tax with that exact rate, so the rate is
  /// never counted twice. With no such tax nothing is guessed.
  static ({TaxApplyOutcome outcome, List<String>? ids, double? rate})
      planApply({
    required List<String>? currentIds,
    required double? currentRate,
    required String taxId,
    required double taxRate,
    required Map<String, double> rates,
  }) {
    var ids = List<String>.from(currentIds ?? const <String>[]);
    final rate = currentRate ?? 0;

    if (ids.isEmpty && rate > _eps) {
      final match = (rate - taxRate).abs() < _eps
          ? taxId
          : taxWithRate(rate, rates);
      if (match == null) {
        return (outcome: TaxApplyOutcome.unlinkedRate, ids: null, rate: null);
      }
      if (match == taxId) {
        return (outcome: TaxApplyOutcome.linked, ids: [taxId], rate: rate);
      }
      ids = [match];
    }

    if (ids.contains(taxId)) {
      return (outcome: TaxApplyOutcome.alreadyApplied, ids: null, rate: null);
    }
    if (ids.length >= maxTaxesPerItem) {
      return (outcome: TaxApplyOutcome.atLimit, ids: null, rate: null);
    }
    return (
      outcome: TaxApplyOutcome.applied,
      ids: [...ids, taxId],
      rate: rate + taxRate,
    );
  }

  /// Removing tax [taxId] (decimal [taxRate]) from an item, or null when the
  /// item does not carry it. The remaining rate is the sum of the remaining
  /// taxes' current rates; when one of them is unknown, [taxRate] is
  /// subtracted instead so no other charge is dropped silently.
  static ({List<String>? ids, double? rate})? planRemove({
    required List<String>? currentIds,
    required double? currentRate,
    required String taxId,
    required double taxRate,
    required Map<String, double> rates,
  }) {
    final ids = List<String>.from(currentIds ?? const <String>[]);
    if (!ids.remove(taxId)) return null;
    if (ids.isEmpty) return (ids: null, rate: null);
    final r = summedRate(ids, rates) ?? ((currentRate ?? 0) - taxRate);
    return (ids: ids, rate: r > _eps ? r : null);
  }

  /// An item's rate after tax [editedId] changed from [oldRate] to [newRate]
  /// (decimal). [ratesAfter] already holds the new rate. The sum of its
  /// taxes when all are known; otherwise only the edited tax's share moves.
  static double? rateAfterTaxEdit({
    required List<String>? ids,
    required double? currentRate,
    required double oldRate,
    required double newRate,
    required Map<String, double> ratesAfter,
  }) {
    final r = summedRate(ids ?? const [], ratesAfter) ??
        ((currentRate ?? 0) - oldRate + newRate);
    return r > _eps ? r : null;
  }

  /// Items that link tax [taxId].
  static List<Items> itemsUsing(String taxId, Iterable<Items> items) => [
        for (final i in items)
          if (i.taxIds?.contains(taxId) ?? false) i,
      ];

  /// Read-only: items whose tax assignment is inconsistent. One reason per
  /// item, the most basic first. [splitsIntoComponents] is
  /// `TaxLabelRule.splitsIntoComponents` — only there do two taxes print as
  /// a wrong CGST/SGST split.
  static List<TaxReviewIssue> review(
    Iterable<Items> items,
    Iterable<Tax> taxes, {
    required bool splitsIntoComponents,
  }) {
    final rates = ratesById(taxes);
    final byId = {for (final t in taxes) t.id: t};
    final issues = <TaxReviewIssue>[];
    for (final item in items) {
      final ids = item.taxIds ?? const <String>[];
      final rate = item.taxRate ?? 0;
      if (ids.isEmpty) {
        if (rate > _eps) {
          issues.add(TaxReviewIssue(item, TaxReviewReason.rateWithoutTax));
        }
        continue;
      }
      final sum = summedRate(ids, rates);
      if (sum == null) {
        issues.add(TaxReviewIssue(item, TaxReviewReason.missingTax));
        continue;
      }
      if ((sum - rate).abs() > 1e-6) {
        issues.add(TaxReviewIssue(item, TaxReviewReason.rateMismatch));
        continue;
      }
      if (splitsIntoComponents &&
          ids.length >= 2 &&
          !isComponentPair([for (final id in ids) byId[id]!])) {
        issues.add(TaxReviewIssue(item, TaxReviewReason.unpairedComponents));
      }
    }
    return issues;
  }

  /// Exactly a CGST tax and an SGST/UTGST tax at the same rate — two taxes
  /// that together print correctly as CGST + SGST.
  static bool isComponentPair(List<Tax> taxes) {
    if (taxes.length != 2) return false;
    bool isCentral(Tax t) => t.taxname.toUpperCase().contains('CGST');
    bool isState(Tax t) {
      final n = t.taxname.toUpperCase();
      return n.contains('SGST') || n.contains('UTGST');
    }

    final a = taxes[0], b = taxes[1];
    final paired = (isCentral(a) && isState(b)) || (isCentral(b) && isState(a));
    final sameRate = a.taxperecentage != null &&
        b.taxperecentage != null &&
        (a.taxperecentage! - b.taxperecentage!).abs() < 1e-9;
    return paired && sameRate;
  }
}
