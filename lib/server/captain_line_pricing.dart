import '../data/models/restaurant/db/cartmodel_308.dart';
import '../data/models/restaurant/db/extramodel_303.dart';
import '../data/models/restaurant/db/itemmodel_302.dart';
import '../data/models/restaurant/db/itemvariantemodel_312.dart';
import '../data/models/restaurant/db/toppingmodel_304.dart';
import '../domain/services/restaurant/inventory_service.dart';

/// A Captain line the POS refuses; [message] is shown to the waiter.
class CaptainLineRejected implements Exception {
  final String message;
  const CaptainLineRejected(this.message);

  @override
  String toString() => message;
}

/// Prices Captain's send-order lines from the POS's own menu (AND-04/05).
///
/// Captain's price, tax rate and discount are never trusted: each line is
/// priced the way the POS prices its own (`ItemOptionsDialog._recalculateTotal`)
/// — variant or item price, × weight for weighed items, plus extras ×
/// their quantity. Quantities must be whole and in range. Any bad line
/// rejects the whole request, so nothing is saved.
class CaptainLinePricing {
  static const int maxQuantity = 999;

  /// [variantNames] maps a variant id to its name (the name Captain sends);
  /// [extrasById] maps an extra group id to the group.
  static List<CartItem> reprice(
    List<CartItem> lines, {
    required Map<String, Items> itemsById,
    required Map<String, String> variantNames,
    required Map<String, Extramodel> extrasById,
  }) =>
      [
        for (final line in lines)
          _price(line, itemsById, variantNames, extrasById),
      ];

  static CartItem _price(
    CartItem line,
    Map<String, Items> itemsById,
    Map<String, String> variantNames,
    Map<String, Extramodel> extrasById,
  ) {
    final item = itemsById[line.productId];
    if (item == null) {
      throw CaptainLineRejected(
          '"${line.title}" is not on the POS menu. Refresh the menu and try again.');
    }

    double? weight;
    if (item.isSoldByWeight) {
      if (line.quantity != 1) {
        throw CaptainLineRejected('Invalid quantity for "${item.name}".');
      }
      final display = line.weightDisplay?.trim() ?? '';
      weight = display.isEmpty
          ? 0
          : InventoryService.weightInStockUnit(display, item.unit ?? 'kg');
      if (weight <= 0) {
        throw CaptainLineRejected('Invalid weight for "${item.name}".');
      }
    } else if (line.quantity < 1 || line.quantity > maxQuantity) {
      throw CaptainLineRejected('Invalid quantity for "${item.name}".');
    }

    ItemVariante? variant;
    final variantName = line.variantName;
    if (variantName != null && variantName.isNotEmpty) {
      for (final v in item.variant ?? const <ItemVariante>[]) {
        if ((variantNames[v.variantId] ?? v.variantId) == variantName) {
          variant = v;
          break;
        }
      }
      if (variant == null) {
        throw CaptainLineRejected(
            '"$variantName" is no longer available for "${item.name}". '
            'Refresh the menu and try again.');
      }
    }

    var unitPrice = variant?.price ?? item.price ?? 0.0;
    if (weight != null) unitPrice *= weight;

    final extras = <Map<String, dynamic>>[];
    for (final e in line.extras ?? const <Map<String, dynamic>>[]) {
      final name = e['name'] as String? ?? '';
      final quantity = (e['quantity'] as num?)?.toInt() ?? 1;
      if (quantity < 1 || quantity > maxQuantity) {
        throw CaptainLineRejected('Invalid quantity for extra "$name".');
      }
      final topping = _topping(item, e['categoryId'] as String?, name, extrasById);
      if (topping == null) {
        throw CaptainLineRejected(
            'Extra "$name" is no longer available for "${item.name}". '
            'Refresh the menu and try again.');
      }
      final price = variant != null &&
              topping.isContainSize == true &&
              topping.variantPrices != null
          ? topping.getPriceForVariant(variant.variantId)
          : topping.price;
      unitPrice += price * quantity;
      extras.add({...e, 'price': price, 'quantity': quantity});
    }

    return CartItem(
      id: line.id,
      productId: item.id,
      title: item.name,
      price: unitPrice,
      quantity: line.quantity,
      isStockManaged: item.trackInventory,
      variantName: variant == null ? null : variantName,
      variantPrice: variant?.price,
      choiceNames: line.choiceNames,
      instruction: line.instruction,
      taxRate: item.taxRate,
      extras: line.extras == null ? null : extras,
      weightDisplay: line.weightDisplay,
      categoryName: line.categoryName,
    );
  }

  /// The topping [name] in one of [item]'s own extra groups — the group
  /// [categoryId] when given, else any of them.
  static Topping? _topping(Items item, String? categoryId, String name,
      Map<String, Extramodel> extrasById) {
    final groupIds = item.extraId ?? const <String>[];
    final candidates = categoryId != null && categoryId.isNotEmpty
        ? (groupIds.contains(categoryId) ? [categoryId] : const <String>[])
        : groupIds;
    for (final id in candidates) {
      for (final t in extrasById[id]?.topping ?? const <Topping>[]) {
        if (t.name == name) return t;
      }
    }
    return null;
  }
}
