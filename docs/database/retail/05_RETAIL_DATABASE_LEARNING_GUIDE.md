# Retail Database: A Learning Guide

> **Who this is for:** a Flutter developer joining Bill Berry Lite who has never worked with a database, or who knows SQL but not Hive.
> **What it covers:** ten beginner questions, each answered with real code from the **retail** side of this repo.
> **How to read citations:** `path:line` is relative to the repo root `D:\flutter\UniPOSs`. "(inferred)" means the conclusion comes from reading the code, not from running it. All of this is static analysis of branch `refactor/shared-code-consolidation`, read on 2026-10-19.
> **Illustrative values:** worked examples that use made-up products, prices or ids are labelled *example*. Field names, box names, file names and code are real.

---

## Contents

1. [What is a database?](#1-what-is-a-database)
2. [What is a record?](#2-what-is-a-record)
3. [What is a model?](#3-what-is-a-model)
4. [What is a database box?](#4-what-is-a-database-box)
5. [What is an ID?](#5-what-is-an-id)
6. [How are records connected?](#6-how-are-records-connected)
7. [How does the Retail app save and retrieve data?](#7-how-does-the-retail-app-save-and-retrieve-data)
8. [What happens to the database during a sale?](#8-what-happens-to-the-database-during-a-sale)
9. [How do inventory and reports get their data?](#9-how-do-inventory-and-reports-get-their-data)
10. [How can I trace a feature from the UI to the database?](#10-how-can-i-trace-a-feature-from-the-ui-to-the-database)
- [Glossary](#glossary)
- [Common beginner mistakes in this codebase](#common-beginner-mistakes-in-this-codebase)
- [Where to go next](#where-to-go-next)

---

## 1. What is a database?

A **database** is the place where an app keeps information after the app is closed. Variables in Dart live in memory and are gone when the process ends. A database writes the information to disk, so it is still there tomorrow.

Think of a shop's paper records: a product register, a bill book and a stock ledger. The database is the digital version of that cupboard of registers.

### Why this POS keeps its database on the device

Bill Berry Lite is an **offline-first** point of sale. A shop has to keep billing when the internet is down, so every product, sale and stock count lives on the device itself. In retail mode:

- The structured data is stored with **Hive**: `hive ^2.2.3` and `hive_flutter ^1.1.0` (`pubspec.yaml:42-43`). There is **no SQL or SQLite layer** in the project.
- Small settings (store name, tax mode, printer settings) live in **SharedPreferences**, and secrets such as the backup password and license token live in **flutter_secure_storage**.
- As far as the code shows, no sales, catalogue, customer or stock data is sent to a server **(inferred)**. The only network calls are licensing, OTP signup and push notifications.

Hive is started once at app launch:

`lib/main.dart` calls `HiveInit.init()` (`:128`), which runs `Hive.initFlutter()` (`lib/core/init/hive_init.dart:108`). Later in `_initializeApp`, `HiveInit.initializeBusinessBoxes()` (`main.dart:142`) opens the retail boxes when `AppConfig.isRetail` is true (`hive_init.dart:852-861`).

### Hive is key-value, not SQL

If you have seen SQL, forget tables, `JOIN`s and `SELECT … WHERE` for a moment. Hive works more like a **set of Dart `Map`s that are saved to disk**:

| SQL idea | Hive idea in this project |
|---|---|
| Table | **Box** (for example the `variants` box) |
| Row | **Record**: one Dart object stored under a key |
| Primary key | The **Hive key** you pass to `box.put(key, value)` |
| `SELECT * WHERE …` | Read `box.values` and filter it in Dart |
| Foreign key with constraints | A plain `String` id field. **Hive does not check it.** |
| Transaction across tables | **None.** Each `put` is saved on its own. |

The last two rows matter a lot. Sections 6 and 8 come back to them.

> **Security note:** no box is encrypted at rest. There is no `HiveAesCipher` anywhere in `lib/` (`hive_init.dart:108` opens Hive with no cipher). Backups *are* encrypted (see the glossary entry on backups).

---

## 2. What is a record?

A **record** is one saved "thing": one product, one sale, one stock movement. In Hive, a record is one Dart object stored under one key inside a box.

The most important retail record is a **variant**: one sellable version of a product, such as "T-Shirt, size L" or "Basmati Rice, loose". It is a `VarianteModel` object stored in the `variants` box. It is also **the only place retail keeps stock** (field `stockQty`).

### Worked example: one variant record

*Example values.* Field numbers, names and types are real (`lib/data/models/retail/hive_model/variante_model_201.dart`).

| HiveField | Field | Type | Example value |
|---|---|---|---|
| 0 | `varianteId` | `String` | `"3f6b1c2e-…-9a1d"` (a UUID; also the Hive key) |
| 1 | `productId` | `String` | `"a81c…-44f0"` (points at a `ProductModel`) |
| 5 | `sku` | `String?` | `null` |
| 6 | `barcode` | `String?` | `"BB0000000042"` |
| 7 | `mrp` | `double?` | `599.0` |
| 8 | `costPrice` | `double?` | `310.0` |
| 9 | `stockQty` | `double` | `24.0` |
| 10 | `minStock` | `double?` | `5.0` |
| 11 | `taxRate` | `double?` | `5.0` |
| 12 | `createdAt` | `String` (ISO) | `"2026-10-01T10:15:00.000"` |
| 14 | `customAttributes` | `Map<String,String>?` | `{"Size": "L"}` |
| 15 | `sellingPrice` | `double?` | `500.0` |
| 20 | `status` | `String` | `"active"` |
| 22 | `isDecimalQuantity` | `bool` | `false` |
| 23 | `unit` | `String?` | `null` (read as `'piece'`) |
| 24 | `expiryDate` | `String?` | `null` (does not expire) |

The same record as JSON-like text:

```text
variants box
  key "3f6b1c2e-…-9a1d"  →  VarianteModel {
      varianteId: "3f6b1c2e-…-9a1d",
      productId:  "a81c…-44f0",
      barcode:    "BB0000000042",
      sellingPrice: 500.0, mrp: 599.0, costPrice: 310.0,
      stockQty: 24.0, minStock: 5.0,
      customAttributes: {"Size": "L"},
      status: "active", isDecimalQuantity: false, ...
  }
```

Things worth noticing:

- The **key** (`"3f6b…"`) and the `varianteId` field hold the same value. That is a convention in this project, explained in section 5.
- `stockQty` is a `double`, so loose goods like 1.75 kg can be stocked (`variante_model_201.dart:27-31`).
- `status` works as a soft "hide" switch: only `'active'` variants are sellable (`lib/domain/store/retail/product_store.dart:29-30`).

---

## 3. What is a model?

A **model** is the Dart class that describes what a record looks like. Hive needs three extra things to save a model to disk:

1. **`@HiveType(typeId: …)`**: a unique number for the class. Hive writes it in front of every saved object so it knows which class to rebuild when reading.
2. **`@HiveField(n)`**: a unique number for each field. Hive stores field **numbers**, not field names.
3. **A generated adapter** (`*.g.dart`): code made by `build_runner` + `hive_generator` that converts the object to bytes and back.

Here is the real top of the variant model:

`lib/data/models/retail/hive_model/variante_model_201.dart:5-31`

```dart
part 'variante_model_201.g.dart';

@HiveType(typeId: HiveTypeIds.retailVariant)
class VarianteModel extends HiveObject {
  @HiveField(0)
  final String varianteId;

  @HiveField(1)
  final String productId;

  @HiveField(5)
  final String? sku;

  @HiveField(6)
  final String? barcode;
  // ...
  /// On-hand stock. `double` so loose goods can be stocked fractionally
  /// (10.5 kg); piece products simply hold whole values (20.0) and behave
  /// exactly as they did when this was an `int`.
  @HiveField(9)
  final double stockQty;
```

And here is the generated adapter reading those numbers back:

`lib/data/models/retail/hive_model/variante_model_201.g.dart:9-27`

```dart
class VarianteModelAdapter extends TypeAdapter<VarianteModel> {
  @override
  final int typeId = 151;

  @override
  VarianteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VarianteModel(
      varianteId: fields[0] as String,
      productId: fields[1] as String,
      sku: fields[5] as String?,
      barcode: fields[6] as String?,
      mrp: fields[7] as double?,
      costPrice: fields[8] as double?,
      stockQty: fields[9] as double,
      // ...
```

Read the adapter like this: "field 9 on disk becomes `stockQty`, and it **must** be a `double`".

### Why field numbers must never be reused

Notice that `VarianteModel` has fields 0, 1, then jumps to 5. Numbers **2, 3 and 4 are missing on purpose**. They used to hold the old `size` / `color` / `weight` columns. Old records on users' devices may still contain bytes under 2, 3 and 4.

If someone later adds `@HiveField(2) final double discount;`, Hive would read the **old size string** into a `double` and crash, or quietly load garbage. So the rule is:

- **Never reuse a retired field number.** Always take the next unused number (for `VarianteModel` the next free one is 25).
- **Never reuse a retired typeId** either. Retail has retired 156, 157, 158, 165, 167 and 172 (`lib/core/constants/hive_type_ids.dart:140-162`). `CartItemModel` also has retired field indices 4, 5 and 6.

### Adding a field safely

The project uses two patterns (no migration framework exists):

- **New nullable field:** old records read it as `null`. Example: `expiryDate` f24: "a new nullable field needs no `defaultValue` and no migration" (`variante_model_201.dart:107-111`).
- **New non-nullable field:** give it a `defaultValue` so old records don't crash. Example:

`lib/data/models/retail/hive_model/variante_model_201.dart:90-91`

```dart
  @HiveField(22, defaultValue: false)
  final bool isDecimalQuantity;
```

which the adapter turns into `isDecimalQuantity: fields[22] == null ? false : fields[22] as bool` (`variante_model_201.g.dart:39`).

### Gotcha: the filename number is NOT the typeId

`variante_model_201.dart` has typeId **151**, not 201. Every retail model file from `_200` to `_221` is off by 50:

| File | Real typeId |
|---|---|
| `product_model_200.dart` | 150 |
| `variante_model_201.dart` | 151 |
| `sale_model_203.dart` | 153 |
| `sale_item_model_204.dart` | 154 |
| `purchase_order_model_211.dart` | 161 |
| `grn_model_213.dart` | 163 |

The `_173` to `_181` files do match. Always trust `lib/core/constants/hive_type_ids.dart` and the `typeId` in the `.g.dart`, never the filename. The next free retail typeId is **200** (`hive_type_ids.dart:196-197`).

---

## 4. What is a database box?

A **box** is Hive's name for a named collection of records, saved as its own file on disk (for example `variants.hive`). Think of one box as one register in the shop cupboard: the "Variants" register, the "Sales" register and so on.

A box must be **opened** before it can be used. Retail opens its boxes in `HiveInit.openRetailBoxes()`:

`lib/core/init/hive_init.dart:487-492`

```dart
    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<CartItemModel>(HiveBoxNames.cartItems);
    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<SupplierModel>(HiveBoxNames.suppliers);
```

`Box<ProductModel>` is a **typed** box: it only holds `ProductModel` objects. In retail mode about **52 boxes** are open: 1 config box, 11 common boxes and 40 retail-phase boxes.

### The main retail boxes

| Box (string on disk) | Holds | What it is for |
|---|---|---|
| `products` | `ProductModel` | Catalogue entry: name, brand, category id, photo bytes. **No stock.** |
| `variants` | `VarianteModel` | Sellable SKU: price, barcode, **stockQty** |
| `sales` | `SaleModel` | Bill header: totals, payments, invoice number. Returns too. |
| `saleItems` | `SaleItemModel` | One row per line on a bill |
| `billingTabs` | `BillingTabModel` | Open POS tabs, each with its cart lines embedded |
| `cartItems` | `CartItemModel` | Cart lines; written but never read back by retail |
| `holdSales` / `holdSaleItems` | parked bills | "Hold" / "Park" a bill and resume it later |
| `customers` | `Customer` | Customers, credit balance, loyalty points |
| `credit_payments` | `CreditPaymentModel` | Credit collections, write-offs, return adjustments |
| `suppliers`, `supplierLedger` | supplier master + balance history | Purchasing |
| `purchaseOrders`, `purchaseOrderItems` | PO header + lines | Ordering stock |
| `grns`, `grnItems` | GRN header + lines | Receiving stock (stock goes **up** here) |
| `purchaseReturns`, `supplierClaims`, `inventoryLosses` (+ item boxes) | damaged-goods documents | |
| `stockTakes`, `stockTakeItems` | physical count sessions | |
| `bundles`, `kitAssemblies` | bundle recipes, kit builds | |
| `attributes`, `attribute_values`, `product_attributes` | Size/Color style attributes | |
| `categories`, `taxes`, `staffBox` | master data | |
| `eodBox` | `EndOfDayReport` | Saved End-of-Day totals |
| `expenseCategory`, `expenseBox` | expenses | Retail has no expense UI yet |

### Boxes shared with restaurant mode

Some data lives in **one physical box used by both modes**. They are the same file on disk, opened with the same name:

`customers`, `categories`, `staffBox`, `taxes`, `shiftBox`, `restaurantAttendanceBox`, `restaurantNotificationsBox`, `restaurantPrintersBox`, `paymentMethodsBox`, `dayManagementBox`, `restaurantSessionsBox`, `cashMovementsBox`, `stockMovementsBox`, `appCounters` (`lib/core/constants/hive_box_names.dart`).

Don't be fooled by the "restaurant" in some names. `stockMovementsBox` is the retail stock ledger too (`hive_init.dart:563`).

Three things are **separate per mode**: EOD (`eodBox` vs `restaurant_eodBox`), expense categories and expenses. Their repositories pick the box with `AppConfig.isRetail ? … : …` (for example `lib/data/repositories/restaurant/eod_repository.dart:11-13`).

### Raw (untyped) boxes

A few boxes are plain key-value maps with no model class:

| Box | Keys (examples) | Used by |
|---|---|---|
| `appCounters` | `lastBarcodeSequence`, `lastSkuSequence`, `lastCustomerSequence`, `INV_lastFy`, `INV_lastSeq`, `INV_prefix`, `CRN_…`, `PO_…`, `GRN_…` | Number generators (section 5) |
| `dayManagementBox` | `openingBalance`, `dayStarted`, `closingBalance`, `currentSessionId`, … | `DayManagementService` |
| `appConfigBox` | `businessMode`, `isSetupComplete`, `firstLaunchDate` | `AppConfig` |

You read them with a string key: `Hive.box(HiveBoxNames.appCounters).get('lastBarcodeSequence')`.

---

## 5. What is an ID?

An **ID** is a value that names exactly one record and never changes. Other records use it to point at that record.

### Rule of thumb: the id is also the Hive key

Almost every retail repository saves a record with **its own id field as the Hive key**:

`lib/data/repositories/retail/product_repository.dart:24-29`

```dart
  /// Add a new product to Hive
  Future<void> addProduct(ProductModel product) async {
    print('ProductRepository.addProduct: Saving product ${product.productName} with ID ${product.productId}');
    await _productBox.put(product.productId, product);
    print('ProductRepository.addProduct: _productBox now has ${_productBox.length} items');
  }
```

This gives fast lookups (`box.get(productId)`), and `put` with an existing key **replaces** the record. That is how an "update" works.

The exceptions are `paymentMethodsBox` (it uses `box.add`, so keys are auto-increment ints) and the singleton boxes such as `businessDetailsBox` (fixed key `'businessDetails'`).

### Kinds of ID in retail

| ID | Format | Where it is made | Is it a Hive key? |
|---|---|---|---|
| `productId`, `varianteId`, `saleItemId`, most others | UUID v4, e.g. `"3f6b1c2e-…"` | `Uuid().v4()` (e.g. `lib/presentation/screens/retail/add_product_screen.dart:850`) | Yes |
| `saleId` (forward sale) | UUID v4 | `checkout_screen.dart:649` | Yes |
| `saleId` (return) | `RTN_<uuid>` | `lib/domain/services/retail/return_service.dart:309` | Yes |
| `invoiceNumber` | `INV-00001` (sale), `CRN-00001` (return) | `DocumentNumberService` | **No**, display only |
| `customerId` (retail) | `CUST-000042` | `CustomerIdGeneratorService` | Yes |
| `barcode` | `BB` + 10 digits, e.g. `BB0000000042` | `BarcodeGeneratorService` | No (a field, kept unique by the repository) |
| PO / GRN / stock take numbers | `PO-00001`, `GRN-00001`, `ST-00001` | `DocumentNumberService` | No |
| `cartItemId` | `<variantId>_<millis>` | `cart_store.dart` | Yes (in `cartItems`) |
| Stock movement id for a sale | `sale_<saleId>_<cartItemId>` | `inventory_service.dart:46` | Yes |

### Why a sale has TWO identifiers

Look at the comment where checkout creates a sale:

`lib/presentation/screens/retail/checkout_screen.dart:645-650`

```dart
      // The key stays a UUID — sale lines, credit payments, returns and the
      // cash drawer all point at it. The invoice number is the customer-facing
      // label beside it, minted here at SUBMIT so an abandoned checkout never
      // burns a number out of the series.
      final saleId = const Uuid().v4();
      final invoiceNumber = await saleStore.nextInvoiceNumber();
```

- `saleId` (UUID) is for **the code**. It is unique forever, and every other record points at it.
- `invoiceNumber` (`INV-00001`) is for **humans and GST**. It **restarts at 00001 every financial year**, so it repeats across years and can never be a key.

The invoice number comes from `DocumentNumberService`, which keeps a counter per prefix in `appCounters`:

`lib/domain/services/common/document_number_service.dart:99-126`

```dart
  Future<int> _reserve(
    String prefix, {
    bool Function(String number)? isTaken,
  }) async {
    final fy = FiscalYearRule.currentKey;
    final label = displayPrefix(prefix);

    // A stored year that isn't this one means the year turned over — start
    // again at 1. ...
    final storedFy = _counters.get(_fyKey(prefix)) as String?;
    var seq = storedFy == fy
        ? (_counters.get(_seqKey(prefix), defaultValue: 0) as int)
        : 0;

    seq++;
    while (isTaken != null && isTaken(_format(label, seq))) {
      seq++;
    }

    await _counters.put(_fyKey(prefix), fy);
    await _counters.put(_seqKey(prefix), seq);
    return seq;
  }

  String _format(String prefix, int seq) =>
      '$prefix-${seq.toString().padLeft(sequenceWidth, '0')}';
```

So `INV-00042` means "the 42nd invoice of the current financial year". A shop can rename the printed prefix (for example to `BILL`) without restarting the series (`document_number_service.dart:55-61`).

### Barcodes and customer ids use the same "counter + skip if taken" idea

`lib/domain/services/retail/barcode_generator_service.dart:51-68`

```dart
    var seq = _counters.get(_sequenceKey, defaultValue: 0) as int;

    String candidate;
    var attempts = 0;
    do {
      seq++;
      attempts++;
      // ...
      candidate = format(seq);
    } while (isTaken(candidate));

    await _counters.put(_sequenceKey, seq);
    return candidate;
```

`lib/domain/services/retail/customer_id_generator_service.dart:27-44`

```dart
  Future<String> generate() async {
    var next = (_counters.get(_sequenceKey, defaultValue: 0) as int) + 1;
    var id = _format(next);

    // Belt-and-braces: if the counter ever lags the box (hand-edited data, a
    // partial restore), skip past anything already taken rather than
    // overwriting a real customer.
    while (_customers.containsKey(id)) {
      next++;
      id = _format(next);
    }

    await _counters.put(_sequenceKey, next);
    return id;
  }

  String _format(int sequence) =>
      '$_prefix-${sequence.toString().padLeft(6, '0')}';
```

The "skip if taken" loop matters because `put` with an existing key **silently overwrites**. Reusing an id would destroy a real customer.

---

## 6. How are records connected?

In SQL you would declare a **foreign key**, and the database would refuse a sale line that points at a missing product. **Hive has no foreign keys.** Records in this project connect in three ways, and none of them is enforced by the database.

### Way 1: id reference ("points at")

A record stores another record's id in a `String` field.

```text
ProductModel (products)            VarianteModel (variants)
  productId: "a81c…"   <─────────────  productId: "a81c…"
                                       varianteId: "3f6b…"

SaleModel (sales)                  SaleItemModel (saleItems)
  saleId: "e2d0…"      <─────────────  saleId: "e2d0…"
  customerId: "CUST-000042" ──┐        varianteId: "3f6b…"  ──> variants
                              └──────> Customer (customers)
```

Real examples: `VarianteModel.productId` (f1), `SaleItemModel.saleId` (f1), `SaleModel.customerId` (f1), `SaleModel.originalSaleId` (f12, on a return), `SaleModel.shiftId` (f33).

To "join" them, code filters in Dart. `ProductStore` builds a product → variants map once and MobX caches it:

`lib/domain/store/retail/product_store.dart:339-350`

```dart
  @computed
  Map<String, List<VarianteModel>> get variantsByProduct {
    final map = <String, List<VarianteModel>>{};
    for (final v in variants) {
      (map[v.productId] ??= <VarianteModel>[]).add(v);
    }
    return map;
  }

  /// Synchronous variant lookup — safe to call inside an `Observer`.
  List<VarianteModel> variantsFor(String productId) =>
      variantsByProduct[productId] ?? const <VarianteModel>[];
```

### Way 2: embedded (one record stored *inside* another)

Some objects are stored inside their parent, not in a box of their own:

- `BillingTabModel.items` holds a full list of `CartItemModel` (the open tab's cart lines).
- `RetailBundleModel` embeds its `BundleComponentModel` list (typeId 183, no box).
- `EndOfDayReport` embeds its payment, category and tax summaries (typeIds 118-121 and 124).
- `SaleModel.paymentListJson` (f18) stores the payment legs (cash, UPI…) as a JSON string inside the sale. The `paymentEntries` box exists but nothing writes to it.

### Way 3: snapshot (a frozen copy)

A **snapshot** copies a value at the moment something happens, so later changes don't rewrite history. This is the most important idea for a POS.

When a sale is saved, each line copies the product's name, price, barcode, HSN code, GST figures and **cost**:

`lib/presentation/screens/retail/checkout_screen.dart:514-531`

```dart
    return bill.lines.map((line) {
      final cartItem = line.item;
      return SaleItemModel.fromCalculated(
        saleId: saleId,
        varianteId: cartItem.variantId,
        productId: cartItem.productId,
        productName: cartItem.productName,
        attributes: cartItem.attributes,
        price: cartItem.price,
        qty: cartItem.qty,
        discountAmount: line.discountAmount,
        gstRate: line.gstRatePercent,
        taxableAmount: line.taxableAmount,
        gstAmount: line.gstAmount,
        total: line.total,
        barcode: cartItem.barcode,
        hsnCode: cartItem.hsnCode,
        costPrice: costByVariantId[cartItem.variantId],
```

So if the shopkeeper renames "T-Shirt" to "Cotton Tee" next month, or raises its price from ₹500 to ₹550, **last month's receipt still prints "T-Shirt ₹500"**, because the receipt reads the stored line, not the live variant. The comment above `_buildSaleItems` explains why cost is frozen: "Profit reports used to look up the variant's live `costPrice` instead, so a supplier price change re-wrote the profit on sales that had already been settled" (`checkout_screen.dart:498-500`).

Snapshots on `SaleModel` include every money field, `isTaxInclusive`, `taxEnabled`, `storeGstNumber`, `roundOff` and `invoiceNumber`.

### What "no foreign keys" means for you

- **Nothing stops a dangling reference.** Deleting a product leaves old `saleItems` pointing at a `productId` that no longer exists. That is fine for receipts (they use snapshots), but code that looks up the live product must handle `null`. For example, stock deduction simply skips a missing variant: `if (variant == null) continue;` (`lib/domain/services/retail/inventory_service.dart:71`).
- **Deletes do not cascade automatically.** Any cascade is hand-written. `ProductRepository.deleteProduct` deletes the product and then loops over its variants itself (`product_repository.dart:38-50`). Sales, POs and stock movements are left alone.
- There is one known join that rewrites history: the Category-wise report uses the **current** product → category mapping, because sale lines have no category snapshot.

---

## 7. How does the Retail app save and retrieve data?

Every feature follows the same four layers. A screen never talks to Hive directly (that is the project rule; there are a few legacy exceptions, such as EOD reading `cashMovementsBox` directly).

```text
 ┌─────────────────────┐  user taps "Save"
 │ Screen (widget)     │  e.g. add_product_screen.dart
 └─────────┬───────────┘
           │ calls an @action
 ┌─────────▼───────────┐
 │ MobX Store          │  e.g. ProductStore  (lib/domain/store/retail/)
 │  @observable lists  │  keeps an in-memory copy for the UI
 └─────────┬───────────┘
           │ calls a method
 ┌─────────▼───────────┐
 │ Repository          │  e.g. VariantRepository  (lib/data/repositories/retail/)
 │  only Hive I/O      │  box.put / box.get / box.delete
 └─────────┬───────────┘
           │
 ┌─────────▼───────────┐
 │ Hive box on disk    │  'variants'
 └─────────────────────┘
           ▲
           │ after the write, the store updates its ObservableList;
           │ every Observer() that read it rebuilds automatically
```

### Step 1: the repository does the disk work

The repository grabs the open box once and wraps every read and write:

`lib/data/repositories/retail/variant_repository.dart:28-38`

```dart
class VariantRepository {
  late Box<VarianteModel> _variantBox;

  VariantRepository() {
    _variantBox = Hive.box<VarianteModel>('variants');
  }

  /// Get all variants
  Future<List<VarianteModel>> getAllVariants() async {
    return _variantBox.values.toList();
  }
```

Repositories are also where data rules live. `addVariant` refuses a duplicate barcode and fills in a `BB…` barcode when it is blank, then saves with the id as key:

`lib/data/repositories/retail/variant_repository.dart:89-98`

```dart
  Future<VariantWriteResult> addVariant(VarianteModel variant) async {
    final guard = _guardBarcode(variant);
    if (!guard.success) return guard;

    final prepared = await _withGeneratedBarcodeIfBlank(
      _withNormalisedBarcode(variant),
    );
    await _variantBox.put(prepared.varianteId, prepared);
    return const VariantWriteResult.ok();
  }
```

### Step 2: the store holds observable state

A MobX **store** keeps an `ObservableList` copy of the box. When the store is first created, it **hydrates**, which means it copies the whole box into memory:

`lib/domain/store/retail/product_store.dart:39-61`

```dart
  @observable
  ObservableList<ProductModel> products = ObservableList<ProductModel>();

  /// Variants live in their own box — products and variants stay separate models.
  /// Holding them here lets screens read stock/price synchronously inside an
  /// `Observer`, without a `FutureBuilder` per card.
  @observable
  ObservableList<VarianteModel> variants = ObservableList<VarianteModel>();

  /// The constructor's hydration, kept so callers can await it.
  late final Future<void> _hydration;

  _ProductStore() {
    _productRepository = ProductRepository();
    _variantRepository = VariantRepository();
    _hydration = _init();
  }

  Future<void> _init() async {
    // Load data from repositories
    await loadProducts();
    await loadVariants();
  }
```

Retail stores are registered as **lazy singletons** in `lib/core/di/service_locator.dart`, so hydration happens the first time something reads `productStore`, not at app start. If you need the data in a one-shot job, `await productStore.ensureLoaded()` (`product_store.dart:71`).

An `@action` writes through the repository **first**, then updates the in-memory list:

`lib/domain/store/retail/product_store.dart:85-92`

```dart
  @action
  Future<void> addProduct(ProductModel product) async {
    // Save to database through repository
    await _productRepository.addProduct(product);

    // Update UI state
    products.add(product);
  }
```

### Step 3: the screen observes

Widgets that read an observable inside `Observer(builder: …)` rebuild by themselves when it changes. For example, the inventory list (`lib/presentation/screens/retail/inventory_screen.dart:649-651`):

```dart
      builder: (context, _) => Observer(
        builder: (context) {
          final rows = _visibleRows();
```

No `setState`, no manual refresh: write to the store, and the UI follows.

### Not everything goes through a store

Two shortcuts exist, and you should know about them:

- **Services** coordinate several stores. Example: `RetailInventoryService` (stock), `DocumentNumberService` (numbers), `ReturnService`.
- Some stores and services **write a box behind another store's back**. Example: `CreditStore` updates `sales` through its own `SaleRepository`, so `saleStore.sales` is stale until it reloads **(inferred)**. If a screen shows old data after a write elsewhere, this is the first thing to check.

---

## 8. What happens to the database during a sale?

Let's follow one illustrative sale through every box it touches.

### The example (*illustrative values*)

| | Item | Qty | Price | Line discount | Line total |
|---|---|---|---|---|---|
| 1 | T-Shirt (L), barcode `BB0000000042` | 1 | ₹500 | ₹50 | ₹450 |
| 2 | Basmati Rice (loose, `isDecimalQuantity = true`) | 2.5 kg | ₹60/kg | – | ₹150 |
| | **Grand total** | | | | **₹600** |

Payment is split: **₹300 cash + ₹300 UPI**. Customer `CUST-000042` is attached. (Tax-inclusive mode; the GST split is left out to keep the arithmetic simple.)

### Phase A: building the cart (POS screen)

| Step | What happens | Box written |
|---|---|---|
| A1 | Scan `BB0000000042`. `VariantRepository.findByBarcode` scans the box with trimmed comparison (`variant_repository.dart:200-207`). | (read `variants`) |
| A2 | `cartStore.addItemToTab(...)` builds a `CartItemModel` with id `<variantId>_<millis>` and price `priceOverride ?? sellingPrice ?? mrp ?? 0` (`lib/domain/store/retail/cart_store.dart:464-465`). | `cartItems` (put line) |
| A3 | The `*InTab` wrapper saves the whole active tab with its embedded lines (`cart_store.dart:1305-1318`). | `billingTabs` (put tab) |
| A4 | Add 2.5 kg of rice through the weight sheet. Same as A2-A3. | `cartItems`, `billingTabs` |
| A5 | Apply the ₹50 line discount (`setLineDiscountInTab`). | `cartItems`, `billingTabs` |

The **tab snapshot in `billingTabs` is the source of truth** for an open cart. `cartItems` is written but never read back by retail. If the app restarts, the cart comes back from `billingTabs` (`cart_store.dart:85-101`).

Here is the tab save:

`lib/domain/store/retail/cart_store.dart:1305-1318`

```dart
  Future<void> _saveCurrentTabItems() async {
    if (tabs.isEmpty || activeTabIndex >= tabs.length) return;

    final currentTab = tabs[activeTabIndex];
    final updatedTab = currentTab.copyWith(
      items: List<CartItemModel>.from(items),
      updatedAt: DateTime.now(),
    );

    await _repository.saveTab(updatedTab);

    // Update in observable list
    tabs[activeTabIndex] = updatedTab;
  }
```

### Phase B: checkout (`_processCheckout`, `checkout_screen.dart:632-736`)

The cashier enters ₹300 cash and ₹300 UPI and presses Pay. Writes happen in this exact order:

| # | Write | Box | Code |
|---|---|---|---|
| 1 | Mint `INV-00042` (*example*): bump `INV_lastSeq`, stamp `INV_lastFy` | `appCounters` | `checkout_screen.dart:650` → `document_number_service.dart:120-121` |
| 2 | Build `SaleModel` in memory: `paymentType = 'split'`, `paymentListJson = [{cash,300},{upi,300}]`, `status = 'paid'`, `shiftId` stamped | – (not saved yet) | `checkout_screen.dart:661-691` |
| 3 | Customer: redeem points (if any), add purchase total, loyalty points, visit count | `customers` | `checkout_screen.dart:694-710` |
| 4 | Save the sale header under key `saleId` | `sales` | `sale_store.dart:89` |
| 5 | Save 2 lines (T-shirt, rice), each with its own `saleItemId` | `saleItems` | `sale_store.dart:90` |
| 6 | T-shirt: `stockQty` 24 → 23 | `variants` | `inventory_service.dart:76-77` |
| 7 | T-shirt: movement `sale_<saleId>_<cartItemId>`, type `out`, reason `Sale` | `stockMovementsBox` | `inventory_service.dart:83-96` |
| 8 | Rice: `stockQty` e.g. 40.0 → 37.5 | `variants` | same |
| 9 | Rice: movement `out` / `Sale`, unit = the variant's unit (e.g. `kg`) | `stockMovementsBox` | same |
| 10 | Clear the cart: wipe the whole `cartItems` box, reset discounts, deselect the customer | `cartItems` | `cart_store.dart:1156-1163` |
| 11 | Save the active tab with an empty item list | `billingTabs` | `cart_store.dart:1475-1479` |

Steps 4-5 come from one store action:

`lib/domain/store/retail/sale_store.dart:87-94`

```dart
  @action
  Future<void> addSaleWithItems(SaleModel sale, List<SaleItemModel> items) async {
    await _saleRepository.addSale(sale);
    await _saleItemRepository.addSaleItems(items);

    sales.insert(0, sale);
    await loadSalesStats();
  }
```

Steps 6-9 are the stock decrement:

`lib/domain/services/retail/inventory_service.dart:69-96`

```dart
      if (lineKey != null && _movements.contains(lineKey)) continue;
      final variant = await productStore.getVariantById(item.variantId);
      if (variant == null) continue;

      // Never clamped: selling past zero (allow-when-out, or a race) leaves a
      // negative count, so the row reconciles and the shortfall stays visible
      // for the next stock take. Same as restaurant's applyStockDelta.
      final finalStock = variant.stockQty - item.qty;
      await productStore.updateVariantStock(item.variantId, finalStock);
      // ...
      await _movements.saveMovement(StockMovementModel(
        id: lineKey ?? const Uuid().v4(),
        timestamp: DateTime.now(),
        itemId: item.productId,
        variantId: item.variantId,
        itemName: label,
        type: 'out',
        quantity: item.qty.toDouble(),
        balanceAfter: finalStock.toDouble(),
        reason: 'Sale',
        // ...
      ));
```

### What is NOT touched during a normal sale

- **`cashMovementsBox`: nothing is written.** Expected cash in the drawer is *calculated later* from the sales' cash legs (`CashDrawerLedger`, `lib/util/retail/cash_drawer_ledger.dart`). Cash movements are only for manual Cash In/Out, Start Day, EOD, cash refunds and cash credit collections.
- **`paymentEntries`**: nothing, ever. Payments live inside the sale (`paymentListJson`).
- **`products`**: the product record is not changed. Stock lives only on variants.
- **Printing** a receipt reads the stored sale and lines; it writes nothing.

### Two lessons from this walk-through

1. **There is no transaction.** Eleven separate writes across seven boxes. If the app crashes between step 5 and step 6, the sale exists but stock was not reduced. The screen has an in-session retry, and the deterministic movement id `sale_<saleId>_<cartItemId>` makes the retry skip lines already done (`inventory_service.dart:34-37,69`). There is no recovery after a full process crash **(inferred)**.
2. **The customer is updated before the sale is saved** (step 3 before step 4). If step 4 fails, the customer's totals have already changed with no sale to explain them. Keep this in mind if you touch checkout.

If the bill had been **partly paid** (for example ₹500 of ₹600), the sale would store `dueAmount = 100` and `status = 'partially_paid'`, and step 3 would also add ₹100 to the customer's `creditBalance` (`checkout_screen.dart:701-703`).

---

## 9. How do inventory and reports get their data?

### Inventory: one number per variant, plus a diary

- **Current stock = `VarianteModel.stockQty`.** That is the only stock field in retail. Products have no stock; a product's total is added up from its variants (`ProductStore.totalStockFor`, `product_store.dart:354-355`).
- **Bundles have no stock of their own.** Selling a bundle reduces each component (`inventory_service.dart:57-66`). Kits and repacks are physical and hold their own `stockQty`.
- **`stockMovementsBox` is an audit log (a diary), not the source of truth.** Every stock change appends a `StockMovementModel` (`in`/`out`, quantity, `balanceAfter`, reason such as `Sale`, `Goods received`, `Return`, `Opening stock`, `Stock edited`). Stock is **not** recomputed by adding up movements. If the two ever disagree, `stockQty` wins.

All stock writes funnel through one store method, which is a good place to set a breakpoint:

`lib/domain/store/retail/product_store.dart:556-566`

```dart
  /// Update stock for a variant
  @action
  Future<void> updateVariantStock(String variantId, double newStock) async {
    await _variantRepository.updateStock(variantId, newStock);
    // Every retail stock movement lands here — keep alerts current.
    RetailNotificationSyncService.scheduleSync();
    // Re-read rather than rebuilding with copyWith — copyWith bumps `updateAt`
    // to now, which would drift the in-memory copy from what was persisted.
    final persisted = await _variantRepository.getVariantById(variantId);
    if (persisted != null) _upsertVariantInMemory(persisted);
  }
```

Who moves stock:

| Event | Direction | Movement reason | Where |
|---|---|---|---|
| New variant with opening stock | up | `Opening stock` | `product_store.dart:502-510` |
| Edit variant with a different stock figure | up/down | `Stock edited` | `product_store.dart:528-539` |
| Sale | down | `Sale` | `inventory_service.dart:38-98` |
| Sale return (resellable reason) | up | `Return` | `inventory_service.dart:208-240` |
| GRN (goods received) | up | `Goods received` | `grn_receiving_service.dart:163-180` |
| Stock adjustment / stock take | up/down | adjustment reason | `StockAdjustmentService` |
| Kit assembly | components down, kit up | `Assembly (…)` | `inventory_service.dart:329+` |

Purchase returns, supplier claims and inventory-loss records **do not** change stock.

### Reports: recomputed from sales every time

- Almost every sales, profit and GST report **reads every `SaleModel` and `SaleItemModel` and adds them up on each load**. Nothing is pre-aggregated or cached (`lib/domain/services/retail/report_service.dart:204-258`). Reports get slower as sales history grows.
- Because sale lines are snapshots, reports show what was actually charged, even after prices change.
- **Returns are their own `SaleModel`** with `isReturn = true`. Their **header** money fields are stored **negative**, and their **lines** stay **positive**. Summing headers nets returns out automatically. Line-level reports multiply by `RetailSaleFilter.revenueSign` (−1 for a return).
- Profit uses each line's frozen `costPrice`; a `null` cost means "unknown", not zero.

### End of Day: the one report that is stored

At EOD, `EODService.generateRetailEODReport` (`lib/domain/services/restaurant/eod_service.dart:436-666`) computes the day's totals once, and `saveEODReport` stores them as an `EndOfDayReport` in `eodBox`. EOD History then shows **the stored numbers as they were at close**. Editing or restoring sales later does not change an old EOD report, so it can differ from a live Daily Sales report for the same day.

| Report kind | Data source | Changes if old sales change? |
|---|---|---|
| Daily/Monthly/Product/Category/GST/Profit | `sales` + `saleItems`, recomputed | Yes |
| Low stock / Stock alerts | live `variants` | – (always current) |
| Stock adjustments | `stockMovementsBox` | – |
| Purchase reports | `purchaseOrders`, `grns`, `grnItems`, damaged-goods boxes | Yes |
| End of Day History | stored `EndOfDayReport` in `eodBox` | **No** (frozen) |

---

## 10. How can I trace a feature from the UI to the database?

### The recipe

1. **Start at the screen.** Find the widget you see. Search for a visible label: Grep `"Pay"` or `'Save Product'` in `lib/presentation/screens/retail/`.
2. **Find the handler.** Look at `onPressed` / `onTap` and jump to the method it calls (e.g. `_processCheckout`).
3. **Follow the store call.** Look for `someStore.someAction(...)`. Store instances are globals from `lib/core/di/service_locator.dart` (e.g. `productStore`, `saleStore`, `cartStore`). Open the matching file in `lib/domain/store/retail/`.
4. **Follow into the repository or service.** Inside the `@action`, find the `_xxxRepository.` call. Repositories are in `lib/data/repositories/retail/` (and `common/`, `restaurant/` for shared boxes). Services are in `lib/domain/services/retail/` and `common/`.
5. **Find the box.** In the repository constructor, find `Hive.box<…>('name')`. Then look up the name in `lib/core/constants/hive_box_names.dart` and the opening line in `lib/core/init/hive_init.dart`.
6. **Find the model.** The box's type parameter (`Box<VarianteModel>`) leads to the model in `lib/data/models/retail/hive_model/`.

### Worked example: "Where does stock drop when I sell?"

| Layer | File:line | What you see |
|---|---|---|
| Screen | `lib/presentation/screens/retail/checkout_screen.dart:632` | `_processCheckout()` runs when Pay is pressed |
| Screen | `checkout_screen.dart:714-720` | saves the sale, then calls `_finishCommittedSale()` |
| Screen | `checkout_screen.dart:559-562` | `RetailInventoryService.deductStockForSale(cartStore.items, saleId: …)` |
| Service | `lib/domain/services/retail/inventory_service.dart:76-77` | `finalStock = variant.stockQty - item.qty;` then `productStore.updateVariantStock(…)` |
| Store | `lib/domain/store/retail/product_store.dart:558-559` | `_variantRepository.updateStock(variantId, newStock)` |
| Repository | `lib/data/repositories/retail/variant_repository.dart:235-241` | `copyWith(stockQty: …)` then `_variantBox.put(variantId, …)` |
| Box | `lib/core/init/hive_init.dart:488` | `Hive.openBox<VarianteModel>(HiveBoxNames.variants)` |
| Model | `variante_model_201.dart:30-31` | `@HiveField(9) final double stockQty;` |

The repository end of the chain:

`lib/data/repositories/retail/variant_repository.dart:234-241`

```dart
  /// Update stock quantity
  Future<void> updateStock(String variantId, double newStockQty) async {
    final variant = _variantBox.get(variantId);
    if (variant != null) {
      final updatedVariant = variant.copyWith(stockQty: newStockQty);
      await _variantBox.put(variantId, updatedVariant);
    }
  }
```

### Search tips

| You want to find… | Grep for |
|---|---|
| Who reads/writes a box | `Hive.box<VarianteModel>` or the literal `'variants'`, and the constant `HiveBoxNames.variants` |
| Every place a field is changed | `copyWith(stockQty:` |
| All callers of a store action | `updateVariantStock(` |
| Where a model's typeId is defined | `retailVariant` in `lib/core/constants/hive_type_ids.dart` |
| Where a box is opened | the constant name in `lib/core/init/hive_init.dart` |
| Whether backup covers a box | the box or key name in `lib/domain/services/common/unified_backup_service.dart` |
| Who mints a document number | `DocumentNumberService` / `.next('` |

Tip: repositories often use the **string literal** (`'variants'`) rather than the constant, so search for both.

### Cheat sheet: "If you want to change X, look at Y"

| If you want to change… | Look at |
|---|---|
| A field on a product or variant | `lib/data/models/retail/hive_model/product_model_200.dart`, `variante_model_201.dart` (then regenerate the `.g.dart`) |
| How products/variants are saved, barcode rules | `lib/data/repositories/retail/product_repository.dart`, `variant_repository.dart` |
| Catalogue state shown on screens | `lib/domain/store/retail/product_store.dart` |
| Cart, tabs, discounts, tax mode | `lib/domain/store/retail/cart_store.dart`, `lib/domain/services/retail/retail_billing_service.dart` |
| What a sale stores | `lib/presentation/screens/retail/checkout_screen.dart` (`_processCheckout`, `_buildSaleItems`), `sale_model_203.dart`, `sale_item_model_204.dart` |
| Invoice / PO / GRN numbering | `lib/domain/services/common/document_number_service.dart` |
| Barcode or customer id format | `barcode_generator_service.dart`, `customer_id_generator_service.dart` (in `lib/domain/services/retail/`) |
| Stock deduction, restock, bundles, kits | `lib/domain/services/retail/inventory_service.dart` |
| Returns and exchanges | `return_service.dart`, `exchange_service.dart` (in `lib/domain/services/retail/`) |
| Receiving goods (GRN) | `lib/domain/services/retail/grn_receiving_service.dart` |
| Customer credit collection | `credit_store.dart` |
| Start Day / sessions | `lib/domain/services/restaurant/day_management_service.dart` |
| EOD | `lib/presentation/screens/retail/eod_screen.dart`, `lib/domain/services/restaurant/eod_service.dart` |
| Reports | `lib/domain/services/retail/report_service.dart` |
| Box names / typeIds | `lib/core/constants/hive_box_names.dart`, `hive_type_ids.dart` |
| Opening boxes, registering adapters | `lib/core/init/hive_init.dart` |
| Backup and restore | `lib/domain/services/common/unified_backup_service.dart` |
| Which store/repo is registered | `lib/core/di/service_locator.dart` |

---

## Glossary

| Term | Meaning in this project |
|---|---|
| **Box** | A named Hive collection saved as one file, e.g. `variants`. Like a table. Opened in `hive_init.dart`. |
| **Typed / raw box** | `Box<ProductModel>` holds only that model. A raw `Box` (e.g. `appCounters`) holds plain key-value pairs. |
| **Record** | One object saved under one key in a box. |
| **Key** | The value passed to `box.put(key, …)`. In retail it is usually the record's own id. |
| **Model** | A Dart class with `@HiveType` and `@HiveField` annotations, e.g. `VarianteModel`. |
| **typeId** | The unique number of a model class (`@HiveType(typeId: …)`). Listed in `hive_type_ids.dart`. Never reuse one. |
| **HiveField** | The numbered slot for one field (`@HiveField(9)`). Hive stores numbers, not names. Never reuse one. |
| **defaultValue** | `@HiveField(n, defaultValue: x)`: what old records read when the field is missing. Needed for new non-nullable fields. |
| **Adapter** | Generated code (`*.g.dart`) that turns an object into bytes and back. Registered in `hive_init.dart`. |
| **Repository** | A class that does Hive I/O for one area, e.g. `VariantRepository`. No UI state. |
| **Store** | A MobX class holding observable state and `@action` methods, e.g. `ProductStore`. Screens talk to stores. |
| **Service** | A helper that coordinates several stores or repos, e.g. `RetailInventoryService`. |
| **Observable** | A MobX value (`@observable`, `ObservableList`) that UI can watch. |
| **@action** | A MobX method allowed to change observables. |
| **@computed** | A value derived from observables and cached until they change, e.g. `variantsByProduct`. |
| **Observer** | A widget that rebuilds when the observables it read change. |
| **Hydration** | Copying a whole box into a store's `ObservableList` on first use. |
| **Lazy singleton** | A store created once, the first time it is used (GetIt `registerLazySingleton`). |
| **Id reference** | A `String` field holding another record's id, e.g. `SaleItemModel.saleId`. Not enforced by Hive. |
| **Embedded** | An object stored inside another record, e.g. cart lines inside `BillingTabModel`. |
| **Snapshot** | A frozen copy of a value at event time, e.g. `SaleItemModel.productName`, `costPrice`. Keeps history correct. |
| **UUID** | A random unique id like `3f6b1c2e-…`. Made with `Uuid().v4()`. |
| **FY numbering** | Document numbers like `INV-00001` that restart each financial year (`FiscalYearRule.currentKey`). Display only. |
| **appCounters** | Shared raw box holding every number sequence (invoice, barcode, customer, PO…). |
| **Invoice / credit note** | A sale's display number `INV-xxxxx`. A return's is `CRN-xxxxx`. |
| **Return** | A separate `SaleModel` with `isReturn = true`, negative header totals and positive lines. Retail has no "void". |
| **PO** | Purchase Order: what the shop orders from a supplier (`purchaseOrders`). Does not change stock. |
| **GRN** | Goods Received Note: what actually arrived (`grns`). This is where purchased stock goes **up**. |
| **Stock movement** | A diary row in `stockMovementsBox` for each stock change. Audit only; `stockQty` is the truth. |
| **Bundle / kit / repack** | Bundle = virtual, sold from components. Kit/repack = physical, holds its own stock. Set by `ProductModel.stockMode`. |
| **Session (day)** | One Start Day → EOD period, a `RestaurantSessionModel` in `restaurantSessionsBox`. The open one is `dayManagementBox['currentSessionId']`. |
| **Shift** | A staff member's working period, a `ShiftModel` in `shiftBox`. Sales store `shiftId`. |
| **EOD** | End of Day: closes the session, counts cash, saves an `EndOfDayReport` in `eodBox`. |
| **Cash movement** | A drawer entry (opening, in, out, adjustment, refund) in `cashMovementsBox`. Sales do **not** write one. |
| **Backup** | An encrypted ZIP of every box, made and restored by `unified_backup_service.dart`. |

---

## Common beginner mistakes in this codebase

### 1. Reusing a field number or typeId

Deleting a field and then giving its number to a new field corrupts every existing record. `VarianteModel` skips 2-4; `CartItemModel` skips 4-6; typeIds 156-158, 165, 167 and 172 are retired. **Always add the next unused number**, and remember the filename suffix is not the typeId (section 3).

### 2. Writing to Hive directly from a screen

```dart
// Don't do this in a widget:
Hive.box<VarianteModel>('variants').put(v.varianteId, v);
```

It skips the repository's rules (barcode uniqueness, normalisation), skips the stock movement log, and leaves `productStore.variants` stale, so the UI won't update. Go through the store: `productStore.updateVariant(v)`. If you need something new, add a repository method and a store `@action`.

### 3. Thinking an `int` ↔ `double` change is safe

Hive stores the runtime type. The adapter does a hard cast: `stockQty: fields[9] as double` (`variante_model_201.g.dart:26`). An old record that saved `stockQty` as an `int` would throw on that cast. The project rule is that **changing a field's numeric type is always breaking**; the JSON backup is the escape hatch. If you must change a type, add a new field number instead.

### 4. Assuming deletes cascade

Hive deletes exactly one key. Nothing else is cleaned up unless someone wrote the code:

- `ProductRepository.deleteProduct` removes the product **and** loops over its variants (`product_repository.dart:38-50`), but leaves sales, PO/GRN lines and movements pointing at it.
- `SaleStore.deleteSale` would delete only the header, not its `saleItems` (it has no callers today).
- Deleting a tax leaves `product.taxId` / `variant.taxId` pointing at nothing.

Before you add a delete, list every box that stores that id, and decide for each: block, cascade, or leave as a snapshot.

### 5. Forgetting backup symmetry

`unified_backup_service.dart` exports and restores each box **by name, one by one**. A new box is **not** backed up until you add it to both the export and the restore. Some current gaps to learn from:

- `restaurantSessionsBox` is opened in retail but left out of the retail backup.
- Several boxes are restored with `box.add()` (auto-int keys) while their repositories look records up by string id (e.g. `holdSales`, `eodBox`, `credit_payments`, `billingTabs`). After a restore, update/delete by id can miss.
- `SaleModel.toMap()` writes the payment legs under `'paymentList'` but `fromMap()` reads `'paymentListJson'`, so split payments don't survive a backup round-trip.

Rule: if you add a box or a field, check `toMap`/`fromMap` and both halves of the backup, and restore with `put(id, …)`.

### 6. Expecting "all or nothing"

Hive has no transaction across boxes. A sale is about eleven separate writes (section 8). When you add a step to a multi-box flow, think about what the data looks like if the app dies right after your step, and prefer deterministic ids so a retry can skip what is already done.

### 7. Reading a store before it has loaded

Stores hydrate asynchronously. Code that runs once (not inside an `Observer`) and reads `productStore.products` right away may see an empty list. Use `await productStore.ensureLoaded()`.

---

## Where to go next

| Document | Read it for |
|---|---|
| [01_RETAIL_DATABASE_OVERVIEW.md](01_RETAIL_DATABASE_OVERVIEW.md) | The full box inventory, init order, storage outside Hive, backup format |
| [02_RETAIL_DATABASE_MODELS.md](02_RETAIL_DATABASE_MODELS.md) | Every model field by field, with typeIds, defaults and id schemes |
| [03_RETAIL_DATABASE_FLOWS.md](03_RETAIL_DATABASE_FLOWS.md) | Step-by-step writes for products, billing, returns, purchasing, EOD and deletes |
| [04_RETAIL_DATABASE_RELATIONSHIPS.md](04_RETAIL_DATABASE_RELATIONSHIPS.md) | How every record points at every other one, snapshots vs live references |

Suggested hands-on exercise: put breakpoints in `ProductStore.updateVariantStock` (`product_store.dart:558`) and `SaleStore.addSaleWithItems` (`sale_store.dart:88`), make a two-item sale in retail mode, and watch the order of writes from section 8 happen.
