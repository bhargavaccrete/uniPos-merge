import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';

/// One legacy Finished item that looks bought-in and resold (Phase 1.9, Q2).
/// A candidate for the owner to review — never a classification.
class TradeItemSuggestion {
  final Items item;

  /// GRN receipts: `in` rows with reason `Purchase (PO-…)`.
  final int supplierReceipts;

  /// Manual adds recorded as `Restock / Purchase`.
  final int manualPurchases;

  const TradeItemSuggestion({
    required this.item,
    required this.supplierReceipts,
    required this.manualPurchases,
  });

  int get evidence => supplierReceipts + manualPurchases;

  /// Why it was suggested, in the owner's terms.
  List<String> get reasons => [
        if (supplierReceipts > 0)
          'Received from a supplier ${_times(supplierReceipts)}',
        if (manualPurchases > 0)
          'Restocked as a purchase ${_times(manualPurchases)}',
        'No recipe',
        'Never produced in-house',
      ];

  static String _times(int n) => n == 1 ? '1 time' : '$n times';
}

/// Which legacy Finished items look like Trade Items. Pure — reads existing
/// data only and changes nothing.
///
/// Eligible: stored type empty or Finished (not legacy Recipe-Based), no
/// preparation mode stored (never saved since the redesign — saving it in
/// Edit Item counts as reviewed), no recipe, never produced. Suggested only
/// with purchase evidence: a GRN receipt or a manual "Restock / Purchase".
/// Stock alone is not evidence — a prepared cake holds stock too.
class TradeItemSuggestionRule {
  TradeItemSuggestionRule._();

  static const String _grnPrefix = 'Purchase (';
  static const String _manualPurchase = 'Restock / Purchase';
  static const String _production = 'Production batch';

  static List<TradeItemSuggestion> suggest({
    required Iterable<Items> items,
    required bool Function(String itemId) hasRecipe,
    required Iterable<StockMovementModel> movements,
  }) {
    final receipts = <String, int>{};
    final manual = <String, int>{};
    final produced = <String>{};
    for (final m in movements) {
      if (m.type != 'in') continue;
      if (m.reason.startsWith(_grnPrefix)) {
        receipts.update(m.itemId, (c) => c + 1, ifAbsent: () => 1);
      } else if (m.reason == _manualPurchase) {
        manual.update(m.itemId, (c) => c + 1, ifAbsent: () => 1);
      } else if (m.reason == _production) {
        produced.add(m.itemId);
      }
    }

    final result = <TradeItemSuggestion>[];
    for (final item in items) {
      if (!_isUnreviewedLegacyFinished(item)) continue;
      if (hasRecipe(item.id) || produced.contains(item.id)) continue;
      final s = TradeItemSuggestion(
        item: item,
        supplierReceipts: receipts[item.id] ?? 0,
        manualPurchases: manual[item.id] ?? 0,
      );
      if (s.evidence > 0) result.add(s);
    }
    result.sort((a, b) {
      final e = b.evidence.compareTo(a.evidence);
      return e != 0 ? e : a.item.name.compareTo(b.item.name);
    });
    return result;
  }

  static bool _isUnreviewedLegacyFinished(Items item) =>
      (item.productType == null ||
          item.productType == ProductType.finishedGood) &&
      item.prepMode == null;
}
