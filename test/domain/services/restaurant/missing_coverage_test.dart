import 'package:flutter_test/flutter_test.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/domain/services/restaurant/cart_calculation_service.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/customerdetails.dart';
import '../../../helpers/test_helpers.dart';

/// Tests for gaps identified in coverage analysis.
///
/// These fill the HIGH-RISK gaps:
/// 1. discountOnItems mode (per-item discount before tax)
/// 2. Tax inclusive + discount combined
/// 3. Round-off formula
/// 4. Items.isInStock computed (variant vs base)
/// 5. Items.basePrice / taxAmount (tax extraction)
/// 6. OrderModel.getItemsByKot() (KOT boundary grouping)
/// 7. Topping.getPriceForVariant() (variant-specific extra pricing)
void main() {
  // ════════════════════════════════════════════════════════════════════════
  // 1. DISCOUNT ON ITEMS MODE
  //
  // SOURCE: CartCalculationService lines 86-110
  //
  // When discountOnItems=true, discount is calculated PER ITEM first,
  // then tax is calculated on the discounted item amount.
  //
  // This differs from discountOnItems=false (bill-level) where the
  // total discount is distributed proportionally THEN tax calculated.
  //
  // With same tax rate, both modes produce the same result.
  // With DIFFERENT tax rates, they can differ because the proportional
  // allocation changes which items absorb more discount.
  // ════════════════════════════════════════════════════════════════════════

  group('discountOnItems=true — per-item discount before tax', () {
    test('percentage discount per-item with uniform tax', () {
      // Two items, both 5% tax, 10% discount
      final calc = CartCalculationService(
        items: [
          makeCartItem(price: 100, taxRate: 0.05),
          makeCartItem(price: 200, taxRate: 0.05),
        ],
        discountType: DiscountType.percentage,
        discountValue: 10, // 10%
        isTaxInclusive: false,
        discountOnItems: true, // ← KEY: per-item mode
      );

      // Per-item calculation:
      // Item A: ₹100, discount = 100 × 10% = ₹10, after = ₹90, tax = 90 × 0.05 = ₹4.50
      // Item B: ₹200, discount = 200 × 10% = ₹20, after = ₹180, tax = 180 × 0.05 = ₹9.00
      // Total discount: 10 + 20 = ₹30
      // Taxable: 90 + 180 = ₹270
      // GST: 4.50 + 9.00 = ₹13.50
      // Grand: 270 + 13.50 = ₹283.50
      expect(calc.discountAmount, closeTo(30, 0.01));
      expect(calc.taxableAmount, closeTo(270, 0.01));
      expect(calc.totalGST, closeTo(13.5, 0.01));
      expect(calc.grandTotal, closeTo(283.5, 0.01));
    });

    test('amount discount per-item with uniform tax', () {
      // ₹50 discount distributed proportionally per item
      final calc = CartCalculationService(
        items: [
          makeCartItem(price: 100, taxRate: 0.05), // 1/3 of total
          makeCartItem(price: 200, taxRate: 0.05), // 2/3 of total
        ],
        discountType: DiscountType.amount,
        discountValue: 50,
        isTaxInclusive: false,
        discountOnItems: true,
      );

      // Item A: share = (100/300) × 50 = ₹16.67 discount
      //   after = 100 - 16.67 = ₹83.33, tax = 83.33 × 0.05 = ₹4.17
      // Item B: share = (200/300) × 50 = ₹33.33 discount
      //   after = 200 - 33.33 = ₹166.67, tax = 166.67 × 0.05 = ₹8.33
      // Total discount: ₹50
      // Taxable: 83.33 + 166.67 = ₹250
      // GST: 4.17 + 8.33 = ₹12.50
      // Grand: 250 + 12.50 = ₹262.50
      expect(calc.discountAmount, closeTo(50, 0.01));
      expect(calc.taxableAmount, closeTo(250, 0.01));
      expect(calc.totalGST, closeTo(12.5, 0.01));
      expect(calc.grandTotal, closeTo(262.5, 0.01));
    });

    test('discount per-item with MIXED tax rates', () {
      // This is where discountOnItems matters most —
      // different tax rates mean different GST per item
      final calc = CartCalculationService(
        items: [
          makeCartItem(price: 100, taxRate: 0.05),  // food 5%
          makeCartItem(price: 100, taxRate: 0.18),  // beverage 18%
        ],
        discountType: DiscountType.percentage,
        discountValue: 10,
        isTaxInclusive: false,
        discountOnItems: true,
      );

      // Item A (5%): ₹100 - 10% = ₹90, tax = 90 × 0.05 = ₹4.50
      // Item B (18%): ₹100 - 10% = ₹90, tax = 90 × 0.18 = ₹16.20
      // Taxable: 90 + 90 = ₹180
      // GST: 4.50 + 16.20 = ₹20.70
      // Grand: 180 + 20.70 = ₹200.70
      expect(calc.discountAmount, closeTo(20, 0.01));
      expect(calc.taxableAmount, closeTo(180, 0.01));
      expect(calc.totalGST, closeTo(20.70, 0.01));
      expect(calc.grandTotal, closeTo(200.70, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 2. TAX INCLUSIVE + DISCOUNT COMBINED
  //
  // The most complex path in CartCalculationService:
  //   1. Price already includes tax
  //   2. Apply discount to gross price
  //   3. Extract tax from discounted gross
  //
  // Formula: discountedAmount = price - discount
  //          base = discountedAmount / (1 + taxRate)
  //          GST = discountedAmount - base
  // ════════════════════════════════════════════════════════════════════════

  group('Tax inclusive + discount — most complex calculation', () {
    test('10% discount on tax-inclusive item', () {
      // Item: ₹105 (includes 5% tax), 10% discount
      final calc = CartCalculationService(
        items: [makeCartItem(price: 105, taxRate: 0.05)],
        discountType: DiscountType.percentage,
        discountValue: 10,
        isTaxInclusive: true,
        discountOnItems: false,
      );

      // Original gross: ₹105
      // Discount: 105 × 10% = ₹10.50
      // After discount gross: 105 - 10.50 = ₹94.50
      // Extract tax: base = 94.50 / 1.05 = ₹90
      //              GST = 94.50 - 90 = ₹4.50
      // Grand: 90 + 4.50 = ₹94.50 (same as gross, because tax is included)
      expect(calc.discountAmount, closeTo(10.5, 0.01));
      expect(calc.taxableAmount, closeTo(90, 0.01));
      expect(calc.totalGST, closeTo(4.5, 0.01));
      expect(calc.grandTotal, closeTo(94.5, 0.01));
    });

    test('₹50 amount discount on tax-inclusive items with mixed rates', () {
      final calc = CartCalculationService(
        items: [
          makeCartItem(price: 105, taxRate: 0.05),   // ₹105 incl 5%
          makeCartItem(price: 236, taxRate: 0.18),   // ₹236 incl 18%
        ],
        discountType: DiscountType.amount,
        discountValue: 50,
        isTaxInclusive: true,
        discountOnItems: false,
      );

      // Original total: 105 + 236 = ₹341
      // Discount: ₹50
      // After discount total: ₹291
      //
      // Item A share: (105/341) × 291 = ₹89.56
      //   base = 89.56 / 1.05 = ₹85.30, GST = 89.56 - 85.30 = ₹4.26
      // Item B share: (236/341) × 291 = ₹201.44
      //   base = 201.44 / 1.18 = ₹170.71, GST = 201.44 - 170.71 = ₹30.73
      //
      // Taxable: 85.30 + 170.71 = ₹256.01
      // GST: 4.26 + 30.73 = ₹34.99
      // Grand: 256.01 + 34.99 = ₹291.00
      expect(calc.discountAmount, closeTo(50, 0.01));
      expect(calc.grandTotal, closeTo(291, 0.01));
      // Verify tax is less than without discount
      expect(calc.totalGST, lessThan(35.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 3. ROUND-OFF FORMULA
  //
  // SOURCE: CartCalculationService._roundToNearest() line 183
  //   (value / nearest).round() * nearest
  //
  // This is private, so we recreate the formula.
  // Tests different rounding targets: ₹1, ₹0.50, ₹10
  // ════════════════════════════════════════════════════════════════════════

  // Extracted from CartCalculationService._roundToNearest()
  double roundToNearest(double value, double nearest) {
    if (nearest <= 0) return value;
    return (value / nearest).round() * nearest;
  }

  group('Round-off formula', () {
    // Round to ₹1
    test('₹234.56 round to ₹1 → ₹235', () {
      expect(roundToNearest(234.56, 1.0), equals(235.0));
    });

    test('₹234.49 round to ₹1 → ₹234', () {
      expect(roundToNearest(234.49, 1.0), equals(234.0));
    });

    test('₹234.50 round to ₹1 → ₹235 (rounds up at .50)', () {
      expect(roundToNearest(234.50, 1.0), equals(235.0));
    });

    // Round to ₹0.50
    test('₹234.30 round to ₹0.50 → ₹234.50', () {
      expect(roundToNearest(234.30, 0.50), closeTo(234.50, 0.01));
    });

    test('₹234.10 round to ₹0.50 → ₹234.00', () {
      expect(roundToNearest(234.10, 0.50), closeTo(234.00, 0.01));
    });

    // Round to ₹10
    test('₹234.56 round to ₹10 → ₹230', () {
      expect(roundToNearest(234.56, 10.0), equals(230.0));
    });

    test('₹235.00 round to ₹10 → ₹240', () {
      expect(roundToNearest(235.00, 10.0), equals(240.0));
    });

    // Edge cases
    test('nearest=0 → returns value unchanged', () {
      expect(roundToNearest(234.56, 0), equals(234.56));
    });

    test('already exact → no change', () {
      expect(roundToNearest(250.0, 1.0), equals(250.0));
    });

    // Round-off amount (what shows on the receipt)
    test('round-off amount = rounded - original', () {
      double original = 234.56;
      double rounded = roundToNearest(original, 1.0);
      double roundOffAmount = rounded - original;
      // 235 - 234.56 = +0.44
      expect(roundOffAmount, closeTo(0.44, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 4. ITEMS.isInStock — variant-aware stock checking
  //
  // SOURCE: itemmodel_302.dart lines 112-117
  //
  // Logic:
  //   hasVariants? → ANY variant in stock = item in stock
  //   no variants? → !trackInventory OR stockQuantity > 0
  //
  // If this is wrong, out-of-stock items show as available on menu.
  // ════════════════════════════════════════════════════════════════════════

  group('Items.isInStock — stock availability check', () {
    // Helper to create test Item (minimal fields)
    Items makeTestItem({
      double price = 100,
      bool trackInventory = false,
      double stockQuantity = 0,
      List<ItemVariante>? variants,
    }) {
      return Items(
        id: 'item-1',
        name: 'Test Item',
        price: price,
        trackInventory: trackInventory,
        stockQuantity: stockQuantity,
        variant: variants,
      );
    }

    test('trackInventory=false → always in stock (unlimited supply)', () {
      final item = makeTestItem(trackInventory: false, stockQuantity: 0);
      expect(item.isInStock, isTrue);
    });

    test('trackInventory=true, stock > 0 → in stock', () {
      final item = makeTestItem(trackInventory: true, stockQuantity: 50);
      expect(item.isInStock, isTrue);
    });

    test('trackInventory=true, stock = 0 → out of stock', () {
      final item = makeTestItem(trackInventory: true, stockQuantity: 0);
      expect(item.isInStock, isFalse);
    });

    test('trackInventory=true, stock negative → out of stock', () {
      final item = makeTestItem(trackInventory: true, stockQuantity: -5);
      expect(item.isInStock, isFalse);
    });

    test('with variants: ANY variant in stock → item in stock', () {
      // Even if base stock is 0, if any variant has stock, item is available
      final item = makeTestItem(
        trackInventory: true,
        stockQuantity: 0,
        variants: [
          ItemVariante(variantId: 'v1', price: 100, trackInventory: true, stockQuantity: 0),
          ItemVariante(variantId: 'v2', price: 150, trackInventory: true, stockQuantity: 10), // ← in stock!
        ],
      );
      // v2 has stock → item is in stock
      expect(item.isInStock, isTrue);
    });

    test('with variants: ALL variants out of stock → item out of stock', () {
      final item = makeTestItem(
        trackInventory: true,
        stockQuantity: 0,
        variants: [
          ItemVariante(variantId: 'v1', price: 100, trackInventory: true, stockQuantity: 0),
          ItemVariante(variantId: 'v2', price: 150, trackInventory: true, stockQuantity: 0),
        ],
      );
      expect(item.isInStock, isFalse);
    });

    test('with variants: variant not tracking inventory → always in stock', () {
      final item = makeTestItem(
        trackInventory: true,
        stockQuantity: 0,
        variants: [
          ItemVariante(variantId: 'v1', price: 100, trackInventory: false, stockQuantity: 0),
          // trackInventory=false → isInStock=true regardless of quantity
        ],
      );
      expect(item.isInStock, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 5. ITEMS.basePrice & taxAmount — tax extraction from gross price
  //
  // SOURCE: itemmodel_302.dart lines 122-133
  //   finalPrice = price ?? 0
  //   basePrice = finalPrice / (1 + taxRate)  [if taxRate exists]
  //   taxAmount = finalPrice - basePrice
  //
  // Used in apply_tax_screen to show "Price before tax" and "Tax amount"
  // ════════════════════════════════════════════════════════════════════════

  group('Items.basePrice & taxAmount — tax extraction getters', () {
    test('no tax → basePrice equals price', () {
      final item = Items(id: '1', name: 'Test', price: 100);
      expect(item.basePrice, equals(100.0));
      expect(item.taxAmount, equals(0.0));
    });

    test('5% tax → extract base from ₹105', () {
      final item = Items(id: '1', name: 'Test', price: 105, taxRate: 0.05);
      // base = 105 / 1.05 = 100
      // taxAmount = 105 - 100 = 5
      expect(item.basePrice, closeTo(100, 0.01));
      expect(item.taxAmount, closeTo(5, 0.01));
    });

    test('18% tax → extract base from ₹118', () {
      final item = Items(id: '1', name: 'Test', price: 118, taxRate: 0.18);
      // base = 118 / 1.18 = 100
      // taxAmount = 118 - 100 = 18
      expect(item.basePrice, closeTo(100, 0.01));
      expect(item.taxAmount, closeTo(18, 0.01));
    });

    test('taxRate = 0 → basePrice equals price (no extraction)', () {
      final item = Items(id: '1', name: 'Test', price: 100, taxRate: 0);
      expect(item.basePrice, equals(100.0));
      expect(item.taxAmount, equals(0.0));
    });

    test('null price → finalPrice = 0, basePrice = 0', () {
      final item = Items(id: '1', name: 'Test', price: null, taxRate: 0.05);
      expect(item.finalPrice, equals(0.0));
      expect(item.basePrice, equals(0.0));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 6. ORDERMODEL.getItemsByKot() — KOT boundary grouping
  //
  // SOURCE: ordermodel_309.dart lines 241-257
  //
  // This groups order items by which KOT they belong to.
  // kotNumbers: [12, 15, 18]
  // kotBoundaries: [3, 5, 7]
  // → KOT#12 = items[0..2], KOT#15 = items[3..4], KOT#18 = items[5..6]
  //
  // If this is wrong, KOTs print wrong items to the kitchen.
  // ════════════════════════════════════════════════════════════════════════

  group('OrderModel.getItemsByKot() — KOT boundary grouping', () {
    // Helper to create test order with specific items and KOT structure
    OrderModel makeTestOrder({
      required List<CartItem> items,
      required List<int> kotNumbers,
      required List<int> kotBoundaries,
    }) {
      return OrderModel(
        id: 'order-1',
        customerName: 'Test',
        customerNumber: '',
        customerEmail: '',
        items: items,
        status: 'Processing',
        timeStamp: DateTime.now(),
        orderType: 'Take Away',
        totalPrice: 0,
        kotNumbers: kotNumbers,
        itemCountAtLastKot: items.length,
        kotBoundaries: kotBoundaries,
      );
    }

    test('single KOT with 3 items', () {
      final items = [
        makeCartItem(price: 100, title: 'Biryani'),
        makeCartItem(price: 60, title: 'Naan'),
        makeCartItem(price: 25, title: 'Raita'),
      ];

      final order = makeTestOrder(
        items: items,
        kotNumbers: [12],
        kotBoundaries: [3], // KOT#12 has items 0..2
      );

      final byKot = order.getItemsByKot();

      // Should have 1 KOT with 3 items
      expect(byKot.length, equals(1));
      expect(byKot.containsKey(12), isTrue);
      expect(byKot[12]!.length, equals(3));
      expect(byKot[12]![0].title, equals('Biryani'));
      expect(byKot[12]![1].title, equals('Naan'));
      expect(byKot[12]![2].title, equals('Raita'));
    });

    test('two KOTs — initial order + added items', () {
      final items = [
        // KOT #12 (initial order)
        makeCartItem(price: 100, title: 'Biryani'),
        makeCartItem(price: 60, title: 'Naan'),
        makeCartItem(price: 25, title: 'Raita'),
        // KOT #15 (added later)
        makeCartItem(price: 40, title: 'Cola'),
        makeCartItem(price: 90, title: 'Lassi'),
      ];

      final order = makeTestOrder(
        items: items,
        kotNumbers: [12, 15],
        kotBoundaries: [3, 5], // KOT#12 = 0..2, KOT#15 = 3..4
      );

      final byKot = order.getItemsByKot();

      // KOT #12: first 3 items
      expect(byKot[12]!.length, equals(3));
      expect(byKot[12]![0].title, equals('Biryani'));

      // KOT #15: next 2 items
      expect(byKot[15]!.length, equals(2));
      expect(byKot[15]![0].title, equals('Cola'));
      expect(byKot[15]![1].title, equals('Lassi'));
    });

    test('three KOTs — multiple rounds of additions', () {
      final items = [
        makeCartItem(price: 100, title: 'A'),
        makeCartItem(price: 100, title: 'B'),
        makeCartItem(price: 100, title: 'C'),
        makeCartItem(price: 100, title: 'D'),
        makeCartItem(price: 100, title: 'E'),
        makeCartItem(price: 100, title: 'F'),
        makeCartItem(price: 100, title: 'G'),
      ];

      final order = makeTestOrder(
        items: items,
        kotNumbers: [12, 15, 18],
        kotBoundaries: [3, 5, 7],
        // KOT#12 = items[0..2] (A,B,C)
        // KOT#15 = items[3..4] (D,E)
        // KOT#18 = items[5..6] (F,G)
      );

      final byKot = order.getItemsByKot();

      expect(byKot.length, equals(3));
      expect(byKot[12]!.length, equals(3)); // A, B, C
      expect(byKot[15]!.length, equals(2)); // D, E
      expect(byKot[18]!.length, equals(2)); // F, G
      expect(byKot[18]![0].title, equals('F'));
      expect(byKot[18]![1].title, equals('G'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 7. TOPPING.getPriceForVariant() — variant-specific extra pricing
  //
  // SOURCE: toppingmodel_304.dart lines 116-121
  //
  // Logic:
  //   variantId provided AND variantPrices has it → return variant price
  //   else → return base price
  //
  // If wrong, "Extra Cheese" charges ₹30 (small price) on a Large pizza
  // instead of ₹50 (large price).
  // ════════════════════════════════════════════════════════════════════════

  group('Topping.getPriceForVariant() — variant-specific pricing', () {
    test('no variant prices → returns base price', () {
      final topping = Topping(
        name: 'Extra Cheese',
        isveg: true,
        price: 30,
        // variantPrices is null
      );
      expect(topping.getPriceForVariant('any-variant'), equals(30.0));
    });

    test('null variantId → returns base price', () {
      final topping = Topping(
        name: 'Extra Cheese',
        isveg: true,
        price: 30,
        variantPrices: {'large': 50.0, 'regular': 30.0},
      );
      expect(topping.getPriceForVariant(null), equals(30.0));
    });

    test('known variant → returns variant-specific price', () {
      final topping = Topping(
        name: 'Extra Cheese',
        isveg: true,
        price: 30, // base price
        variantPrices: {
          'var-large': 50.0,    // ₹50 for Large
          'var-regular': 30.0,  // ₹30 for Regular
        },
      );

      // Large → ₹50, Regular → ₹30
      expect(topping.getPriceForVariant('var-large'), equals(50.0));
      expect(topping.getPriceForVariant('var-regular'), equals(30.0));
    });

    test('unknown variant → falls back to base price', () {
      final topping = Topping(
        name: 'Extra Cheese',
        isveg: true,
        price: 30,
        variantPrices: {'var-large': 50.0},
      );

      // 'var-small' not in variantPrices → returns base ₹30
      expect(topping.getPriceForVariant('var-small'), equals(30.0));
    });

    test('variant prices empty map → returns base price', () {
      final topping = Topping(
        name: 'Extra Cheese',
        isveg: true,
        price: 30,
        variantPrices: {}, // empty map
      );
      expect(topping.getPriceForVariant('var-large'), equals(30.0));
    });
  });
}
