import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/product_type.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/domain/services/restaurant/inventory_service.dart';
import 'package:billberrylite/domain/services/restaurant/stock_adjust_service.dart';
import 'package:billberrylite/domain/store/restaurant/restaurant_purchase_order_store.dart';

/// Outcome of an inventory run.
class InventoryDataResult {
  int rawMaterials = 0;
  int semiFinished = 0;
  int recipes = 0;
  int suppliers = 0;
  int purchaseOrders = 0;
  int grns = 0;
  int partialGrns = 0;
  int damagedLines = 0;
  int creditNotes = 0;
  int returnsCancelled = 0;
  int claimsSettled = 0;
  int claimsRejected = 0;
  int payments = 0;
  int productions = 0;
  int adjustments = 0;
  int stockTakeLines = 0;
  final List<String> warnings = [];
}

class _Raw {
  final String name;
  final String unit;
  final double cost;
  final String supplier;
  const _Raw(this.name, this.unit, this.cost, this.supplier);
}

class _Semi {
  final String name;
  final String unit;
  final Map<String, double> perUnit;
  final double batch;
  const _Semi(this.name, this.unit, this.perUnit, this.batch);
}

/// Restaurant inventory data through the real inventory stores and services:
/// raw materials, semi-finished items with recipes, recipes on menu dishes,
/// suppliers, PO → GRN (stock in, purchase payable, damaged-goods documents),
/// credit notes, claims, supplier payments, production batches, manual
/// adjustments and a stock take.
///
/// Dates: GRN received dates, supplier payments and credit notes are spread
/// over the past [historyDays] (those APIs take a date). Everything the
/// stores stamp themselves — stock movements, PO creation, claims,
/// production, adjustments, the stock take — is dated today.
class InventoryDataGenerator {
  InventoryDataGenerator._();

  static final Random _random = Random();
  static const _uuid = Uuid();
  static const String generatedBy = 'TestData';

  static const _suppliers = {
    'veg': ('Fresh Farms Vegetables', 'Market Yard, Shop 12'),
    'meat': ('Royal Meat Suppliers', 'Sector 5, Cold Storage Lane'),
    'dairy': ('Dairy Best Pvt Ltd', 'Industrial Area Phase 2'),
    'grocery': ('Metro Wholesale Traders', 'APMC Market, Block C'),
    'drinks': ('City Beverage Distributors', 'Warehouse Road 7'),
  };

  static const _raws = [
    _Raw('Onion', 'kg', 30, 'veg'),
    _Raw('Tomato', 'kg', 40, 'veg'),
    _Raw('Capsicum', 'kg', 60, 'veg'),
    _Raw('Ginger Garlic Paste', 'kg', 120, 'veg'),
    _Raw('Chicken', 'kg', 220, 'meat'),
    _Raw('Mutton', 'kg', 650, 'meat'),
    _Raw('Fish', 'kg', 380, 'meat'),
    _Raw('Paneer', 'kg', 320, 'dairy'),
    _Raw('Butter', 'kg', 480, 'dairy'),
    _Raw('Fresh Cream', 'liter', 220, 'dairy'),
    _Raw('Mozzarella Cheese', 'kg', 450, 'dairy'),
    _Raw('Milk', 'liter', 56, 'dairy'),
    _Raw('Basmati Rice', 'kg', 110, 'grocery'),
    _Raw('Wheat Flour', 'kg', 38, 'grocery'),
    _Raw('Cooking Oil', 'liter', 140, 'grocery'),
    _Raw('Spice Mix', 'kg', 400, 'grocery'),
    _Raw('Sugar', 'kg', 45, 'grocery'),
  ];

  static const _semis = [
    _Semi('Makhani Gravy', 'liter', {
      'Tomato': 0.6,
      'Butter': 0.08,
      'Fresh Cream': 0.1,
      'Onion': 0.2,
      'Spice Mix': 0.02,
    }, 8),
    _Semi('Pizza Dough', 'piece', {
      'Wheat Flour': 0.2,
      'Cooking Oil': 0.01,
      'Sugar': 0.005,
    }, 20),
  ];

  /// Recipes for made-to-order dishes without variants (matched by name
  /// prefix, so "Butter Chicken 2" gets one too).
  static const _dishRecipes = {
    'Butter Chicken': {'Chicken': 0.2, 'Makhani Gravy': 0.15, 'Butter': 0.02},
    'Paneer Butter Masala': {'Paneer': 0.15, 'Makhani Gravy': 0.15},
    'Paneer Tikka': {'Paneer': 0.2, 'Capsicum': 0.05, 'Spice Mix': 0.01},
    'Chicken Tikka': {'Chicken': 0.25, 'Spice Mix': 0.015},
    'Butter Naan': {'Wheat Flour': 0.1, 'Butter': 0.01},
    'Garlic Naan': {'Wheat Flour': 0.1, 'Butter': 0.01, 'Ginger Garlic Paste': 0.01},
    'Masala Chai': {'Milk': 0.15, 'Sugar': 0.01},
    'Mutton Rogan Josh': {'Mutton': 0.25, 'Onion': 0.1, 'Spice Mix': 0.02},
  };

  static Future<InventoryDataResult> generate({
    required int purchaseOrders,
    required int historyDays,
    void Function(String message)? onProgress,
  }) async {
    final r = InventoryDataResult();
    await Future.wait([
      itemStore.loadItems(),
      restaurantSupplierStore.loadSuppliers(),
      restaurantPurchaseOrderStore.loadPurchaseOrders(),
      restaurantPurchaseOrderStore.loadGRNs(),
      restaurantDamagedGoodsStore.loadAll(),
      restaurantStockTakeStore.loadTakes(),
    ]);

    onProgress?.call('Inventory: raw materials & recipes…');
    final byName = await _materials(r);
    await _recipes(byName, r);

    onProgress?.call('Inventory: suppliers…');
    final suppliers = await _ensureSuppliers(r);
    if (suppliers.isEmpty) {
      r.warnings.add('No suppliers — purchasing skipped');
      return r;
    }

    final grnDates = await _purchasing(
        purchaseOrders, max(1, historyDays), suppliers, byName, r, onProgress);

    onProgress?.call('Inventory: credit notes, claims, payments…');
    await _damagedFollowUps(r);
    await _payments(suppliers, grnDates, r);

    onProgress?.call('Inventory: production, adjustments, stock take…');
    await _production(byName, r);
    await _adjustments(byName, r);
    await _stockTake(r);

    await Future.wait([
      itemStore.loadItems(),
      restaurantSupplierStore.loadSuppliers(),
      restaurantDamagedGoodsStore.loadAll(),
    ]);
    return r;
  }

  // ── Materials & recipes ──────────────────────────────────────────────────

  static Future<Map<String, Items>> _materials(InventoryDataResult r) async {
    final byName = {
      for (final i in itemStore.items) i.name.trim().toLowerCase(): i,
    };

    Future<void> add(String name, String unit, String type,
        {double? cost}) async {
      if (byName.containsKey(name.toLowerCase())) return;
      final item = Items(
        id: _uuid.v4(),
        name: name,
        unit: unit,
        productType: type,
        trackInventory: true,
        stockQuantity: 0,
        allowOrderWhenOutOfStock: false,
        lastPurchaseCost: ProductType.seededLastPurchaseCost(type, cost),
        lowStockThreshold: unit == 'piece' ? 10 : 3,
        lowStockAlertEnabled: true,
        taxRate: 0,
        createdTime: DateTime.now(),
        editedBy: generatedBy,
      );
      if (await itemStore.addItem(item)) {
        byName[name.toLowerCase()] = item;
        type == ProductType.rawMaterial ? r.rawMaterials++ : r.semiFinished++;
      } else {
        r.warnings.add('$name not added: ${itemStore.errorMessage}');
      }
    }

    for (final raw in _raws) {
      await add(raw.name, raw.unit, ProductType.rawMaterial, cost: raw.cost);
    }
    for (final semi in _semis) {
      await add(semi.name, semi.unit, ProductType.semiFinished);
    }
    return byName;
  }

  static Future<void> _recipes(
      Map<String, Items> byName, InventoryDataResult r) async {
    Future<void> save(Items item, Map<String, double> perUnit, String unit) async {
      if (recipeRepository.getRecipeForItem(item.id) != null) return;
      final ingredients = <RecipeIngredientModel>[];
      for (final e in perUnit.entries) {
        final ing = byName[e.key.toLowerCase()];
        if (ing == null) continue;
        ingredients.add(RecipeIngredientModel(
          ingredientItemId: ing.id,
          quantity: e.value,
          unit: ing.unit,
        ));
      }
      if (ingredients.isEmpty) return;
      await recipeRepository.saveForItem(RecipeModel(
        id: _uuid.v4(),
        itemId: item.id,
        yieldQty: 1,
        yieldUnit: unit,
        ingredients: ingredients,
        createdTime: DateTime.now(),
        editedBy: generatedBy,
      ));
      r.recipes++;
    }

    for (final semi in _semis) {
      final item = byName[semi.name.toLowerCase()];
      if (item != null) await save(item, semi.perUnit, semi.unit);
    }

    for (final item in itemStore.items) {
      if (item.hasVariants) continue;
      if (ProductType.effective(item.productType) != ProductType.finishedGood) {
        continue;
      }
      if (ProductType.effectivePrepMode(item.productType, item.prepMode) !=
          ProductType.madeToOrder) {
        continue;
      }
      final dish = _dishRecipes.keys
          .where((k) => item.name.startsWith(k))
          .firstOrNull;
      if (dish != null) await save(item, _dishRecipes[dish]!, 'portion');
    }
  }

  // ── Suppliers ────────────────────────────────────────────────────────────

  static Future<Map<String, RestaurantSupplierModel>> _ensureSuppliers(
      InventoryDataResult r) async {
    final out = <String, RestaurantSupplierModel>{};
    for (final e in _suppliers.entries) {
      final (name, address) = e.value;
      final existing = restaurantSupplierStore.suppliers
          .where((s) => s.name.trim().toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        out[e.key] = existing;
        continue;
      }
      try {
        final s = await restaurantSupplierStore.addSupplier(
          name: name,
          phone: '9${_random.nextInt(900000000) + 100000000}',
          address: address,
          openingBalance: _random.nextBool()
              ? (5000 + _random.nextInt(15000)).toDouble()
              : 0,
        );
        out[e.key] = s;
        r.suppliers++;
      } catch (err) {
        r.warnings.add('Supplier $name not added: $err');
      }
    }
    return out;
  }

  // ── PO → GRN ─────────────────────────────────────────────────────────────

  /// Returns supplierId → list of (receivedDate, amount) for payments.
  static Future<Map<String, List<(DateTime, double)>>> _purchasing(
    int count,
    int historyDays,
    Map<String, RestaurantSupplierModel> suppliers,
    Map<String, Items> byName,
    InventoryDataResult r,
    void Function(String message)? onProgress,
  ) async {
    final grnDates = <String, List<(DateTime, double)>>{};

    final catalog = <String, List<(Items, double)>>{};
    for (final raw in _raws) {
      final item = byName[raw.name.toLowerCase()];
      if (item != null) {
        catalog.putIfAbsent(raw.supplier, () => []).add((item, raw.cost));
      }
    }
    final trade = itemStore.items
        .where((i) =>
            ProductType.effective(i.productType) == ProductType.tradeItem &&
            !i.hasVariants)
        .map((i) => (i, _round((i.price ?? 40) * 0.6)))
        .toList();
    if (trade.isNotEmpty) catalog['drinks'] = trade;

    final keys = catalog.keys.where(suppliers.containsKey).toList();
    if (keys.isEmpty) {
      r.warnings.add('No purchasable items — purchasing skipped');
      return grnDates;
    }

    final today = DateTime.now();
    const handlings = ['returnToSupplier', 'keepForClaim', 'writeOff'];
    var damageTurn = 0;

    for (var i = 0; i < count; i++) {
      if (i % 5 == 0) onProgress?.call('Inventory: purchase order ${i + 1}/$count');
      final key = keys[i % keys.length];
      final supplier = suppliers[key]!;
      final pool = [...catalog[key]!]..shuffle(_random);
      final picked = pool.take(min(pool.length, 2 + _random.nextInt(4)));

      // Oldest first, ending yesterday; the newest few stay undelivered.
      final daysAgo = max(1, historyDays - (i * historyDays ~/ max(1, count)));
      final received = DateTime(today.year, today.month, today.day - daysAgo,
          9 + _random.nextInt(8), _random.nextInt(60));

      final lines = <PurchaseOrderLine>[
        for (final (item, cost) in picked)
          (
            itemId: item.id,
            itemName: item.name,
            qty: _orderQty(item),
            price: _round(cost * (0.95 + _random.nextDouble() * 0.1)),
          ),
      ];

      try {
        final po = await restaurantPurchaseOrderStore.createPurchaseOrder(
          supplierId: supplier.supplierId,
          supplierName: supplier.name,
          expectedDeliveryDate: received.toIso8601String(),
          notes: generatedBy,
          lines: lines,
        );
        r.purchaseOrders++;

        final isLast = i >= count - max(1, count ~/ 10);
        if (i == count - 1) continue; // one stays a draft
        await restaurantPurchaseOrderStore.markPOSent(po.poId);
        if (isLast) continue; // a few sent, not yet delivered

        final partial = _random.nextDouble() < 0.15;
        final poItems =
            restaurantPurchaseOrderItemRepository.getItemsByPOId(po.poId);
        final price = {for (final l in lines) l.itemId: l.price};
        final receipt = <GRNReceiptLine>[];
        for (final p in poItems) {
          final recv = partial
              ? _round(p.orderedQty * (0.6 + _random.nextDouble() * 0.3))
              : p.orderedQty;
          final damaged = _random.nextDouble() < 0.12
              ? min(recv, (1 + _random.nextInt(3)).toDouble())
              : 0.0;
          if (damaged > 0) r.damagedLines++;
          receipt.add((
            poItemId: p.poItemId,
            itemId: p.itemId,
            itemName: p.itemName ?? '',
            orderedQty: p.orderedQty,
            receivedQty: recv,
            acceptedQty: recv - damaged,
            damagedQty: damaged > 0 ? damaged : null,
            costPrice: price[p.itemId] ?? p.estimatedPrice,
            damagedHandling:
                damaged > 0 ? handlings[damageTurn++ % handlings.length] : null,
          ));
        }

        await restaurantPurchaseOrderStore.confirmGRN(
          poId: po.poId,
          poNumber: po.poNumber,
          supplierId: supplier.supplierId,
          supplierName: supplier.name,
          receivedDate: received.toIso8601String(),
          invoiceNumber: 'INV-${10000 + _random.nextInt(89999)}',
          notes: generatedBy,
          lines: receipt,
        );
        r.grns++;
        if (partial) r.partialGrns++;
        final amount = receipt.fold<double>(
            0, (s, l) => s + l.receivedQty * (l.costPrice ?? 0));
        grnDates
            .putIfAbsent(supplier.supplierId, () => [])
            .add((received, amount));
      } catch (err) {
        r.warnings.add('PO ${i + 1}: $err');
      }
    }
    return grnDates;
  }

  static double _orderQty(Items item) {
    if (item.unit == 'piece' ||
        ProductType.effective(item.productType) == ProductType.tradeItem) {
      return (24 * (1 + _random.nextInt(4))).toDouble();
    }
    return (10 + _random.nextInt(31)).toDouble();
  }

  // ── Damaged goods follow-ups ─────────────────────────────────────────────

  static Future<void> _damagedFollowUps(InventoryDataResult r) async {
    await restaurantDamagedGoodsStore.loadAll();

    // Returns and claims are created by the GRN dated today, so their
    // credit notes are dated today too (never before the return itself).
    for (final ret in restaurantDamagedGoodsStore.purchaseReturns.toList()) {
      if (!ret.isOpen) continue;
      final roll = _random.nextDouble();
      if (roll < 0.7) {
        final ok = await restaurantDamagedGoodsStore.recordCreditNote(
          returnId: ret.returnId,
          creditNoteNumber: 'CN-${1000 + _random.nextInt(8999)}',
        );
        if (ok) r.creditNotes++;
      } else if (roll < 0.8) {
        final ok = await restaurantDamagedGoodsStore.cancelPurchaseReturn(
            ret.returnId,
            reason: 'Supplier refused return');
        if (ok) r.returnsCancelled++;
      }
    }

    for (final claim in restaurantDamagedGoodsStore.supplierClaims.toList()) {
      if (!claim.isOpen) continue;
      final roll = _random.nextDouble();
      if (roll < 0.6) {
        final approved = await restaurantDamagedGoodsStore.updateClaimStatus(
          claimId: claim.claimId,
          status: RestaurantSupplierClaimStatus.approved,
          resolutionNote: 'Approved by supplier',
        );
        if (approved && roll < 0.4) {
          final settled = await restaurantDamagedGoodsStore.updateClaimStatus(
            claimId: claim.claimId,
            status: RestaurantSupplierClaimStatus.settled,
            resolutionNote: 'Credit adjusted on next bill',
          );
          if (settled) r.claimsSettled++;
        }
      } else if (roll < 0.8) {
        final rejected = await restaurantDamagedGoodsStore.updateClaimStatus(
          claimId: claim.claimId,
          status: RestaurantSupplierClaimStatus.rejected,
          resolutionNote: 'Damage not covered',
        );
        if (rejected) {
          r.claimsRejected++;
          await restaurantDamagedGoodsStore.writeOffRejectedClaim(claim.claimId);
        }
      }
    }
  }

  // ── Supplier payments ────────────────────────────────────────────────────

  static Future<void> _payments(Map<String, RestaurantSupplierModel> suppliers,
      Map<String, List<(DateTime, double)>> grnDates,
      InventoryDataResult r) async {
    const modes = ['Cash', 'UPI', 'Bank', 'Cheque'];
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    for (final e in grnDates.entries) {
      final receipts = [...e.value]..sort((a, b) => a.$1.compareTo(b.$1));
      for (final (date, amount) in receipts) {
        if (_random.nextDouble() > 0.7 || amount <= 0) continue;
        var paidOn = date.add(Duration(days: 2 + _random.nextInt(9)));
        if (paidOn.isAfter(yesterday)) paidOn = yesterday;
        final pay = _round(amount * (_random.nextBool() ? 1 : 0.5));
        final mode = modes[_random.nextInt(modes.length)];
        try {
          await restaurantSupplierStore.recordBalanceMovement(
            supplierId: e.key,
            amount: -pay,
            type: RestaurantSupplierLedgerType.payment,
            description: 'Payment to supplier',
            paymentMode: mode,
            referenceNo: mode == 'Cash' ? null : 'REF${100000 + _random.nextInt(899999)}',
            date: paidOn.toIso8601String(),
          );
          r.payments++;
        } catch (err) {
          r.warnings.add('Payment failed: $err');
        }
      }
    }
  }

  // ── Production, adjustments, stock take (dated today) ────────────────────

  static Future<void> _production(
      Map<String, Items> byName, InventoryDataResult r) async {
    for (final semi in _semis) {
      final item = _live(byName[semi.name.toLowerCase()]);
      if (item == null) continue;
      try {
        await InventoryService.produceBatch(item: item, batchQty: semi.batch);
        r.productions++;
      } catch (err) {
        r.warnings.add('Production ${semi.name}: $err');
      }
    }
  }

  static Future<void> _adjustments(
      Map<String, Items> byName, InventoryDataResult r) async {
    final plan = <(String, double, String)>[
      ('Tomato', -1.5, 'Wastage / Spoilage'),
      ('Onion', -2, 'Wastage / Spoilage'),
      ('Fresh Cream', -0.5, 'Wastage / Spoilage'),
      ('Milk', -1, 'Wastage / Spoilage'),
      ('Chicken', -0.5, 'Theft / Loss'),
      ('Paneer', -0.25, 'Sample / Complimentary'),
      ('Basmati Rice', 2, 'Stock correction'),
      ('Cooking Oil', 1, 'Stock correction'),
    ];
    for (final (name, delta, reason) in plan) {
      final item = _live(byName[name.toLowerCase()]);
      if (item == null || item.stockQuantity + delta < 0) continue;
      try {
        await StockAdjustService.adjustBy(
          item: item,
          delta: delta,
          reason: reason,
          note: generatedBy,
        );
        r.adjustments++;
      } catch (err) {
        r.warnings.add('Adjust $name: $err');
      }
    }
  }

  static Future<void> _stockTake(InventoryDataResult r) async {
    final take =
        await restaurantStockTakeStore.startTake(scopeNote: 'Monthly count ($generatedBy)');
    if (take == null) {
      r.warnings.add('Stock take not started: ${restaurantStockTakeStore.errorMessage}');
      return;
    }
    final candidates = itemStore.items
        .where((i) => i.trackInventory && !i.hasVariants && i.stockQuantity > 0)
        .take(15)
        .toList();
    for (final item in candidates) {
      final roll = _random.nextDouble();
      final counted = roll < 0.7
          ? item.stockQuantity
          : max(0.0, item.stockQuantity + (roll < 0.9 ? -1 : 1));
      if (await restaurantStockTakeStore.countItem(
          item: item, countedQty: counted)) {
        r.stockTakeLines++;
      }
    }
    final result = await restaurantStockTakeStore.commit(
      shortageReason: 'Wastage / Spoilage',
      note: generatedBy,
    );
    if (!result.success) r.warnings.add('Stock take commit did not complete');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// The item's current version from the store (stock changes after GRNs).
  static Items? _live(Items? item) => item == null
      ? null
      : itemStore.items.where((i) => i.id == item.id).firstOrNull;

  static double _round(double v) => double.parse(v.toStringAsFixed(2));
}
