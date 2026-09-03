import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// Who may CHANGE the catalogue — products, variants, categories, attributes
/// and bulk import.
///
/// Admin and Manager pass; a Cashier does not. Viewing is deliberately NOT
/// gated: a cashier still opens Products and Inventory to look up a price,
/// stock level or barcode at the counter. Only the mutations are hidden.
///
/// Mirrors restaurant's six Manage Menu tabs, which share one `_canEdit` getter
/// to hide the add bar and the edit/delete icons while leaving the read-only
/// surface intact.
///
/// Callers must HIDE the action when this is false rather than showing it and
/// refusing — the retail house pattern.
class CatalogPermission {
  CatalogPermission._();

  static bool get canEdit => RestaurantSession.canAccess('catalogEdit');
}
