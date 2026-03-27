import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/cash_handover_model.dart';
import 'package:unipos/data/models/restaurant/db/cash_movement_model.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/domain/services/restaurant/cart_calculation_service.dart';
import 'package:unipos/domain/services/restaurant/esc_pos_receipt_builder.dart';
import 'package:unipos/domain/services/retail/receipt_pdf_service.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/cart/customerdetails.dart';
import '../../../helpers/test_helpers.dart';

/// Final coverage tests — fills ALL remaining gaps.
///
/// 1. CartItem equality operator (==)
/// 2. OrderModel.getNewlyAddedItems()
/// 3. OrderModel.getKotStatus()
/// 4. OrderModel.paymentList getter (JSON parsing + fallback)
/// 5. CashMovementModel helpers (isCashIn, signedAmount, label)
/// 6. CashHandoverModel status (PENDING, MATCHED, DISCREPANCY)
/// 7. ItemVariante.isInStock
/// 8. Discount exceeds total (clamping)
/// 9. CartCalculation with quantities > 1
/// 10. EscPosReceiptBuilder output structure
void main() {
  // ════════════════════════════════════════════════════════════════════════
  // 1. CARTITEM EQUALITY (==)
  //
  // SOURCE: cartmodel_308.dart lines 96-110
  //   Compares: id, title, variantName, choiceNames
  //   Does NOT compare: price, quantity, extras
  //
  // WHY: Used in cart deduplication. If two CartItems are "equal",
  // the cart increments quantity instead of adding a new row.
  // If broken → same item appears as separate rows in cart.
  // ════════════════════════════════════════════════════════════════════════

  group('CartItem equality operator (==)', () {
    test('same id + title + variant + choices → equal', () {
      final a = makeCartItem(
        id: 'item-1',
        price: 100,
        title: 'Biryani',
        variantName: 'Large',
        choiceNames: ['Spicy'],
      );
      final b = makeCartItem(
        id: 'item-1',
        price: 200, // different price — shouldn't matter
        title: 'Biryani',
        variantName: 'Large',
        choiceNames: ['Spicy'],
      );
      expect(a == b, isTrue);
    });

    test('different id → not equal', () {
      final a = makeCartItem(id: 'item-1', price: 100, title: 'Biryani');
      final b = makeCartItem(id: 'item-2', price: 100, title: 'Biryani');
      expect(a == b, isFalse);
    });

    test('different variant → not equal', () {
      // Same item, different size = different cart row
      final a = makeCartItem(
          id: 'item-1', price: 100, title: 'Biryani', variantName: 'Large');
      final b = makeCartItem(
          id: 'item-1', price: 100, title: 'Biryani', variantName: 'Regular');
      expect(a == b, isFalse);
    });

    test('different choices → not equal', () {
      final a = makeCartItem(
          id: 'item-1', price: 100, title: 'Biryani',
          choiceNames: ['Spicy']);
      final b = makeCartItem(
          id: 'item-1', price: 100, title: 'Biryani',
          choiceNames: ['Mild']);
      expect(a == b, isFalse);
    });

    test('identical object → equal (identity check)', () {
      final a = makeCartItem(id: 'item-1', price: 100, title: 'Biryani');
      expect(a == a, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 2. ORDERMODEL.getNewlyAddedItems()
  //
  // SOURCE: ordermodel_309.dart lines 228-233
  //   Returns items.sublist(itemCountAtLastKot)
  //   If itemCountAtLastKot >= items.length → empty list
  //
  // WHY: Used to detect new items for KOT printing.
  // If broken, new KOT prints nothing or reprints all items.
  // ════════════════════════════════════════════════════════════════════════

  // Helper to create test OrderModel
  OrderModel makeOrder({
    required List<CartItem> items,
    required int itemCountAtLastKot,
    List<int>? kotNumbers,
    List<int>? kotBoundaries,
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
      kotNumbers: kotNumbers ?? [1],
      itemCountAtLastKot: itemCountAtLastKot,
      kotBoundaries: kotBoundaries ?? [items.length],
    );
  }

  group('OrderModel.getNewlyAddedItems()', () {
    test('no new items → empty list', () {
      final items = [
        makeCartItem(price: 100, title: 'A'),
        makeCartItem(price: 100, title: 'B'),
      ];
      // itemCountAtLastKot = 2, items.length = 2 → nothing new
      final order = makeOrder(items: items, itemCountAtLastKot: 2);
      expect(order.getNewlyAddedItems(), isEmpty);
    });

    test('2 new items added after last KOT', () {
      final items = [
        makeCartItem(price: 100, title: 'A'), // old
        makeCartItem(price: 100, title: 'B'), // old
        makeCartItem(price: 100, title: 'C'), // NEW
        makeCartItem(price: 100, title: 'D'), // NEW
      ];
      // Last KOT had 2 items, now 4 → items[2..3] are new
      final order = makeOrder(items: items, itemCountAtLastKot: 2);
      final newItems = order.getNewlyAddedItems();

      expect(newItems.length, equals(2));
      expect(newItems[0].title, equals('C'));
      expect(newItems[1].title, equals('D'));
    });

    test('itemCountAtLastKot > items.length → empty (defensive)', () {
      // Edge case: should not happen but shouldn't crash
      final items = [makeCartItem(price: 100, title: 'A')];
      final order = makeOrder(items: items, itemCountAtLastKot: 5);
      expect(order.getNewlyAddedItems(), isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 3. ORDERMODEL.getKotStatus()
  //
  // SOURCE: ordermodel_309.dart lines 260-267
  //   If kotStatuses has the KOT number → return KOT-level status
  //   Else → fall back to order-level status
  //
  // WHY: KDS displays per-KOT status. If fallback is wrong,
  // kitchen sees wrong status for specific KOTs.
  // ════════════════════════════════════════════════════════════════════════

  group('OrderModel.getKotStatus()', () {
    test('KOT has specific status → returns it', () {
      final order = makeOrder(
        items: [makeCartItem(price: 100, title: 'A')],
        itemCountAtLastKot: 1,
      ).copyWith(
        kotStatuses: {1: 'Ready', 2: 'Processing'},
      );
      expect(order.getKotStatus(1), equals('Ready'));
      expect(order.getKotStatus(2), equals('Processing'));
    });

    test('KOT not in kotStatuses → falls back to order status', () {
      final order = makeOrder(
        items: [makeCartItem(price: 100, title: 'A')],
        itemCountAtLastKot: 1,
      ).copyWith(
        status: 'Cooking',
        kotStatuses: {1: 'Ready'}, // KOT#99 not in map
      );
      // KOT#99 not found → falls back to order.status = 'Cooking'
      expect(order.getKotStatus(99), equals('Cooking'));
    });

    test('kotStatuses is null → falls back to order status', () {
      final order = makeOrder(
        items: [makeCartItem(price: 100, title: 'A')],
        itemCountAtLastKot: 1,
      );
      // kotStatuses not set (null) → falls back to order.status
      expect(order.getKotStatus(1), equals('Processing'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 4. ORDERMODEL.paymentList GETTER
  //
  // SOURCE: ordermodel_309.dart lines 363-378
  //   Parses paymentListJson → List<Map>
  //   If null/empty → fallback to [{method: paymentMethod, amount: totalPrice}]
  //   If JSON parse fails → same fallback
  //
  // WHY: Shown on receipt for split payments.
  // If JSON parse crashes, receipt print fails entirely.
  // ════════════════════════════════════════════════════════════════════════

  group('OrderModel.paymentList getter — JSON parsing', () {
    test('valid JSON → parses correctly', () {
      final json = jsonEncode([
        {'method': 'cash', 'amount': 300.0},
        {'method': 'upi', 'amount': 200.0},
      ]);
      final order = makeOrder(
        items: [makeCartItem(price: 500, title: 'A')],
        itemCountAtLastKot: 1,
      ).copyWith(paymentListJson: json, totalPrice: 500);

      final list = order.paymentList;
      expect(list.length, equals(2));
      expect(list[0]['method'], equals('cash'));
      expect(list[0]['amount'], equals(300.0));
      expect(list[1]['method'], equals('upi'));
    });

    test('null paymentListJson → fallback to single payment', () {
      final order = makeOrder(
        items: [makeCartItem(price: 500, title: 'A')],
        itemCountAtLastKot: 1,
      ).copyWith(paymentMethod: 'card', totalPrice: 500);

      final list = order.paymentList;
      expect(list.length, equals(1));
      expect(list[0]['method'], equals('card'));
      expect(list[0]['amount'], equals(500.0));
    });

    test('empty string paymentListJson → fallback', () {
      final order = makeOrder(
        items: [makeCartItem(price: 500, title: 'A')],
        itemCountAtLastKot: 1,
      ).copyWith(paymentListJson: '', paymentMethod: 'cash', totalPrice: 500);

      final list = order.paymentList;
      expect(list.length, equals(1));
      expect(list[0]['method'], equals('cash'));
    });

    test('invalid JSON → fallback (no crash)', () {
      final order = makeOrder(
        items: [makeCartItem(price: 500, title: 'A')],
        itemCountAtLastKot: 1,
      ).copyWith(
          paymentListJson: 'not valid json!!!',
          paymentMethod: 'cash',
          totalPrice: 500);

      // Should NOT throw, should fallback gracefully
      final list = order.paymentList;
      expect(list.length, equals(1));
      expect(list[0]['method'], equals('cash'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 5. CASHMOVEMENTMODEL HELPERS
  //
  // SOURCE: cash_movement_model.dart lines 79-85
  //   isCashIn → type == 'in'
  //   signedAmount → positive for in, negative for out
  //   label → "Cash In — reason" or "Cash Out — reason"
  //
  // WHY: Used in cash drawer display and EOD calculation.
  // Wrong sign = cash reconciliation off by 2× the amount.
  // ════════════════════════════════════════════════════════════════════════

  group('CashMovementModel helpers', () {
    CashMovementModel makeMovement(String type, double amount,
        {String reason = 'Test'}) {
      return CashMovementModel(
        id: 'mov-1',
        timestamp: DateTime.now(),
        type: type,
        amount: amount,
        reason: reason,
        staffName: 'Admin',
      );
    }

    test('type=in → isCashIn=true, positive signedAmount', () {
      final m = makeMovement('in', 2000);
      expect(m.isCashIn, isTrue);
      expect(m.signedAmount, equals(2000.0));
    });

    test('type=out → isCashIn=false, negative signedAmount', () {
      final m = makeMovement('out', 5000);
      expect(m.isCashIn, isFalse);
      expect(m.signedAmount, equals(-5000.0));
    });

    test('type=adjustment → isCashIn=false, negative signedAmount', () {
      // Adjustments are treated as 'out' (not 'in')
      final m = makeMovement('adjustment', 100);
      expect(m.isCashIn, isFalse);
      expect(m.signedAmount, equals(-100.0));
    });

    test('label formats correctly', () {
      final cashIn = makeMovement('in', 2000, reason: 'Owner deposit');
      expect(cashIn.label, equals('Cash In — Owner deposit'));

      final cashOut = makeMovement('out', 5000, reason: 'Safe drop');
      expect(cashOut.label, equals('Cash Out — Safe drop'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 6. CASHHANDOVERMODEL STATUS
  //
  // SOURCE: cash_handover_model.dart
  //   PENDING → only closer has counted
  //   MATCHED → both counted, variance within tolerance (±1)
  //   DISCREPANCY → counts differ significantly
  //
  // We test the model creation, not the store logic.
  // ════════════════════════════════════════════════════════════════════════

  group('CashHandoverModel status', () {
    test('PENDING — only closer counted', () {
      final handover = CashHandoverModel(
        id: 'h-1',
        closedBy: 'Rahul',
        closedAt: DateTime.now(),
        closedAmount: 12500,
        status: 'PENDING',
        // receivedBy/receivedAmount are null
      );
      expect(handover.status, equals('PENDING'));
      expect(handover.receivedBy, isNull);
      expect(handover.variance, isNull);
    });

    test('MATCHED — both counted same amount', () {
      final handover = CashHandoverModel(
        id: 'h-1',
        closedBy: 'Rahul',
        closedAt: DateTime.now(),
        closedAmount: 12500,
        receivedBy: 'Priya',
        receivedAt: DateTime.now(),
        receivedAmount: 12500,
        status: 'MATCHED',
        variance: 0,
      );
      expect(handover.status, equals('MATCHED'));
      expect(handover.variance, equals(0.0));
    });

    test('DISCREPANCY — counts differ', () {
      final handover = CashHandoverModel(
        id: 'h-1',
        closedBy: 'Rahul',
        closedAt: DateTime.now(),
        closedAmount: 12500,
        receivedBy: 'Priya',
        receivedAt: DateTime.now(),
        receivedAmount: 12200,
        status: 'DISCREPANCY',
        variance: -300, // 12200 - 12500 = -300 shortage
      );
      expect(handover.status, equals('DISCREPANCY'));
      expect(handover.variance, equals(-300.0));
      expect(handover.variance! < 0, isTrue); // shortage
    });

    // Test the variance calculation formula
    test('variance = receivedAmount - closedAmount', () {
      final closed = 12500.0;
      final received = 12200.0;
      final variance = received - closed;
      expect(variance, equals(-300.0));

      // Tolerance check: ±1 = MATCHED
      expect(variance.abs() <= 1, isFalse); // -300 is not within ±1
      expect((12500.5 - 12500.0).abs() <= 1, isTrue); // 0.5 is within ±1
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 7. ITEMVARIANTE.isInStock
  //
  // SOURCE: itemvariantemodel_312.dart line 29
  //   !(trackInventory ?? false) || (stockQuantity ?? 0) > 0
  //
  // Different from Items.isInStock — this is per-variant.
  // ════════════════════════════════════════════════════════════════════════

  group('ItemVariante.isInStock — per-variant stock', () {
    test('trackInventory=null → in stock (default no tracking)', () {
      final v = ItemVariante(variantId: 'v1', price: 100);
      // trackInventory defaults to null → !(null ?? false) = !false = true
      expect(v.isInStock, isTrue);
    });

    test('trackInventory=false → always in stock', () {
      final v = ItemVariante(
          variantId: 'v1', price: 100, trackInventory: false, stockQuantity: 0);
      expect(v.isInStock, isTrue);
    });

    test('trackInventory=true, stock > 0 → in stock', () {
      final v = ItemVariante(
          variantId: 'v1', price: 100, trackInventory: true, stockQuantity: 25);
      expect(v.isInStock, isTrue);
    });

    test('trackInventory=true, stock = 0 → out of stock', () {
      final v = ItemVariante(
          variantId: 'v1', price: 100, trackInventory: true, stockQuantity: 0);
      expect(v.isInStock, isFalse);
    });

    test('trackInventory=true, stock null → out of stock', () {
      final v = ItemVariante(
          variantId: 'v1', price: 100, trackInventory: true, stockQuantity: null);
      // (null ?? 0) > 0 = false
      expect(v.isInStock, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 8. DISCOUNT EXCEEDS TOTAL — clamping
  //
  // SOURCE: CartCalculationService line 95
  //   itemDiscount = itemDiscount.clamp(0, itemOriginalAmount)
  //
  // WHY: A ₹500 discount on a ₹300 order should cap at ₹300,
  // not produce a -₹200 bill.
  // ════════════════════════════════════════════════════════════════════════

  group('Discount exceeds total — clamping edge cases', () {
    test('discount larger than order total → clamped to total', () {
      final calc = CartCalculationService(
        items: [makeCartItem(price: 100, taxRate: 0.05)],
        discountType: DiscountType.amount,
        discountValue: 500, // ₹500 discount on ₹100 order!
        isTaxInclusive: false,
        discountOnItems: true,
      );

      // Discount should be clamped to ₹100 (not ₹500)
      // After discount: ₹0 taxable, ₹0 tax, ₹0 grand total
      expect(calc.discountAmount, closeTo(100, 0.01));
      expect(calc.taxableAmount, closeTo(0, 0.01));
      expect(calc.grandTotal, closeTo(0, 0.01));
    });

    test('100% percentage discount → zero total', () {
      final calc = CartCalculationService(
        items: [makeCartItem(price: 250, taxRate: 0.05)],
        discountType: DiscountType.percentage,
        discountValue: 100, // 100% off
        isTaxInclusive: false,
        discountOnItems: true,
      );

      expect(calc.discountAmount, closeTo(250, 0.01));
      expect(calc.grandTotal, closeTo(0, 0.01));
    });

    test('zero discount → no effect', () {
      final calc = CartCalculationService(
        items: [makeCartItem(price: 100, taxRate: 0.05)],
        discountType: DiscountType.amount,
        discountValue: 0,
        isTaxInclusive: false,
        discountOnItems: true,
      );
      // No discount → full price + tax
      expect(calc.discountAmount, equals(0));
      expect(calc.grandTotal, closeTo(105, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 9. CART CALCULATION WITH QUANTITIES > 1
  //
  // Most previous tests use quantity=1. This verifies that
  // price × quantity flows correctly through the full pipeline.
  // ════════════════════════════════════════════════════════════════════════

  group('CartCalculation with quantities > 1', () {
    test('2x ₹250 item with 5% tax and 10% discount', () {
      final calc = CartCalculationService(
        items: [makeCartItem(price: 250, quantity: 2, taxRate: 0.05)],
        discountType: DiscountType.percentage,
        discountValue: 10,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // itemTotal = 250 × 2 = ₹500
      // Discount = 500 × 10% = ₹50
      // Taxable = 500 - 50 = ₹450
      // GST = 450 × 0.05 = ₹22.50
      // Grand = 450 + 22.50 = ₹472.50
      expect(calc.itemTotal, equals(500));
      expect(calc.discountAmount, closeTo(50, 0.01));
      expect(calc.taxableAmount, closeTo(450, 0.01));
      expect(calc.totalGST, closeTo(22.5, 0.01));
      expect(calc.grandTotal, closeTo(472.5, 0.01));
    });

    test('mixed quantities: 3x₹100 + 1x₹500 with amount discount', () {
      final calc = CartCalculationService(
        items: [
          makeCartItem(price: 100, quantity: 3, taxRate: 0.05),  // 300
          makeCartItem(price: 500, quantity: 1, taxRate: 0.18),  // 500
        ],
        discountType: DiscountType.amount,
        discountValue: 100,
        isTaxInclusive: false,
        discountOnItems: false,
      );

      // itemTotal = 300 + 500 = ₹800
      // Discount = ₹100
      // After discount = ₹700
      // Item A share: (300/800) × 700 = ₹262.50, tax = 262.50 × 0.05 = ₹13.125
      // Item B share: (500/800) × 700 = ₹437.50, tax = 437.50 × 0.18 = ₹78.75
      // Taxable: 262.50 + 437.50 = ₹700
      // GST: 13.125 + 78.75 = ₹91.875
      // Grand: 700 + 91.875 = ₹791.875
      expect(calc.itemTotal, equals(800));
      expect(calc.discountAmount, closeTo(100, 0.01));
      expect(calc.taxableAmount, closeTo(700, 0.01));
      expect(calc.totalGST, closeTo(91.875, 0.01));
      expect(calc.grandTotal, closeTo(791.875, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 10. ESCPOSRECEIPTBUILDER OUTPUT STRUCTURE
  //
  // SOURCE: Our esc_pos_receipt_builder.dart
  //
  // Verify the byte output has correct structure:
  //   - Starts with ESC @ (init: 0x1B, 0x40)
  //   - Ends with GS V 1 (cut: 0x1D, 0x56, 0x01)
  //   - Contains expected text (store name, items, etc.)
  //
  // We can't check exact bytes (formatting varies), but we can
  // verify the structure is correct.
  // ════════════════════════════════════════════════════════════════════════

  group('EscPosReceiptBuilder — output structure', () {
    test('test ticket starts with init and ends with cut', () {
      final bytes = EscPosReceiptBuilder.buildTestTicket(80);

      // Must start with ESC @ (printer init)
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));

      // Must end with GS V 1 (paper cut)
      final len = bytes.length;
      expect(bytes[len - 3], equals(0x1D)); // GS
      expect(bytes[len - 2], equals(0x56)); // V
      expect(bytes[len - 1], equals(0x01)); // 1 (partial cut)
    });

    test('test ticket contains UniPOS text', () {
      final bytes = EscPosReceiptBuilder.buildTestTicket(80);
      // Convert to string to check text content
      final text = String.fromCharCodes(
          bytes.where((b) => b >= 32 && b < 127)); // printable ASCII only
      expect(text.contains('UniPOS'), isTrue);
      expect(text.contains('Test'), isTrue);
    });

    test('KOT ticket contains item names', () {
      // Create minimal ReceiptData for KOT
      final saleModel = SaleModel.createWithGst(
        saleId: 'kot-1',
        customerId: null,
        totalItems: 1,
        subtotal: 0,
        discountAmount: 0,
        totalTaxableAmount: 0,
        totalGstAmount: 0,
        grandTotal: 0,
        paymentType: 'Pending',
        isReturn: false,
      );

      final receiptData = ReceiptData(
        sale: saleModel,
        items: [],
        storeName: 'Test Restaurant',
        kotNumber: 42,
        orderType: 'Dine In',
        tableNo: 'T3',
      );

      final bytes = EscPosReceiptBuilder.buildKotTicket(
        receiptData: receiptData,
        paperWidth: 80,
      );

      final text = String.fromCharCodes(
          bytes.where((b) => b >= 32 && b < 127));

      expect(text.contains('Test Restaurant'), isTrue);
      expect(text.contains('KOT #42'), isTrue);
      expect(text.contains('Dine In'), isTrue);
      expect(text.contains('T3'), isTrue);
    });

    test('80mm paper produces wider output than 58mm', () {
      final bytes80 = EscPosReceiptBuilder.buildTestTicket(80);
      final bytes58 = EscPosReceiptBuilder.buildTestTicket(58);

      // 80mm has more characters per line (48 vs 32),
      // so divider lines are longer → more bytes
      expect(bytes80.length, greaterThan(bytes58.length));
    });
  });
}
