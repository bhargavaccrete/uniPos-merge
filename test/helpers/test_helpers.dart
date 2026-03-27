/// Shared test helpers for creating test objects.
///
/// WHY: Multiple test files need CartItem objects. Instead of duplicating
/// the helper in every test file, we define it once here and import it.
/// This is the test equivalent of a shared utility.
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';

/// Create a minimal CartItem for testing.
///
/// CartItem has 16 fields but most tests only need a few.
/// This helper provides sensible defaults for everything so tests
/// only specify what they're actually testing.
///
/// Example:
/// ```dart
/// makeCartItem(price: 100, quantity: 2, taxRate: 0.05)
/// ```
CartItem makeCartItem({
  String? id,
  String? productId,
  String title = 'Test Item',
  required double price,
  int quantity = 1,
  double? taxRate,
  String? variantName,
  double? variantPrice,
  List<String>? choiceNames,
  String? instruction,
  String? weightDisplay,
  List<Map<String, dynamic>>? extras,
  String? categoryName,
  bool? isStockManaged,
  int? refundedQuantity,
}) {
  return CartItem(
    id: id ?? 'test-${price.toInt()}-${quantity}',
    productId: productId ?? 'prod-${price.toInt()}',
    title: title,
    price: price,
    quantity: quantity,
    taxRate: taxRate,
    variantName: variantName,
    variantPrice: variantPrice,
    choiceNames: choiceNames,
    instruction: instruction,
    weightDisplay: weightDisplay,
    extras: extras,
    categoryName: categoryName,
    isStockManaged: isStockManaged,
    refundedQuantity: refundedQuantity,
  );
}
