import 'package:flutter/material.dart';

import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/presentation/widget/componets/common/weight_item_dialog.dart'
    as shared;

/// Restaurant's adapter over the shared [showWeightItemDialog].
///
/// The dialog itself is vertical-neutral (see
/// `widget/componets/common/weight_item_dialog.dart`); this file holds the only
/// restaurant-specific part — turning the cashier's answer into a [CartItem].
///
/// Kept as a separate wrapper with the ORIGINAL signature so `menu.dart`'s call
/// site is unchanged: sharing the dialog with retail must not disturb a working
/// restaurant flow.
Future<CartItem?> showWeightItemDialog(BuildContext context, Items item) async {
  if (!item.isSoldByWeight) return null;

  final selection = await shared.showWeightItemDialog(
    context,
    name: item.name,
    unitPrice: item.price ?? 0.0,
    unit: item.unit,
    stockQuantity: item.stockQuantity,
    trackInventory: item.trackInventory,
  );
  if (selection == null) return null;

  // Reproduced verbatim from the pre-share version. Two things here are
  // deliberate and must not be "tidied":
  //   * `price` carries the LINE TOTAL with `quantity: 1` — a 1.75 kg sale is
  //     one unit costing the whole amount, which is what the cart totals assume.
  //   * `id` reuses the item id rather than a fresh uuid (unlike the non-weight
  //     path), which is what decides how repeat weighed lines merge.
  return CartItem(
    productId: item.id,
    id: item.id,
    title: item.name,
    price: selection.amount,
    quantity: 1,
    taxRate: item.taxRate,
    weightDisplay: selection.display,
  );
}
