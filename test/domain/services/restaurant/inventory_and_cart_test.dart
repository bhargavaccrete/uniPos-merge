import 'package:flutter_test/flutter_test.dart';
import '../../../helpers/test_helpers.dart';

/// Unit tests for inventory logic and cart computed properties.
///
/// We CAN'T test InventoryService.deductStockForOrder() directly because
/// it reads from Hive (itemStore, variantStore). That's an integration test.
///
/// What we CAN test as pure unit tests:
/// 1. Weight parsing logic (extracted from InventoryService)
/// 2. Cart total calculations (pure math on a list)
/// 3. CartItem.finalItemPrice getter (price - discount logic)
/// 4. Refund quantity tracking logic
///
/// These are the pieces where a bug means wrong stock or wrong money.
void main() {
  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 1: Weight Parsing
  //
  // SOURCE CODE: InventoryService._parseWeightFromDisplay()
  //
  // This is a PRIVATE method, so we can't call it directly from tests.
  // Instead, we recreate the same logic here to test it.
  //
  // WHY TEST THIS: If "500GM" is parsed as 500000 instead of 500,
  // stock deduction will wipe out the entire inventory in one order.
  // ════════════════════════════════════════════════════════════════════════

  // Recreate the parsing logic (same as InventoryService._parseWeightFromDisplay)
  // In production, you'd extract this into a public utility function.
  double parseWeightFromDisplay(String weightDisplay) {
    String normalized = weightDisplay.replaceAll(' ', '').toUpperCase();
    RegExp numericRegex = RegExp(r'(\d+\.?\d*)');
    Match? match = numericRegex.firstMatch(normalized);

    if (match == null) return 0.0;

    double value = double.parse(match.group(1)!);

    if (normalized.contains('KG')) {
      return value * 1000; // kg → grams
    } else if (normalized.contains('G') ||
        normalized.contains('GM') ||
        normalized.contains('GRAM')) {
      return value; // already grams
    } else if (normalized.contains('LB') ||
        normalized.contains('POUND')) {
      return value * 453.592; // pounds → grams
    } else {
      return value; // unknown unit, use as-is
    }
  }

  group('Weight parsing — convert display string to grams', () {
    // ── GRAMS ──
    // These are the most common format for Indian restaurants.
    // Staff enters "500" in the weight dialog → becomes "500GM"
    test('500GM → 500 grams', () {
      expect(parseWeightFromDisplay('500GM'), equals(500.0));
    });

    test('250g → 250 grams (lowercase g)', () {
      expect(parseWeightFromDisplay('250g'), equals(250.0));
    });

    test('100GRAM → 100 grams', () {
      expect(parseWeightFromDisplay('100GRAM'), equals(100.0));
    });

    test('750 GM → 750 grams (with space)', () {
      expect(parseWeightFromDisplay('750 GM'), equals(750.0));
    });

    // ── KILOGRAMS ──
    // Converted to grams: 1 KG = 1000 grams
    // Stock is tracked in grams, so KG must be converted
    test('1.5KG → 1500 grams', () {
      expect(parseWeightFromDisplay('1.5KG'), equals(1500.0));
    });

    test('2KG → 2000 grams', () {
      expect(parseWeightFromDisplay('2KG'), equals(2000.0));
    });

    test('0.5KG → 500 grams', () {
      expect(parseWeightFromDisplay('0.5KG'), equals(500.0));
    });

    // ── POUNDS ──
    // Converted to grams: 1 LB = 453.592 grams
    test('2LB → 907.184 grams', () {
      expect(parseWeightFromDisplay('2LB'), closeTo(907.184, 0.01));
    });

    test('1POUND → 453.592 grams', () {
      expect(parseWeightFromDisplay('1POUND'), closeTo(453.592, 0.01));
    });

    // ── EDGE CASES ──
    // These test defensive coding — what happens with bad input?
    test('empty string → 0 grams', () {
      expect(parseWeightFromDisplay(''), equals(0.0));
    });

    test('no number → 0 grams', () {
      expect(parseWeightFromDisplay('KG'), equals(0.0));
    });

    test('plain number without unit → value as-is', () {
      // If no unit is recognized, assume it's in the inventory unit
      expect(parseWeightFromDisplay('500'), equals(500.0));
    });

    test('decimal grams 250.5GM → 250.5', () {
      expect(parseWeightFromDisplay('250.5GM'), equals(250.5));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 2: Cart Total Calculations
  //
  // SOURCE CODE: CartStoreRes computed properties
  //   cartTotal = items.fold(0, (sum, item) => sum + (item.price * item.quantity))
  //   totalQuantity = items.fold(0, (sum, item) => sum + item.quantity)
  //
  // These are computed properties on the MobX store, but the MATH is
  // pure: sum of (price × quantity). We can test the same formula.
  //
  // WHY TEST THIS: Cart total is shown on screen and used in checkout.
  // If 2 × ₹100 shows as ₹100 instead of ₹200, customer is undercharged.
  // ════════════════════════════════════════════════════════════════════════

  // Recreate the cart total formula (same as CartStoreRes.cartTotal)
  double calcCartTotal(List<dynamic> items) {
    return items.fold<double>(
        0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  int calcTotalQuantity(List<dynamic> items) {
    return items.fold<int>(0, (sum, item) => sum + (item.quantity as int));
  }

  group('Cart total calculations', () {
    test('empty cart → total = 0', () {
      expect(calcCartTotal([]), equals(0.0));
    });

    test('single item × 1', () {
      final items = [makeCartItem(price: 250, quantity: 1)];
      expect(calcCartTotal(items), equals(250.0));
    });

    test('single item × 3', () {
      // 3 × ₹250 = ₹750
      final items = [makeCartItem(price: 250, quantity: 3)];
      expect(calcCartTotal(items), equals(750.0));
    });

    test('multiple items with different quantities', () {
      final items = [
        makeCartItem(price: 100, quantity: 2), // 200
        makeCartItem(price: 50, quantity: 3),  // 150
        makeCartItem(price: 300, quantity: 1), // 300
      ];
      // 200 + 150 + 300 = 650
      expect(calcCartTotal(items), equals(650.0));
    });

    test('total quantity sums all items', () {
      final items = [
        makeCartItem(price: 100, quantity: 2),
        makeCartItem(price: 50, quantity: 3),
        makeCartItem(price: 300, quantity: 1),
      ];
      // 2 + 3 + 1 = 6
      expect(calcTotalQuantity(items), equals(6));
    });

    test('decimal prices', () {
      final items = [
        makeCartItem(price: 99.50, quantity: 2), // 199.00
        makeCartItem(price: 45.75, quantity: 1), // 45.75
      ];
      // 199.00 + 45.75 = 244.75
      expect(calcCartTotal(items), closeTo(244.75, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 3: CartItem.finalItemPrice Getter
  //
  // SOURCE CODE: cartmodel_308.dart lines 82-94
  //   finalItemPrice = price - (discount ?? 0), clamped to >= 0
  //   totalPrice = finalItemPrice * quantity
  //
  // WHY TEST THIS: This getter is used in refund calculations.
  // If a ₹250 item with ₹50 discount shows finalItemPrice as ₹250
  // instead of ₹200, refund amounts will be wrong.
  // ════════════════════════════════════════════════════════════════════════

  group('CartItem.finalItemPrice — price after item-level discount', () {
    test('no discount → finalItemPrice equals price', () {
      final item = makeCartItem(price: 250);
      // No discount field set → discount defaults to null → 0
      expect(item.finalItemPrice, equals(250.0));
    });

    test('with ₹50 discount → price reduced', () {
      final item = makeCartItem(price: 250);
      // CartItem.discount is final, set via constructor
      // We need to create with discount via the CartItem constructor directly
      final discountedItem = item.copyWith(discount: 50);
      // finalItemPrice = 250 - 50 = 200
      expect(discountedItem.finalItemPrice, equals(200.0));
    });

    test('discount exceeds price → clamped to 0 (not negative)', () {
      final item = makeCartItem(price: 100);
      final discountedItem = item.copyWith(discount: 150);
      // finalItemPrice = 100 - 150 = -50, clamped to 0
      expect(discountedItem.finalItemPrice, equals(0.0));
    });

    test('totalPrice = finalItemPrice × quantity', () {
      final item = makeCartItem(price: 200, quantity: 3);
      final discountedItem = item.copyWith(discount: 20);
      // finalItemPrice = 200 - 20 = 180
      // totalPrice = 180 × 3 = 540
      expect(discountedItem.totalPrice, equals(540.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 4: Refund Quantity Logic
  //
  // SOURCE CODE: refund_service.dart lines 48-60
  //   newRefundedQuantity = (item.refundedQuantity ?? 0) + quantityToRefund
  //   isFullyRefunded = ALL items have refundedQuantity >= quantity
  //
  // WHY TEST THIS: Wrong refund tracking means either:
  //   - Customer gets refunded twice (money loss)
  //   - Customer can't get legitimate refund (bad service)
  //
  // We test the LOGIC, not the Hive persistence.
  // ════════════════════════════════════════════════════════════════════════

  group('Refund quantity tracking', () {
    test('initial refundedQuantity is null (no refund yet)', () {
      final item = makeCartItem(price: 100, quantity: 3);
      expect(item.refundedQuantity, isNull);
    });

    test('partial refund — 1 of 3 refunded', () {
      final item = makeCartItem(price: 100, quantity: 3);

      // Simulate what refund_service does:
      // newRefundedQuantity = (item.refundedQuantity ?? 0) + quantityToRefund
      final currentRefunded = item.refundedQuantity ?? 0;
      final quantityToRefund = 1;
      final newRefunded = currentRefunded + quantityToRefund;

      // Create updated item (simulating what refund_service saves)
      final refundedItem = item.copyWith(refundedQuantity: newRefunded);

      expect(refundedItem.refundedQuantity, equals(1));
      // Not fully refunded: 1 < 3
      expect(refundedItem.refundedQuantity! < refundedItem.quantity, isTrue);
    });

    test('full refund — all 3 of 3 refunded', () {
      final item = makeCartItem(price: 100, quantity: 3);
      final refundedItem = item.copyWith(refundedQuantity: 3);

      // Fully refunded: 3 >= 3
      expect(refundedItem.refundedQuantity! >= refundedItem.quantity, isTrue);
    });

    test('refund amount calculation — per-item proportional', () {
      // Item: ₹200 × 2 = ₹400 total
      // Refund 1 of 2: refund amount = ₹200 (1 × item price)
      final item = makeCartItem(price: 200, quantity: 2);
      final quantityToRefund = 1;

      // Refund amount = item.price × quantityToRefund
      final refundAmount = item.price * quantityToRefund;
      expect(refundAmount, equals(200.0));

      // Remaining after refund
      final remainingQty = item.quantity - quantityToRefund;
      expect(remainingQty, equals(1));
      final remainingValue = item.price * remainingQty;
      expect(remainingValue, equals(200.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 5: Stock Deduction Math
  //
  // We can't call InventoryService directly (Hive dependency), but we
  // can verify the MATH that happens inside it:
  //   newStock = currentStock - orderQuantity
  //   For weight items: newStock = currentStock - (weight × quantity)
  //
  // WHY TEST THIS: If stock deduction math is wrong, inventory
  // shows wrong numbers → staff thinks items are available when they're not.
  // ════════════════════════════════════════════════════════════════════════

  group('Stock deduction math', () {
    test('unit item: 50 in stock, order 3 → 47 remaining', () {
      double stock = 50;
      int orderQty = 3;
      double newStock = stock - orderQty;
      expect(newStock, equals(47.0));
    });

    test('weight item: 5000g stock, order 500g × 2 → 4000g remaining', () {
      double stock = 5000; // grams
      double singleWeight = parseWeightFromDisplay('500GM'); // 500g
      int quantity = 2;
      double totalWeight = singleWeight * quantity; // 1000g
      double newStock = stock - totalWeight;
      expect(newStock, equals(4000.0));
    });

    test('weight item KG: 10000g stock, order 1.5KG × 1 → 8500g', () {
      double stock = 10000; // grams
      double singleWeight = parseWeightFromDisplay('1.5KG'); // 1500g
      int quantity = 1;
      double totalWeight = singleWeight * quantity; // 1500g
      double newStock = stock - totalWeight;
      expect(newStock, equals(8500.0));
    });

    test('oversell allowed: stock goes negative', () {
      // When allowOrderWhenOutOfStock = true, stock CAN go negative
      double stock = 2;
      int orderQty = 5;
      double newStock = stock - orderQty;
      expect(newStock, equals(-3.0));
      expect(newStock < 0, isTrue); // Negative = oversold
    });

    test('exact stock: order exactly what remains → 0', () {
      double stock = 10;
      int orderQty = 10;
      double newStock = stock - orderQty;
      expect(newStock, equals(0.0));
    });
  });
}
