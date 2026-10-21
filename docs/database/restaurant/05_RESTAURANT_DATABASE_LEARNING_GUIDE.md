# Restaurant Database: A Learning Guide

> **Who this is for:** a Flutter developer joining Bill Berry Lite who will work on the **restaurant** side, has never worked with a database, or knows SQL but not Hive.
> **What it covers:** the same ten beginner questions as the retail guide, answered with real code from the **restaurant** side of this repo.
> **Read the retail guide first?** Not required, but the generic ideas (what Hive is, what a box or model is, why field numbers must never be reused) are explained in more depth in [../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md). This guide keeps those parts short and spends its time on what is **different** in a restaurant.
> **How to read citations:** `path:line` is relative to the repo root `D:\flutter\UniPOSs`. "(inferred)" means the conclusion comes from reading the code, not from running it. All of this is static analysis of branch `refactor/shared-code-consolidation`, read on 2026-10-19.
> **Illustrative values:** worked examples that use made-up dishes, prices or ids are labelled *example*. Field names, box names, file names and code are real.

---

## Contents

1. [What is a database?](#1-what-is-a-database)
2. [What is a record?](#2-what-is-a-record)
3. [What is a model?](#3-what-is-a-model)
4. [What is a database box?](#4-what-is-a-database-box)
5. [What is an ID?](#5-what-is-an-id)
6. [How are records connected?](#6-how-are-records-connected)
7. [How does the Restaurant app save and retrieve data?](#7-how-does-the-restaurant-app-save-and-retrieve-data)
8. [What happens to the database during a sale?](#8-what-happens-to-the-database-during-a-sale)
9. [How do inventory and reports get their data?](#9-how-do-inventory-and-reports-get-their-data)
10. [How can I trace a feature from the UI to the database?](#10-how-can-i-trace-a-feature-from-the-ui-to-the-database)
- [Glossary](#glossary)
- [Common beginner mistakes in this codebase](#common-beginner-mistakes-in-this-codebase)
- [Where to go next](#where-to-go-next)

---

## The restaurant in one picture

Before the ten questions, here is the one idea that makes the restaurant database different from retail. A retail bill is born and finished in one step (checkout). A restaurant order **lives for a while**: the kitchen gets tickets (KOTs), more food is added, the bill is paid, the food is served, and only then is the order "finished".

```text
 menu taps            Place Order              add food (2nd KOT)        Pay + Served
     │                     │                          │                       │
     ▼                     ▼                          ▼                       ▼
 cart_box  ──────────►  orderBox  ─────────────►  orderBox  ─────────────►  pastorderBox
 (CartItem rows,        (OrderModel: "active"     (same record, more        (PastOrderModel:
  int keys,              order, items EMBEDDED,    items appended, one       the "sale" that
  wiped after            KOT = index ranges)       more KOT range)           reports read)
  every order)                                                                + orderBox row DELETED
```

Keep this picture in mind. Almost every restaurant-specific rule in this guide comes from it.

---

## 1. What is a database?

A **database** keeps information after the app is closed. The restaurant side uses the same storage as retail:

- **Hive** (`hive ^2.2.3`, `hive_flutter ^1.1.0`, `pubspec.yaml:42-43`) for all business data. There is no SQL layer.
- **SharedPreferences** for settings toggles (for example "Generate KOT", "Tax Is Inclusive", "Auto Serve Dine In On Payment"), the logged-in staff session and print settings.
- **flutter_secure_storage** for the backup password and the license.

Hive is key-value, not SQL: a box is like a table, a record is like a row, and there are **no foreign keys and no transactions across boxes**. The retail guide explains this with a SQL-to-Hive table ([retail §1](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md#1-what-is-a-database)).

### What is different in restaurant

- **The database also has a network door.** Restaurant mode starts a small local web server on port **9090** (`lib/main.dart:202-206` → `server/server.dart:64-95`). The **Captain** waiter app and the **KDS** kitchen screen talk to it over the shop's Wi-Fi, and its handlers **write straight into the same Hive boxes** the POS uses (`orderBox`, `appCounters`, `itemBoxs`, `stockMovementsBox`, `tablesBox`). Section 6 and section 8 come back to this.
- **No encryption at rest**, same as retail. Backups are encrypted.

---

## 2. What is a record?

A **record** is one saved "thing". In the restaurant, the two records you will meet most are a **menu item** (`Items`, box `itemBoxs`) and an **order** (`OrderModel` while open in `orderBox`, `PastOrderModel` once finished in `pastorderBox`).

### Worked example: one menu item record

*Example values.* Field numbers, names and types are real (`lib/data/models/restaurant/db/itemmodel_302.dart`).

| HiveField | Field | Type | Example value |
|---|---|---|---|
| 0 | `id` | `String` | `"9c1e…-77ab"` (UUID; normally also the Hive key, see §5) |
| 1 | `name` | `String` | `"Margherita Pizza"` |
| 2 | `imageBytes` | `Uint8List?` | the photo itself, stored **inside** the record |
| 3 | `price` | `double?` | `240.0` |
| 5 | `categoryOfItem` | `String?` | `"c41d…"` (a `Category.id`; `''` = uncategorised) |
| 8 | `variant` | `List<ItemVariante>?` | `[]` (sizes with their own price and stock, **embedded**) |
| 10 | `extraId` | `List<String>?` | `["e7f0…"]` (ids of `Extramodel` groups, e.g. "Toppings") |
| 11 | `taxRate` | `double?` | `0.05` (a **fraction**, the sum of the applied taxes) |
| 12 | `isEnabled` | `bool` | `true` (soft hide switch) |
| 13 | `trackInventory` | `bool` | `false` |
| 14 | `stockQuantity` | `double` | `0.0` (a recipe dish holds no stock of its own) |
| 25 | `itemCode` | `String?` | `"1004"` |
| 28 | `productType` | `String?` | `"recipeBased"` (also `rawMaterial`, `semiFinished`, `finishedGood`; `null` reads as `finishedGood`) |
| 30 | `lastPurchaseCost` | `double?` | `null` (last GRN cost; the only cost source for food costing) |

Things worth noticing, compared with retail:

- **One model for everything you stock or sell.** A pizza on the menu, a kilo of flour in the store room, and a pot of sauce made in the kitchen are all `Items`. `productType` tells them apart. Retail splits catalogue (`ProductModel`) from sellable SKU (`VarianteModel`); restaurant does not.
- **Stock lives on the item itself** (`stockQuantity`), or on each embedded `ItemVariante` for items with sizes. There is no separate variants-with-stock box.
- **The photo is inside the record** (`imageBytes`). It travels with the item into backups and even into the Captain menu response.

---

## 3. What is a model?

A model is the Dart class for a record, annotated with `@HiveType(typeId: …)` and numbered `@HiveField(n)` slots, plus a generated `*.g.dart` adapter. The full explanation, and the rule "never reuse a field number or typeId", is in [retail §3](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md#3-what-is-a-model).

The real top of the restaurant item model:

`lib/data/models/restaurant/db/itemmodel_302.dart:12-24`

```dart
@HiveType(typeId: HiveTypeIds.restaurantItem)
class Items extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final Uint8List? imageBytes; // Image stored as bytes for web+mobile compatibility

  @HiveField(3)
  final double? price;
  // ...
```

And two fields added later with a `defaultValue`, so old records still load:

`lib/data/models/restaurant/db/itemmodel_302.dart:86-90`

```dart
  @HiveField(23, defaultValue: false)
  bool lowStockAlertEnabled; // Per-item opt-in for low-stock alerts (the YES/NO toggle)

  @HiveField(24, defaultValue: false)
  bool isFavorite; // Pinned to the "Favorites" tab in the POS menu
```

### Restaurant-specific facts

| Fact | Detail |
|---|---|
| Filename suffix is off by **200** | `itemmodel_302.dart` is typeId **102**, `ordermodel_309.dart` is **109**, `pastordermodel_313.dart` is **113**, `cartmodel_308.dart` is **108**. Trust `lib/core/constants/hive_type_ids.dart`, never the filename. |
| Restaurant typeId range | 100-149 is full. Overflow range 185-199 holds the supplier ledger (185). **Next free restaurant typeId is 186.** 101 (old `Company`) is retired: never reuse it. |
| Retired field numbers | `CartItem` has no field **2**; `Category` has no field **2** ("was imagePath — removed"). Next free `CartItem` field is 17; next free `Items` field is 32. |
| Deprecated but kept | `OrderModel.kotNumber` (f10) and `PastOrderModel.kotNumber` (f5) are never written. They stay so old bytes still decode. Use `kotNumbers` (f21 / f18). |
| A registered-adapter gap | `TestBillItem` (123) has no registered adapter. Its parent box `testBillBox` has no callers, so nothing writes it today. |
| Late non-nullable fields without a default | e.g. `Items.isSoldByWeight` f16, `OrderModel.itemCountAtLastKot` f22. A record written before those fields existed would fail to load **(inferred)**. The project is pre-release, so breaking local data is accepted. |

---

## 4. What is a database box?

A box is a named collection of records saved as one file. Restaurant mode opens **49 boxes**: 1 `appConfigBox`, 11 common boxes, and 37 restaurant-phase boxes in `HiveInit.openRestaurantBoxes()`.

`lib/core/init/hive_init.dart:769-787`

```dart
    // Core restaurant boxes - use actual box names from database files
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Extramodel>(HiveBoxNames.restaurantExtras);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<ChoicesModel>(HiveBoxNames.restaurantChoices);

    // Restaurant cart
    await Hive.openBox<CartItem>(HiveBoxNames.restaurantCart);

    // Orders
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    // ...
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);

    // Past Orders
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);
```

### The main restaurant boxes

The box string on disk is often **not** what the constant is called. Search for both.

| Box (string on disk) | Constant | Holds | What it is for |
|---|---|---|---|
| `itemBoxs` | `restaurantItems` | `Items` (embeds `ItemVariante`) | Menu items, raw materials, prep items. Stock lives here. |
| `variante` | `restaurantVariants` | `VariantModel` | Global size **names** only ("Half", "Full"). Price and stock are on the item. |
| `choice` | `restaurantChoices` | `ChoicesModel` (embeds `ChoiceOption`) | Free modifiers ("Spice: Mild / Hot") |
| `extra` | `restaurantExtras` | `Extramodel` (embeds `Topping`) | Paid add-ons ("Cheese +40") |
| `cart_box` | `restaurantCart` | `CartItem` | The working cart. **Auto-increment int keys.** Wiped after every order. |
| `orderBox` | `restaurantOrders` | `OrderModel` (embeds `CartItem` list) | **Active** (open) orders, KOTs, partial payments |
| `pastorderBox` | `restaurantPastOrders` | `PastOrderModel` (embeds `CartItem` list) | **Finished** bills, voids, refunds. The restaurant "sales" box. |
| `tablesBox` | `restaurantTables` | `TableModel` | Tables and their status |
| `restaurantRecipesBox` | `restaurantRecipes` | `RecipeModel` (embeds `RecipeIngredientModel`) | Bill of materials for recipe dishes and prep items |
| `restaurantRecipeProductionsBox` | `restaurantRecipeProductions` | `RecipeProductionModel` | Log of kitchen production batches |
| `restaurantItemCancellationsBox` | `restaurantItemCancellations` | `ItemCancellationModel` | Audit row when an already-KOT'd item is cancelled |
| `restaurant_eodBox` | `restaurantEOD` | `EndOfDayReport` | Saved End-of-Day totals, one per session |
| `restaurant_expenseBox`, `restaurant_expenseCategory` | | `Expense`, `ExpenseCategory` | Expenses (restaurant has the expense UI) |
| `cashHandoversBox` | `restaurantCashHandovers` | `CashHandoverModel` | Two-step drawer handover (the UI that creates them is unreachable today) |
| `restaurantSuppliersBox`, `restaurantPurchaseOrders(Items)Box`, `restaurantGrns(Items)Box`, `restaurantSupplierLedgerBox` | | supplier, PO, GRN, ledger | Purchasing raw materials |
| `restaurantPurchaseReturns…`, `restaurantSupplierClaims…`, `restaurantInventoryLossesBox`, `restaurantStockTakes…` | | damaged-goods and count documents | |
| `testBillBox` | `testBillBox` | `TestBillModel` | Dead: opened and backed up, never written |

### Boxes shared with retail (same file on disk)

`categories`, `customers`, `staffBox`, `taxes`, `shiftBox`, `restaurantAttendanceBox`, `restaurantNotificationsBox`, `restaurantPrintersBox`, `paymentMethodsBox`, `dayManagementBox`, `restaurantSessionsBox`, `cashMovementsBox`, `stockMovementsBox`, `appCounters`. Retail has its own separate EOD and expense boxes.

### Raw (untyped) boxes the restaurant uses

| Box | Keys (examples) | Used by |
|---|---|---|
| `appCounters` | `lastKotNumber` + `lastKotDate`, `lastOrderNumber` + `lastOrderDate`, `lastBillNumber` + `lastBillResetYear`, `PO_…`, `GRN_…` | Number generators (section 5) |
| `dayManagementBox` | `currentSessionId`, `dayStarted`, `openingBalance`, `closingBalance`, `lastDayDate`, `dayStartTimestamp` | `DayManagementService` |

### What is NOT a box in restaurant

There is **no KOT box** and **no payment box**. A KOT is a range of indexes inside an order (section 6). Payments are a JSON string inside the order (`paymentListJson`). If you search for `KotModel` or `PaymentRepository`, you will not find them.

---

## 5. What is an ID?

An ID names exactly one record and never changes. The general rule from retail holds: most repositories save a record **under its own id field as the Hive key**, so `put` with an existing id replaces it ([retail §5](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md#5-what-is-an-id)).

`lib/data/repositories/restaurant/order_repository.dart:23-26`

```dart
  /// Add an order to the database
  Future<void> addOrder(OrderModel order) async {
    await _orderBox.put(order.id, order);
  }
```

### Kinds of ID in restaurant

| ID | Format | Where it is made | Hive key? |
|---|---|---|---|
| `Items.id`, `RecipeModel.id`, most masters | UUID v4 | e.g. `add_item_form_state.dart:181` | Yes (mostly, see below) |
| Order id (POS) | UUID v4 | `takeaway.dart:1467` | Yes, in `orderBox` |
| Order id (Captain / KDS server) | **epoch milliseconds as a string**, e.g. `"1760870400123"` | `captain_handler.dart:248`, `order_handler.dart:24` | Yes |
| Past order id | **the same id as the active order** it came from (a fresh UUID for Quick Settle / Settle & Print) | `customerdetails.dart:1456` | Yes, in `pastorderBox` |
| `CartItem.id` | UUID; **weighed items reuse the item id** on purpose (it drives merging) | `menu.dart:731`, `weight_item_dialog_restaurant.dart:37` | **No.** `cart_box` uses auto-int keys. |
| `TableModel.id` | **the table's display name**, e.g. `"T5"` | `table.dart:76` | Yes |
| KOT number | plain int, **resets each calendar day** | `OrderRepository.getNextKotNumber` | No (a number inside the order) |
| Order number | plain int, resets each calendar day | `OrderRepository.getNextOrderNumber` | No |
| Bill number | plain int, **resets each financial year**, no prefix | `OrderRepository.getNextBillNumber` | No, display only |
| PO / GRN / return numbers | `PO-00001` etc., per financial year | `DocumentNumberService` | No |
| Restaurant customer id | UUID (retail uses `CUST-000042`) | customer store | Yes |

### Three counters, three reset rules

All three live in the shared raw box `appCounters`. Each "next number" call is a read, then a `put`:

`lib/data/repositories/restaurant/order_repository.dart:70-86`

```dart
  /// Get next KOT number (Resets Daily)
  Future<int> getNextKotNumber() async {
    final lastKotDate = await _counterBox.get('lastKotDate');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // If it's a new day, reset the counter
    if (lastKotDate != todayStr) {
      await _counterBox.put('lastKotNumber', 0);
      await _counterBox.put('lastKotDate', todayStr);
    }

    int lastNumber = await _counterBox.get('lastKotNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    await _counterBox.put('lastKotNumber', newNumber);
    return newNumber;
  }
```

`lib/data/repositories/restaurant/order_repository.dart:93-110`

```dart
  Future<int> getNextBillNumber() async {
    final lastResetYear = await _counterBox.get('lastBillResetYear');

    final currentFiscalYearStartYear = FiscalYearRule.startOfCurrent.year;

    // If we haven't reset for this fiscal year yet, reset now
    if (lastResetYear != currentFiscalYearStartYear) {
      await _counterBox.put('lastBillNumber', 0);
      await _counterBox.put('lastBillResetYear', currentFiscalYearStartYear);
    }
    // ...
    await _counterBox.put('lastBillNumber', newNumber);

    return newNumber;
  }
```

Things to know:

- Many code comments still say "Daily bill number" (for example `customerdetails.dart:1475`). They are stale. The bill number resets per **financial year**.
- The KOT counter resets by **calendar date**, not by session. A shift that runs past midnight starts again at KOT 1.
- **There is a second KOT counter.** The static helper used by the Captain "add items" path writes the same key but never resets:

`lib/data/models/restaurant/db/database/hive_order.dart:46-55`

```dart
  static Future<int> getNextKotNumber() async {
    // Box is already opened during app startup in HiveInit
    final counterBox = Hive.box(_counterBoxName);
    // Get the last number, defaulting to 0 if it doesn't exist
    int lastNumber = await counterBox.get('lastKotNumber', defaultValue: 0);
    int newNumber = lastNumber + 1;
    // Save the new number back to the box for the next order
    await counterBox.put('lastKotNumber', newNumber);
    return newNumber;
  }
```

  So a Captain add-on early in the day can continue yesterday's KOT count; the next POS call then resets to 1.
- Numbers are reserved **before** the write that uses them. A cancel-KOT print, a "print bill" for an active order (`restaurant_print_helper.dart:692`) or a retry all burn a number. Gaps in the KOT and bill sequences are normal.

### When "the id is the key" is not true: `itemBoxs`

Items created by the dev data generators were saved with `box.addAll(...)`, which gives **auto-increment int keys**. A plain `put(item.id, …)` would then make a second copy. So `ItemRepository.updateItem` finds every key holding that id, overwrites the first in place and deletes the rest:

`lib/data/repositories/restaurant/item_repository.dart:56-67`

```dart
  Future<void> updateItem(Items item) async {
    final keysForId =
        _itemBox.keys.where((k) => _itemBox.get(k)?.id == item.id).toList();

    if (keysForId.isEmpty) {
      await _itemBox.put(item.id, item);
    } else {
      await _itemBox.put(keysForId.first, item); // in-place, order preserved
      for (final k in keysForId.skip(1)) {
        await _itemBox.delete(k); // remove duplicates
      }
    }
    // ...
```

`getAllItems` also collapses duplicates by id on read (`item_repository.dart:26-36`). But `deleteItem` only does `_itemBox.delete(itemId)` (`:77-79`), so an item still stored under an int key is **not** deleted and comes back on the next load **(inferred)**.

---

## 6. How are records connected?

Hive has no foreign keys. Records connect by **id reference**, **embedding** and **snapshot**, exactly as in retail ([retail §6](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md#6-how-are-records-connected)). What changes in a restaurant is *which* links use which method, and four links that have no retail equivalent.

### 6.1 Order lines are embedded inside the order

In retail, a sale header (`sales`) and its lines (`saleItems`) are two boxes joined by `saleId`. In restaurant there is **no lines box**. The order holds a full list of `CartItem` objects:

`lib/data/models/restaurant/db/ordermodel_309.dart:8-23`

```dart
@HiveType(typeId: HiveTypeIds.restaurantOrder)
class OrderModel extends HiveObject {
  @HiveField(0)
  final String id;
  // ...
  @HiveField(4)
  final List<CartItem> items;
```

`PastOrderModel.items` (field 3) is the same list, copied when the order finishes. Each `CartItem` is a **snapshot**: name (`title`), unit price **with the chosen variant and extras already folded in** (`price`), `variantName`, `choiceNames`, extras as raw maps, `taxRate`, `categoryName`. Its only live link is `productId` → `Items.id`.

`lib/data/models/restaurant/db/cartmodel_308.dart:6-18`

```dart
@HiveType(typeId: HiveTypeIds.restaurantCart)
class CartItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(3)
  final double price;

  @HiveField(4)
  int quantity;
```

Consequences:

- Renaming or repricing a dish never changes an old bill. The bill reads its own embedded lines.
- To change one line you rewrite the **whole order record**.
- Refunds mark lines in place (`CartItem.refundedQuantity`, f14) on the past order.

### 6.2 A KOT is not a record: it is an index range on the order

A **KOT** (Kitchen Order Ticket) is the slip the kitchen cooks from. Every time the waiter sends food, a new KOT is printed. You might expect a `kots` box. There isn't one. The order stores four parallel fields:

`lib/data/models/restaurant/db/ordermodel_309.dart:74-85`

```dart
  // --- MULTIPLE KOT SUPPORT ---
  @HiveField(21)
  final List<int> kotNumbers; // List of all KOT numbers - REQUIRED [1, 2, 3...]

  @HiveField(22)
  final int itemCountAtLastKot; // Number of items when last KOT was generated - REQUIRED

  @HiveField(23)
  final List<int> kotBoundaries; // Item count at each KOT [3, 5, 6] means items 0-2 in KOT1, 3-4 in KOT2, 5-5 in KOT3

  @HiveField(24)
  final Map<int, String>? kotStatuses; // Status for each KOT number {1: 'Ready', 2: 'Processing'}
```

plus `kotTimestamps` (f36, when each add-on KOT was created). `kotBoundaries` are **cumulative end indexes**. The model slices `items` with them:

`lib/data/models/restaurant/db/ordermodel_309.dart:277-293`

```dart
  Map<int, List<CartItem>> getItemsByKot() {
    Map<int, List<CartItem>> itemsByKot = {};

    int startIndex = 0;
    for (int i = 0; i < kotNumbers.length; i++) {
      int endIndex = kotBoundaries[i];
      int kotNum = kotNumbers[i];

      // Get items for this KOT
      List<CartItem> kotItems = items.sublist(startIndex, endIndex);
      itemsByKot[kotNum] = kotItems;

      startIndex = endIndex;
    }

    return itemsByKot;
  }
```

*Example:* `items` has 3 lines, `kotNumbers = [14, 15]`, `kotBoundaries = [2, 3]`. KOT 14 is `items[0..2)`, KOT 15 is `items[2..3)`.

Rules that follow from this design:

- **Items are append-only.** A new KOT appends lines to the end and appends one boundary equal to the new `items.length`.
- **The invariant is `kotBoundaries.last == items.length`**, and `kotNumbers.length == kotBoundaries.length` (debug-only asserts at `ordermodel_309.dart:167-169`).
- **Removing a line means shifting every boundary after it.** The Active Orders cancel path does this (`activeorder.dart:1540-1567`). The cart's immediate-cancel path does **not** adjust boundaries when it removes a whole line (`takeaway.dart:1120-1129`), and `OrderModel.getItemsByKot` has no bounds check, so a later KOT print can throw a `RangeError` **(inferred)**. `PastOrderModel.getItemsByKot` clamps and is safe.
- Printing and the KDS screen both read KOTs through `getItemsByKot()` (`restaurant_print_helper.dart:50`; `kds_handler.dart:9-110`).

### 6.3 Tables are linked by name

`OrderModel.tableNo` (f8) holds the `TableModel.id`, and **the table id is its display name** (for example `"T5"`). The live "which order is on this table?" lookup does not use the table's own `currentOrderId`; it scans active orders by `tableNo`:

`lib/domain/store/restaurant/order_store.dart:570-581`

```dart
  OrderModel? getActiveOrderByTableId(String tableId) {
    try {
      return orders.firstWhere(
        (order) =>
            order.tableNo == tableId &&
            (order.status == 'Processing' ||
             order.status == 'Cooking' ||
             order.status == 'Ready' ||
             order.status == 'Running' ||
             order.status == 'Reserved' ||
             order.status == 'Served'),
      );
```

- `TableModel.currentOrderId` is a hint only. POS status updates often omit `orderId`, and the repository then writes it as `null` (`table_repository.dart:30-49`).
- **Renaming a table** is delete + add with the new name (`table.dart:261-285`). It does not rewrite `OrderModel.tableNo`, and it is not blocked while the table is occupied, so the open order loses its table **(inferred)**.

### 6.4 Other links worth knowing

| Link | Kind | Note |
|---|---|---|
| `CartItem.productId` → `Items.id` | id reference | Stock code falls back to matching by **item name** if the id is not found (`inventory_service.dart:36-49`) |
| `CartItem.variantName` → `VariantModel.name` | **by name** | Variant stock is found by name, so renaming a size breaks deduction for carts already holding the old name |
| `Items.variant[].variantId` → `VariantModel.id` | id reference inside an embedded list | The size **name** lives in `variante`; its **price and stock** live on the item |
| `Items.choiceIds`, `extraId`, `taxIds`, `categoryOfItem` | id references | Deleting the master leaves the id dangling; the POS dialog skips missing groups |
| `RecipeModel.itemId` → `Items.id` | id reference (the real recipe link) | `Items.recipeId` is written but **never read** for lookup |
| `RecipeIngredientModel.ingredientItemId` → `Items.id` | id reference inside an embedded list | |
| `OrderModel.sessionId`, `PastOrderModel.sessionId` → session | id reference | Drives EOD |
| `PastOrderModel.shiftId` → `ShiftModel.id` | id reference | Only past orders carry a shift |
| Staff on orders | **names only** | `discountAppliedBy`, `voidedBy`, `refundedBy`, `lastModifiedBy` are display strings, not staff ids |
| Payment legs | embedded JSON string | `paymentListJson` on the order; no payment box |

---

## 7. How does the Restaurant app save and retrieve data?

The intended layering is the same as retail: **Screen → MobX Store → Repository → Hive box** ([retail §7](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md#7-how-does-the-retail-app-save-and-retrieve-data)). Stores live in `lib/domain/store/restaurant/`, repositories in `lib/data/repositories/restaurant/`, services in `lib/domain/services/restaurant/`. Stores are lazy singletons registered in `lib/core/di/service_locator.dart:382-499` and reached through globals such as `itemStore`, `orderStore`, `pastOrderStore`, `restaurantCartStore`, `tableStore`.

### Retrieval: hydrate, then observe

`ItemStore`'s constructor starts `loadItems()` but nothing awaits it, so screens call `ensureLoaded()` first (`item_store.dart:17-35`). The menu screen awaits categories, items and the cart together (`tabbar/menu.dart:582-612`).

`PastOrderStore` does **not** load itself (`past_order_store.dart:16`). Every report calls `pastOrderStore.loadPastOrders()`, which reads the whole `pastorderBox`.

### Saving: write the box first, then memory

`ItemStore.addItem` (`item_store.dart:167-217`) checks plan gates and duplicates, calls `_repository.addItem(item)`, then `items.add(item)`. Many order-store actions do the same, but **catch the exception and return `false`**, and almost no caller checks that `bool` (`order_store.dart:263-327`, `past_order_store.dart:127-136`). Section 8 shows why that matters.

### Where the restaurant leaves the golden path

You need to know these, because the UI can show stale data after them:

| Shortcut | Where | Effect |
|---|---|---|
| **Captain / KDS server writes** | `server/handlers/captain_handler.dart`, `kds_handler.dart`, `order_handler.dart` | Some go through `orderStore`; the Captain append/modify/status paths call the static `HiveOrders` helper (`data/models/restaurant/db/database/hive_order.dart`), which writes `orderBox` **directly**. The POS refreshes by calling `orderStore.loadOrders()` when it hears `ORDER_UPDATED` / `NEW_ITEMS_ADDED` on the WebSocket (`activeorder.dart:63-125`). Start Order also reloads orders when you switch tabs (`startorder.dart:130-138`). |
| `DayManagementService` | `day_management_service.dart` | Static; writes `restaurantSessionsBox`, `dayManagementBox`, `cashMovementsBox` directly |
| `EODService` | `eod_service.dart:203-217` | Reads `cashMovementsBox` with `Hive.box` directly |
| `StockMovementRepository()` | `inventory_service.dart:30` and 6+ other places | `new`'d ad hoc, not from DI |
| Item Cancellation report | `itemCancellationReport.dart:67` | Screen calls the repository directly |
| Cash Drawer History | `cash_drawer_history_screen.dart:179,345` | Screen opens `Hive.box` directly |

### The stock choke point

Every sale, recipe cascade, void/refund restore, production batch and GRN goes through one store method, `ItemStore.applyStockDelta`. It queues writes **per item**, so two sales of the same dish cannot both start from the same stock figure:

`lib/domain/store/restaurant/item_store.dart:364-384`

```dart
  @action
  Future<double> applyStockDelta({
    required String itemId,
    String? variantId,
    required double delta,
    double? lastPurchaseCost,
  }) async {
    // Queued synchronously, before any await, so a caller arriving mid-write
    // always lines up behind this one.
    final previous = _stockMutationTails[itemId] ?? Future<void>.value();
    final run = previous.then((_) => _applyStockDeltaInOrder(
          itemId: itemId,
          variantId: variantId,
          delta: delta,
          lastPurchaseCost: lastPurchaseCost,
        ));
    // ...
```

It persists through `_repository.updateItem(updated)` **before** swapping the in-memory copy (`item_store.dart:446-456`).

Manual stock adjustments, stock-take commit, the Low Stock "Add" button and the Edit Item stock field do **not** use it. They write a whole item snapshot through `itemStore.updateItem`, which is plan-gated and returns `false` silently, so a sale that lands while such a screen is open can be overwritten **(inferred)**.

---

## 8. What happens to the database during a sale?

Let's follow one illustrative dine-in order through every box it touches. Only writes confirmed by the code are listed.

### The example (*illustrative values*)

| Step | What the waiter does |
|---|---|
| 1 | Opens **Table T5** (`TableModel.id = "T5"`). The day (session) is already started. |
| 2 | Adds **1 × Margherita Pizza** (a Recipe-Based item) **with extra Cheese +₹40** → line price ₹240 + ₹40 = **₹280** |
| 3 | Adds **2 × Masala Dosa** at ₹120 (a Finished Good with `trackInventory = true`) → **₹240** |
| 4 | Places the order → **KOT 14** prints |
| 5 | Later adds **1 × Cold Coffee** ₹150 → **KOT 15** prints |
| 6 | Settles **₹670**: **₹400 cash + ₹270 UPI** |
| 7 | Kitchen marks everything **Served** |

Tax is left out to keep the arithmetic simple. Settings are defaults: "Auto Serve Dine In On Payment" off, "Generate KOT" on.

### Phase A: building the cart (`cart_box`)

| Step | What happens | Box written |
|---|---|---|
| A1 | Tap Pizza. Because it has extras, `ItemOptionsDialog` builds a `CartItem` whose `price` already includes the cheese (`tabbar/item_options_dialog.dart:222-252`) and whose `extras` holds `{name: Cheese, price: 40, quantity: 1, …}`. | – |
| A2 | `menu.dart:643` checks `DayManagementService.isEodStrictlyPending()` first. | (read `dayManagementBox`) |
| A3 | `restaurantCartStore.addToCart` → `CartRepository.addToCart` (`cart_repository.dart:23`): an **equal** line (same title, variant, price, choices, extras) is merged with `putAt(index)`; otherwise `_cartBox.add(item)`. | `cart_box` (new int key) |
| A4 | Tap Dosa twice. The second tap matches the first line and bumps `quantity` to 2. | `cart_box` (`putAt`) |

`cart_box` is a scratch pad. It is cleared after every place or settle.

### Phase B: Place Order → active order (`Takeaway._placeOrder`, `takeaway.dart:1370-1543`)

| # | Write | Box | Code |
|---|---|---|---|
| B1 | Gates: plan `billingInvoiceCreate`, bill-per-day cap, EOD pending, session open, stock check by **name** | (reads) | `takeaway.dart:1375-1429` |
| B2 | Customer: reuse or create if a phone was typed and customers are licensed | `customers` (only if needed) | `takeaway.dart:1450` |
| B3 | KOT number 14: `lastKotDate`, `lastKotNumber` | `appCounters` | `takeaway.dart:1458` |
| B4 | Daily order number: `lastOrderDate`, `lastOrderNumber` | `appCounters` | `takeaway.dart:1461` |
| B5 | Read `currentSessionId` | (read `dayManagementBox`) | `takeaway.dart:1464` |
| B6 | Save the `OrderModel` under its UUID | `orderBox` | `takeaway.dart:1500` |
| B7 | Print KOT 14 (no box write) | – | `takeaway.dart:1508` |
| B8 | Pizza: no stock of its own → each **recipe ingredient** goes down, one movement each with reason `Sale (recipe: Margherita Pizza)` | `itemBoxs`, `stockMovementsBox` | `inventory_service.dart:54-65,124-162` |
| B9 | Dosa: `stockQuantity` minus 2, one movement `Sale` | `itemBoxs`, `stockMovementsBox` | `inventory_service.dart:67-107` |
| B10 | Table T5 → `Running`, total, order id, time | `tablesBox` | `takeaway.dart:1525-1531` |
| B11 | Clear the cart | `cart_box` (all deleted) | `takeaway.dart:1534` |

The order that B6 saves:

`lib/presentation/screens/restaurant/start order/cart/takeaway.dart:1466-1498`

```dart
    final neworder = OrderModel(
      id: Uuid().v4(),
      // ...
      items: plainItems,
      status: 'Processing',
      timeStamp: DateTime.now(),
      orderType: widget.isDineIn ? 'Dine In' : 'Take Away',
      tableNo: widget.selectedTableNo ?? '',
      // ...
      kotNumbers: [newKotNumber],
      itemCountAtLastKot: plainItems.length,
      kotBoundaries: [plainItems.length], // First KOT boundary at item count
      kotStatuses: {newKotNumber: 'Processing'}, // Initialize first KOT status
      orderNumber: orderNumber, // Daily order number
      customerId: customer?.customerId, // Link to customer (now properly set)
      isTaxInclusive:
          AppSettings.isTaxInclusive, // Store tax mode at order creation
      sessionId: currentSessionId, // Link to POS session
    );
```

So after Phase B, *example*: `items = [Pizza×1, Dosa×2]`, `kotNumbers = [14]`, `kotBoundaries = [2]`, `totalPrice = 520`, no payment fields.

> **Stock drops at order placement, not at payment.** That is the opposite of retail, where stock moves at checkout.

> **The extra cheese is not stock-deducted.** `deductStockForOrder` never reads `cartItem.extras`; it deducts the item (or its recipe) by `quantity` only.

### Phase C: add Cold Coffee → second KOT (`Takeaway._updateExistingOrder`, `takeaway.dart:1585-1925`)

Tapping table T5 again opens the cart with the existing order (`table.dart:619-645`). The coffee goes into `cart_box` (as in Phase A). Pressing Place Order on an existing order:

| # | Write | Box | Code |
|---|---|---|---|
| C1 | Diff the active lines against the baseline (nothing removed here) | – | `takeaway.dart:1630-1675` |
| C2 | KOT number 15 | `appCounters` | `takeaway.dart:1703` |
| C3 | Append coffee to `items`, append `15` to `kotNumbers`, append boundary `3`, `kotStatuses[15] = 'Processing'`, `kotTimestamps[15] = now`, new `totalPrice` 670, recompute `paymentStatus` | `orderBox` (whole record rewritten) | `takeaway.dart:1701-1747` |
| C4 | Deduct coffee stock (or its recipe), movement rows | `itemBoxs`, `stockMovementsBox` | `takeaway.dart:1756-1757` |
| C5 | Broadcast `NEW_ITEMS_ADDED` to the KDS over WebSocket (no box write) | – | `takeaway.dart:1798-1848` |
| C6 | Print add-on KOT 15 | – | `takeaway.dart:1851-1863` |
| C7 | Table total updated | `tablesBox` | `takeaway.dart:1899-1907` |
| C8 | Clear the cart | `cart_box` | |

`lib/presentation/screens/restaurant/start order/cart/takeaway.dart:1702-1710`

```dart
    if (hasNewItems) {
      newAddedKotNumber = await orderStore.getNextKotNumber();
      updatedKotNumbers.add(newAddedKotNumber);
      updatedKotBoundaries.add(
        currentActiveItems.length + newlyAddedItems.length,
      );
      updatedKotStatuses[newAddedKotNumber] = 'Processing';
      updatedKotTimestamps[newAddedKotNumber] = DateTime.now();
    }
```

After Phase C, *example*: `items = [Pizza×1, Dosa×2, Coffee×1]`, `kotNumbers = [14, 15]`, `kotBoundaries = [2, 3]`, `totalPrice = 670`.

If the waiter had **reduced** a line that was already on a KOT, the same step would restore stock and write an `ItemCancellationModel` row to `restaurantItemCancellationsBox` (`takeaway.dart:1761-1795`) and print a "Cancel KOT" with a fresh KOT number that is **not** stored on the order.

### Phase D: settle ₹400 cash + ₹270 UPI (`Customerdetails.proceed`, `customerdetails.dart:1245-1441`)

The split-payment widget produces two legs. Each leg's `amount` is the money **moved** (`split_payment_widget.dart:63-75`). The order is dine-in and not yet served, and "Auto Serve" is off, so the order **stays active**:

| # | Write | Box | Code |
|---|---|---|---|
| D1 | Merge earlier payments (none) with these two legs; `totalPaid = 670`; `settledInFull = true` | – | `customerdetails.dart:1309-1323` |
| D2 | Mint bill number (e.g. 1287) | `appCounters` (`lastBillNumber`, `lastBillResetYear`) | `customerdetails.dart:1390` |
| D3 | Save the order with `paymentListJson = [{cash,400},{upi,270}]`, `isSplitPayment = true`, `paymentMethod = 'Split Payment'`, `paymentStatus = 'Paid'`, `isPaid = true`, `billNumber = 1287` | `orderBox` | `customerdetails.dart:1393-1394` |
| D4 | Clear the cart | `cart_box` | `customerdetails.dart:1395` |
| D5 | If a customer is attached: redeem points, then add visit + earned points | `customers` | `customerdetails.dart:1396-1404` |

`lib/presentation/screens/restaurant/start order/cart/customerdetails.dart:1389-1394`

```dart
        // Generate a bill number now so the receipt can show "Bill No" immediately
        final int billNumber = await orderStore.getNextBillNumber();

        // Store the bill number on the order so later prints use the same number
        final orderWithBill = completedOrder.copyWith(billNumber: billNumber);
        await orderStore.updateOrder(orderWithBill);
```

### Phase E: Served → past order (`activeorder.dart`)

| # | Write | Box | Code |
|---|---|---|---|
| E1 | Mark KOT 14 and KOT 15 `Served` (from the POS status dialog or the KDS). Overall status is derived from the KOT statuses. | `orderBox`, `tablesBox` (status mirrored) | `activeorder.dart:1304,1383,1458` or `kds_handler.dart:188-293` |
| E2 | All KOTs served **and** fully paid → `_moveOrderToPast`: reuse bill 1287, build `PastOrderModel` with the **same id**, all items, KOT fields and payment legs | `pastorderBox` | `activeorder.dart:1501-1533` |
| E3 | Delete the active order | `orderBox` | `activeorder.dart:1534` |
| E4 | Table T5 → `Available` | `tablesBox` | `activeorder.dart:1535-1537` |

`lib/presentation/screens/restaurant/tabbar/activeorder.dart:1499-1504`

```dart
    // Reuse the stored bill number if payment was recorded earlier (Dine In paid-but-not-served flow),
    // otherwise generate a fresh one now.
    final int billNumber =
        latestOrder.billNumber ?? await orderStore.getNextBillNumber();

    final pastOrder = PastOrderModel(
```

Note: this "served" path does not copy `customerId`, `shiftId`, `loyaltyPointsUsed` or `discountAppliedBy` onto the past order (`activeorder.dart:1504-1531`). A later refund therefore cannot restore redeemed points, and the shift report attributes the bill by time window.

### The other settle shape: take-away, already served, or Auto Serve on

If the order had been take-away, already `Served`, or "Auto Serve Dine In On Payment" were on, Phase D would call `completeOrder` and finish in one step. That is the only finaliser with a crash guard:

`lib/presentation/screens/restaurant/start order/cart/customerdetails.dart:1494-1501`

```dart
    // Idempotency guard: if this order is already in pastOrderBox (crash on previous
    // attempt between addOrder and deleteOrder), skip the write and just clean up.
    final alreadySettled = await pastOrderStore.getOrderById(activeModel.id);
    if (alreadySettled == null) {
      await pastOrderStore.addOrder(pastOrder);
    }
    // Always attempt delete — harmless if already deleted after a crash.
    await orderStore.deleteOrder(activeModel.id);
```

`completeOrder` always mints a **new** bill number (`customerdetails.dart:1450`), even if the order already had one.

### Summary: every box touched, in order (*example* order above)

`cart_box` → `customers` (optional) → `appCounters` (KOT, order no.) → `orderBox` (create) → `itemBoxs` + `stockMovementsBox` (pizza ingredients, dosa) → `tablesBox` → `cart_box` (clear) → `cart_box` (coffee) → `appCounters` (KOT 15) → `orderBox` (update) → `itemBoxs` + `stockMovementsBox` (coffee) → `tablesBox` → `cart_box` (clear) → `appCounters` (bill no.) → `orderBox` (payment) → `cart_box` (clear) → `customers` (optional) → `orderBox` + `tablesBox` (KOT statuses) → `pastorderBox` (create) → `orderBox` (delete) → `tablesBox` (Available).

### What is NOT touched during a normal sale

- **`cashMovementsBox`: nothing.** Expected cash is *derived* from the cash legs of **finished (past) orders** (`cash_drawer_screen.dart:157-275`, `eod_service.dart:221-239`). A paid dine-in order still in `orderBox` does not count toward the drawer until it moves to past.
- **No KOT box, no payment box, no sale-lines box.** They don't exist.
- **`restaurantItemCancellationsBox`** only when an already-KOT'd line is cancelled or reduced.
- **`restaurant_eodBox`** only at End of Day.
- **Printing** writes nothing except the counter it may burn.

### The crash-recovery net

Because there is no transaction, the app can die between "write past order" and "delete active order". On the next load, `OrderStore.loadOrders` deletes any active order whose id already exists in `pastorderBox`:

`lib/domain/store/restaurant/order_store.dart:240-251`

```dart
      // Reconcile crash-interrupted settlements: an order present in both
      // activeBox and pastOrderBox means the app died after addOrder but before
      // deleteOrder. Remove from active so it doesn't show as unpaid again.
      final List<OrderModel> clean = [];
      for (final order in loadedOrders) {
        final alreadySettled = await pastOrderStore.getOrderById(order.id);
        if (alreadySettled != null) {
          await _repository.deleteOrder(order.id);
        } else {
          clean.add(order);
        }
      }
```

This works **because the past order reuses the active order's id**. It does not free the table, redo stock or redo customer points; a table left occupied shows the "No Active Order" dialog with a Reset option (`table.dart:641-668`).

### Three lessons from this walk-through

1. **About twenty separate writes, no transaction.** Stock is deducted *after* the order is saved, and stock movements carry no order id, so a crash in between loses the deduction with no way to replay it **(inferred)**.
2. **Store actions swallow errors.** `pastOrderStore.addOrder` returns `false` on failure, and `completeOrder` / `_moveOrderToPast` then delete the active order anyway. A failed past-order write can lose the sale **(inferred)**. If you add a finaliser, check the result.
3. **The Captain and KDS write the same boxes.** A Captain "send order" runs the same stock deduction and table update, but skips the EOD-pending, session and bill-cap gates (`captain_handler.dart:250-277`), trusts the client's prices and totals, and stores an epoch-ms order id.

### VOID vs VOIDED

Deleting an active order never just deletes it. It writes a past record first (`activeorder.dart:156-190`):

`lib/presentation/screens/restaurant/tabbar/activeorder.dart:156-176`

```dart
      final bool wasPaid =
          order.isPaid == true ||
          (order.paymentStatus?.toLowerCase() == 'paid');
      // Save to past orders as VOID/VOIDED so it appears in the Void Order Report
      final voidRecord = PastOrderModel(
        id: order.id,
        // ...
        paymentmode: wasPaid ? (order.paymentMethod ?? 'N/A') : 'N/A',
        paymentListJson: wasPaid ? order.paymentListJson : null,
        // ...
        orderStatus: wasPaid ? 'VOIDED' : 'VOID',
```

- **`VOID`** = deleted before any payment. `paymentmode = 'N/A'`, no legs.
- **`VOIDED`** = money had been collected. Legs and `totalPaid` are kept so a refund can be issued later. A refund on a `VOIDED` order keeps it `VOIDED` (`refund_service.dart:73-74`).
- Stock is restored only for KOTs that were **not** `Served` (`activeorder.dart:192-221`).
- Always test with `OrderStatusFilter.isVoided` (`contains('VOID')`), never `== 'VOID'`.
- A **partly** paid order is treated as unpaid here (`wasPaid` ignores `totalPaid > 0`), so it becomes `VOID` / `N/A` and the collected money disappears from totals **(inferred)**.

---

## 9. How do inventory and reports get their data?

### Inventory: stock on the item, recipes cascade

| Item type (`productType`) | Where its stock lives | What a sale does |
|---|---|---|
| Finished Good (or `null`) | `Items.stockQuantity`, or `ItemVariante.stockQuantity` per size | Deducts its own stock if `trackInventory` |
| Raw Material | `Items.stockQuantity` | Deducted when used in a recipe, or when sold directly |
| Semi-Finished (prep, e.g. sauce) | `Items.stockQuantity` | Made by **production batches**; deducted as an ingredient |
| **Recipe-Based** (a dish) | **No stock.** Availability is computed live from ingredients (`InventoryService.effectiveAvailableStock`) | Each recipe ingredient is deducted |

A recipe is a `RecipeModel` in `restaurantRecipesBox`, found by the dish's item id:

`lib/data/repositories/restaurant/recipe_repository.dart:14-21`

```dart
  /// The recipe that produces [itemId], if any.
  RecipeModel? getRecipeForItem(String itemId) {
    try {
      return _box.values.firstWhere((r) => r.itemId == itemId);
    } catch (_) {
      return null;
    }
  }
```

Each embedded ingredient row is scaled for unit and wastage:

`lib/data/models/restaurant/db/recipe_ingredient_model.dart:63-64`

```dart
  double get effectiveQuantity =>
      quantity * conversionFactor * (1 + wastagePercent / 100);
```

and the whole recipe is scaled by how many portions were sold:

`lib/domain/services/restaurant/inventory_service.dart:221-233`

```dart
  static List<({String ingredientItemId, double quantity})> ingredientQuantitiesFor(
    RecipeModel recipe,
    double outputQty,
  ) {
    final yieldQty = recipe.yieldQty > 0 ? recipe.yieldQty : 1.0;
    final batches = outputQty / yieldQty;
    return [
      for (final line in recipe.ingredients)
        (
          ingredientItemId: line.ingredientItemId,
          quantity: batches * line.effectiveQuantity,
        ),
    ];
  }
```

*Example:* the pizza recipe yields 1 and lists "Mozzarella 80 g" with `conversionFactor 0.001` (stock in kg) and 5 % wastage. Selling 1 pizza deducts 1 × 80 × 0.001 × 1.05 = **0.084 kg** of mozzarella.

Things to know:

- The cascade is **one level deep**. A Semi-Finished ingredient is deducted from its own stock; it does not cascade into its own recipe.
- A Recipe-Based item with **no recipe** sells with no deduction at all (`inventory_service.dart:134`).
- A deleted ingredient is skipped silently (`:139-142`).
- Variants and weight are ignored for recipe dishes; the cart quantity is the portion count.

### `stockMovementsBox` is a diary, not the truth

Every stock change appends a `StockMovementModel` (`in`/`out`, quantity, `balanceAfter`, reason, `unitCost`). It is shared with retail. Stock is **not** recomputed from it; `Items.stockQuantity` wins.

| Event | Direction | Reason text | Where |
|---|---|---|---|
| Opening stock on a new item | in | `Opening stock` | `stock_adjust_service.dart:133-177` |
| Sale of a stocked item | out | `Sale` | `inventory_service.dart:95-107` |
| Sale of a recipe dish (per ingredient) | out | `Sale (recipe: X)` | `inventory_service.dart:148-160` |
| Production: ingredients / output | out / in | `Production (X)` / `Production batch` | `inventory_service.dart:380-527` |
| Void, item cancel, refund restock | in | `Void / Refund return` (or `… (recipe: X)`) | `inventory_service.dart:727-905` |
| GRN receive | in | `Purchase (PO-…)` | `restaurant_purchase_order_store.dart:370-383` |
| Manual adjust, stock take | in/out | dropdown reason, `Stock take`, `Stock correction` | `manage_Inventory.dart`, `stock_adjust_service.dart` |

GRN sets `Items.lastPurchaseCost` to the latest cost (last-cost, not an average). Purchase returns, supplier claims and loss records **do not** move stock.

> **Backup gap:** the restaurant backup does **not** export `stockMovementsBox` (nor `dayManagementBox`, `restaurantItemCancellationsBox`, `restaurantNotificationsBox`). After a restore, stock figures come back but Stock History, Ingredient Usage and Wastage are empty.

### Reports: recomputed from `pastorderBox`

- Sales reports (Total Sale, Sales by Item, Payment Mode, Refund, Void, Discount, Comparison, Customer by Revenue) call `pastOrderStore.loadPastOrders()` and add up the **embedded lines** every time. Nothing is pre-aggregated.
- **Grand total = stored `totalPrice`.** Reports use `totalPrice − refundAmount` and exclude statuses through `OrderStatusFilter` (`VOID`, `VOIDED`, `CANCELLED`, `FULLY_REFUNDED`). Never recompute a bill from its lines.
- **Active orders are not sales.** A dine-in order paid but not served is still in `orderBox` and is absent from reports until it moves to past.
- **Sales by Category** joins through the **live** item → category map (`salesbycategory.dart:146-150`), so re-categorising an item moves its history.
- **Item Cancellation** reads `restaurantItemCancellationsBox`. Captain cancels write no row, so they are missing from it.
- **Food Cost** (`recipe_report_service.dart`) is a live snapshot: recipe × each ingredient's current `lastPurchaseCost`. Its Ingredient Usage and Wastage tabs read `stockMovementsBox`.

### End of Day: per session, and stored

EOD belongs to a **session** (one Start Day → End Day), not to a calendar date. `EODService.generateEODReport` picks past orders by `sessionId`, falling back to calendar day only for legacy orders with no session:

`lib/domain/services/restaurant/eod_service.dart:53-65`

```dart
    // Filter orders by sessionId
    final allDayOrders = pastOrders.where((order) {
      if (targetSessionId != null) {
        if (order.sessionId == targetSessionId) return true;
        // Legacy fallback: null sessionId orders attributed by calendar day, not session timestamps.
        // ...
        if (order.sessionId == null) {
          if (order.orderAt == null) return false;
          final d = order.orderAt!;
          return d.year == date.year && d.month == date.month && d.day == date.day;
        }
        return false;
      }
```

- Before EOD can finish, **every** active order must be resolved by the manager: complete service, void (unpaid only), or refund (`endday.dart:711-724`).
- The report is saved once to `restaurant_eodBox`, replacing any earlier report for the same session (`eod_service.dart:402-417`). Daily Closing and POS End Day read these **stored** numbers; a refund made later does not change them.
- Then `endSession` closes the session and removes `currentSessionId` from `dayManagementBox` (`day_management_service.dart:109-125`).
- The Safe Drop and any shortage/overage adjustment are written **after** the session closes, so they carry `sessionId = null`.
- The restaurant EOD's per-rate tax table is always empty, because every writer stores `gstRate: 0` and the summary only runs for `gstRate > 0` (`eod_service.dart:367`).

| Report kind | Data source | Changes if old bills change? |
|---|---|---|
| Sales, items, payment mode, refunds, voids, discounts | `pastorderBox`, recomputed | Yes |
| Sales by Category | `pastorderBox` + **live** `itemBoxs` + `categories` | Yes, and with catalogue edits |
| Item Cancellation | `restaurantItemCancellationsBox` | – |
| Daily Closing, POS End Day | stored `EndOfDayReport` in `restaurant_eodBox` | **No** (frozen) |
| Stock history, wastage, ingredient usage | `stockMovementsBox` | – |
| Food Cost & Margin | live `itemBoxs` + `restaurantRecipesBox` | Changes with today's costs |
| Low stock | live `itemBoxs` | – (always current) |
| Purchase reports | PO / GRN / damaged-goods / ledger boxes | Yes |

---

## 10. How can I trace a feature from the UI to the database?

### The recipe

1. **Start at the screen.** Restaurant screens live in `lib/presentation/screens/restaurant/`. The big ones: `start order/cart/takeaway.dart` (cart, place, add-on, cancel, quick settle), `start order/cart/customerdetails.dart` (pay and settle), `tabbar/activeorder.dart` (KOT status, void, move to past), `tabbar/table.dart`, `end day/endday.dart`.
2. **Find the handler** behind the button (`onPressed` → `_placeOrder`, `proceed`, `_moveOrderToPast` …).
3. **Follow the store or service call.** Globals come from `lib/core/di/service_locator.dart`. Services are static classes (`InventoryService`, `DayManagementService`, `EODService`).
4. **Follow into the repository.** `lib/data/repositories/restaurant/` (and `common/` for shared boxes).
5. **Find the box.** In the repository, find `Hive.box<…>(…)`, look up the constant in `lib/core/constants/hive_box_names.dart` and the opener in `lib/core/init/hive_init.dart:764-848`.
6. **Find the model** in `lib/data/models/restaurant/db/`.
7. **Check the side door.** For anything touching orders, also look in `server/handlers/` and `data/models/restaurant/db/database/hive_order.dart`.

### Worked example: "Where does ingredient stock drop when I place an order?"

| Layer | File:line | What you see |
|---|---|---|
| Screen | `lib/presentation/screens/restaurant/start order/cart/takeaway.dart:1370` | `_placeOrder` runs when the order dialog's button is pressed |
| Screen | `takeaway.dart:1500` | `orderStore.addOrder(neworder)` saves the order **first** |
| Screen | `takeaway.dart:1520` | `InventoryService.deductStockForOrder(plainItems)` |
| Service | `lib/domain/services/restaurant/inventory_service.dart:36-49` | resolve the `Items` by `productId`, else by lowercase **name** |
| Service | `inventory_service.dart:54-65` | `if (item.isRecipeBased)` → `_deductRecipeIngredients(...)` |
| Repository | `lib/data/repositories/restaurant/recipe_repository.dart:15-21` | `getRecipeForItem(item.id)` scans `restaurantRecipesBox` |
| Service | `inventory_service.dart:221-233` | `ingredientQuantitiesFor` scales by yield and `effectiveQuantity` |
| Service | `inventory_service.dart:145-146` → `:533-535` | `_deductItemStock(ingredient, qty)` → `itemStore.applyStockDelta(delta: -qty)` |
| Store | `lib/domain/store/restaurant/item_store.dart:364-458` | per-item queue; `copyWith(stockQuantity: …)` |
| Repository | `lib/data/repositories/restaurant/item_repository.dart:56-67` | `updateItem` → `_itemBox.put(existingKey, item)` |
| Box | `lib/core/init/hive_init.dart:771` | `Hive.openBox<Items>(HiveBoxNames.restaurantItems)` → `'itemBoxs'` |
| Model | `lib/data/models/restaurant/db/itemmodel_302.dart:57-58` | `@HiveField(14) double stockQuantity;` |
| Diary | `inventory_service.dart:148-160,181-195` | `StockMovementModel` with reason `Sale (recipe: …)` → `stockMovementsBox` |

The service end of the chain:

`lib/domain/services/restaurant/inventory_service.dart:133-155`

```dart
    final RecipeModel? recipe = recipeRepository.getRecipeForItem(recipeItem.id);
    if (recipe == null || !recipe.hasIngredients) return; // unconfigured recipe — nothing to deduct

    for (final line in ingredientQuantitiesFor(recipe, saleQty)) {
      Items? ingredient;
      try {
        ingredient = items.firstWhere((i) => i.id == line.ingredientItemId);
      } catch (_) {
        continue; // ingredient item was deleted — skip rather than crash the sale
      }
      if (!ingredient.trackInventory) continue;

      final deductQty = line.quantity;
      final stockAfter = await _deductItemStock(ingredient, deductQty);

      await _logMovementAndAlert(
        // ...
        reason: 'Sale (recipe: ${recipeItem.name})',
```

**Other callers of the same deduction** (so the same chain also runs from): add-on items (`takeaway.dart:1755-1757`), settle with unplaced items (`customerdetails.dart:1278`), Settle & Print (`customerdetails.dart:1570`), Quick Settle (`takeaway.dart:3373`), KDS `POST /orders` (`order_handler.dart:51`) and Captain send-order (`captain_handler.dart:205,274`). The reverse chain is `restoreStockForOrder` / `restoreStockForRefund` (`inventory_service.dart:727-905`).

### Search tips

| You want to find… | Grep for |
|---|---|
| Who reads/writes a box | the **string** (`'itemBoxs'`, `'orderBox'`, `'pastorderBox'`, `'cart_box'`) **and** the constant (`HiveBoxNames.restaurantItems`) |
| Every place an order is finalised | `pastOrderStore.addOrder(` |
| Every place an active order is removed | `orderStore.deleteOrder(` and `HiveOrders.deleteOrder(` |
| Every KOT/bill number mint | `getNextKotNumber(` and `getNextBillNumber(` (two implementations each) |
| Every stock movement | `applyStockDelta(` and `saveMovement(` |
| Who changes KOT ranges | `kotBoundaries` |
| Void / refund status logic | `'VOIDED'`, `isVoided`, `OrderStatusFilter` |
| Writes from the Captain / KDS | `lib/server/handlers/` and `HiveOrders.` |
| Whether backup covers a box | the box name in `lib/domain/services/common/unified_backup_service.dart` (restaurant branch `:712-1056`, restore `:2169-2553`) |

### Cheat sheet: "If you want to change X, look at Y"

| If you want to change… | Look at |
|---|---|
| A field on a menu item | `lib/data/models/restaurant/db/itemmodel_302.dart` (then regenerate `.g.dart`; add to `toMap`/`fromMap`) |
| How items are saved / deduplicated | `lib/data/repositories/restaurant/item_repository.dart`, `lib/domain/store/restaurant/item_store.dart` |
| Add / Edit Item screens | `presentation/widget/componets/restaurant/bottom_sheets/add_item_sheet.dart`, `add_item_form_state.dart`, `presentation/screens/restaurant/manage menu/tab/edit_item.dart` |
| What a cart line stores (variants, extras, price) | `cartmodel_308.dart`, `tabbar/item_options_dialog.dart`, `cart_repository.dart` |
| What an order stores, KOT ranges | `ordermodel_309.dart`, `order_repository.dart`, `order_store.dart` |
| Place order / add-on KOT / item cancel | `start order/cart/takeaway.dart` (`_placeOrder`, `_updateExistingOrder`, `_cancelItemImmediately`) |
| Payment, split, settlement | `start order/cart/customerdetails.dart` (`proceed`, `completeOrder`), `widget/componets/common/split_payment_widget.dart` |
| What a finished bill stores | `pastordermodel_313.dart`, plus every writer: `customerdetails.dart`, `activeorder.dart`, `endday.dart`, `takeaway.dart` (Quick Settle) |
| Void / refund | `tabbar/activeorder.dart` (`_deleteOrder`), `domain/services/restaurant/refund_service.dart`, `tabbar/partial_refund_dialog.dart` |
| Tables | `table_Model_311.dart`, `table_repository.dart`, `table_store.dart`, `tabbar/table.dart` |
| Stock deduction, recipes, production | `domain/services/restaurant/inventory_service.dart`, `recipe_repository.dart`, `recipe_model.dart`, `recipe_ingredient_model.dart` |
| Manual stock, stock take, opening stock | `domain/services/restaurant/stock_adjust_service.dart`, `restaurant_stock_take_store.dart` |
| Purchasing / GRN | `domain/store/restaurant/restaurant_purchase_order_store.dart` (`confirmGRN`) |
| KOT / bill / order numbers | `order_repository.dart:71-136` (and the legacy `hive_order.dart:46-90`) |
| Start Day / sessions | `domain/services/restaurant/day_management_service.dart` |
| EOD | `presentation/screens/restaurant/end day/endday.dart`, `domain/services/restaurant/eod_service.dart` |
| Captain / KDS behaviour | `lib/server/server.dart`, `router.dart`, `handlers/*.dart`, `data/models/restaurant/db/database/hive_order.dart` |
| KOT and bill printing | `presentation/screens/restaurant/util/restaurant_print_helper.dart` |
| Reports | `presentation/screens/restaurant/Reports/`, `util/restaurant/order_status_filter.dart`, `domain/services/restaurant/recipe_report_service.dart` |
| Box names / typeIds | `lib/core/constants/hive_box_names.dart`, `hive_type_ids.dart` |
| Opening boxes, registering adapters | `lib/core/init/hive_init.dart:569-848` |
| Backup and restore | `lib/domain/services/common/unified_backup_service.dart` |

---

## Glossary

| Term | Meaning in this project |
|---|---|
| **Box** | A named Hive collection saved as one file, e.g. `itemBoxs`. Like a table. |
| **Typed / raw box** | `Box<OrderModel>` holds one model. A raw box (`appCounters`, `dayManagementBox`) holds plain key-value pairs. |
| **Record** | One object saved under one key. |
| **Key** | The value given to `box.put(key, …)`. Usually the record's id. Not so in `cart_box` (int keys) or for legacy generated items. |
| **Model** | A Dart class with `@HiveType` / `@HiveField`, e.g. `OrderModel`. |
| **typeId** | The unique class number. Restaurant uses 100-149 and 185+; next free is **186**. Restaurant file suffixes are typeId + 200. |
| **HiveField** | The numbered slot of one field. Never reuse a retired number (`CartItem` 2, `Category` 2). |
| **Adapter** | Generated `*.g.dart` code that turns an object into bytes and back. |
| **Repository / Store / Service** | Hive I/O / MobX observable state + `@action`s / multi-store helper. Same meaning as retail. |
| **Hydration** | A store copying a whole box into memory on first use (`ensureLoaded()`, `loadPastOrders()`). |
| **Embedded** | An object stored inside another record. Restaurant embeds order lines, item variants, recipe ingredients, choice options and toppings. |
| **Snapshot** | A frozen copy taken at event time, e.g. `CartItem.title`, `price`, `categoryName`; `PastOrderModel.storeGstNumber`, `roundOffStep`. Keeps old bills correct. |
| **Cart (`cart_box`)** | Scratch rows while building an order. Cleared after every place or settle. |
| **Active order** | An `OrderModel` in `orderBox`: the food is not yet finished and/or not yet paid. |
| **Past order** | A `PastOrderModel` in `pastorderBox`: a finished bill, void or refund record. The restaurant "sale". Never deleted by the app. |
| **KOT** | Kitchen Order Ticket: the slip for one batch of food sent to the kitchen. **Not a record**; a range of an order's `items`. |
| **`kotNumbers`** | The KOT numbers on an order, in issue order, e.g. `[14, 15]`. |
| **`kotBoundaries`** | Cumulative end index into `items` for each KOT, e.g. `[2, 3]`. Last value must equal `items.length`. |
| **`kotStatuses`** | Per-KOT kitchen status (`Processing`, `Cooking`, `Ready`, `Served`). The order's own `status` is derived from them. |
| **`itemCountAtLastKot`** | `items.length` when the last KOT was sent. Lines after it are "new, not yet sent". |
| **Add-on KOT** | A second or later KOT on the same order. |
| **Cancel KOT** | A printed correction slip. Its number is consumed from the counter but not stored on the order. |
| **Order number** | Daily counter shown to staff (`orderNumber`). Not set on every path. |
| **Bill number** | Plain int on the receipt (`billNumber`). Resets per financial year. |
| **VOID** | Past-order status for an order deleted before payment. `paymentmode = 'N/A'`. |
| **VOIDED** | Past-order status for an order deleted after money was collected. Payment kept; can be refunded. |
| **PARTIALLY_REFUNDED / FULLY_REFUNDED** | Refund statuses set in place on the past order by `RefundService`. `refundAmount` is cumulative and positive. |
| **Item cancellation** | An `ItemCancellationModel` audit row when an already-KOT'd line is cancelled or reduced on the POS. |
| **Table** | A `TableModel`; its id is its name. Orders point at it through `tableNo`. |
| **Session (day)** | One Start Day → End of Day period, a `RestaurantSessionModel` in `restaurantSessionsBox`. The open one is `dayManagementBox['currentSessionId']`. Orders, expenses and movements carry `sessionId`. |
| **Shift** | A staff member's working period, a `ShiftModel` in `shiftBox`. Independent of the session. Only past orders carry `shiftId`. |
| **EOD** | End of Day: resolves open orders, totals the session from past orders, saves an `EndOfDayReport` in `restaurant_eodBox`, closes the session. |
| **Expected cash** | Opening + cash legs of **finished** orders + cash in − cash out − cash expenses. Computed, never stored per sale. |
| **Safe drop** | Cash taken out of the drawer at EOD, written as an `out` cash movement after the session closes. |
| **Recipe** | A `RecipeModel` (bill of materials) linked to a dish or prep item by `itemId`. |
| **Ingredient** | A `RecipeIngredientModel` row inside a recipe: which item, how much, unit conversion, wastage. |
| **Recipe-Based item** | A dish with no stock of its own; selling it deducts its ingredients. |
| **Semi-Finished item** | A prep item (sauce, dough) with its own stock, made by a production batch. |
| **Production batch** | Turning ingredients into a Semi-Finished item; logged in `restaurantRecipeProductionsBox`. |
| **Stock movement** | A diary row in `stockMovementsBox`. Audit only; `stockQuantity` is the truth. |
| **`lastPurchaseCost`** | The latest GRN unit cost on an item; the only cost used for food costing. |
| **PO** | Purchase Order to a supplier (`restaurantPurchaseOrdersBox`). Does not move stock. |
| **GRN** | Goods Received Note (`restaurantGrnsBox`). Stock goes **up** here and the supplier balance is billed. |
| **Captain** | The separate waiter app that sends orders to the POS over the LAN (`/captain/*` on port 9090). |
| **KDS** | Kitchen Display System: reads KOTs and updates their status over the LAN (`/kds/*`). |
| **Local server** | The shelf server on `0.0.0.0:9090` inside the POS, plus a broadcast-only WebSocket `/ws`. It writes Hive. |
| **`HiveOrders`** | Legacy static helper that writes `orderBox` and `appCounters` directly; used by the Captain paths. |
| **appCounters** | Shared raw box holding every number sequence (KOT, order, bill, PO, GRN…). |
| **Backup** | Encrypted ZIP made by `unified_backup_service.dart`. Restaurant leaves out 4 boxes (see section 9). |

---

## Common beginner mistakes in this codebase

### 1. Looking for a KOT box, or editing `items` without the KOT fields

There is no KOT record. If you insert, remove or reorder `OrderModel.items`, you must update `kotBoundaries` (and drop a KOT whose range became empty), keep `kotNumbers.length == kotBoundaries.length`, and keep `kotBoundaries.last == items.length`. `OrderModel.getItemsByKot` (`ordermodel_309.dart:277-293`) will throw otherwise. New lines are **appended**, never inserted.

### 2. Reading sales from `orderBox`

`orderBox` holds unfinished orders. Sales, EOD, the cash drawer and every report read `pastorderBox`. A dine-in order that was paid but not served is **not** a sale yet. Conversely, don't look for a deleted active order: it is now a past record with the same id.

### 3. Comparing void status with `==`

Use `OrderStatusFilter.isVoided` / `isExcludedFromRevenue` (`util/restaurant/order_status_filter.dart`). `'VOID'` and `'VOIDED'` mean different things (unpaid vs paid), and a refund keeps `'VOIDED'`. Some screens still use their own string lists (`cash_drawer_history_screen.dart:265`, `shift_repository.dart:96`); don't copy them.

### 4. Recomputing a bill's total from its lines

The grand total is the stored `totalPrice`. `CartItem.price` already includes variant and extras, discounts and loyalty are applied at order level, inclusive-mode GST is inside the price, and the round-off amount is not stored. Use `totalPrice − refundAmount`.

### 5. Writing `orderBox` behind the store's back

The Captain paths use `HiveOrders.updateOrder` and the MobX list goes stale until `orderStore.loadOrders()` runs. If you add a new writer, go through `orderStore`, or make sure the POS reloads.

### 6. Assuming the id is always the key

`cart_box` is index-addressed (`putAt`/`deleteAt`). Generated items may sit under int keys, so `itemBox.delete(item.id)` can miss them, and a plain `put(item.id)` can duplicate them. Follow `ItemRepository.updateItem`'s "find every key with this id" pattern.

### 7. Ignoring a store's `bool` result

`orderStore.addOrder/updateOrder/deleteOrder`, `pastOrderStore.addOrder` and `itemStore.updateItem` return `false` on failure instead of throwing. Check it before you delete the source record or write the matching movement.

### 8. Moving stock without `applyStockDelta`

Only `ItemStore.applyStockDelta` serialises writes per item and preserves the embedded variant's `trackInventory`. A screen that writes a whole `Items` snapshot with a stock figure it read earlier can wipe out a sale that happened in between.

### 9. Matching by name

Stock lookups fall back to the item **title** (`inventory_service.dart:36-49`, `checkStockAvailability`), and variants are matched by **name**. Two items with the same name, or a renamed size, deduct the wrong stock. Prefer ids in any new code.

### 10. Adding a field to `OrderModel` but not to `toMap`/`fromMap`

`OrderModel.toMap` already drops `billNumber`, `sessionId`, `lastModifiedBy`, `lastModifiedAt` and `kotTimestamps` (`ordermodel_309.dart:306-396`), and backup uses `toMap`/`fromMap` for active orders. A restored open order loses its session and pre-assigned bill number. When you add a field, add it to both maps, and check both halves of the backup for any new box.

### 11. Field numbers, typeIds and `int` ↔ `double`

Same rules as retail ([retail mistakes 1 and 3](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md#common-beginner-mistakes-in-this-codebase)): never reuse a retired number, the filename suffix is not the typeId (restaurant is +200), and changing a field's numeric type is always breaking. Note `CartItem.quantity` is an `int` (`fields[4] as int`).

### 12. Forgetting the side door

Any rule you add at a POS entrance (EOD pending, session open, plan cap, price check) is skipped by `POST /orders` and `/captain/send-order` unless you also add it in `lib/server/handlers/`.

---

## Where to go next

| Document | Read it for |
|---|---|
| [01_RESTAURANT_DATABASE_OVERVIEW.md](01_RESTAURANT_DATABASE_OVERVIEW.md) | All 49 boxes, init order, storage outside Hive, the local server, backup coverage |
| [02_RESTAURANT_DATABASE_MODELS.md](02_RESTAURANT_DATABASE_MODELS.md) | Every restaurant model field by field: items, orders, past orders, recipes, purchasing, EOD |
| [03_RESTAURANT_DATABASE_FLOWS.md](03_RESTAURANT_DATABASE_FLOWS.md) | Step-by-step writes for menu, ordering, KOTs, settlement, void/refund, day management, Captain/KDS, deletes, crash windows |
| [04_RESTAURANT_DATABASE_RELATIONSHIPS.md](04_RESTAURANT_DATABASE_RELATIONSHIPS.md) | How every record points at every other one, embedded vs referenced vs snapshot |
| [../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md](../retail/05_RETAIL_DATABASE_LEARNING_GUIDE.md) | The generic concepts in more depth, and the retail sale for comparison |
| [../retail/01_RETAIL_DATABASE_OVERVIEW.md](../retail/01_RETAIL_DATABASE_OVERVIEW.md) … [04](../retail/04_RETAIL_DATABASE_RELATIONSHIPS.md) | The retail side of the shared boxes (`categories`, `customers`, `stockMovementsBox`, `appCounters` …) |

Suggested hands-on exercise: put breakpoints in `OrderRepository.addOrder` (`order_repository.dart:24`), `ItemStore.applyStockDelta` (`item_store.dart:365`), `OrderRepository.updateOrder` (`:49`) and `PastOrderRepository.addOrder` (`past_order_repository.dart:20`). Create a Recipe-Based dish with two tracked ingredients, then run the section 8 walk-through on a dine-in table: place it, add an item, settle with a split payment, and mark it served. Watch the KOT fields grow and the order move from `orderBox` to `pastorderBox`.
