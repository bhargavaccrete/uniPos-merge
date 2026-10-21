import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Identity and validation for an "open"/quick item — a line the cashier types
/// at the POS to sell something the catalogue does not carry.
///
/// **Why a synthetic id rather than a nullable one.** `CartItemModel.variantId`
/// / `productId` and `SaleItemModel.varianteId` / `productId` are required
/// non-nullable Strings, and `CartStore` keys every mutation on
/// `items.indexWhere((i) => i.variantId == variantId)`. Making those fields
/// nullable would touch four Hive models and every mutation site; minting an id
/// that resolves to nothing touches neither.
///
/// **The prefix IS the flag.** Every path that would need to know "this is
/// ad-hoc" already carries the id: the cart line, the parked-sale line and the
/// sale line all persist it as an ordinary String. So park/restore, checkout and
/// reporting recognise a quick item with no extra Hive field and no adapter
/// regeneration.
///
/// **Nothing resolves these ids, and that is the point.** Every catalogue lookup
/// on the sale path is already null-guarded — stock deduction skips the line
/// (`RetailInventoryService.deductStockForSale`), checkout stores a null
/// `costPrice`, and the profit reports count the line's revenue while reporting
/// its cost as genuinely unknown. A quick item therefore sells, prints and
/// reports correctly without ever creating a Product or Variant.
class QuickItemService {
  QuickItemService._();

  /// Marks an id as belonging to a quick item. Catalogue ids are bare uuids, so
  /// no real variant can collide with this.
  static const String idPrefix = 'QUICK-';

  /// A fresh line identity. **Unique per call, never reused** — `CartStore`
  /// merges by `variantId`, so a shared id would make a second quick item bump
  /// the first one's quantity instead of adding its own line.
  static String newVariantId() => '$idPrefix${_uuid.v4()}';

  /// Unique per line as well, deliberately NOT a shared `'QUICK'` constant:
  /// `ReportService.getProductWiseSalesReport` names each group from the FIRST
  /// line it encounters, so one shared id would label every quick item ever sold
  /// with whichever name happened to sell first.
  static String newProductId() => '${idPrefix}P-${_uuid.v4()}';

  /// True when this line was typed at the POS rather than picked from the
  /// catalogue. Safe on any id — a catalogue variant simply returns false.
  static bool isQuickItem(String variantId) => variantId.startsWith(idPrefix);

  /// Null when valid, else the message to show under the field.
  static String? validateName(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.isEmpty) return 'Enter an item name';
    return null;
  }

  static String? validatePrice(double? price) {
    if (price == null) return 'Enter a price';
    if (price <= 0) return 'Price must be greater than 0';
    return null;
  }

  /// Quick items sell in whole units — they have no variant to carry the
  /// `isDecimalQuantity` flag, and `CartStore` already steps them by 1.
  static String? validateQty(int? qty) {
    if (qty == null) return 'Enter a quantity';
    if (qty < 1) return 'Quantity must be at least 1';
    return null;
  }
}
