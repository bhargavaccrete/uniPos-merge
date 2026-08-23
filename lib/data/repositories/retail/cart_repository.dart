import 'package:hive/hive.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import '../../models/retail/hive_model/cart_model_202.dart';
import '../../models/retail/hive_model/billing_tab_model_173.dart';

/// Repository layer for Cart data access (Retail).
/// Owns every Hive read/write for the cart-item and billing-tab boxes so
/// [CartStore] stays pure state — same split the restaurant side uses.
///
/// Reads are synchronous because the boxes are already opened by HiveInit and
/// [CartStore]'s constructor restores the active tab before the first frame.
/// Writes are async to match the rest of the repository layer.
class CartRepository {
  late Box<CartItemModel> _cartBox;
  late Box<BillingTabModel> _tabBox;

  CartRepository() {
    _cartBox = Hive.box<CartItemModel>(HiveBoxNames.cartItems);
    _tabBox = Hive.box<BillingTabModel>(HiveBoxNames.billingTabs);
  }

  // ==================== Cart items ====================

  /// All persisted cart items.
  List<CartItemModel> getAllCartItems() => _cartBox.values.toList();

  /// Insert or update a cart item (keyed by its `cartItemId`).
  Future<void> saveCartItem(CartItemModel item) async {
    await _cartBox.put(item.cartItemId, item);
  }

  /// Delete a single cart item.
  Future<void> deleteCartItem(String cartItemId) async {
    await _cartBox.delete(cartItemId);
  }

  /// Wipe the cart-item box.
  Future<void> clearCartItems() async {
    await _cartBox.clear();
  }

  // ==================== Billing tabs ====================

  /// All saved billing tabs. Empty on a fresh install — the store then
  /// creates its default "Tab 1".
  List<BillingTabModel> getAllTabs() => _tabBox.values.toList();

  /// Insert or update a billing tab (keyed by its `id`).
  Future<void> saveTab(BillingTabModel tab) async {
    await _tabBox.put(tab.id, tab);
  }

  /// Delete a billing tab.
  Future<void> deleteTab(String tabId) async {
    await _tabBox.delete(tabId);
  }

  /// Wipe the billing-tab box.
  Future<void> clearTabs() async {
    await _tabBox.clear();
  }
}
