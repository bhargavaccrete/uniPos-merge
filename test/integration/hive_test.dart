import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/saved_printer_model.dart';

/// HIVE INTEGRATION TESTS
///
/// These tests verify the actual read/write cycle through Hive:
///   Create model → save to box → read from box → verify data matches
///
/// WHY THESE ARE DIFFERENT FROM UNIT TESTS:
///   Unit tests: test logic/math in isolation (no I/O)
///   Integration tests: test that data survives the Hive serialize→deserialize cycle
///
/// SETUP: Each test group creates a temporary directory for Hive,
/// registers adapters, opens boxes, and cleans up after.
/// This isolates each test — no leftover data between runs.
void main() {
  // ── Hive Setup/Teardown ──
  // Create a temp directory for each test run so tests don't interfere
  late Directory tempDir;

  setUp(() async {
    // Create unique temp dir for this test
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);

    // Register adapters (same as hive_init.dart but only what we need)
    // Check isAdapterRegistered to avoid double-registration across tests
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCart)) {
      Hive.registerAdapter(CartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCategory)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantItem)) {
      Hive.registerAdapter(ItemsAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantItemVariant)) {
      Hive.registerAdapter(ItemVarianteAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.savedPrinter)) {
      Hive.registerAdapter(SavedPrinterModelAdapter());
    }
  });

  tearDown(() async {
    // Close all boxes and delete temp directory
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 1: CartItem — Save and Read
  //
  // Verifies that a CartItem survives the Hive round-trip:
  //   CartItem → adapter serializes → write to disk → read from disk
  //   → adapter deserializes → same CartItem
  //
  // WHY: If any HiveField is wrong (wrong index, wrong type),
  // data gets corrupted silently. These tests catch that.
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: CartItem round-trip', () {
    test('save and read simple CartItem', () async {
      final box = await Hive.openBox<CartItem>('test_cart');

      // Create
      final original = CartItem(
        id: 'cart-1',
        productId: 'prod-1',
        title: 'Chicken Biryani',
        price: 250.0,
        quantity: 2,
        taxRate: 0.05,
      );

      // Save
      await box.put(original.id, original);

      // Read
      final loaded = box.get('cart-1');

      // Verify — every field must match
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('cart-1'));
      expect(loaded.productId, equals('prod-1'));
      expect(loaded.title, equals('Chicken Biryani'));
      expect(loaded.price, equals(250.0));
      expect(loaded.quantity, equals(2));
      expect(loaded.taxRate, equals(0.05));

      await box.close();
    });

    test('save CartItem with variants and extras', () async {
      final box = await Hive.openBox<CartItem>('test_cart_full');

      final original = CartItem(
        id: 'cart-2',
        productId: 'prod-2',
        title: 'Pizza',
        price: 350.0,
        quantity: 1,
        variantName: 'Large',
        variantPrice: 50.0,
        choiceNames: ['Spicy', 'Thin Crust'],
        instruction: 'No onions please',
        taxRate: 0.18,
        weightDisplay: null,
        extras: [
          {'name': 'cheese', 'displayName': 'Extra Cheese', 'price': 30.0, 'quantity': 2},
          {'name': 'olives', 'displayName': 'Olives', 'price': 20.0, 'quantity': 1},
        ],
        categoryName: 'Main Course',
        isStockManaged: true,
      );

      await box.put(original.id, original);
      final loaded = box.get('cart-2');

      expect(loaded, isNotNull);
      expect(loaded!.variantName, equals('Large'));
      expect(loaded.variantPrice, equals(50.0));
      expect(loaded.choiceNames, equals(['Spicy', 'Thin Crust']));
      expect(loaded.instruction, equals('No onions please'));
      expect(loaded.extras, isNotNull);
      expect(loaded.extras!.length, equals(2));
      expect(loaded.extras![0]['displayName'], equals('Extra Cheese'));
      expect(loaded.extras![0]['quantity'], equals(2));
      expect(loaded.categoryName, equals('Main Course'));
      expect(loaded.isStockManaged, isTrue);

      await box.close();
    });

    test('update quantity and re-read', () async {
      final box = await Hive.openBox<CartItem>('test_cart_update');

      final original = CartItem(
        id: 'cart-3',
        productId: 'prod-3',
        title: 'Naan',
        price: 60.0,
        quantity: 1,
      );

      await box.put(original.id, original);

      // Update quantity (simulates cart ± button)
      final updated = original.copyWith(quantity: 5);
      await box.put(original.id, updated);

      final loaded = box.get('cart-3');
      expect(loaded!.quantity, equals(5));
      expect(loaded.price, equals(60.0)); // price unchanged

      await box.close();
    });

    test('delete from box', () async {
      final box = await Hive.openBox<CartItem>('test_cart_delete');

      final item = CartItem(
        id: 'cart-4',
        productId: 'prod-4',
        title: 'Cola',
        price: 40.0,
        quantity: 1,
      );

      await box.put(item.id, item);
      expect(box.get('cart-4'), isNotNull);

      await box.delete('cart-4');
      expect(box.get('cart-4'), isNull);

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 2: Category — Save and Read
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: Category round-trip', () {
    test('save and read category', () async {
      final box = await Hive.openBox<Category>('test_categories');

      final original = Category(
        id: 'cat-1',
        name: 'Main Course',
        createdTime: DateTime(2026, 3, 24),
      );

      await box.put(original.id, original);
      final loaded = box.get('cat-1');

      expect(loaded, isNotNull);
      expect(loaded!.id, equals('cat-1'));
      expect(loaded.name, equals('Main Course'));
      expect(loaded.createdTime, equals(DateTime(2026, 3, 24)));

      await box.close();
    });

    test('list all categories', () async {
      final box = await Hive.openBox<Category>('test_categories_list');

      await box.put('c1', Category(id: 'c1', name: 'Starters'));
      await box.put('c2', Category(id: 'c2', name: 'Main Course'));
      await box.put('c3', Category(id: 'c3', name: 'Beverages'));

      final all = box.values.toList();
      expect(all.length, equals(3));

      final names = all.map((c) => c.name).toList();
      expect(names, contains('Starters'));
      expect(names, contains('Main Course'));
      expect(names, contains('Beverages'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 3: Items with Variants — Nested Object Persistence
  //
  // This is the trickiest Hive test — Items contains a List<ItemVariante>
  // (embedded typed objects). Hive needs both adapters registered
  // and correct HiveField indices to serialize nested lists.
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: Items with embedded variants', () {
    test('save item with variants and read back', () async {
      final box = await Hive.openBox<Items>('test_items');

      final original = Items(
        id: 'item-1',
        name: 'Chicken Biryani',
        price: 250,
        categoryOfItem: 'cat-1',
        isVeg: 'non-veg',
        taxRate: 0.05,
        trackInventory: true,
        stockQuantity: 100,
        variant: [
          ItemVariante(variantId: 'v-large', price: 300, trackInventory: true, stockQuantity: 50),
          ItemVariante(variantId: 'v-regular', price: 250, trackInventory: true, stockQuantity: 30),
        ],
        choiceIds: ['choice-1', 'choice-2'],
        extraId: ['extra-1'],
      );

      await box.put(original.id, original);
      final loaded = box.get('item-1');

      // Verify top-level fields
      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Chicken Biryani'));
      expect(loaded.price, equals(250));
      expect(loaded.taxRate, equals(0.05));
      expect(loaded.trackInventory, isTrue);
      expect(loaded.stockQuantity, equals(100));

      // Verify nested variants survived round-trip
      expect(loaded.variant, isNotNull);
      expect(loaded.variant!.length, equals(2));
      expect(loaded.variant![0].variantId, equals('v-large'));
      expect(loaded.variant![0].price, equals(300));
      expect(loaded.variant![0].stockQuantity, equals(50));
      expect(loaded.variant![1].variantId, equals('v-regular'));

      // Verify ID lists
      expect(loaded.choiceIds, equals(['choice-1', 'choice-2']));
      expect(loaded.extraId, equals(['extra-1']));

      // Verify computed properties work on loaded data
      expect(loaded.hasVariants, isTrue);
      expect(loaded.isInStock, isTrue); // v-large has 50 stock
      expect(loaded.basePrice, closeTo(250 / 1.05, 0.01));

      await box.close();
    });

    test('update stock and re-read', () async {
      final box = await Hive.openBox<Items>('test_items_stock');

      final original = Items(
        id: 'item-2',
        name: 'Naan',
        price: 60,
        trackInventory: true,
        stockQuantity: 50,
      );

      await box.put(original.id, original);

      // Simulate stock deduction (what InventoryService does)
      final loaded = box.get('item-2')!;
      loaded.stockQuantity = loaded.stockQuantity - 3;
      await box.put(loaded.id, loaded);

      final reloaded = box.get('item-2')!;
      expect(reloaded.stockQuantity, equals(47));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 4: SavedPrinterModel — Our New Model
  //
  // Verifies our thermal printer model persists correctly.
  // Important because we just created this model — no production testing yet.
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: SavedPrinterModel round-trip', () {
    test('save WiFi printer and read back', () async {
      final box = await Hive.openBox<SavedPrinterModel>('test_printers');

      final original = SavedPrinterModel(
        id: 'p-1',
        name: 'Kitchen Printer',
        type: 'wifi',
        address: '192.168.1.100:9100',
        paperSize: 80,
        role: 'kot',
        isDefault: true,
      );

      await box.put(original.id, original);
      final loaded = box.get('p-1');

      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Kitchen Printer'));
      expect(loaded.type, equals('wifi'));
      expect(loaded.address, equals('192.168.1.100:9100'));
      expect(loaded.paperSize, equals(80));
      expect(loaded.role, equals('kot'));
      expect(loaded.isDefault, isTrue);

      // Verify computed helpers
      expect(loaded.isWifi, isTrue);
      expect(loaded.isBluetooth, isFalse);
      expect(loaded.isKotPrinter, isTrue);
      expect(loaded.isReceiptPrinter, isFalse);

      await box.close();
    });

    test('save Bluetooth printer and read back', () async {
      final box = await Hive.openBox<SavedPrinterModel>('test_printers_bt');

      final original = SavedPrinterModel(
        id: 'p-2',
        name: 'Counter BT',
        type: 'bluetooth',
        address: 'AA:BB:CC:DD:EE:FF',
        paperSize: 58,
        role: 'both',
        isDefault: false,
      );

      await box.put(original.id, original);
      final loaded = box.get('p-2');

      expect(loaded, isNotNull);
      expect(loaded!.isBluetooth, isTrue);
      expect(loaded.paperSize, equals(58));
      expect(loaded.role, equals('both'));
      expect(loaded.isKotPrinter, isTrue);
      expect(loaded.isReceiptPrinter, isTrue);

      await box.close();
    });

    test('delete printer from box', () async {
      final box = await Hive.openBox<SavedPrinterModel>('test_printers_del');

      await box.put('p-3', SavedPrinterModel(
        id: 'p-3',
        name: 'Temp',
        type: 'wifi',
        address: '1.2.3.4:9100',
      ));

      expect(box.length, equals(1));
      await box.delete('p-3');
      expect(box.length, equals(0));
      expect(box.get('p-3'), isNull);

      await box.close();
    });

    test('multiple printers — query by type', () async {
      final box = await Hive.openBox<SavedPrinterModel>('test_printers_multi');

      await box.put('w1', SavedPrinterModel(id: 'w1', name: 'WiFi 1', type: 'wifi', address: '1.1.1.1:9100'));
      await box.put('w2', SavedPrinterModel(id: 'w2', name: 'WiFi 2', type: 'wifi', address: '2.2.2.2:9100'));
      await box.put('b1', SavedPrinterModel(id: 'b1', name: 'BT 1', type: 'bluetooth', address: 'AA:BB:CC'));

      final wifiPrinters = box.values.where((p) => p.type == 'wifi').toList();
      final btPrinters = box.values.where((p) => p.type == 'bluetooth').toList();

      expect(wifiPrinters.length, equals(2));
      expect(btPrinters.length, equals(1));
      expect(btPrinters.first.name, equals('BT 1'));

      await box.close();
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // TEST GROUP 5: Box Operations — Clear, Count, Exists
  // ════════════════════════════════════════════════════════════════════════

  group('Hive: Box operations', () {
    test('clear box removes all entries', () async {
      final box = await Hive.openBox<CartItem>('test_clear');

      await box.put('a', CartItem(id: 'a', productId: 'p', title: 'A', price: 10));
      await box.put('b', CartItem(id: 'b', productId: 'p', title: 'B', price: 20));
      await box.put('c', CartItem(id: 'c', productId: 'p', title: 'C', price: 30));

      expect(box.length, equals(3));
      await box.clear();
      expect(box.length, equals(0));
      expect(box.isEmpty, isTrue);

      await box.close();
    });

    test('containsKey checks existence', () async {
      final box = await Hive.openBox<CartItem>('test_contains');

      await box.put('exists', CartItem(id: 'exists', productId: 'p', title: 'X', price: 10));

      expect(box.containsKey('exists'), isTrue);
      expect(box.containsKey('nope'), isFalse);

      await box.close();
    });

    test('put same key overwrites (not duplicate)', () async {
      final box = await Hive.openBox<CartItem>('test_overwrite');

      await box.put('id-1', CartItem(id: 'id-1', productId: 'p', title: 'Version 1', price: 100));
      await box.put('id-1', CartItem(id: 'id-1', productId: 'p', title: 'Version 2', price: 200));

      // Only 1 entry, not 2
      expect(box.length, equals(1));
      expect(box.get('id-1')!.title, equals('Version 2'));
      expect(box.get('id-1')!.price, equals(200));

      await box.close();
    });
  });
}
