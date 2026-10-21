# Restaurant Database Models (Hive)

> Bill Berry Lite, **restaurant mode**. Branch `refactor/shared-code-consolidation`, checked on 2026-10-19.
> This is a static reading of the code. Nothing was run.
> Every statement is confirmed from code at the cited `path:line` unless it is marked **(inferred)** (a conclusion drawn from code) or **(unverified)** (not checked).
> Paths are relative to `D:\flutter\UniPOSs\`. When a path starts with `.../`, it means `lib/data/models/restaurant/db/`.
> Companion document for the retail side: [Retail Database Models](../retail/02_RETAIL_DATABASE_MODELS.md). Shared models are described here again with their full field tables, but the narrative focuses on how **restaurant** uses them.

---

## How to read this document

### What a "Hive model" is in this project

Hive is the only database the app uses. There is no SQL. Each kind of record is a Dart class that looks like this:

```dart
@HiveType(typeId: HiveTypeIds.restaurantItem)   // 102: a number that identifies the CLASS on disk
class Items extends HiveObject {                 // HiveObject lets you call .save() / .delete() on it
  @HiveField(0) final String id;                 // 0: a number that identifies the FIELD on disk
  @HiveField(1) final String name;
  ...
}
part 'itemmodel_302.g.dart';                     // generated adapter (build_runner) that reads/writes bytes
```

- **`typeId`** is written into every stored record. When Hive reads the bytes, it uses the typeId to choose the adapter (the class). All typeIds are constants in `lib/core/constants/hive_type_ids.dart`.
- **`@HiveField(n)`** gives each field a number. Hive stores `n → value`, not the field name. You can rename a Dart field safely, but you must never change its number.
- **The generated adapter** (`*.g.dart`) is the ground truth. Its `read()` method shows exactly what happens when a field is missing from an old record.
- **A box** is one file on disk (`<name>.hive`) that holds records of one type. Box names are constants in `lib/core/constants/hive_box_names.dart`. Restaurant adapters are registered in `registerRestaurantAdapters()` (`lib/core/init/hive_init.dart:569-761`) and restaurant boxes are opened in `openRestaurantBoxes()` (`:764-848`). Common boxes used by both modes are opened in `openCommonBoxes()` (`:164-203`).
- **The Hive key** is the key you pass to `box.put(key, value)`. In restaurant it is usually the record's own string id. When code uses `box.add(value)`, Hive assigns an auto-increment **int** key instead. The restaurant cart (`cart_box`), `PaymentMethod` and every box that backup restores with `addAll`/`add` (extras, EOD reports, the three settings singletons) end up with int keys. Mixing the two kinds of key is the source of several bugs (see "Serialization & schema evolution").
- Restaurant opens **49 boxes**: 1 `appConfigBox` + 11 common + 37 restaurant-phase (36 typed + 1 raw `dayManagementBox`). None is lazy and none is encrypted (`hive_init.dart:164-203, 764-848`; no `HiveAesCipher` anywhere in `lib/`).

### The rules you must follow

| Rule | Why |
|---|---|
| **Never reuse a typeId.** Retired shared id: **101** (old `Company`, `hive_type_ids.dart:55-58`). **123** (`TestBillItem`) is declared but never registered; treat it as reserved. The restaurant range 100-149 is full; the restaurant overflow range is 185-199 and the **next free restaurant id is 186** (`hive_type_ids.dart:3-32, 199-206`). | Old records on a device still carry the old id. Hive would decode them with the wrong class. |
| **Never reuse a field index.** Retired indices in restaurant/common models: `CartItem` **2** (`cartmodel_308.dart:11-14`, no comment) and `Category` **2** ("was imagePath — removed", `categorymodel_300.dart:13`). `TaxDetails` 7 is retired too (see the retail doc). No class has a duplicate index. | An old record still has bytes under that index. A new field with the same index would read garbage. |
| **Hive `defaultValue` vs constructor default.** `@HiveField(23, defaultValue: false)` is used when an OLD record has no field 23. A constructor default (`this.isEnabled = true`) is **not** used when Hive reads; the adapter calls the constructor with `fields[n] as T`, so a missing field becomes `null` and a non-nullable cast throws. | A non-nullable field added later **without** `defaultValue` makes old records throw on read. Add new fields as nullable, or give them `defaultValue`. |
| **The filename suffix is not the typeId.** `itemmodel_302.dart` is **102**, `table_Model_311.dart` is **111**, `testbillmodel_318.dart` is **122**, `eodmodel_317.dart` is **117**. Only a few match (`customer_model_125.dart` = 125, `item_cancellation_model_134.dart` = 134). | Always look up `HiveTypeIds`, not the filename. |
| **int ↔ double is always a breaking change** in Hive. | `CartItem.quantity` is `int`; making it `double` would break every stored cart line and every embedded order line. |
| **Only these fields have a Hive `defaultValue`** in the models below: `Items` f23, f24; `EndOfDayReport` f28; `RecipeModel` f9; `RecipeIngredientModel` f3, f5; `RestaurantSupplierModel` f8; `RestaurantSupplierLedgerEntryModel` f13; `Customer` f15-f19; `BusinessDetails` f14, f17, f18 (grep of `HiveField(n, defaultValue` across `lib/`). Every other field has none. | Use this list when you reason about old data. |
| **Late non-nullable fields without a default** exist: `Items.isSoldByWeight` f16 and `editCount` f20 (`itemmodel_302.g.dart:28,40`), `Category.editCount` f6, `OrderModel.itemCountAtLastKot` f22 (`ordermodel_309.g.dart:42`), `CartItem.productId` f15 (`cartmodel_308.g.dart:23`). | A record written before such a field existed throws on read **(inferred)**. Accepted because the app is pre-release and local data may be wiped. |

### Columns used in every field table

| Column | Meaning |
|---|---|
| **#** | The `@HiveField` index |
| **Req?** | `req` = non-nullable Dart type (must be present). `opt` = nullable (`T?`) |
| **Hive default** | `defaultValue:` in the annotation, or `–` if none |
| **Ctor default** | The constructor's default. Remember: it is NOT applied on read |

### Domain conventions you must know before reading the models

| Convention | Where it is defined |
|---|---|
| **One `Items` model is everything on the menu and in the store room**: finished dishes, raw materials, semi-finished prep and recipe-based dishes. `Items.productType` (a String: `rawMaterial`, `semiFinished`, `finishedGood`, `recipeBased`; null = `finishedGood`) decides the behaviour. `ProductType` is a constants class, not a Hive type. | `itemmodel_302.dart` f28; `product_type.dart:7-96` |
| **Stock lives on `Items.stockQuantity` and/or on the embedded `ItemVariante.stockQuantity`.** A variant item keeps item-level stock at 0 and tracks per-variant stock; the **item's** `trackInventory` governs (the variant flag is ignored). A Recipe-Based item has no own stock (forced `trackInventory=false`, `stockQuantity=0`); its availability is derived from its ingredients. | `itemmodel_302.dart:186-191`; `product_type.dart:73-85` |
| **The tax rate is cached on the item as a DECIMAL sum.** `Tax.taxperecentage` is a percent (5); `Items.taxRate` is the sum of the applied taxes as a fraction (0.05 + 0.12 = 0.17). Billing reads only `Items.taxRate`, copied onto `CartItem.taxRate`. `Items.taxIds` is read only by Edit Item. | `itemmodel_302.dart:47-48,242-266`; `menu.dart:735`; `item_options_dialog.dart:368` |
| **Order lines are embedded snapshots.** `OrderModel.items` and `PastOrderModel.items` are `List<CartItem>` copied from the cart. Names, prices, variant, extras, category and tax rate are frozen in the line. Never re-price a past order from the menu. | `ordermodel_309.dart` f4; `pastordermodel_313.dart` f3 |
| **There is no KOT model.** A KOT is encoded on the order: `kotNumbers` (numbers in issue order), `kotBoundaries` (cumulative exclusive end index into `items`), `kotStatuses` (per-KOT status) and `kotTimestamps` (add-on KOT times). `getItemsByKot()` slices the line list. | `ordermodel_309.dart:75-123, 277-293` |
| **Grand Total = the stored `totalPrice`** on `OrderModel`/`PastOrderModel` (restaurant's name for retail's `totalAmount`). Every writer stores `CartCalculationService.grandTotal` (taxable + GST + service charge, rounded). Net sales = `totalPrice − refundAmount`. Never recompute the total from the lines, especially in tax-inclusive mode. | `cart_calculation_service.dart:396-408`; `eod_service.dart:106-112` |
| **`subTotal` = taxable base after discount and loyalty, before GST**, in both tax modes. Loyalty points reduce the taxable base before GST. | `cart_calculation_service.dart:117-119, 343-384` |
| **`VOID` vs `VOIDED` vs `CANCELLED`.** `VOID` = an order removed before any money was taken (`paymentmode 'N/A'`, no legs). `VOIDED` = money had been collected; legs and `totalPaid` are kept so a refund can follow. `CANCELLED` is read by filters but **never written**. Always test with `OrderStatusFilter.isVoided` (`contains('VOID')`). | `activeorder.dart:166-176`; `refund_service.dart:73-74, 214-219`; `util/restaurant/order_status_filter.dart` |
| **A payment leg's `amount` = money actually moved** (`settledAmount`). `totalPaid` = money TENDERED (can exceed the bill; `changeReturn` holds the excess). Legs live as a JSON string in `paymentListJson`; there is no payment box. | `split_payment_widget.dart:63-75, 198-201` |
| **Restaurant has no credit.** No due/credit model exists. A partly-paid order finalized at EOD keeps `amountDue > 0` on a COMPLETED past order with no receivable. `Customer.creditBalance`/`creditLimit` stay 0. | `endday.dart:602-640` |
| **Recipe deduction happens one level deep, at order/KOT placement**, not at payment. A Recipe-Based item deducts its ingredients; a Semi-Finished ingredient is deducted from its own stock (it is not exploded further). | `inventory_service.dart:21-162` |
| **Cost = last purchase cost.** `Items.lastPurchaseCost` is overwritten by each GRN and by production. There is no weighted average anywhere in restaurant code. | `restaurant_purchase_order_store.dart:364-368`; `item_store.dart:400-458` |
| **A table's id IS its display name.** `OrderModel.tableNo` stores that string. | `table.dart:76`; `ordermodel_309.dart:35` |
| **Staff are referenced by NAME on orders and cash records** (`discountAppliedBy`, `voidedBy`, `refundedBy`, `lastModifiedBy`, `staffName`, `closedBy`). Only `ShiftModel.staffId` and `AttendanceModel.staffId` hold a staff id. | rest notes 03 §12 |
| **The business day is a session.** `RestaurantSessionModel.sessionId` is stamped on orders, past orders, expenses, cash movements, item cancellations, attendance and EOD. EOD is per SESSION, not per calendar date. | `eod_service.dart:54-71, 402-417` |
| **Numbers:** bill number = plain int that resets each **financial year**; KOT number resets each **calendar day**; order number resets each calendar day. All three live in the raw `appCounters` box. | `order_repository.dart:71-144` |

---

## Table of contents

**Menu & catalog**
1. [Items](#1-items) · 2. [ItemVariante](#2-itemvariante-embedded) · 3. [VariantModel](#3-variantmodel) · 4. [ChoicesModel](#4-choicesmodel) · 5. [ChoiceOption](#5-choiceoption-embedded) · 6. [Extramodel](#6-extramodel) · 7. [Topping](#7-topping-embedded) · 8. [Category](#8-category-shared) · 9. [Tax](#9-tax-shared) · 10. [ProductType (not Hive)](#10-producttype-not-hive)

**Recipes & production**
11. [RecipeModel](#11-recipemodel) · 12. [RecipeIngredientModel](#12-recipeingredientmodel-embedded) · 13. [RecipeProductionModel](#13-recipeproductionmodel)

**Floor, orders & billing**
14. [TableModel](#14-tablemodel) · 15. [CartItem](#15-cartitem) · 16. [OrderModel](#16-ordermodel) · 17. [PastOrderModel](#17-pastordermodel) · 18. [ItemCancellationModel](#18-itemcancellationmodel) · 19. [PaymentMethod](#19-paymentmethod-shared) · 20. [Customer](#20-customer-shared)

**Purchasing**
21. [RestaurantSupplierModel](#21-restaurantsuppliermodel) · 22. [RestaurantSupplierLedgerEntryModel](#22-restaurantsupplierledgerentrymodel) · 23. [RestaurantPurchaseOrderModel](#23-restaurantpurchaseordermodel) · 24. [RestaurantPurchaseOrderItemModel](#24-restaurantpurchaseorderitemmodel) · 25. [RestaurantGRNModel](#25-restaurantgrnmodel) · 26. [RestaurantGRNItemModel](#26-restaurantgrnitemmodel) · 27. [RestaurantPurchaseReturnModel](#27-restaurantpurchasereturnmodel) · 28. [RestaurantPurchaseReturnItemModel](#28-restaurantpurchasereturnitemmodel) · 29. [RestaurantSupplierClaimModel](#29-restaurantsupplierclaimmodel) · 30. [RestaurantSupplierClaimItemModel](#30-restaurantsupplierclaimitemmodel)

**Inventory**
31. [StockMovementModel](#31-stockmovementmodel-shared) · 32. [RestaurantInventoryLossModel](#32-restaurantinventorylossmodel) · 33. [RestaurantStockTakeModel](#33-restaurantstocktakemodel) · 34. [RestaurantStockTakeItemModel](#34-restaurantstocktakeitemmodel)

**Day / Cash / EOD / Staff**
35. [RestaurantSessionModel](#35-restaurantsessionmodel-shared--the-business-day) · 36. [EndOfDayReport + embedded summaries](#36-endofdayreport--embedded-summaries-shared-model) · 37. [CashMovementModel](#37-cashmovementmodel-shared) · 38. [CashHandoverModel](#38-cashhandovermodel) · 39. [ExpenseCategory](#39-expensecategory-shared-model) · 40. [Expense](#40-expense-shared-model) · 41. [StaffModel](#41-staffmodel-shared) · 42. [ShiftModel](#42-shiftmodel-shared) · 43. [AttendanceModel](#43-attendancemodel-shared) · 44. [AppNotificationModel](#44-appnotificationmodel-shared)

**Settings & singletons**
45. [BusinessDetails](#45-businessdetails-shared-singleton) · 46. [BusinessType](#46-businesstype-shared-singleton) · 47. [TaxDetails](#47-taxdetails-shared-singleton) · 48. [SavedPrinterModel](#48-savedprintermodel-shared) · 49. [Raw untyped boxes](#49-raw-untyped-boxes-appcounters-daymanagementbox-app_state-appconfigbox-storebox)

**Dead / legacy**
50. [TestBillModel / TestBillItem (dead)](#50-testbillmodel--testbillitem-dead) · 51. [Retired and legacy items](#51-retired-and-legacy-items)

Then: [Serialization & schema evolution](#serialization--schema-evolution) · [Model gotchas](#model-gotchas)

### Quick index

| # | Model | typeId (constant) | Box string | Hive key | In backup? |
|---|---|---|---|---|---|
| 1 | Items | 102 `restaurantItem` | `itemBoxs` | `id` (int for generator-written rows) | yes (photos as ZIP entries) |
| 2 | ItemVariante | 112 `restaurantItemVariant` | embedded in `Items.variant` | – | via Items |
| 3 | VariantModel | 105 `restaurantVariant` | `variante` | `id` | yes |
| 4 | ChoicesModel | 106 `restaurantChoice` | `choice` | `id` | yes |
| 5 | ChoiceOption | 107 `restaurantChoiceOption` | embedded | – | via Choices |
| 6 | Extramodel | 103 `restaurantExtra` | `extra` | `Id` (**int after restore**) | yes |
| 7 | Topping | 104 `restaurantTopping` | embedded | – | via Extras |
| 8 | Category | 100 `category` | `categories` (shared) | `id` | yes |
| 9 | Tax | 114 `tax` | `taxes` (shared) | `id` | yes |
| 10 | ProductType | not Hive | String on `Items.productType` | – | – |
| 11 | RecipeModel | 135 `restaurantRecipe` | `restaurantRecipesBox` | `id` | yes |
| 12 | RecipeIngredientModel | 136 `restaurantRecipeIngredient` | embedded | – | via Recipe |
| 13 | RecipeProductionModel | 137 `restaurantRecipeProduction` | `restaurantRecipeProductionsBox` | `id` | yes |
| 14 | TableModel | 111 `restaurantTable` | `tablesBox` | `id` (= table name) | yes |
| 15 | CartItem | 108 `restaurantCart` | `cart_box` + embedded in orders | auto-int | yes |
| 16 | OrderModel | 109 `restaurantOrder` | `orderBox` | `id` | yes (**5 fields lost**) |
| 17 | PastOrderModel | 113 `restaurantPastOrder` | `pastorderBox` | `id` | yes |
| 18 | ItemCancellationModel | 134 `restaurantItemCancellation` | `restaurantItemCancellationsBox` | `id` | **no** |
| 19 | PaymentMethod | **literal 6** | `paymentMethodsBox` (shared) | auto-int | yes |
| 20 | Customer | 125 `customer` | `customers` (shared) | `customerId` | yes |
| 21 | RestaurantSupplierModel | 138 `restaurantSupplier` | `restaurantSuppliersBox` | `supplierId` | yes |
| 22 | RestaurantSupplierLedgerEntryModel | 185 `restaurantSupplierLedgerEntry` | `restaurantSupplierLedgerBox` | `entryId` | yes |
| 23 | RestaurantPurchaseOrderModel | 139 `restaurantPurchaseOrder` | `restaurantPurchaseOrdersBox` | `poId` | yes |
| 24 | RestaurantPurchaseOrderItemModel | 140 `restaurantPurchaseOrderItem` | `restaurantPurchaseOrderItemsBox` | `poItemId` | yes |
| 25 | RestaurantGRNModel | 141 `restaurantGrn` | `restaurantGrnsBox` | `grnId` | yes |
| 26 | RestaurantGRNItemModel | 142 `restaurantGrnItem` | `restaurantGrnItemsBox` | `grnItemId` | yes |
| 27 | RestaurantPurchaseReturnModel | 143 | `restaurantPurchaseReturnsBox` | `returnId` | yes |
| 28 | RestaurantPurchaseReturnItemModel | 144 | `restaurantPurchaseReturnItemsBox` | `returnItemId` | yes |
| 29 | RestaurantSupplierClaimModel | 145 | `restaurantSupplierClaimsBox` | `claimId` | yes |
| 30 | RestaurantSupplierClaimItemModel | 146 | `restaurantSupplierClaimItemsBox` | `claimItemId` | yes |
| 31 | StockMovementModel | 126 `restaurantStockLog` | `stockMovementsBox` (shared) | `id` | **no** (restaurant restore) |
| 32 | RestaurantInventoryLossModel | 147 | `restaurantInventoryLossesBox` | `lossId` | yes |
| 33 | RestaurantStockTakeModel | 148 | `restaurantStockTakesBox` | `takeId` | yes |
| 34 | RestaurantStockTakeItemModel | 149 | `restaurantStockTakeItemsBox` | `takeItemId` | yes |
| 35 | RestaurantSessionModel | 131 `restaurantSession` | `restaurantSessionsBox` (shared) | `sessionId` | yes |
| 36 | EndOfDayReport | 117 `restaurantEod` (+118-121, 124 embedded) | `restaurant_eodBox` | `reportId` (**int after restore**) | yes |
| 37 | CashMovementModel | 128 `restaurantCashMovement` | `cashMovementsBox` (shared) | `id` | yes |
| 38 | CashHandoverModel | 129 `restaurantCashHandover` | `cashHandoversBox` | `id` | yes |
| 39 | ExpenseCategory | 115 `restaurantExpense` | `restaurant_expenseCategory` | `id` | yes |
| 40 | Expense | 116 `restaurantExpense1` | `restaurant_expenseBox` | `id` | yes |
| 41 | StaffModel | 110 `staff` | `staffBox` (shared) | `id` | yes |
| 42 | ShiftModel | 127 `shift` | `shiftBox` (shared) | `id` | yes |
| 43 | AttendanceModel | 132 `attendance` | `restaurantAttendanceBox` (shared) | `id` | yes |
| 44 | AppNotificationModel | 133 `appNotification` | `restaurantNotificationsBox` (shared) | `id` | **no** |
| 45 | BusinessDetails | 4 `businessDetails` | `businessDetailsBox` | `'businessDetails'` (**int after restore**) | yes |
| 46 | BusinessType | 3 `businessType` | `businessTypeBox` | `'selectedBusinessType'` (**int after restore**) | yes |
| 47 | TaxDetails | 2 `taxDetails` | `taxBox` | `'taxDetails'` (**int after restore**) | yes |
| 48 | SavedPrinterModel | 130 `savedPrinter` | `restaurantPrintersBox` (common) | `id` | yes (default slots are not) |
| 49 | raw boxes | – | `appCounters`, `dayManagementBox`, `app_state`, `appConfigBox`, `storebox` | string keys | all except `dayManagementBox` |
| 50 | TestBillModel / TestBillItem | 122 / 123 (unregistered) | `testBillBox` | auto-int | yes (always empty) |

"Shared" means the retail mode uses the **same physical box file**. `restaurant_eodBox`, `restaurant_expenseCategory` and `restaurant_expenseBox` are restaurant-only; retail uses `eodBox`, `expenseCategory`, `expenseBox`. The "In backup?" column is the restaurant branch of `UnifiedBackupService` (`unified_backup_service.dart:712-1056` export, `:2169-2553` restore). The four open boxes it does not restore are `dayManagementBox`, `stockMovementsBox`, `restaurantItemCancellationsBox` and `restaurantNotificationsBox`.

---

# Menu & catalog

## 1. Items

**What it is.** One thing the restaurant sells or stocks: a dish ("Paneer Tikka"), a drink, a raw material ("Paneer, kg"), a prep item ("Tikka marinade") or a recipe-based dish. All four kinds are the same class; `productType` tells them apart.

**Why the app needs it.** It is the menu tile on the POS, the line source for the cart, the stock record for inventory, the produced item and the ingredient in recipes, and the target of PO/GRN lines.

| Fact | Value |
|---|---|
| Class | `Items extends HiveObject` (`itemmodel_302.dart:12-13`) |
| File | `.../itemmodel_302.dart` (generated `itemmodel_302.g.dart`, `writeByte(32)` at `:59`) |
| typeId | **102** `HiveTypeIds.restaurantItem` (`hive_type_ids.dart:59`) |
| Box | `HiveBoxNames.restaurantItems` = `'itemBoxs'` (`hive_box_names.dart:166`), opened `hive_init.dart:771` |
| Hive key | `item.id` on add (`item_repository.dart:39-46`). Rows written by the dev data generators with `addAll` carry **auto-int** keys; `updateItem` rewrites under the existing key (see Update) |

### Fields

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Primary id (UUID). Intended Hive key |
| 1 | name | String | req | – | required | Display name. Unique case-insensitively **within its category**, checked on add only (`item_store.dart:184-192`) |
| 2 | imageBytes | Uint8List? | opt | – | – | Photo bytes (works on web). The only photo storage; there is no path field |
| 3 | price | double? | opt | – | – | Selling price of a simple item. For a Raw Material it is the "Cost Price" input of the form |
| 4 | description | String? | opt | – | – | |
| 5 | categoryOfItem | String? | opt | – | – | **FK → `Category.id`**. `''` = uncategorised (form default and category delete) |
| 6 | isVeg | String? | opt | – | – | `'Veg'` / `'Non-Veg'` / `'Egg'`. Form default `'Veg'` (`add_item_form_state.dart:59`) |
| 7 | unit | String? | opt | – | – | Weight unit when sold by weight; `'piece'` for raw/semi sold by unit; `null` for finished/recipe sold by unit (`add_item_form_state.dart:200-205`) |
| 8 | variant | List<ItemVariante>? | opt | – | `const []` | **Embedded** per-item variant prices and stock (§2) |
| 9 | choiceIds | List<String>? | opt | – | `const []` | FK list → `ChoicesModel.id` |
| 10 | extraId | List<String>? | opt | – | `const []` | FK list → `Extramodel.Id` |
| 11 | taxRate | double? | opt | – | – | **Cached SUM of applied tax rates as a DECIMAL** (0.05 = 5 %). The only tax value billing reads. `null`/0 = no tax |
| 12 | isEnabled | bool | req | – | `true` | Soft-hide flag. The POS shows `isEnabled && sellsAtPos` (`menu.dart:985,1073,1337,1444`) |
| 13 | trackInventory | bool | req | – | `false` | Stock switch. For a variant item the **item's** flag governs |
| 14 | stockQuantity | double | req | – | `0.0` | Item-level stock. Always 0 for variant items and Recipe-Based items |
| 15 | allowOrderWhenOutOfStock | bool | req | – | `true` | The form flips it to `false` when tracking is turned on (`add_item_form_state.dart:331-335`) |
| 16 | isSoldByWeight | bool | req | – | `false` | Weight/decimal selling |
| 17 | createdTime | DateTime? | opt | – | – | Audit |
| 18 | lastEditedTime | DateTime? | opt | – | – | Set by `AuditTrailHelper.trackEdit` (`lib/util/restaurant/audit_trail_helper.dart:29-38`) |
| 19 | editedBy | String? | opt | – | – | Staff name or role |
| 20 | editCount | int | req | – | `0` | Incremented by `trackEdit` |
| 21 | extraConstraints | Map<String, Map<String,int>>? | opt | – | – | `{extraId: {min, max}}`, per-item override of `Extramodel.minimum/maximum` (read `item_options_dialog.dart:210-211,1110-1112`; written `edit_item.dart:458-473`) |
| 22 | lowStockThreshold | double? | opt | – | – | Per-item override; null = `AppSettings.lowStockThreshold` |
| 23 | lowStockAlertEnabled | bool | req | **false** | `false` | Per-item opt-in |
| 24 | isFavorite | bool | req | **false** | `false` | Pinned to the POS Favorites tab |
| 25 | itemCode | String? | opt | – | – | 4-5 digit code, unique (`item_store.dart:194-201,231-238`). Suggested as max+1 from 1001 (`:574-587`) |
| 26 | defaultChoiceOptionIds | List<String>? | opt | – | – | FK list → `ChoiceOption.id`, pre-ticked in the POS dialog (`item_options_dialog.dart:154-166`) |
| 27 | taxIds | List<String>? | opt | – | – | FK list → `Tax.id`, at most 2 (`applyTax`, `:242-251`). Read only by Edit Item (`edit_item.dart:174`) |
| 28 | productType | String? | opt | – | – | `rawMaterial` / `semiFinished` / `finishedGood` / `recipeBased`; null reads as `finishedGood` (§10) |
| 29 | recipeId | String? | opt | – | – | Meant to point at `RecipeModel.id`. Written by Edit Item (`edit_item.dart:517-519`), **never read** |
| 30 | lastPurchaseCost | double? | opt | – | – | Last GRN unit cost or produced unit cost. **The only cost source** for food costing |
| 31 | sellDirectlyAtPos | bool? | opt | – | – | POS-visibility override. Only raw/semi carry it; other types are forced to null (`add_item_form_state.dart:218-222`) |

Line references: `itemmodel_302.dart:14-112`. Only f23 and f24 have a Hive default (`.g.dart:44-45`).

### Validation rules and defaults
- **Getters** (`:150-236`): `hasVariants`; `effectiveProductType`, `isRawMaterial`, `isSemiFinished`, `isFinishedGood`, `isRecipeBased`; `hasRecipe`, `isStockDerivedFromRecipe`; `sellsAtPos = sellDirectlyAtPos ?? !isRawMaterial` (`:177`); `isInStock` (`:185-195`) and `isLowStock` (`:205-220`) read the **stored** stock (Recipe-Based items must use `InventoryService.effectiveAvailableStock` instead); `finalPrice`, `basePrice = price/(1+taxRate)`, `taxAmount` (`:225-236`) assume inclusive tax and a decimal rate.
- **Create rules** (`add_item_form_state.dart:110-232`): category and price are required only for menu types (`ProductType.isMenuType`); raw/semi get no variants; item-level stock is set only when tracking is on and there are no variants. `setProductType` (`:313-327`): raw/semi → `trackInventory=true`, `allowOOS=false`, `sellDirectlyAtPos=false`; recipeBased → `trackInventory=false`, `allowOOS=false`.
- **Plan gates** (`item_store.dart`): add needs `EntKeys.manageMenuItemsAdd` + `manageMenuItemsMax`; update needs `manageMenuItemsEdit`; delete needs `manageMenuItemsDelete`. A refused update returns `false` without throwing.
- **`ItemStore.lowStockItems` uses a hard-coded `< 10`** (`item_store.dart:104,135-136`) and so disagrees with `Items.isLowStock`.

### Identifier
UUID v4: Add Item sheet `AddItemFormState.toItem` (`add_item_form_state.dart:181`); setup wizard (`setup_add_item_screen.dart:462`); bulk import upserts with `existingItem?.id ?? Uuid().v4()` (`restaurant_bulk_import_service.dart:1061`); dev generator (`comprehensive_data_generator.dart:632`).

### References
- Outgoing: `categoryOfItem` → Category; `taxIds` → Tax (rate cached in f11); `variant[].variantId` → VariantModel; `choiceIds` → ChoicesModel; `defaultChoiceOptionIds` → ChoiceOption; `extraId` and `extraConstraints` keys → Extramodel.
- Incoming: `CartItem.productId`, `RecipeModel.itemId`, `RecipeIngredientModel.ingredientItemId`, `RecipeProductionModel.itemId`, PO/GRN/return/claim/loss/stock-take lines (`itemId` + `itemName` snapshot), `StockMovementModel.itemId`.
- None of the incoming references is guarded on delete. Orders keep their own snapshot lines and still display.

### Serialization
- `toMap` (`:339-374`) writes every field; `imageBytes` becomes `List<int>`, DateTimes ISO strings.
- `fromMap` (`:377-468`) is defensive: price from String or num; `_parseBool` accepts bool/`'yes'`/`'1'`/int; id lists coerced; `imageBytes` from `Uint8List` or JSON list; a legacy `imagePath` is read into bytes if the file still exists (`:412-422`); `id`/`name` default `''`. Exceptions: `editCount: map['editCount'] ?? 0` is not coerced (a JSON `3.0` throws); `DateTime.parse` throws on a malformed date.
- `copyWith` (`:268-336`) uses `??` everywhere: **no field can be cleared**. Edit Item therefore assigns `taxRate`, `taxIds`, `recipeId`, `sellDirectlyAtPos`, `lowStockAlertEnabled`, `lowStockThreshold`, `trackInventory` directly after `copyWith` (`edit_item.dart:512-559`).
- Backup: exported without `imageBytes`; each photo goes into the ZIP as `item_img_<id>` and is patched back on restore (`unified_backup_service.dart:718-724, 2212-2247`). Restore is `putAll` keyed by id, which normalises any int keys. Web export drops photos.
- **Model-level Hive I/O:** `applyTax(taxId, rate)` / `removeTax(taxId, rate)` (`:242-266`) call `save()` from the model, and callers then call `itemStore.updateItem`, so each item is written twice.

### Where it is created and read
- Repository `lib/data/repositories/restaurant/item_repository.dart`; store `lib/domain/store/restaurant/item_store.dart` (DI `service_locator.dart:386,428-429`).
- Screens: Manage Menu (`manage menu/manage_menu_screen.dart`, `items_tab.dart`, `all_tab.dart`, `edit_item.dart`), Add Item (`add_item_sheet.dart`, `add_item_form_state.dart`, selection screens), setup wizard (`auth/setup_add_item_screen.dart`), POS (`tabbar/menu.dart`, `menu_grid_screen.dart`, `item_options_dialog.dart`), bulk import, `inventory/manage_Inventory.dart`, production, stock take, PO screens.
- Also read by `CartRepository` (`cart_repository.dart:18`), `CategoryRepository` (`:31`), the legacy static `hive_db.dart:50`, and the Captain `/captain/menu` endpoint (which sends `imageBytes` as a JSON int list).

### Update and delete
- **Stock deltas** (sale, recipe cascade, void/refund restore, GRN, production) go through `ItemStore.applyStockDelta` (`item_store.dart:364-458`): serialised per item, re-reads the live item, writes through the repo (not plan-gated), rebuilds `ItemVariante` with every field. **Manual adjustment, Low Stock add, stock-take commit and Edit Item do not**; they save a full snapshot via the plan-gated `updateItem`, ignore its bool, and drop `ItemVariante.trackInventory` when rebuilding variants (rest notes 04 N2, N6).
- **Edit Item** ignores the `updateItem` result (`edit_item.dart:580`); the recipe save/delete and stock-movement logs still run if the plan gate refused. It also re-seeds a Raw Material's `lastPurchaseCost` from the price field on every save (`edit_item.dart:474-482`), which overwrites the GRN cost.
- **Key reconciliation:** `getAllItems` dedupes by id (`item_repository.dart:26-36`); `updateItem` finds every key holding the id, overwrites the first and deletes the rest (`:56-74`). `deleteItem`, `getItemById`, `updateStock`, `toggleItemStatus` use `box.get/delete(itemId)` and miss int-keyed rows; a deleted int-keyed item reappears on the next load (latent: only dev generators write int keys).
- **Delete** is a hard delete with no reference guard (`items_tab.dart:70-88` → `item_store.dart:267-292` → `item_repository.dart:77-79`). It leaves the item's own `RecipeModel` orphaned, and recipes that use it as an ingredient silently skip the missing line at sale time (`inventory_service.dart:136-142`). The soft alternative is `isEnabled = false`.

## 2. ItemVariante (embedded)

**What it is.** The price (and optionally stock) of one size of one item, e.g. "Paneer Tikka — Half ₹180".

**Why the app needs it.** Restaurant variants are a global name list (`VariantModel`: Half, Full, Large) plus a per-item price. This class is that per-item row.

| Fact | Value |
|---|---|
| Class / file | `ItemVariante extends HiveObject`, `.../itemvariantemodel_312.dart:5-6` |
| typeId | **112** `restaurantItemVariant` (`hive_type_ids.dart:69`) |
| Box / key | None. Embedded in `Items.variant` (f8) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | variantId | String | req | – | required | **FK → `VariantModel.id`**. Not an own id |
| 1 | price | double | req | – | required | Selling price of this variant of this item |
| 2 | trackInventory | bool? | opt | – | – | **Ignored.** The add form never sets it; `Items.isInStock` uses the item flag (`itemmodel_302.dart:186-191`). Manual adjustment paths null it |
| 3 | stockQuantity | double? | opt | – | – | Per-variant stock, used when the parent item tracks inventory |

- **Validation/defaults:** none in the model. There is no `name`: the POS resolves it through `variantStore.getVariantById(variantId)` and **silently drops** a variant whose lookup fails (`item_options_dialog.dart:121-148`).
- **Identifier:** none of its own.
- **References:** `variantId` → VariantModel. `CartItem.variantName` snapshots the resolved name; sale deduction finds the variant **by name** (`inventory_service.dart:72-79, 540-556`).
- **Serialization:** `fromMap` (`:40-60`) turns a missing `stockQuantity` into **0.0** (not null), `variantId` to `''`, `price` to 0. No `copyWith`; edits rebuild the object (`edit_item.dart:432-439`, `item_store.dart:429-434`).
- **Where used:** Add/Edit Item, `item_options_dialog.dart`, `InventoryService`, Manage Inventory.
- **Update/delete:** only by rewriting the parent `Items`. `updateStock(delta)` (`:31-36`) calls `save()` on an embedded object, which would throw; it has no callers (dead).

## 3. VariantModel

**What it is.** A global variant name such as "Half", "Full", "Large".

**Why the app needs it.** Items and toppings refer to these names by id so a size is named once and priced per item.

| Fact | Value |
|---|---|
| Class / file | `VariantModel`, a **plain class, not a HiveObject** (`.../variantmodel_305.dart:8-9`) |
| typeId | **105** `restaurantVariant` (`hive_type_ids.dart:62`) |
| Box | `'variante'` (`hive_box_names.dart:169`), opened `hive_init.dart:773`; the repo uses the literal (`variant_repository.dart:10`) |
| Hive key | `id` (`variant_repository.dart:14-31`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | name | String | req | – | required | "Half", "Full". UI refuses duplicates on add and rename (`variant_tab.dart:290-295`) |
| 2 | createdTime | DateTime? | opt | – | – | |
| 3 | lastEditedTime | DateTime? | opt | – | – | |
| 4 | editedBy | String? | opt | – | – | |
| 5 | editCount | int | req | – | `0` | |

- **Identifier:** `Uuid().v4()` (`variant_tab.dart:304`, `item/variant_selection_screen.dart:71,878,893`, bulk import `:531`).
- **References:** referenced by `ItemVariante.variantId` and `Topping.variantPrices` keys; also embedded as copies in `Topping.variantion` (bulk import only).
- **Serialization:** `DateTime.parse` in `fromMap` (not `tryParse`).
- **Where used:** repo `lib/data/repositories/restaurant/variant_repository.dart` (class `VariantRepositoryRes`); store `lib/domain/store/restaurant/variant_store.dart` (`:42-108`, no plan gate in the store); screen `manage menu/tab/variant_tab.dart`. `CartRepository` also opens the box (`:19`).
- **Update:** the rename builds `VariantModel(id, name)` (`variant_tab.dart:298-302`), which **drops `createdTime` and resets `editCount` to 0**.
- **Delete:** plan-gated in the UI (`manageMenuVariantsDelete`, `:313-333`), hard delete, **no in-use check**. `ItemVariante.variantId` and `Topping.variantPrices` keys dangle; an item whose variants are all deleted still says `hasVariants` but its dialog has nothing to pick.

## 4. ChoicesModel

**What it is.** A group of free modifiers, e.g. "Spice level: Mild / Medium / Hot".

**Why the app needs it.** The POS option dialog shows these groups for each item that links them; the picked names go onto the cart line.

| Fact | Value |
|---|---|
| Class / file | `ChoicesModel extends HiveObject`, `.../choicemodel_306.dart:7-8` |
| typeId | **106** `restaurantChoice` |
| Box | `'choice'` (`hive_box_names.dart:172`), opened `hive_init.dart:774`; repo literal `choice_repository.dart:11` |
| Hive key | `id` (`choice_repository.dart:16`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | name | String | req | – | required | Group name; UI refuses duplicates (`choice_tab.dart:663-673`) |
| 2 | choiceOption | List<ChoiceOption> | req | – | `const []` | Embedded options (§5) |
| 3 | createdTime | DateTime? | opt | – | – | |
| 4 | lastEditedTime | DateTime? | opt | – | – | |
| 5 | editedBy | String? | opt | – | – | |
| 6 | editCount | int | req | – | `0` | |
| 7 | allowMultipleSelection | bool? | opt | – | – | null/false = pick one (`item_options_dialog.dart:995`) |

- **Identifier:** `Uuid().v4()` (`choice_tab.dart:702`, `item/choice_selection_screen.dart:685`).
- **References:** referenced by `Items.choiceIds`; its options by `Items.defaultChoiceOptionIds`. `CartItem.choiceNames` snapshots the picked option names.
- **Serialization:** `fromMap` defaults id/name to `''` and options to `[]` (`:83-98`) but uses `DateTime.parse`. **`copyWith` defect:** the parameter is named `option` (`:48`) but the body uses `choiceOption ?? this.choiceOption` (`:58`), i.e. the field, so a new option list is ignored. `ChoiceRepository.addOption/removeOption/updateOption` (`:40-87`) therefore write the record back unchanged and return `true`; their store wrappers have no callers (latent).
- **Where used:** store `lib/domain/store/restaurant/choice_store.dart` (`:43-109`); screens `manage menu/tab/choice_tab.dart`, `item/choice_selection_screen.dart`; legacy `hive_choice.dart:12`.
- **Update:** the edit builds a fresh model keeping `id`, `createdTime`, `editCount+1` and setting `editedBy` (`choice_tab.dart:686-699`); existing option ids are kept, new options get new UUIDs (`:87, :143`).
- **Delete:** plan-gated (`manageMenuChoicesDelete`, `:711-732`), hard delete, no in-use check. Dangling `choiceIds` and `defaultChoiceOptionIds` are skipped by the POS (`item_options_dialog.dart:157-167`).

## 5. ChoiceOption (embedded)

**What it is / why.** One option inside a choice group ("Hot"). Choices are free, so it has no price.

| Fact | Value |
|---|---|
| Class / file | `ChoiceOption extends HiveObject`, `.../choiceoptionmodel_307.dart:7-8` |
| typeId | **107** `restaurantChoiceOption` |
| Box / key | None. Embedded in `ChoicesModel.choiceOption` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String (final) | req | – | required | UUID. FK target of `Items.defaultChoiceOptionIds` |
| 1 | name | String (mutable) | req | – | required | Label |

- **Identifier:** UUID v4 assigned when the option is added in `choice_tab.dart` (`:143`).
- **Serialization:** `fromMap` hard-casts `map['id'] as String` (`:39-44`); a missing key throws.
- **Delete:** removing an option leaves `Items.defaultChoiceOptionIds` dangling; the POS ignores it.

## 6. Extramodel

**What it is.** A group of paid add-ons, e.g. "Extras: Cheese +20, Olives +30".

**Why the app needs it.** The POS dialog lists the linked groups; the chosen toppings and their quantities are added to the line price.

| Fact | Value |
|---|---|
| Class / file | `Extramodel extends HiveObject`, `.../extramodel_303.dart:7-8`. Note the capitalised fields `Id` and `Ename` |
| typeId | **103** `restaurantExtra` |
| Box | `'extra'` (`hive_box_names.dart:175`), opened `hive_init.dart:772`; repo literal `extra_repository.dart:11` |
| Hive key | `Id` (`extra_repository.dart:15-31`). **Auto-int after a backup restore** (see Serialization) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | Id | String | req | – | required | Id / intended key |
| 1 | Ename | String | req | – | required | Group name |
| 2 | isEnabled | bool? | opt | – | `true` | **No reader anywhere**; the POS shows every linked extra |
| 3 | topping | List<Topping>? | opt | – | `const []` | Embedded toppings (§7) |
| 4 | createdTime | DateTime? | opt | – | – | |
| 5 | lastEditedTime | DateTime? | opt | – | – | |
| 6 | editedBy | String? | opt | – | – | |
| 7 | editCount | int | req | – | `0` | |
| 8 | minimum | int? | opt | – | – | Minimum toppings to pick; overridden per item by `Items.extraConstraints` |
| 9 | maximum | int? | opt | – | – | Maximum (0 or null = unlimited) |

- **Identifier:** `Uuid().v4()` (`extra_tab.dart:1049`, `item/extra_selection_screen.dart:717`).
- **References:** referenced by `Items.extraId` and `Items.extraConstraints` keys. `CartItem.extras` snapshots the picked toppings as raw maps (with `categoryId` = the extra's id).
- **Serialization:** `fromMap` hard-casts `Id`/`Ename` and uses `as int?` for min/max (`:96-111`); a JSON double throws. `copyWith` (`:54-77`) has no `isEnabled` parameter. **Restore defect:** extras are restored with `restoreBox` = `clear` + `addAll` (`unified_backup_service.dart:2175-2187, 2250`), so they get int keys. After a restore `getExtraById(id)` (`extra_repository.dart:24-26`) returns null and **every extra disappears from the POS dialog**; an edit then `put(Id)`s a second copy and a delete by `Id` misses.
- **Where used:** repo `extra_repository.dart` (topping add/remove/update at `:39-93` work); store `lib/domain/store/restaurant/extra_store.dart` (`:43-153`); screens `manage menu/tab/extra_tab.dart`, `item/extra_selection_screen.dart`; legacy `hive_extra.dart`.
- **Update:** the edit rebuilds `Extramodel(Id, Ename, topping, min, max)` (`extra_tab.dart:1039-1046`), which resets `isEnabled` to true and drops `createdTime`, `editedBy`, `editCount`.
- **Delete:** plan-gated (`manageMenuExtrasDelete`, `:1132-1155`), hard delete, no in-use check; dangling ids are skipped by the POS (`item_options_dialog.dart:171-188`).

## 7. Topping (embedded)

**What it is / why.** One paid add-on inside an extra group ("Cheese +20"), optionally priced per item variant.

| Fact | Value |
|---|---|
| Class / file | `Topping extends HiveObject`, `.../toppingmodel_304.dart:7-8` |
| typeId | **104** `restaurantTopping` |
| Box / key | None. Embedded in `Extramodel.topping` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | name | String | req | – | required | **The only identity a topping has** (no id) |
| 1 | isveg | bool | req | – | required | |
| 2 | price | double | req | – | required | Base price; with sizes on, the first variant price (`extra_tab.dart:1074-1080`) |
| 3 | isContainSize | bool? | opt | – | – | Prices vary by item variant |
| 4 | variantion (sic) | List<VariantModel>? | opt | – | – | Embedded VariantModel copies. **Only bulk import writes it** (`restaurant_bulk_import_service.dart:772`) |
| 5 | variantPrices | Map<String,double>? | opt | – | – | `{VariantModel.id: price}`; `getPriceForVariant(variantId)` falls back to `price` (`:122-127`) |
| 6 | createdTime | DateTime? | opt | – | – | |
| 7 | lastEditedTime | DateTime? | opt | – | – | |
| 8 | editedBy | String? | opt | – | – | |
| 9 | editCount | int | req | – | `0` | |

- **Identity hazard:** the POS dialog keys quantities by `topping.name` (`item_options_dialog.dart:183,199`); two same-named toppings in different extras on one item share a counter.
- **Serialization:** `fromMap` (`:99-119`) hard-casts `name`/`isveg`; an int `price` throws; `Map<String,double>.from` throws on int values. `toMap` serialises `variantion` as maps (`:87-89`), which fixed the `/captain/menu` encode crash.
- **Update:** `_saveTopping` (`extra_tab.dart:1065-1104`) builds a new Topping with no audit fields.

## 8. Category (shared)

**What it is.** A menu section such as "Starters", "Main Course", "Beverages".

**Why the app needs it.** POS category tabs, Manage Menu grouping, and category sales on the EOD report (via the snapshot `CartItem.categoryName`).

| Fact | Value |
|---|---|
| Class / file | `Category`, a **plain class, not HiveObject**, `lib/data/models/common/categorymodel_300.dart` |
| typeId | **100** `HiveTypeIds.category` (`hive_type_ids.dart:54`) |
| Box | `HiveBoxNames.category` = `'categories'`, **one physical box for both modes**; restaurant opens it at `hive_init.dart:770` |
| Hive key | `id` (`category_repository.dart:29,44,49,98`) |
| Retired index | **2** (old imagePath) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | name | String | req | – | required | Display name |
| 3 | createdTime | DateTime? | opt | – | – | |
| 4 | lastEditedTime | DateTime? | opt | – | – | Set by `AuditTrailHelper.trackEdit` on rename |
| 5 | editedBy | String? | opt | – | – | Set by restaurant on rename (retail does not) |
| 6 | editCount | int | req | – | `0` | Incremented on rename |

- **Validation:** restaurant **does** guard renames against duplicate names, excluding itself (`edit_category.dart:43-66`); add is guarded case-insensitively in the store. Plan-gated via `ModeKeys.categoriesAdd/Edit/Delete`.
- **Identifier (restaurant):** UUID v4 (`bottom_sheets/add_category_dialog.dart:137`, `auth/category_management_screen.dart:418`, bulk import `:405`). Retail uses ms timestamps. Restaurant never seeds default categories (only retail does, `category_store.dart:104-108`).
- **References:** referenced by `Items.categoryOfItem` (`''` = none). Orders do not reference it; they carry `CartItem.categoryName`.
- **Serialization:** `fromMap` hard-parses dates (`categorymodel_300.dart:55-63`), defaults `editCount ?? 0`. `copyWith` has no clear flags.
- **Where used:** repo `lib/data/repositories/common/category_repository.dart`; store `lib/domain/store/common/category_store.dart`. Restaurant-only store state `categoryItemsMap` (`:126-134`) is a snapshot that goes stale after item edits until `loadCategories` runs again. Screens: `manage menu/tab/categories_tab.dart`, `edit_category.dart`, `add_category_dialog.dart`, `auth/category_management_screen.dart`, POS `menu.dart`.
- **Delete:** **never deletes items.** `CategoryRepository.deleteCategory` (`:72-99`) iterates the item box by key and writes `item.copyWith(categoryOfItem: '')` back under the same key (safe for int-keyed rows), then deletes the category. `CategoryStore.deleteCategory` (`:213-260`) mirrors it in memory. The POS shows such items in an "Uncategorised" section (sentinel `'__uncategorised__'`, `menu.dart:192-215`). The class doc at `category_repository.dart:17-19` still mentions an item-delete step (stale).
- Retail view: [Retail §9 Category](../retail/02_RETAIL_DATABASE_MODELS.md#9-category-shared).

## 9. Tax (shared)

**What it is.** A named tax rate, e.g. "CGST 2.5%" or "GST 5%".

**Why the app needs it.** Items pick up to two taxes; their rates are summed and cached on the item as a decimal.

| Fact | Value |
|---|---|
| Class / file | `Tax extends HiveObject` (mutable fields), `lib/data/models/common/taxmodel_314.dart` |
| typeId | **114** `HiveTypeIds.tax` (`hive_type_ids.dart:71`) |
| Box | `'taxes'` (shared), restaurant open `hive_init.dart:790` |
| Hive key | `id` (`tax_repository.dart:11,16`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | taxname | String | req | – | required | "GST 5%" |
| 2 | taxperecentage (sic) | double? | opt | – | – | Rate in **percent** (5, not 0.05) |

- **Validation:** the add form refuses a duplicate name and a rate outside 0-100 (`TaxSetting/addMultipleTax.dart:66-86`).
- **Identifier:** UUID v4 (`addMultipleTax.dart:100`, `item/tax_selection_screen.dart:285`, bulk import `:502`).
- **References / units:** `Items.taxIds` (≤ 2) → Tax. The percent is divided by 100 and **added** into `Items.taxRate` (`addMultipleTax.dart:131`, `apply_tax_screen.dart:137,175`, `tax_selection_screen.dart:177,302-303`, bulk import `:1040-1045`). Billing reads only the cached decimal. Item tax is applied only when the business tax switch is on (`TaxFeature`).
- **Serialization:** `fromMap` defaults id/name to `''`; `copyWith` cannot clear the rate.
- **Where used:** repo `lib/data/repositories/common/tax_repository.dart`; store `lib/domain/store/common/tax_store.dart`; screens `TaxSetting/addMultipleTax.dart`, `apply_tax_screen.dart`, `item/tax_selection_screen.dart`. Optional "apply to all items" runs `item.applyTax` + `updateItem` (`addMultipleTax.dart:130-141`).
- **Update:** editing a rate **does not re-cache** onto items (`addMultipleTax.dart:91-97`). A later `removeTax(id, newRate)` subtracts the new rate from a sum built with the old one and leaves a wrong residual.
- **Delete:** unguarded (`addMultipleTax.dart:126-128`, `tax_selection_screen.dart:361-381`). Items keep the dangling `taxIds` **and keep billing the deleted rate**.
- Retail view: [Retail §10 Tax](../retail/02_RETAIL_DATABASE_MODELS.md#10-tax-shared).

## 10. ProductType (not Hive)

**What it is.** A constants class with a private constructor (`.../product_type.dart:7-8`). Its values are stored as a plain String in `Items.productType` (f28).

| Value | `hasRecipe` | `isStockDerived` | `isMenuType` | POS default (`sellsAtPos`) | Stock replenished by |
|---|---|---|---|---|---|
| `rawMaterial` | no | no | no | **hidden** | PO → GRN |
| `semiFinished` | **yes** | no | no | shown (the form sets the override to false on create, `add_item_form_state.dart:318`) | Production (§13) |
| `finishedGood` (also `null`) | no | no | yes | shown | GRN or manual |
| `recipeBased` | **yes** | **yes** (own stock forced to 0, tracking off) | yes | shown | derived from ingredients |

- Helpers: `effective` (`:61`), `displayName` (`:45-57`), `hasRecipe` (`:38-39`), `isStockDerived` (`:43`), `isMenuType` (`:67-68`), `resolvePhysicalStock` (`:73-85`), `seededLastPurchaseCost` (`:95-96`, raw material only).
- In short: **ingredient** = raw or semi; **recipe** = semi (stocked) or recipeBased (derived); **sellable** = `sellsAtPos && isEnabled`.

---

# Recipes & production

## 11. RecipeModel

**What it is.** The bill of materials for one item: "1 batch of Tikka marinade (yield 2 kg) = 1.5 kg curd + 0.2 kg spice mix …".

**Why the app needs it.** A Recipe-Based dish deducts its ingredients when it is ordered; a Semi-Finished item consumes its ingredients when a batch is produced; the Food Cost report prices a dish from its ingredients' last purchase cost.

| Fact | Value |
|---|---|
| Class / file | `RecipeModel extends HiveObject`, `.../recipe_model.dart:10-11` |
| typeId | **135** `restaurantRecipe` (`hive_type_ids.dart:107`) |
| Box | `'restaurantRecipesBox'` (`hive_box_names.dart:236`), opened `hive_init.dart:824` |
| Hive key | `id` (`recipe_repository.dart:23-25`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | itemId | String | req | – | required | **FK → `Items.id` of the produced item. This is the real link**; lookups go by `itemId`, not `Items.recipeId` |
| 2 | yieldQty | double | req | – | `1.0` | Output units per batch. The builder coerces `<= 0` to 1.0 (`recipe_builder_widget.dart:182-186`) |
| 3 | yieldUnit | String? | opt | – | – | Label |
| 4 | ingredients | List<RecipeIngredientModel> | req | – | `const []` | Embedded lines (§12) |
| 5 | prepInstructions | String? | opt | – | – | Never edited by the builder; carried over from `initialRecipe` (`:190`) |
| 6 | createdTime | DateTime? | opt | – | – | |
| 7 | lastEditedTime | DateTime? | opt | – | – | Set to now on every emit |
| 8 | editedBy | String? | opt | – | – | Carried over; the builder never sets it |
| 9 | editCount | int | req | **0** | `0` | Never incremented by the builder |

- **Validation/defaults:** one recipe per item is a **convention only**: `getRecipeForItem(itemId)` takes the first match (`recipe_repository.dart:15-21`); uniqueness comes from the builder reusing the id. Ingredients must be raw or semi items and not the item itself, enforced only by the picker filter (`recipe_builder_widget.dart:236-240`); that filter is what keeps the cascade one level deep.
- **Getters:** `hasIngredients` (`:58`); `estimatedCost(costOf) = Σ effectiveQuantity × costOf(id)`; `estimatedCostPerUnit = estimatedCost / yieldQty` (`:64-76`).
- **Identifier:** `widget.initialRecipe?.id ?? Uuid().v4()` (`recipe_builder_widget.dart:86`).
- **References:** `itemId` → Items; `ingredients[].ingredientItemId` → Items. Referenced by `RecipeProductionModel.recipeId`. `Items.recipeId` points here but is write-only.
- **Serialization:** `fromMap` uses `tryParse` for dates and coerces numbers (`:117-136`). Backed up (`recipes`, `unified_backup_service.dart:931/2380`).
- **Where used:** **no MobX store**; `recipeRepository` (DI `service_locator.dart:387`) is used directly by `inventory_service.dart:133,280,387,870` (sale cascade, availability, production), `cart_repository.dart:65`, `menu.dart:785,869`, `recipes_screen.dart:158`, `production_screen.dart`, `recipe_report_service.dart`.
- **Update/delete:** the only writer is Edit Item (`edit_item.dart:583-589`): `saveRecipe(recipe.copyWith(itemId))` when the type has a recipe, else `deleteRecipeForItem`. Emptying every row makes the builder emit null, which deletes the recipe (`recipe_builder_widget.dart:177-180`). The Add Item sheet never creates a recipe (it asks the user to add it in Edit). Deleting the produced item does **not** delete its recipe (orphan row).

## 12. RecipeIngredientModel (embedded)

**What it is / why.** One line of a recipe: which stock item, how much per batch, in which unit, with what wastage.

| Fact | Value |
|---|---|
| Class / file | `RecipeIngredientModel extends HiveObject`, `.../recipe_ingredient_model.dart:11-12` |
| typeId | **136** `restaurantRecipeIngredient` (`hive_type_ids.dart:108`), registered before 135 (`hive_init.dart:697`) |
| Box / key | None. Embedded in `RecipeModel.ingredients` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | ingredientItemId | String | req | – | required | FK → `Items.id` (raw or semi only, by picker) |
| 1 | quantity | double | req | – | required | Quantity per `yieldQty` units. The builder drops rows with `qty <= 0` |
| 2 | unit | String? | opt | – | – | Label only; conversion is through f5 |
| 3 | wastagePercent | double | req | **0.0** | `0.0` | Prep loss in percent |
| 4 | note | String? | opt | – | – | Never written by the builder (`recipe_builder_widget.dart:166-174`) |
| 5 | conversionFactor | double | req | **1.0** | `1.0` | Ingredient stock-units per recipe unit (g → kg = 0.001) |

- `effectiveQuantity = quantity × conversionFactor × (1 + wastagePercent/100)` (`:63-64`).
- **Sale cascade:** `ingredientQuantitiesFor` (`inventory_service.dart:221-233`) returns `(saleQty / yieldQty) × effectiveQuantity` per line, so wastage, unit conversion and yield are all applied.
- **Delete:** no guard when the ingredient item is deleted; the line is skipped at sale time (`inventory_service.dart:139-142`) and the dish's available-to-make figure goes wrong.

## 13. RecipeProductionModel

**What it is.** A log row for one production run: "Produced 2 kg Tikka marinade at 10:40 by Ravi".

**Why the app needs it.** It ties the ingredient `out` movements and the produced `in` movement of one batch together for audit and reports.

| Fact | Value |
|---|---|
| Class / file | `RecipeProductionModel`, `.../recipe_production_model.dart:10` |
| typeId | **137** `restaurantRecipeProduction` (`hive_type_ids.dart:109`) |
| Box | `'restaurantRecipeProductionsBox'` (`hive_box_names.dart:239`), opened `hive_init.dart:825` |
| Hive key | `id` (`recipe_production_repository.dart:19`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (`inventory_service.dart:509`) |
| 1 | recipeId | String | req | – | required | FK → RecipeModel |
| 2 | itemId | String | req | – | required | FK → the produced Semi-Finished item |
| 3 | itemName | String | req | – | required | Snapshot |
| 4 | batchQty | double | req | – | required | **Output units**, not number of batches |
| 5 | producedTime | DateTime | req | – | required | |
| 6 | producedBy | String? | opt | – | – | Staff name |
| 7 | movementIds | List<String> | req | – | `const []` (`:50`) | Ingredient out-movements plus the produced in-movement |

- **Writer:** `InventoryService.produceBatch(item, batchQty)` (`inventory_service.dart:380-527`), from `production_screen.dart:88-120` (picker lists Semi-Finished only; the service itself does not check the type). Order: validate stock per line → per ingredient `applyStockDelta(−qty)` + movement `out` / `Production (X)` → `producedUnitCost = recipe.estimatedCostPerUnit(lastPurchaseCost)` → `applyStockDelta(+batchQty, lastPurchaseCost: producedUnitCost)` + movement `in` / `Production batch` → this row last. There is no rollback: a failure midway leaves a partial deduction and no production row.
- **Serialization:** `fromMap` maps `movementIds` with `toString()` and falls back to empty (`:74-75`). Backed up (`recipeProductions`).
- **Update/delete:** append-only; the repo exposes save and get only (`recipe_production_repository.dart:8-21`).

---

# Floor, orders & billing

## 14. TableModel

**What it is.** A dine-in table ("T1", "Patio 3") and its current state.

**Why the app needs it.** The table grid shows which tables are free or occupied and the running total; a dine-in order is attached to a table by name.

| Fact | Value |
|---|---|
| Class / file | `TableModel extends HiveObject`, `.../table_Model_311.dart:7-8` |
| typeId | **111** `restaurantTable` |
| Box | `'tablesBox'` (`hive_box_names.dart:182`), opened `hive_init.dart:784` |
| Hive key | `id` = **the table's display name** (`table_repository.dart:20-22`; `table.dart:76` → `TableModel(id: name)`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Table name and key. `OrderModel.tableNo` stores this string |
| 1 | status | String | req | – | `'Available'` | `Available` / `Reserved` / an occupied state (`Processing`, `Cooking`, `Running`, `Ready`, `Served`) (`table.dart:87-89,632-637`) |
| 2 | currentOrderTotal | double? | opt | – | – | Cached running total |
| 3 | currentOrderId | String? | opt | – | – | FK → `OrderModel.id`. **Set only by the Captain/KDS server paths** (`captain_handler.dart:283`); POS paths never pass it |
| 4 | timeStamp | String? (ISO) | opt | – | – | When the order was placed |
| 5 | tableCapacity | int? | opt | – | – | Seats |

- **Validation:** add is plan-gated by `EntKeys.billingTablesCreate` and `billingTablesMax` (`table_store.dart:86-104`). Delete is refused for an occupied table (`table.dart:203-231`) but allowed for Reserved; no plan gate on delete.
- **Identifier:** the user-typed name.
- **References:** the live table→order link is `OrderStore.getActiveOrderByTableId` (`order_store.dart:570-584`), matching `tableNo` + an active status, not `currentOrderId`.
- **Serialization:** no `copyWith`; `toMap`/`fromMap` at `:40-61`; `tableCapacity` is hard-assigned (a JSON double throws).
- **Where used:** repo `lib/data/repositories/restaurant/table_repository.dart`; store `lib/domain/store/restaurant/table_store.dart`; screen `tabbar/table.dart`; Captain `/captain/tables`; legacy `hive_Table.dart`.
- **Update:** `TableRepository.updateTableStatus` (`:30-55`) mutates and `save()`s; for a non-Available status it writes `total` and `orderId` **even when null**, clearing them on disk, while `TableStore.updateTableStatus` (`:118-156`) keeps them in memory. About 20 callers pass only a status.
- **Rename defect:** rename is delete-then-add copying only `status` and `tableCapacity` (`table.dart:276-284`), is offered even for occupied tables (`:192-199`), drops `currentOrderId`/`currentOrderTotal`/`timeStamp`, and leaves the running `OrderModel.tableNo` on the old name. It goes through the plan-gated add, so on a capped plan the delete succeeds and the add is refused.

## 15. CartItem

**What it is.** One line in the restaurant cart ("2 × Paneer Tikka (Half) + Cheese, no onion") **and** the same class embedded as a line of every order and past order.

**Why the app needs it.** The cart is the working area before Place Order; once placed, each line is copied into the order and becomes a frozen snapshot used for KOTs, bills, refunds and EOD category sales.

| Fact | Value |
|---|---|
| Class / file | `CartItem extends HiveObject`, `.../cartmodel_308.dart:6-7` |
| typeId | **108** `restaurantCart` (`hive_type_ids.dart:65`) |
| Box | `'cart_box'` (`hive_box_names.dart:178`), opened `hive_init.dart:777`; repo literal `cart_repository.dart:17`. Also embedded in `OrderModel.items` (f4) and `PastOrderModel.items` (f3) |
| Hive key | **auto-int** (`_cartBox.add(item)`, `cart_repository.dart:128`); updates via `putAt(index)`, removal via `deleteAt(index)` (`:126-155`) |
| Retired index | **2**. Next free index: 17 |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Line id: UUID for menu/option lines; **the item id for weighed lines** (`weight_item_dialog_restaurant.dart:37`). Not the box key |
| 1 | title | String | req | – | required | Item name snapshot |
| 3 | price | double | req | – | required | **Unit price including the selected variant price and extras**: the variant price replaces the base, extras × their qty are added (`item_options_dialog.dart:222-252`). For weighed lines it is the **whole line amount** with quantity 1 |
| 4 | quantity | int (mutable) | req | – | `1` | Units. Hard-cast `fields[4] as int` |
| 5 | variantName | String? | opt | – | – | Variant label snapshot; stock is found by NAME (`cart_repository.dart:83-89`) |
| 6 | variantPrice | double? | opt | – | – | Display only; **not** added again (`finalItemPrice`, `:83`) |
| 7 | choiceNames | List<String>? | opt | – | – | Selected free choices |
| 8 | instruction | String? | opt | – | – | Kitchen note; also "Cancelled from KOT #n" on cancel-KOT print copies (`takeaway.dart:1170`) |
| 9 | taxRate | double? | opt | – | – | **Fraction** (0.18), copied from `Items.taxRate` |
| 10 | discount | double? | opt | – | – | Per-unit discount subtracted in `finalItemPrice` (`:86`). **No production writer**; restaurant line discounts are not carried here |
| 11 | weightDisplay | String? | opt | – | – | e.g. "1.75 kg"; part of equality |
| 12 | extras | List<Map<String,dynamic>>? | opt | – | – | Raw maps `{name, displayName, price, categoryName, categoryId, quantity}` (`item_options_dialog.dart:394-401`). Already folded into f3 |
| 13 | categoryName | String? | opt | – | – | Category snapshot; EOD category-sales key (`eod_service.dart:333`) |
| 14 | refundedQuantity | int? (mutable) | opt | – | – | Units refunded so far; meaningful only on past-order lines (`refund_service.dart:45-64`) |
| 15 | productId | String | req | – | required | **FK → `Items.id`**. Hard-cast `fields[15] as String`; stock lookup falls back to a title match (`cart_repository.dart:44-55`) |
| 16 | isStockManaged | bool? | opt | – | – | Snapshot of `Items.trackInventory` |

- **Getters:** `finalItemPrice = max(price − discount, 0)` (`:78-90`); `totalPrice = finalItemPrice × quantity` (`:92`) = gross line, before order discount and (exclusive mode) before GST.
- **Equality** (`:94-128`): title + variantName + weightDisplay + price (±0.001) + sorted choices + normalised extras; **not** id/productId. `CartRepository.addToCart` merges equal lines (`:28`).
- **Identifier:** `const Uuid().v4()` (`item_options_dialog.dart:360`, `menu.dart:731`, `menu_grid_screen.dart:188+`); weighed lines reuse the item id on purpose (it drives merging).
- **References:** `productId` → Items (live, for stock); `variantName` → VariantModel.name (live, by name); everything else is a snapshot.
- **Serialization:** `toMap`/`fromMap` (`:172-213`) match 1:1 for all 16 fields; `fromMap` defaults `id/title/productId` to `''` and `quantity` to 1. `copyWith` (`:129-169`) cannot clear nullable fields. Cart box backed up as `restaurantCart` and restored with `addAll` (index-based repo, so harmless).
- **Where used:** repo `data/repositories/restaurant/cart_repository.dart` (stock-validated `addToCart` `:23-135`, `removeFromCart`, `updateQuantity`, `clearCart` `:171`); store `domain/store/restaurant/cart_store.dart` (`CartStoreRes`, per-product computed `cartStateFor` `:94`). Embedded lines are written by every order writer and read by KOT/bill printing, KDS (`kds_handler.dart`), refunds and EOD.
- **Update/delete:** the cart is cleared after every place/settle (`customerdetails.dart:1395,1426,1583,1688`). Embedded lines are only changed by add-on KOTs, item cancel (line removed) and refunds (`refundedQuantity`).

## 16. OrderModel

**What it is.** An open (active) order: a running dine-in table, or a takeaway/delivery order that has been sent to the kitchen but not yet settled and moved to history.

**Why the app needs it.** It holds the lines, the KOT history, the kitchen status per KOT, and any partial payments until the order is finalized into a `PastOrderModel`.

| Fact | Value |
|---|---|
| Class / file | `OrderModel extends HiveObject`, `.../ordermodel_309.dart:8-9` |
| typeId | **109** `restaurantOrder` (`hive_type_ids.dart:66`) |
| Box | `'orderBox'` (`hive_box_names.dart:185`), opened `hive_init.dart:780` |
| Hive key | `order.id` (`order_repository.dart:25`); `updateOrder` scans keys for the matching id and `put`s under that key (`:49-66`) |

### Fields

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | PK. UUID on POS paths; **epoch-ms string** on Captain/KDS paths. Reused as the PastOrderModel id |
| 1 | customerName | String | req | – | required | Snapshot (`'Captain Order'` / `'Walk-in'` on server paths) |
| 2 | customerNumber | String | req | – | required | Phone snapshot (may be `''`) |
| 3 | customerEmail | String | req | – | required | Snapshot |
| 4 | items | List<CartItem> | req | – | required | Embedded snapshot lines **in KOT order** |
| 5 | status | String | req | – | required | `Processing` / `Cooking` / `Ready` / `Served` (persisted). Overall status is derived from KOT statuses (`activeorder.dart:1457-1479`) |
| 6 | timeStamp | DateTime | req | – | required | Order creation. Becomes `PastOrderModel.orderAt`; KOT #1 time fallback |
| 7 | orderType | String | req | – | required | `'Dine In'`, `'Take Away'`, `'Delivery'` |
| 8 | tableNo | String? | opt | – | – | `TableModel.id` (= name). `''` for non-table orders on POS paths |
| 9 | totalPrice | double | req | – | required | **Grand total** = `grandTotal` (incl. GST, service charge, round-off; after discount and loyalty) |
| 10 | kotNumber | int? | opt | – | – | **Deprecated**, never written; superseded by f21 |
| 11 | discount | double? | opt | – | – | Discount total in currency (regular discount only, excludes loyalty) |
| 12 | serviceCharge | double? | opt | – | – | Service-charge amount (delivery charge for Delivery) |
| 13 | paymentMethod | String? | opt | – | – | Display: single leg method or `'Split Payment'` |
| 14 | completedAt | DateTime? | opt | – | – | Last settle time |
| 15 | paymentStatus | String? | opt | – | – | `Unpaid` / `Paid` / `Partially Paid`; null on takeaway-screen orders |
| 16 | subTotal | double? | opt | – | – | Taxable base. Takeaway-screen orders in inclusive mode store `taxable − GST` (GST subtracted twice, `takeaway.dart:1483-1485`) |
| 17 | isPaid | bool? | opt | – | – | Convenience flag; truth is `amountDue` |
| 18 | gstRate | double? | opt | – | – | **Always 0** from POS writers |
| 19 | gstAmount | double? | opt | – | – | Total GST |
| 20 | remark | String? | opt | – | – | Dual meaning: kitchen remark OR discount reason / `'no Remark'` |
| 21 | kotNumbers | List<int> | req | – | required | KOT numbers in issue order (asserted non-empty, `:167`) |
| 22 | itemCountAtLastKot | int | req | – | required | `items.length` when the last KOT was printed; `getNewlyAddedItems = items.sublist(this)` (`:264-269`) |
| 23 | kotBoundaries | List<int> | req | – | required | Cumulative exclusive end index per KOT: `[3,5,6]` → KOT1 = items[0..3), KOT2 = [3..5), KOT3 = [5..6) |
| 24 | kotStatuses | Map<int,String>? | opt | – | – | Per-KOT status; `getKotStatus` falls back to f5 (`:296-303`) |
| 25 | orderNumber | int? | opt | – | – | Daily order number. Set by the takeaway screen and Captain; **not** by the customer-details place path nor KDS `/orders` |
| 26 | customerId | String? | opt | – | – | FK → Customer (UUID) |
| 27 | paymentListJson | String? | opt | – | – | JSON array of legs (money moved). Prior + new legs are merged on re-settle |
| 28 | isSplitPayment | bool? | opt | – | – | `legs.length > 1` |
| 29 | totalPaid | double? | opt | – | – | Money tendered, **accumulated** across settles |
| 30 | changeReturn | double? | opt | – | – | Change of the LAST settle only |
| 31 | isTaxInclusive | bool? | opt | – | – | Tax mode frozen at creation (`AppSettings.isTaxInclusive`) |
| 32 | billNumber | int? | opt | – | – | Set when a dine-in order is PAID before being served (`customerdetails.dart:1389-1394`), reused when moved to past |
| 33 | sessionId | String? | opt | – | – | Session at placement; refreshed to the current session on settle |
| 34 | lastModifiedBy | String? | opt | – | – | Stamped by every `OrderStore.updateOrder` (`order_store.dart:282-291`) |
| 35 | lastModifiedAt | DateTime? | opt | – | – | Same |
| 36 | kotTimestamps | Map<int,DateTime>? | opt | – | – | Creation time of add-on KOTs; KOT #1 falls back to f6; read by KDS (`kds_handler.dart:86`) |

### Validation rules and defaults
- Constructor asserts `kotNumbers`/`kotBoundaries` non-empty and of equal length (`:167-169`), **debug-only**.
- `amountDue = totalPrice − totalPaid` (`:174-180`).
- **KOT encoding:** new order → `kotNumbers [k]`, `kotBoundaries [items.length]`, `itemCountAtLastKot = items.length` (`customerdetails.dart:1657-1659`). Add-on → append items, append the new KOT number and the new `items.length` boundary (`order_repository.dart:148-183`, `takeaway.dart:1698-1739`). Item cancel → remove the line, decrement every boundary from that KOT on, drop a KOT that became empty (`activeorder.dart:1540-1567`). Invariant: `kotBoundaries.last == items.length`. `getItemsByKot` (`:277-293`) has **no bounds guards** (the PastOrderModel version clamps).
- **Counters** (raw `appCounters`): KOT number from `OrderRepository.getNextKotNumber` (`:71-86`, resets per calendar day); the Captain append path uses `HiveOrders.getNextKotNumber` (`hive_order.dart:46-55`), which writes the **same key without the daily reset**. A cancel-KOT print consumes a KOT number (`takeaway.dart:1167`).

### Identifier
`Uuid().v4()` on POS paths (`customerdetails.dart:1512`, `takeaway.dart:1467`); epoch-ms on server paths (`captain_handler.dart:248`, `order_handler.dart:24`). The past order reuses this id, so both formats reach `pastorderBox`.

### References
`tableNo` → TableModel (by name); `customerId` → Customer; `sessionId` → RestaurantSessionModel; `items[].productId` → Items. Staff only by name (`lastModifiedBy`). Snapshots: customer name/phone/email, every line.

### Serialization
- **`toMap` (`:306-341`) omits `billNumber`, `sessionId`, `lastModifiedBy`, `lastModifiedAt` and `kotTimestamps`, and `fromMap` (`:343-396`) does not read them.** Backup exports active orders with `toMap()` (`unified_backup_service.dart:785`) and restores with `fromMap` (`:2261`). After a restore, a paid-not-served dine-in order loses its bill number (a new one is issued on serve) and every open order loses its `sessionId`, so EOD's session filter cannot attribute it once it moves to past.
- `paymentListJson` uses the same key both ways (`:335`, `:390`).
- `fromMap` hard-casts `id`, `customerName`, `customerNumber`, `customerEmail`, `status`, `orderType`, `totalPrice`, `kotNumbers`, `kotBoundaries`; ints go through `_toInt`; `kotStatuses` keys are re-parsed from JSON strings (`:383-387`).
- `copyWith` (`:183-261`) uses `??`; it cannot clear anything (e.g. `tableNo`).

### Where it is created and read
- Repo `data/repositories/restaurant/order_repository.dart` (CRUD `:24-66`, counters `:71-144`, `updateOrderWithNewItems` `:148`; unused `markOrderAsPaid`, `bulkUpdateOrderStatus`, `deleteOrdersByDateRange`, `deleteAllOrders`). Store `domain/store/restaurant/order_store.dart` (`loadOrders` with crash reconcile `:240-252`, `addOrder :262`, `updateOrder :276`, `deleteOrder :300`, `updateOrderStatus :315`, `getActiveOrderByTableId :570`).
- Writers: `start order/cart/takeaway.dart` (place, add-on, cancel), `cart/customerdetails.dart` (place, settle), `tabbar/activeorder.dart` (KOT status, void, move to past), `end day/endday.dart` (resolution), and the local server (`server/handlers/order_handler.dart`, `captain_handler.dart`, `kds_handler.dart`) which writes through the static `HiveOrders` helper, outside the store.

### Update and delete
- Updated in place for KOT status, add-on items, partial payments and item cancels.
- **Deleted** once it has been moved to `pastorderBox` (`customerdetails.dart:1501`, `activeorder.dart:228,1534`, `endday.dart:633,683`). Crash safety: settlement checks the past box first, and `loadOrders` deletes any active order whose id already exists in `pastorderBox`.
- EOD blocks until every active order is resolved by the manager (complete service, refund, or void-if-unpaid; `endday.dart:711-724`).

## 17. PastOrderModel

**What it is.** A finalized bill: settled, voided, or later refunded. This is the restaurant "sale" record.

**Why the app needs it.** Every report, EOD, shift total, cash-drawer expected cash, refund and reprint reads it. It is never deleted.

| Fact | Value |
|---|---|
| Class / file | `PastOrderModel extends HiveObject`, `.../pastordermodel_313.dart:11-13` |
| typeId | **113** `restaurantPastOrder` (`hive_type_ids.dart:70`) |
| Box | `'pastorderBox'` (`hive_box_names.dart:188`), opened `hive_init.dart:787` |
| Hive key | `id` (`past_order_repository.dart:21,31`) = the active order's id, or a fresh UUID for Settle & Print / Quick Settle |

### Fields

Index 35 (`voidReason`) is declared between 31 and 32 in the source (`:117-118`); that is valid.

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | PK |
| 1 | customerName | String | req | – | required | Snapshot (`'Quick Settle'` on quick settle) |
| 2 | totalPrice | double | req | – | required | **Canonical grand total**, gross. Refunds are NOT subtracted here; net = `totalPrice − refundAmount` |
| 3 | items | List<CartItem> | req | – | required | Snapshot lines; `refundedQuantity` mutated by refunds |
| 4 | orderAt | DateTime? | opt | – | required (nullable) | **Order CREATION time** (`activeModel.timeStamp`), not settlement. Used by shift attribution, refund window and date filters |
| 5 | kotNumber | int? | opt | – | – | Deprecated, never written |
| 6 | orderType | String? | opt | – | required (nullable) | |
| 7 | paymentmode | String? | opt | – | required (nullable) | Display/bucket fallback: method, `'Split Payment'`, `'Cash'`, `'N/A'` for VOID |
| 8 | remark | String? | opt | – | – | Discount reason or kitchen remark (dual meaning) |
| 9 | subTotal | double? | opt | – | – | Taxable base (after discount/loyalty, pre-GST) |
| 10 | Discount | double? | opt | – | – | Capitalised name; regular discount total |
| 11 | gstRate | double? | opt | – | – | **Always 0** from every writer |
| 12 | gstAmount | double? | opt | – | – | Total GST |
| 13 | isRefunded | bool? | opt | – | – | **Dead**: only the demo generator writes it |
| 14 | refundReason | String? | opt | – | – | Append-only log `"\n[yyyy-MM-dd HH:mm] <staff>: <reason>"` (`refund_service.dart:86-87`); `voidOrder` overwrites it with `'VOIDED: <reason>'` |
| 15 | refundAmount | double? | opt | – | – | **Cumulative, POSITIVE** money refunded |
| 16 | refundedAt | DateTime? | opt | – | – | Last refund or past-order void time; EOD uses it for the refund window |
| 17 | orderStatus | String? (mutable) | opt | – | `'COMPLETED'` | `COMPLETED`, `VOID`, `VOIDED`, `PARTIALLY_REFUNDED`, `FULLY_REFUNDED`. `CANCELLED` is never written |
| 18 | kotNumbers | List<int> | req | – | required | Copied from the active order |
| 19 | kotBoundaries | List<int> | req | – | required | Copied |
| 20 | billNumber | int? | opt | – | – | Sequential bill no., **resets per financial year** (the "Daily" comment at `:80` is stale). Null on unpaid VOID unless the order already had one |
| 21 | paymentListJson | String? | opt | – | – | Legs (money moved). Null on Quick Settle and VOID → `paymentList` falls back to `{paymentmode, totalPrice}` (`:417-432`) |
| 22 | isSplitPayment | bool? | opt | – | – | |
| 23 | totalPaid | double? | opt | – | – | Tendered. Null on Quick Settle/VOID → `amountDue` treats null/0 as fully paid (`:190-193`) |
| 24 | changeReturn | double? | opt | – | – | |
| 25 | isTaxInclusive | bool? | opt | – | – | Frozen mode. Missing on paid-void records |
| 26 | tableNo | String? | opt | – | – | Table name snapshot |
| 27 | loyaltyPointsUsed | int? | opt | – | – | Points redeemed; restored proportionally on refund (`refund_service.dart:99-110`) |
| 28 | shiftId | String? | opt | – | – | `RestaurantSession.currentShiftId` at SETTLEMENT |
| 29 | sessionId | String? | opt | – | – | Session the bill belongs to for EOD |
| 30 | discountAppliedBy | String? | opt | – | – | `'Admin'` or `'<name> (<role>)'` |
| 31 | voidedBy | String? | opt | – | – | Same label; `'EOD by <staff>'` on EOD voids |
| 32 | refundedBy | String? | opt | – | – | Last refunder label |
| 33 | customerId | String? | opt | – | – | FK → Customer; needed for loyalty restore |
| 34 | serviceCharge | double? | opt | – | – | Amount |
| 35 | voidReason | String? | opt | – | – | Set by Active-Orders void and EOD void only |
| 36 | taxEnabled | bool? | opt | – | – | `TaxFeature.enabled` snapshot (null → `TaxFeature.forRecord` live) |
| 37 | storeGstNumber | String? | opt | – | – | GSTIN snapshot; `''` = none, null = legacy |
| 38 | roundOffStep | double? | opt | – | – | Round-off step at settlement (0 = off). The round-off AMOUNT is not stored; reprints recompute it |
| 39 | discountOnItems | bool? | opt | – | – | Setting snapshot for reprint math |

### Validation rules and defaults
- Getters: `amountDue`, `isFullyPaid` (`:190-194`), `paymentList` (`:417-432`), `paymentDisplay` (`:437-448`), clamped `getItemsByKot` (`:288-322`).
- **VOID vs VOIDED:** `VOID` = removed before any payment (`paymentmode 'N/A'`, no legs; `activeorder.dart:176`, `endday.dart:661`). `VOIDED` = money had been collected; legs/`totalPaid` kept so a refund can follow. A refund on a `VOIDED` order keeps `VOIDED`. Test with `OrderStatusFilter.isVoided`; `ShiftRepository._restaurantTxns` uses its own literal list (`shift_repository.dart:85-99`).
- **No credit:** a partly-paid dine-in finalized at EOD keeps `amountDue > 0` on a COMPLETED record; `totalSales` counts the full `totalPrice` while the cash bucket counts only money moved.

### Writers (which fields each path fills)

| Path | File:line | Status | Notable gaps |
|---|---|---|---|
| Settle (takeaway/delivery/served/auto-serve) | `customerdetails.dart:1443-1504` `completeOrder` | COMPLETED | Full set. **Always takes a NEW bill number**, ignoring the order's stored one (`:1450`) |
| Settle & Print (no active order) | `customerdetails.dart:1524-1567` | COMPLETED | Full set; deducts stock (`:1570`) |
| Quick Settle | `takeaway.dart:3283-3322` | COMPLETED | No `paymentListJson`, `totalPaid`, `changeReturn`, `customerId`, `Discount`, `serviceCharge`, `loyaltyPointsUsed`. Stores the method **name**, not the value (rest notes 05, inferred) |
| Move to past on Served | `activeorder.dart:1491-1538` `_moveOrderToPast` | COMPLETED | No `customerId`, `loyaltyPointsUsed`, `shiftId`, `discountAppliedBy`, `gstRate`. Reuses the stored `billNumber` |
| EOD "complete service" | `endday.dart:602-640` | COMPLETED | No `loyaltyPointsUsed`, `discountAppliedBy`, `remark`; `shiftId` = closer's shift |
| Void from Active Orders | `activeorder.dart:135-230` | VOID / VOIDED | No `shiftId`, `changeReturn`, `customerId`, `isTaxInclusive`, `serviceCharge`, `loyaltyPointsUsed`. Restores stock for non-Served KOTs |
| EOD void (zero payment) | `endday.dart:645-688` | VOID | Restores stock only if the order is `Processing` |

`takeaway.dart:2909 completeOrder` is dead (no callers).

### Identifier
The active order's id (UUID or epoch-ms), or `Uuid().v4()` for Settle & Print / Quick Settle (`takeaway.dart:3293`).

### References
`customerId` → Customer; `sessionId` → Session; `shiftId` → ShiftModel (the only order→shift link); `items[].productId` → Items (for restock). Staff by name only. `ItemCancellationModel.orderId` points here after the move.

### Serialization
- `toMap`/`fromMap` (`:325-414`): keys match for all 40 fields. `fromMap` casts `kotNumbers` elements with `e as int` (fails on JSON doubles) and defaults them to `[1]`/`[0]` when absent (`:391`); `orderStatus` defaults to `'COMPLETED'`.
- `copyWith` (`:196-280`): the parameter is spelled `customername` but the body uses `customerName ?? this.customerName` (the field), so the customer name can never be changed through it. `paymentMode` param maps to `paymentmode`.
- Backed up as `pastOrders` (`unified_backup_service.dart:877-886`), restored with `putAll(id)` (`:2260`).

### Where it is created and read
Repo `past_order_repository.dart`; store `past_order_store.dart`. Readers: EOD (`domain/services/restaurant/eod_service.dart:35-291`), `PaymentModeSummary`, `ShiftRepository._restaurantTxns` (`shift_repository.dart:91-113`), cash drawer, `DayManagementService` (`:223,325`), all `Reports/` screens (via `OrderStatusFilter`), reprint (`util/restaurant_print_helper.dart:748,774` uses the stored `billNumber`).

### Update and delete
- **Refund** (`RefundService.processRefund`, `refund_service.dart:30-116`, gated by `EntKeys.billingReturns`, window `AppSettings.refundWindowMinutes` from `orderAt`): distributes refunded qty over lines by group key `productId_variant_extras_choices`, sets `PARTIALLY_/FULLY_REFUNDED` (or keeps `VOIDED`), adds to `refundAmount`, appends `refundReason`, stamps `refundedAt/refundedBy`, restocks, restores loyalty `round(pointsUsed × refund/totalPrice)`.
- **Void of a past order** (`RefundService.voidOrder`, `:200-229`): status `VOIDED`, no restock, no refund amount, overwrites `refundReason`, does **not** set `voidReason`.
- **Never deleted** by app flows (`data_clear_service.dart` preserves them).

## 18. ItemCancellationModel

**What it is.** An audit row: "1 × Paneer Tikka cancelled from KOT 14 on table T3 by Ravi, reason: customer changed mind".

**Why the app needs it.** The Item Cancellation report and fraud review. Cancelling an item already sent to the kitchen otherwise leaves no trace, because the line is removed from the order.

| Fact | Value |
|---|---|
| Class / file | `ItemCancellationModel extends HiveObject`, `.../item_cancellation_model_134.dart:9-69` |
| typeId | **134** `restaurantItemCancellation` (`hive_type_ids.dart:104`) |
| Box | `'restaurantItemCancellationsBox'` (`hive_box_names.dart:233`), opened `hive_init.dart:821` |
| Hive key | `record.id` (`item_cancellation_repository.dart:11`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | itemName | String | req | – | required | `CartItem.title` snapshot |
| 2 | variantName | String? | opt | – | – | |
| 3 | quantity | int | req | – | required | Units cancelled (positive) |
| 4 | amount | double | req | – | required | `item.price × qty`: gross unit price, pre-discount, tax per order mode |
| 5 | reason | String | req | – | required | Staff reason or `'No reason given'` |
| 6 | orderId | String | req | – | required | FK → OrderModel.id (later PastOrderModel.id) |
| 7 | billNumber | int? | opt | – | – | **Never written** |
| 8 | kotNumber | int? | opt | – | – | KOT the item was on (null when 0) |
| 9 | staffName | String? | opt | – | – | |
| 10 | timestamp | DateTime | req | – | required | |
| 11 | sessionId | String? | opt | – | – | |
| 12 | orderType | String? | opt | – | – | |
| 13 | tableNo | String? | opt | – | – | |

- **Identifier:** `Uuid().v4()` (`takeaway.dart:1145,1773`).
- **Writers:** single-item cancel (`takeaway.dart:1136-1160`) and bulk corrections on update (`:1761-1793`), both in try/catch so a failure never blocks the order. **Not written** by the Captain modify path (`captain_handler.dart:329-445`) nor by `activeorder.dart:1540 _cancelKotItem` (reachability **unverified**), so the audit is incomplete.
- **Serialization:** no `toMap`/`fromMap`/`copyWith`. **Not in backup**; a restore loses the cancellation history.
- **Where used:** repo `data/repositories/restaurant/item_cancellation_repository.dart` (`add :10`, `getAll`, `delete :21`); report `Reports/item Cancellation Report/itemCancellationReport.dart:67`.
- **Update/delete:** append-only in practice.

## 19. PaymentMethod (shared)

**What it is.** A tender type: Cash, Card, UPI, or a custom one ("Zomato Pay").

**Why the app needs it.** It drives the payment buttons, and its `value` is the reporting bucket key stored on each payment leg.

| Fact | Value |
|---|---|
| Class / file | `PaymentMethod extends HiveObject`, `lib/models/payment_method.dart` |
| typeId | **literal `6`** (`:5`), the only hard-coded typeId in the project |
| Box | `'paymentMethodsBox'` (shared, common open `hive_init.dart:194`, seeded at `:197-198, 206-264`) |
| Hive key | **auto-int** (`box.add`, `hive_init.dart:262`). The `id` field is NOT the key |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (not the key) |
| 1 | name | String | req | – | required | Display name |
| 2 | value | String | req | – | required | **Reporting bucket key** (`cash`, `card`, `upi`, …). Payment legs and `paymentmode` store this string |
| 3 | iconName | String | req | – | required | |
| 4 | isEnabled | bool | req | – | `true` | |
| 5 | sortOrder | int | req | – | `0` | |

- **Restaurant screen:** `lib/presentation/screens/restaurant/Settings/paymentsMethods.dart`.
- **Restaurant defect:** the edit dialog rewrites `value` from the edited name, `name.toLowerCase().replaceAll(' ', '_')` (`:167-171`), **for built-in methods too**. Renaming "Cash" to "Cash Payment" moves the bucket from `'cash'` to `'cash_payment'`, which splits reports and breaks cash-drawer logic keyed on `'cash'`; the UPI check `method.value == 'upi'` (`:151`) also stops matching. Retail keeps `value` for built-ins.
- **Method strings on orders** are lower-case UI values; `PaymentModeSummary.normalizeMethod` buckets them case-insensitively (`util/restaurant/payment_mode_summary.dart:72-90`).
- **Update/delete:** by position (`putAt`/`deleteAt`); hard delete with no history guard; past orders keep the string.
- Restore: `clear` + `add()` (`unified_backup_service.dart:2015-2028`); fine because the repo is index-based.
- Retail view: [Retail §17 PaymentMethod](../retail/02_RETAIL_DATABASE_MODELS.md#17-paymentmethod-shared).

## 20. Customer (shared)

**What it is.** A guest: name, phone, food preference, favourite items, loyalty points.

**Why the app needs it.** Named orders (delivery, takeaway), loyalty earn/redeem, and customer history.

| Fact | Value |
|---|---|
| Class / file | `Customer extends HiveObject`, `lib/data/models/common/customer_model_125.dart` |
| typeId | **125** `HiveTypeIds.customer` (`hive_type_ids.dart:85`) |
| Box | `'customers'`, one shared physical box; restaurant open `hive_init.dart:805` |
| Hive key | `customerId` (`customer_repository.dart:15,20,56,61`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning (restaurant) |
|---|---|---|---|---|---|---|
| 0 | customerId | String | req | – | required | Id / key (UUID in restaurant) |
| 1 | name | String? | opt | – | – | |
| 2 | phone | String? | opt | – | – | |
| 3 | totalVisites (sic) | int | req | – | `0` | Visit count |
| 4 | lastVisitAt | String? | opt | – | – | |
| 5 | lastorderType | String? | opt | – | – | **Restaurant only**: last order type |
| 6 | favoriteItems | String? | opt | – | – | **Restaurant only** |
| 7 | foodPrefrence (sic) | String? | opt | – | – | **Restaurant only** (veg / non-veg …) |
| 8 | notes | String? | opt | – | – | |
| 9 | loyaltyPoints | int | req | – | `0` | Current points balance |
| 10 | createdAt | String | req | – | required | |
| 11 | updatedAt | String? | opt | – | – | `copyWith` sets now |
| 12 | email | String? | opt | – | – | |
| 13 | address | String? | opt | – | – | Delivery address |
| 14 | gstNumber | String? | opt | – | – | |
| 15 | totalPurchaseAmount | double | req | **0.0** | `0.0` | Lifetime spend |
| 16 | totalPointEarned | int | req | **0** | `0` | |
| 17 | totalPointRedeemed | int | req | **0** | `0` | |
| 18 | creditBalance | double | req | **0.0** | `0.0` | **Always 0 in restaurant** (no credit) |
| 19 | creditLimit | double | req | **0.0** | `0.0` | **Always 0 in restaurant** |

- **Identifier (restaurant):** UUID v4 (`customer/customer_form_dialog.dart:135`, `customer/manage_customers_screen.dart:735`, `start order/cart/customerdetails.dart:2075`, `start order/cart/takeaway.dart:1339`). Retail uses `CUST-000042`, so a device's ids follow the mode that created them.
- **References:** referenced by `OrderModel.customerId` and `PastOrderModel.customerId` (missing on several past-order writers, see §17).
- **Serialization:** `fromMap` fully defensive; `copyWith` clear flags `clearEmail`, `clearAddress`, `clearGstNumber`, `clearNotes`, `clearFoodPrefrence`.
- **Where used:** repo `lib/data/repositories/common/customer_repository.dart`; store `lib/domain/store/common/customer_store.dart` (screens must call `loadCustomers()` themselves). Loyalty points are deducted at payment (`customerdetails.dart:1396-1400`) and restored proportionally on refund.
- **Delete:** restaurant **does** expose a hard delete (`customer_list_screen.dart:96-114`, `customer_detail_screen.dart:139-160`, `manage_customers_screen.dart:775-776`); the store method has no guard and no plan gate (`customer_store.dart:191-203`). `PastOrderModel.customerId` then dangles; orders keep the `customerName` snapshot.
- Retail view: [Retail §18 Customer](../retail/02_RETAIL_DATABASE_MODELS.md#18-customer-shared).

---

# Purchasing

Restaurant has its **own** procurement models (typeIds 138-149 and 185), separate from retail's `SupplierModel`/`PurchaseOrderModel`/… (155-181). They share only the mechanisms: `DocumentNumberService` numbering in `appCounters` and the `StockMovementModel` box. All timestamps on these models are ISO-8601 **Strings**, not `DateTime`.

**Document numbering** (`lib/domain/services/common/document_number_service.dart:31-91`): format `PREFIX-00001` (five digits), counter keys `<P>_lastSeq` / `<P>_lastFy` (+ optional `<P>_prefix`) in `appCounters`, reset each **financial year**. The counter is mode-agnostic, so retail and restaurant share the `PO` and `GRN` series. Restaurant prefixes: `PO` (`restaurant_purchase_order_repository.dart:38-43`), `GRN` (`restaurant_grn_repository.dart:36-41`), `PR`, `CLM`, `LOSS` (`restaurant_damaged_goods_store.dart:53-55`), `ST` (`restaurant_stock_take_store.dart:51`). Several model doc comments still show the old daily format (`PO-20260824-001`, `PR-20260813-001`); they are stale.

## 21. RestaurantSupplierModel

**What it is.** A vendor the kitchen buys from ("Fresh Dairy Co."), with what the restaurant currently owes it.

**Why the app needs it.** POs and GRNs are raised against a supplier, and every GRN, credit note, claim settlement and payment moves its balance.

| Fact | Value |
|---|---|
| Class / file | `RestaurantSupplierModel`, `.../restaurant_supplier_model.dart:12` |
| typeId | **138** `restaurantSupplier` (`hive_type_ids.dart:114`) |
| Box | `'restaurantSuppliersBox'` (`hive_box_names.dart:242`), opened `hive_init.dart:828` |
| Hive key | `supplierId` (`restaurant_supplier_repository.dart:14`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | supplierId | String | req | – | required | UUID (`:67`) / key |
| 1 | name | String | req | – | required | |
| 2 | phone | String? | opt | – | – | |
| 3 | address | String? | opt | – | – | |
| 4 | gstNumber | String? | opt | – | – | |
| 5 | currentBalance | double | req | – | `0` | **Positive = we owe the supplier.** `.create` sets it to `openingBalance` (`:74`). Moved only by `recordBalanceMovement` |
| 6 | createdAt | String (ISO) | req | – | required | |
| 7 | updatedAt | String (ISO) | req | – | required | Re-stamped by `copyWith` (`:100`) |
| 8 | openingBalance | double | req | **0.0** | `0` | Liability brought in at creation; posted once as the `opening` ledger row |

- **Validation:** none in the store beyond the UI form.
- **Identifier:** UUID v4 in the factory.
- **References:** referenced by PO, GRN, return, claim, loss and ledger rows (`supplierId` + `supplierName` snapshot).
- **Serialization:** `copyWith` clear flags `clearPhone`, `clearAddress`, `clearGstNumber` (`:80-102`). Backed up (`restaurantSuppliers`).
- **Where used:** repo `restaurant_supplier_repository.dart`; store `restaurant_supplier_store.dart` (DI getter `:61`); screens `inventory/supplier/*`.
- **Update:** `updateSupplier` (`:139-156`) saves `supplier.copyWith(...)` from the screen's snapshot, so it can carry a stale `currentBalance` (low risk).
- **Delete:** the UI (`restaurant_supplier_detail_screen.dart:91-130`) refuses when `referencesFor` finds POs, GRNs, returns or claims, or when `currentBalance != 0`. `deleteSupplier` (`restaurant_supplier_store.dart:162-167`) re-checks nothing, deletes **all the supplier's ledger rows**, then the supplier. A zero-balance supplier with payment history can be deleted and that history is destroyed.

## 22. RestaurantSupplierLedgerEntryModel

**What it is.** One line of a supplier's account: opening balance, purchase (GRN), return credit, claim credit, payment or adjustment, with the running balance after it.

**Why the app needs it.** The supplier statement and the reconciliation check against `currentBalance`.

| Fact | Value |
|---|---|
| Class / file | `RestaurantSupplierLedgerEntryModel`, `.../restaurant_supplier_ledger_entry_model.dart:45` |
| typeId | **185** `restaurantSupplierLedgerEntry` (`hive_type_ids.dart:206`), the only restaurant model in the overflow range |
| Box | `'restaurantSupplierLedgerBox'` (`hive_box_names.dart:284`), opened `hive_init.dart:844-845` |
| Hive key | `entryId` (`restaurant_supplier_ledger_repository.dart:13-17`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | entryId | String | req | – | required | UUID (`:145`) / key |
| 1 | supplierId | String | req | – | required | FK → RestaurantSupplierModel |
| 2 | date | String (ISO) | req | – | required | When it happened (`date ?? now` in the factory); payments can be back-dated; GRN rows use `receivedDate` |
| 3 | type | String | req | – | required | `RestaurantSupplierLedgerType.name`: `opening`, `purchase`, `returnCredit`, `claimCredit`, `payment`, `adjustment` (`:17-24`). Unknown → adjustment (`:161-165`) |
| 4 | amount | double | req | – | required | **Signed**: + increases what is owed |
| 5 | balanceAfter | double | req | – | required | Stored running balance |
| 6 | description | String | req | – | required | |
| 7 | docNumber | String? | opt | – | – | `GRN-…` / `PR-…` / `CLM-…` |
| 8 | docId | String? | opt | – | – | Source document id |
| 9 | paymentMode | String? | opt | – | – | Payments only |
| 10 | referenceNo | String? | opt | – | – | |
| 11 | note | String? | opt | – | – | |
| 12 | createdAt | String | req | – | required | Write time (factory: now) |
| 13 | seq | int | req | **0** | `0` | Per-supplier ordinal, tie-break after date |

- **Ordering:** `compareRestaurantLedgerEntries` sorts by date then `seq` (`:228-235`); `summariseRestaurantLedger` folds rows into buckets and takes the closing balance from the last row's `balanceAfter` (`:296-336`). The repo's `getAll()` sorts by date only (`restaurant_supplier_ledger_repository.dart:28-30`).
- **Writer (the choke point):** `RestaurantSupplierStore.recordBalanceMovement` (`restaurant_supplier_store.dart:178-230`): backfill an opening row if missing → `balanceAfter = repo supplier.currentBalance + amount` → `seq = max+1` → save the row → save the supplier → reload. Not serialised: two concurrent calls can race. Direct-write exceptions: the `opening` row in `addSupplier` (`:115-129`) and `_backfillOpeningIfNeeded` (`:240-256`). Callers: GRN confirm, credit note, claim settle, payment/adjustment dialog (`restaurant_supplier_payment_dialog.dart:87-97`).
- **Serialization:** backed up (`restaurantSupplierLedger`, export `:990`, restore `:2459`). An older backup without this key leaves the device's rows in place (`restoreBoxWithId` returns without clearing when the key is absent).
- **Update/delete:** append-only, except `deleteBySupplier` (`:39-45`) on supplier delete.
- Retail counterpart: [Retail §21](../retail/02_RETAIL_DATABASE_MODELS.md#21-supplierledgerentrymodel).

## 23. RestaurantPurchaseOrderModel

**What it is.** An order the kitchen sends to a supplier: "PO-00012: 10 kg paneer, 5 L cream, expected Friday".

**Why the app needs it.** GRNs are received against PO lines; the PO status shows what is still outstanding.

| Fact | Value |
|---|---|
| Class / file | `RestaurantPurchaseOrderModel`, `.../restaurant_purchase_order_model.dart:23` |
| typeId | **139** `restaurantPurchaseOrder` (`hive_type_ids.dart:115`) |
| Box | `'restaurantPurchaseOrdersBox'` (`hive_box_names.dart:245`), opened `hive_init.dart:829` |
| Hive key | `poId` (`restaurant_purchase_order_repository.dart:24`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | poId | String | req | – | required | UUID from the store (`restaurant_purchase_order_store.dart:116`) / key |
| 1 | poNumber | String | req | – | required | `PO-00001` (the comment `PO-20260824-001` at `:29` is stale) |
| 2 | supplierId | String | req | – | required | FK |
| 3 | supplierName | String? | opt | – | – | Snapshot |
| 4 | expectedDeliveryDate | String (ISO) | req | – | required | |
| 5 | totalItems | double | req | – | `0` | **Sum of ordered quantity**, not a line count |
| 6 | estimatedTotal | double | req | – | `0` | Σ qty × estimated price |
| 7 | status | String | req | – | required | `RestaurantPOStatus.name`: `draft`, `sent`, `partiallyReceived`, `completed`, `cancelled` (`:12-18`). Unknown reads as draft (`:99-102`) |
| 8 | notes | String? | opt | – | – | `copyWith` cannot clear it (`:128`) |
| 9 | createdAt | String | req | – | required | |
| 10 | updatedAt | String | req | – | required | |

- **Getters:** `canEdit` = draft; `canReceive` = sent or partiallyReceived; `isCompleted` = completed or cancelled (`:104-108`). **`cancelled` is unreachable** (no setter); a short-closed PO stays `partiallyReceived` forever.
- **Create** (`createPurchaseOrder`, `:104-153`): mint `PO` number (writes `appCounters` even if the save fails) → header (draft) → lines. No store validation; the screen checks qty > 0.
- **Edit** (`updatePurchaseOrder`, `:180-248`): only a draft with no GRN; deletes all lines, recreates them with **new `poItemId`s**, then rewrites the header keeping number/createdAt/status.
- **Status:** `markPOSent` (`:155-164`) has no state guard in the store. GRN confirm rolls it up: `Σ confirmed GRN totalReceivedQty ≥ totalItems` → completed; > 0 → partiallyReceived (`:410-426`). Header totals are compared, so surplus on one line can close a shortfall on another, and damaged units count as received.
- **Delete:** draft with no GRN only (`canDeletePurchaseOrder`, `:272-276`); lines first, then header.
- **Where used:** repo `restaurant_purchase_order_repository.dart`; store `restaurant_purchase_order_store.dart`; screens `inventory/purchase_order/add_purchase_order_screen.dart`, `purchase_order_list_screen.dart`, `goods_receiving_screen.dart`.

## 24. RestaurantPurchaseOrderItemModel

**What it is / why.** One line of a PO: item, ordered quantity, estimated price.

| Fact | Value |
|---|---|
| Class / file | `RestaurantPurchaseOrderItemModel`, `.../restaurant_purchase_order_item_model.dart:12` |
| typeId | **140** `restaurantPurchaseOrderItem` (`hive_type_ids.dart:116`) |
| Box | `'restaurantPurchaseOrderItemsBox'` (`hive_box_names.dart:248`), opened `hive_init.dart:830` |
| Hive key | `poItemId` (PO repo `:48,54`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | poItemId | String | req | – | required | UUID (`:57`) / key. **Re-minted on every PO edit** |
| 1 | poId | String | req | – | required | FK → PO |
| 2 | itemId | String | req | – | required | FK → `Items.id`. The picker allows Raw Material **or** Finished Good (`add_purchase_order_screen.dart:944-946`); the field comment "must be a Raw Material" is stale |
| 3 | itemName | String? | opt | – | – | Snapshot |
| 4 | orderedQty | double | req | – | required | |
| 5 | estimatedPrice | double? | opt | – | – | Per unit; seeds the GRN cost (`estimatedPrice ?? 0`) |
| 6 | estimatedTotal | double? | opt | – | – | qty × price, or null (`:63`) |
| 7 | createdAt | String | req | – | required | |

- **Received quantity is not stored.** The receiving screen computes `remaining = orderedQty − Σ receivedQty of every GRN item for that poItem` (damaged included, header status not checked; `goods_receiving_screen.dart:73-100`; repo `getTotalReceivedQtyForPOItem`, `restaurant_grn_repository.dart:67-71`).
- No `copyWith`; lines are deleted and recreated (`restaurant_purchase_order_store.dart:229-239`). `deleteItemsByPOId` loops `delete` (`:57-62`).

## 25. RestaurantGRNModel

**What it is.** A Goods Received Note: "GRN-00007 against PO-00012, received 14 Oct, supplier invoice INV/883".

**Why the app needs it.** Receiving is the only way purchased stock enters inventory, the only event that updates `lastPurchaseCost`, and the event that bills the supplier.

| Fact | Value |
|---|---|
| Class / file | `RestaurantGRNModel`, `.../restaurant_grn_model.dart:16` |
| typeId | **141** `restaurantGrn` (`hive_type_ids.dart:117`) |
| Box | `'restaurantGrnsBox'` (`hive_box_names.dart:252`), opened `hive_init.dart:831` |
| Hive key | `grnId` (`restaurant_grn_repository.dart:26`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | grnId | String | req | – | required | UUID (`:101`) / key |
| 1 | grnNumber | String | req | – | required | `GRN-00001`, minted by the caller |
| 2 | poId | String | req | – | required | FK |
| 3 | poNumber | String | req | – | required | Snapshot |
| 4 | supplierId | String | req | – | required | FK |
| 5 | supplierName | String? | opt | – | – | Snapshot |
| 6 | receivedDate | String | req | – | required | Date-picker value, up to 30 days back (`goods_receiving_screen.dart:105-110`); also the ledger row date |
| 7 | totalOrderedQty | double | req | – | `0` | Σ of the **full PO-line orderedQty** for the received lines (not the remaining qty), so `isFullyReceived` (`:126`) misleads on a second partial GRN |
| 8 | totalReceivedQty | double | req | – | `0` | Σ receivedQty, **damaged included** |
| 9 | totalAmount | double? | opt | – | – | Σ receivedQty × costPrice = the **billed** value (store `:315-316`) |
| 10 | status | String | req | – | required | Enum `{draft, confirmed, cancelled}` (`:11`); **only `confirmed` is ever written** |
| 11 | notes | String? | opt | – | – | |
| 12 | invoiceNumber | String? | opt | – | – | Supplier invoice number. There is no tax field |
| 13 | createdAt | String | req | – | required | |
| 14 | updatedAt | String | req | – | required | |

- **Writer:** `RestaurantPurchaseOrderStore.confirmGRN` (`restaurant_purchase_order_store.dart:289-435`). It does not check `po.canReceive` or the item type. Order: totals → mint GRN number (`appCounters`) → per line: save GRN item, skip if `acceptedQty ≤ 0` or the item was deleted (the line is **still billed**), `itemStore.applyStockDelta(itemId, +acceptedQty, lastPurchaseCost: costPrice)` (item-level, no variant, no `trackInventory` check), stock movement `in` / `Purchase (PO-…)` with **no `unitCost`** → save GRN header → if `totalAmount > 0`, `recordBalanceMovement(+totalAmount, purchase)` → PO roll-up → reload. Then the screen calls `RestaurantDamagedGoodsStore.recordFromGRN` for damaged lines.
- **Semantics:** cost = **last cost overwrites** (a null cost keeps the old one); the supplier is billed the full received value including damaged units; stock for a variant item lands on `Items.stockQuantity`, which variant sales never read; stock for a `trackInventory=false` item still goes up.
- **Crash safety:** none. GRN items are written before the header and count as received even without one; no idempotency key, so a retry creates a second GRN (rest notes 04 §I).
- **Delete:** the repo has **no delete**; a GRN is permanent.

## 26. RestaurantGRNItemModel

**What it is / why.** One received line: how many arrived, how many were damaged and what to do with them, and the unit cost.

| Fact | Value |
|---|---|
| Class / file | `RestaurantGRNItemModel`, `.../restaurant_grn_item_model.dart:13` |
| typeId | **142** `restaurantGrnItem` (`hive_type_ids.dart:118`) |
| Box | `'restaurantGrnItemsBox'` (`hive_box_names.dart:255`), opened `hive_init.dart:832` |
| Hive key | `grnItemId` (GRN repo `:54,64`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | grnItemId | String | req | – | required | UUID (`:99`) / key |
| 1 | grnId | String | req | – | required | FK → GRN |
| 2 | poItemId | String | req | – | required | FK → PO line (breaks if the PO were edited; hence the draft-only edit guard) |
| 3 | itemId | String | req | – | required | FK → Items |
| 4 | itemName | String? | opt | – | – | Snapshot |
| 5 | orderedQty | double | req | – | required | Full PO-line qty |
| 6 | receivedQty | double | req | – | required | |
| 7 | acceptedQty | double | req | – | required | `received − damaged`, clamped ≥ 0 by the screen. **The only figure that enters stock** |
| 8 | damagedQty | double? | opt | – | – | Null when 0 |
| 9 | costPrice | double? | opt | – | – | Per unit; null when 0. Becomes `Items.lastPurchaseCost` |
| 10 | totalAmount | double? | opt | – | – | receivedQty × costPrice (billed figure) |
| 11 | remarks | String? | opt | – | – | Never set by the restaurant screen |
| 12 | createdAt | String | req | – | required | |
| 13 | damagedHandling | String? | opt | – | – | `returnToSupplier` / `keepForClaim` / `writeOff` |

- Getters: `shortageQty`, `goodQty`, `acceptedAmount`, `damagedAmount` (`:116-126`).
- Over-receipt is not validated (the line dialog checks only `damaged ≤ received`, `goods_receiving_screen.dart:268-279`).
- Referenced by `RestaurantPurchaseReturnItemModel`, `RestaurantSupplierClaimItemModel` and `RestaurantInventoryLossModel` (`grnItemId`).

## 27. RestaurantPurchaseReturnModel

**What it is.** A return note for damaged goods sent back to the supplier, raised automatically from a GRN line whose handling is `returnToSupplier`.

**Why the app needs it.** It tracks the expected credit note and, when it arrives, reduces what is owed.

| Fact | Value |
|---|---|
| Class / file | `RestaurantPurchaseReturnModel`, `.../restaurant_purchase_return_model.dart:28` |
| typeId | **143** `restaurantPurchaseReturn` (`hive_type_ids.dart:125`) |
| Box | `'restaurantPurchaseReturnsBox'` (`hive_box_names.dart:258`), opened `hive_init.dart:835` |
| Hive key | `returnId` (`restaurant_purchase_return_repository.dart:11,24,67`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | returnId | String | req | – | required | UUID (`:126`) / key |
| 1 | returnNumber | String | req | – | required | `PR-00001` |
| 2 | grnId | String | req | – | required | Source GRN |
| 3 | grnNumber | String | req | – | required | Snapshot |
| 4 | poId | String | req | – | required | Source PO |
| 5 | poNumber | String | req | – | required | Snapshot |
| 6 | supplierId | String | req | – | required | FK |
| 7 | supplierName | String? | opt | – | – | Snapshot |
| 8 | returnDate | String | req | – | required | Now |
| 9 | totalQty | double | req | – | `0` | Σ damagedQty |
| 10 | totalAmount | double | req | – | `0` | Σ damaged × cost |
| 11 | status | String | req | – | required | Enum `{pending, creditReceived, cancelled}` (`:13-17`) |
| 12 | creditNoteNumber | String? | opt | – | – | |
| 13 | creditNoteDate | String? | opt | – | – | |
| 14 | creditNoteAmount | double? | opt | – | – | |
| 15 | notes | String? | opt | – | – | "Raised automatically from GRN-…" |
| 16 | createdAt | String | req | – | required | |
| 17 | updatedAt | String | req | – | required | |
| 18 | creditApplied | bool? | opt | – | – | Once-only guard for the ledger credit |

- `creditAdjustment(r, noteAmount)` returns 0 if credit was already applied, else `-(noteAmount ?? totalAmount)` (`:158-164`).
- **Created by** `recordFromGRN` → `_createReturn` (`restaurant_damaged_goods_store.dart:110-183`): header first, then items. Any exception is swallowed (`:141-144`).
- **Credit note** (`recordCreditNote`, `:259-297`): saves status `creditReceived` + note fields + `creditApplied = true`, then `recordBalanceMovement(adjustment, returnCredit)`. No status guard (a cancelled return can be credited), no amount validation (a negative amount increases the balance).
- **Cancel** (`cancelPurchaseReturn`, `:301-314`): requires open, sets `cancelled`, moves nothing. **A return never moves stock** (damaged units never entered stock).

## 28. RestaurantPurchaseReturnItemModel

| Fact | Value |
|---|---|
| Class / file | `RestaurantPurchaseReturnItemModel`, `.../restaurant_purchase_return_item_model.dart:12` |
| typeId | **144** (`hive_type_ids.dart:126`) |
| Box / key | `'restaurantPurchaseReturnItemsBox'` (`hive_box_names.dart:261`, opened `hive_init.dart:836`) / `returnItemId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | returnItemId | String | req | – | required | UUID / key |
| 1 | returnId | String | req | – | required | FK → return |
| 2 | grnItemId | String | req | – | required | FK → GRN line |
| 3 | itemId | String | req | – | required | FK → Items |
| 4 | itemName | String? | opt | – | – | Snapshot |
| 5 | returnedQty | double | req | – | required | |
| 6 | costPrice | double? | opt | – | – | |
| 7 | totalAmount | double? | opt | – | – | qty × cost |
| 8 | remarks | String? | opt | – | – | |
| 9 | createdAt | String | req | – | required | |

`returnedQtyForGRNItem` excludes cancelled returns (repo `:49-60`). Delete cascades item-first with the header.

## 29. RestaurantSupplierClaimModel

**What it is.** A claim against the supplier for damaged goods the kitchen keeps (handling `keepForClaim`), to be approved/rejected and finally settled as a credit.

| Fact | Value |
|---|---|
| Class / file | `RestaurantSupplierClaimModel`, `.../restaurant_supplier_claim_model.dart:29` |
| typeId | **145** (`hive_type_ids.dart:127`) |
| Box / key | `'restaurantSupplierClaimsBox'` (`hive_box_names.dart:264`, opened `hive_init.dart:837`) / `claimId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | claimId | String | req | – | required | UUID / key |
| 1 | claimNumber | String | req | – | required | `CLM-00001` |
| 2 | grnId | String | req | – | required | |
| 3 | grnNumber | String | req | – | required | |
| 4 | poId | String | req | – | required | |
| 5 | poNumber | String | req | – | required | |
| 6 | supplierId | String | req | – | required | |
| 7 | supplierName | String? | opt | – | – | |
| 8 | claimDate | String | req | – | required | |
| 9 | totalQty | double | req | – | `0` | |
| 10 | totalAmount | double | req | – | `0` | |
| 11 | status | String | req | – | required | Enum `{pending, approved, rejected, settled}` (`:14-19`) |
| 12 | resolutionNote | String? | opt | – | – | |
| 13 | resolvedAt | String? | opt | – | – | |
| 14 | notes | String? | opt | – | – | |
| 15 | createdAt | String | req | – | required | |
| 16 | updatedAt | String | req | – | required | |
| 17 | creditApplied | bool? | opt | – | – | |
| 18 | lossRecorded | bool? | opt | – | – | Set after a rejected claim is written off |

- **Lifecycle** (`updateClaimStatus`, `restaurant_damaged_goods_store.dart:334-389`): approve/reject from pending (status only); settle from approved → `claimBalanceAdjustment` = `-totalAmount` only for a first transition to settled without prior credit (`:164-171`) through the ledger choke point. The claim is saved before the ledger write (at-most-once credit). No partial settlement.
- **Write-off** (`writeOffRejectedClaim`, `:393-444`): requires `rejected` and `!lossRecorded`, writes one `LOSS` row per line (source `claim_rejected`), then sets `lossRecorded`. A crash between the two duplicates the losses on retry. Claims never move stock.

## 30. RestaurantSupplierClaimItemModel

| Fact | Value |
|---|---|
| Class / file | `RestaurantSupplierClaimItemModel`, `.../restaurant_supplier_claim_item_model.dart:12` |
| typeId | **146** (`hive_type_ids.dart:128`) |
| Box / key | `'restaurantSupplierClaimItemsBox'` (`hive_box_names.dart:267`, opened `hive_init.dart:838`) / `claimItemId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | claimItemId | String | req | – | required | UUID / key |
| 1 | claimId | String | req | – | required | FK → claim |
| 2 | grnItemId | String | req | – | required | FK → GRN line |
| 3 | itemId | String | req | – | required | FK → Items |
| 4 | itemName | String? | opt | – | – | |
| 5 | claimedQty | double | req | – | required | |
| 6 | costPrice | double? | opt | – | – | |
| 7 | totalAmount | double? | opt | – | – | |
| 8 | remarks | String? | opt | – | – | |
| 9 | createdAt | String | req | – | required | |

---

# Inventory

## 31. StockMovementModel (shared)

**What it is.** One line in the stock history: "−0.2 kg Paneer, reason `Sale (recipe: Paneer Tikka)`, balance after 4.6".

**Why the app needs it.** The stock ledger, Ingredient Usage and Wastage reports, purchase reports, and the stock-take idempotency id.

| Fact | Value |
|---|---|
| Class / file | `StockMovementModel`, `.../stock_movement_model.dart:11` (a restaurant model reused by retail) |
| typeId | **126** `restaurantStockLog` (`hive_type_ids.dart:86`) |
| Box | `'stockMovementsBox'` (`hive_box_names.dart:216`), **shared**; restaurant open `hive_init.dart:811` |
| Hive key | `id` (`stock_movement_repository.dart:11,15`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning (restaurant) |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID, or `st_<takeItemId>` for stock-take lines |
| 1 | timestamp | DateTime | req | – | required | Write time |
| 2 | itemId | String | req | – | required | `Items.id` |
| 3 | variantId | String? | opt | – | – | `ItemVariante.variantId` for variant sales |
| 4 | itemName | String | req | – | required | Snapshot, with "(variant)" |
| 5 | type | String | req | – | required | `'in'` / `'out'` |
| 6 | quantity | double | req | – | required | Always positive |
| 7 | balanceAfter | double | req | – | required | Stock after the move |
| 8 | reason | String | req | – | required | Free text and the real taxonomy (below) |
| 9 | note | String? | opt | – | – | |
| 10 | unit | String | req | – | required | |
| 11 | staffName | String | req | – | required | |
| 12 | sessionId | String? | opt | – | – | |
| 13 | unitCost | double? | opt | – | – | Cost per unit at write time. **Set only by the InventoryService writers** |

**Restaurant writers** (✗ = no `unitCost`):

| Writer | type / reason | unitCost |
|---|---|---|
| `inventory_service.dart:95-107` → `_logMovementAndAlert` `:181-195` | out / `Sale` | ✓ |
| `:148-160` | out / `Sale (recipe: X)` | ✓ |
| `:437-451` | out / `Production (X)` | ✓ |
| `:491-505` | in / `Production batch` | ✓ (produced cost) |
| `:832-848` | in / `Void / Refund return` | ✓ |
| `:886-900` | in / `… (recipe: X)` | ✓ |
| `restaurant_purchase_order_store.dart:370-383` | in / `Purchase (PO-…)` | ✗ |
| `stock_adjust_service.dart:145-158, 164-176` | in / `Opening stock` | ✗ |
| `:192-207` (`logAdjustment`) | in or out / `Stock correction` | ✗ |
| `:246-262` (`addStock`) | in / caller's reason | ✗ |
| `:319-335` (`adjustTo`) | in or out / `Stock take` or a correction | ✗ |
| `manage_Inventory.dart:379-410` | in or out / dropdown reason | ✗ |

- **Readers:** `recipe_report_service.dart` (Ingredient Usage = `out` rows whose reason starts `Sale (recipe` or `Production (`; Wastage = reason exactly `Wastage / Spoilage`), `restaurant_purchase_report_service.dart:546`, stock ledger screens. Missing `unitCost` falls back to today's `lastPurchaseCost`.
- **Idempotency:** only stock-take uses a deterministic id (`st_<takeItemId>`); `adjustTo` writes the item **before** the movement, so a crash between them double-applies on re-commit.
- **Repository:** `lib/data/repositories/restaurant/stock_movement_repository.dart`, **not in DI**; created ad hoc (`inventory_service.dart:30,419,746`, `stock_adjust_service.dart:41`, `restaurant_purchase_order_store.dart:52`, report services).
- **Backup gap:** exported in the common section, but restored **only** by `_restoreRetailData` (`unified_backup_service.dart:2783-2793`); `_restoreRestaurantData` has no entry. A restaurant restore keeps `Items.stockQuantity` but loses the whole movement history (food cost, ledger, recipe reports).
- **Update/delete:** append-only (`:6-10`).
- Retail view: [Retail §30](../retail/02_RETAIL_DATABASE_MODELS.md#30-stockmovementmodel-shared).

## 32. RestaurantInventoryLossModel

**What it is.** A register row for stock that was lost: damaged on receipt and written off, a rejected claim, or a manual removal with a loss reason (wastage, theft, …).

**Why the app needs it.** It records the money value of losses. It **never moves stock** (`:27-29`); stock was either never received or already removed by the adjustment.

| Fact | Value |
|---|---|
| Class / file | `RestaurantInventoryLossModel`, `.../restaurant_inventory_loss_model.dart:30` |
| typeId | **147** (`hive_type_ids.dart:129`) |
| Box / key | `'restaurantInventoryLossesBox'` (`hive_box_names.dart:270`, opened `hive_init.dart:839`) / `lossId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | lossId | String | req | – | required | UUID (`:123`) / key |
| 1 | lossNumber | String | req | – | required | `LOSS-00001` |
| 2 | source | String | req | – | required | `grn_damage` (factory default, `:108`), `claim_rejected`, `stock_adjustment` (constants `:10-22`) |
| 3 | grnId | String? | opt | – | – | |
| 4 | grnNumber | String? | opt | – | – | |
| 5 | grnItemId | String? | opt | – | – | |
| 6 | poId | String? | opt | – | – | |
| 7 | supplierId | String? | opt | – | – | |
| 8 | supplierName | String? | opt | – | – | |
| 9 | itemId | String | req | – | required | FK → Items |
| 10 | itemName | String? | opt | – | – | Includes "(Variant)" for adjustments |
| 11 | quantity | double | req | – | required | |
| 12 | costPrice | double? | opt | – | – | `lastPurchaseCost` for adjustments, GRN line cost otherwise |
| 13 | lossValue | double | req | – | `0` | qty × cost, 0 when cost is null (`:136`). Frozen |
| 14 | reason | String | req | – | required | |
| 15 | note | String? | opt | – | – | |
| 16 | recordedAt | String | req | – | required | |

- **Writers:** `_createLosses` from `recordFromGRN` (`restaurant_damaged_goods_store.dart:223-252`), `writeOffRejectedClaim` (`:393-444`), `StockAdjustService.recordLoss` (`stock_adjust_service.dart:62-85`, numbered at `:70` **without** an `isTaken` guard).
- **Readers:** `inventory_loss_list_screen.dart` (read-only). **No food-cost tab reads it.**
- **Delete:** the repo has `delete` (`:48`) with no caller.

## 33. RestaurantStockTakeModel

**What it is.** A physical count session: "ST-00004, counted by Ravi, 23 items, 5 variances applied".

**Why the app needs it.** It snapshots system stock, records counts, and commits the variances as stock corrections.

| Fact | Value |
|---|---|
| Class / file | `RestaurantStockTakeModel`, `.../restaurant_stock_take_model.dart:28` |
| typeId | **148** (`hive_type_ids.dart:130`) |
| Box / key | `'restaurantStockTakesBox'` (`hive_box_names.dart:273`, opened `hive_init.dart:840`) / `takeId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | takeId | String | req | – | required | UUID / key |
| 1 | takeNumber | String | req | – | required | `ST-00001` |
| 2 | status | String | req | – | required | Enum `{draft, completed, cancelled}` (`:13-17`); `cancelled` is never written (cancel hard-deletes) |
| 3 | scopeNote | String? | opt | – | – | |
| 4 | varianceReason | String? | opt | – | – | Always the constant `'Stock take'` (store `:54,398`) |
| 5 | note | String? | opt | – | – | |
| 6 | countedBy | String | req | – | required | Staff-name snapshot |
| 7 | createdAt | String | req | – | required | |
| 8 | updatedAt | String | req | – | required | |
| 9 | completedAt | String? | opt | – | – | |
| 10 | committedLineCount | int? | opt | – | – | |
| 11 | committedNetQty | double? | opt | – | – | |

- **Lifecycle** (`restaurant_stock_take_store.dart`): `startTake` (`:164-188`) mints `ST` and saves a draft; `countItem` (`:191-251`) creates/updates lines; `cancelTake` (`:279-304`) is refused if any line is applied, otherwise hard-deletes the take and its lines; `commit` (`:322-426`) applies each pending variance through `StockAdjustService.adjustTo(..., movementId: 'st_<takeItemId>')` with a **delta-based** target `item.stockQuantity + variance`, saves `appliedQty`, and marks the take `completed` only when no variance line is outstanding.
- **Picker** (`stock_take_screen.dart:79-95`): tracked items only, Recipe-Based excluded; raw, semi and finished allowed.
- `adjustTo` goes through the plan-gated `updateItem` and ignores its result, forces `trackInventory = true`, and nulls variant `trackInventory`.

## 34. RestaurantStockTakeItemModel

| Fact | Value |
|---|---|
| Class / file | `RestaurantStockTakeItemModel`, `.../restaurant_stock_take_item_model.dart:17` |
| typeId | **149** (`hive_type_ids.dart:131`), the last id in the 100-149 range |
| Box / key | `'restaurantStockTakeItemsBox'` (`hive_box_names.dart:276`, opened `hive_init.dart:841`) / `takeItemId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | takeItemId | String | req | – | required | UUID / key. Also the suffix of the movement id `st_<takeItemId>` |
| 1 | takeId | String | req | – | required | FK → take |
| 2 | itemId | String | req | – | required | FK → Items. **There is no variantId field**: variant items are counted against `Items.stockQuantity`, which variant items never use |
| 3 | itemName | String? | opt | – | – | |
| 4 | systemQty | double | req | – | required | Snapshot at count time (re-snapshotted on recount) |
| 5 | countedQty | double | req | – | required | |
| 6 | costPrice | double? | opt | – | – | `lastPurchaseCost` at count time |
| 7 | countedAt | String | req | – | required | Re-stamped only on a recount (`:108-112`) |
| 8 | appliedQty | double? | opt | – | – | Null until committed |

- Getters: `variance = counted − system` (`:85`), `hasVariance`, `isShortage`, `varianceValue` (`:92`). A line is keyed by `(takeId, itemId)` (`findLine`, repo `:66-71`). An applied line cannot be recounted or removed.

---

# Day / Cash / EOD / Staff

These models are shared with retail (same class; mostly the same box). The field tables are repeated here; the narrative describes restaurant behaviour. Engine: `lib/domain/services/restaurant/day_management_service.dart` (static) and `lib/domain/services/restaurant/eod_service.dart`.

## 35. RestaurantSessionModel (shared) — the business day

**What it is.** One trading session from Start Day to End of Day, with opening and closing cash.

**Why the app needs it.** It defines the EOD window. Its id is stamped on OrderModel/PastOrderModel, Expense, CashMovement, ItemCancellation, Attendance and EOD.

| Fact | Value |
|---|---|
| Class / file | `RestaurantSessionModel extends HiveObject`, `.../session_model.dart:6-24` |
| typeId | **131** `restaurantSession` (`hive_type_ids.dart:98`) |
| Box | `'restaurantSessionsBox'` (`hive_box_names.dart:225`), shared; restaurant open `hive_init.dart:817` |
| Hive key | `sessionId` (`day_management_service.dart:34,60`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning (restaurant) |
|---|---|---|---|---|---|---|
| 0 | sessionId | String | req | – | required | Key |
| 1 | startTime | DateTime | req | – | required | Day start; EOD window start |
| 2 | endTime | DateTime? | opt (mutable) | – | – | Set at close |
| 3 | openingCash | double | req | – | required | Opening float |
| 4 | closingCash | double? | opt (mutable) | – | – | **Restaurant stores the COUNTED cash** (`endday.dart:848`); retail stores the kept cash |
| 5 | isClosed | bool | req (mutable) | – | `false` | |

- **Identifier:** `Uuid().v4()` (`day_management_service.dart:51`). Pointer `dayManagementBox['currentSessionId']` (`:61`), deleted by `endSession` (`:121`).
- **Start:** `startSession` also writes the `'opening'` cash movement (no `sessionId`, note `Session ID: <id>`) and calls `_resetDailyBillNumberIfAvailable` (`:69`), which reaches the **no-op** `OrderRepository.resetDailyBillNumber`; bill numbers do not reset per day.
- **Close:** `endSession(closingCash: counted)` runs in a `finally` of the EOD flow (`endday.dart:848`). The kept figure after the safe drop goes only to `dayManagementBox['closingBalance']` via `markDayEnded` (`day_management_service.dart:193-195,109-125`).
- **Serialization:** `fromMap` uses `DateTime.parse(startTime)` (hard), `sessionId ?? ''`, `isClosed ?? false`. Backed up in restaurant (`restaurantSessions`, `:907/:2358`). But `dayManagementBox` is not, so after a restore `currentSessionId` can point at a session that is not there **(inferred)**.
- **Update/delete:** `session.save()` at close; never deleted.
- Retail view: [Retail §34](../retail/02_RETAIL_DATABASE_MODELS.md#34-restaurantsessionmodel-shared--the-business-day).

## 36. EndOfDayReport + embedded summaries (shared model)

**What it is.** The day-close report: sales by order type, category and payment mode, discount, tax, refunds, cancelled orders, expected vs counted cash.

**Why the app needs it.** It closes the session, is printed as the settlement slip, and keeps a history of each day.

| Fact | Value |
|---|---|
| Class / file | `EndOfDayReport extends HiveObject`, `.../eodmodel_317.dart:7-116` |
| typeId | **117** `restaurantEod` (`hive_type_ids.dart:74`) |
| Box | `HiveBoxNames.restaurantEOD` = `'restaurant_eodBox'` (`hive_box_names.dart:191`), opened `hive_init.dart:797`. `EodRepository` picks the box by `AppConfig.isRetail` (`eod_repository.dart:11-13`) |
| Hive key | `reportId` (`eod_repository.dart:18,57,62`). **Auto-int after a restore** (`addAll`, `unified_backup_service.dart:2258`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Restaurant meaning |
|---|---|---|---|---|---|---|
| 0 | date | DateTime | req | – | required | The calendar date passed in by the EOD screen, not the session start |
| 1 | openingBalance | double | req | – | required | Passed in |
| 2 | orderSummaries | List<OrderTypeSummary> | req | – | required | Per `orderType`, net of `refundAmount`, excluded statuses dropped (`eod_service.dart:293-315`) |
| 3 | totalDiscount | double | req | – | required | Σ `Discount` over non-excluded orders (`:114-118`) |
| 4 | totalTax | double | req | – | required | Σ `gstAmount × (net/total)` minus the GST share of refunds on earlier-session orders (`:120-136`) |
| 5 | categorySales | List<CategorySales> | req | – | required | By `CartItem.categoryName`; amount = `item.totalPrice × refundRatio` (gross line) while `percentage` divides by net order totals; the two bases differ (`:317-358`) |
| 6 | paymentSummaries | List<PaymentSummary> | req | – | required | `PaymentModeSummary.summarize` (legs × net ratio) minus external-refund amounts (`:83,139-166`) |
| 7 | cashReconciliation | CashReconciliation | req | – | required | **`systemExpectedCash` = cash SALES only** (`:239`); `difference = actual − closingBalance`; status uses exact `== 0` (no tolerance, `:229-236`) |
| 8 | totalSales | double | req | – | required | Σ (`totalPrice − refundAmount`) over non-excluded session orders, minus refunds made this session on other sessions' orders (`:106-112`) |
| 9 | closingBalance | double | req | – | required | **System-expected drawer** = opening + cash sales + cash in − cash out − cash expenses (`:226`) |
| 10 | taxSummaries | List<TaxSummary> | req | – | required | **Always empty in practice**: built only when `gstRate > 0` (`:367`) and every writer stores `gstRate: 0` |
| 11 | totalOrderCount | int | req | – | required | Non-excluded orders |
| 12 | totalRefunds | double | req | – | required | Σ positive `refundAmount` whose `refundedAt` is in the window, including VOIDED (`:87-104`) |
| 13 | reportId | String | req | – | required | UUID (`:267`) / key |
| 14 | totalExpenses | double | req | – | required | From `restaurant_expenseBox` by session (`:171-197`) |
| 15 | cashExpenses | double | req | – | required | `paymentType.toLowerCase() == 'cash'` |
| 16 | mode | String? | opt | – | – | **null for restaurant** |
| 17 | roundOff | double | req | – | `0` | Σ per order `totalPrice − (subTotal + gst − Discount + svc)` (`:254-265`). Likely wrong: `subTotal` is already after discount, so discounts leak into "round off" |
| 18 | cancelledOrderCount | int | req | – | `0` | Orders with VOID/VOIDED/CANCELLED/FULLY_REFUNDED |
| 19 | cancelledOrderAmount | double | req | – | `0` | Σ `totalPrice` of those |
| 20 | sessionId | String? | opt | – | – | Target session |
| 21 | cashCollections | double | req | – | `0` | Retail only; 0 in restaurant (no credit) |
| 22 | cardCollections | double | req | – | `0` | Retail only |
| 23 | upiCollections | double | req | – | `0` | Retail only |
| 24 | totalCost | double | req | – | `0` | Retail only |
| 25 | grossProfit | double | req | – | `0` | Retail only |
| 26 | customersWithDue | int | req | – | `0` | Retail only |
| 27 | totalOutstanding | double | req | – | `0` | Retail only |
| 28 | cashWithdrawn | double | req | **0.0** | `0` | **Never set by restaurant**, although restaurant does a safe drop; `cashKept` therefore equals counted cash |

**Embedded types.** All `extends HiveObject`, stored only inside the EOD (no box, no key). Registration comments at `hive_init.dart:643-662` say "18-22"; the real ids are 118-121 and 124.

| Type (typeId) | Fields (all req, no defaults) |
|---|---|
| OrderTypeSummary (118, `eodmodel_317.dart:250`) | 0 orderType String · 1 orderCount int · 2 totalAmount double · 3 averageOrderValue double |
| CategorySales (119, `:292`) | 0 categoryName String · 1 totalAmount double · 2 itemsSold int (minus `refundedQuantity`) · 3 percentage double |
| PaymentSummary (120, `:334`) | 0 paymentType String (bucket key) · 1 totalAmount double · 2 transactionCount int · 3 percentage double |
| CashReconciliation (121, `:376`) | 0 systemExpectedCash double · 1 actualCash double · 2 difference double · 3 reconciliationStatus String (`Balanced`/`Overage`/`Shortage`) · 4 remarks String? (opt) |
| TaxSummary (124, `:464`) | 0 taxName String · 1 taxRate double · 2 taxAmount double · 3 taxableAmount double |

A commented-out older `EndOfDayReport` class remains at `:426-462`; it is not compiled.

- **Session filter:** orders matched by `sessionId`; a null `sessionId` falls back to the **calendar day of `orderAt`** (`:60-64`); expenses/movements with null session use the [dayStart, now] window. Expected cash reads **past orders only**: paid-but-unserved dine-in cash does not count until the order moves to past (`:50-51,221-226`).
- **Close flow** (`end day/endday.dart:700-926`): resolve every active order → freeze stale shifts/attendance → generate + save EOD → close shifts → `endSession(closingCash: counted)` → safe-drop dialog writes an `'adjustment'` and an `'out'` "Safe drop - End of Day" movement (with **no sessionId**, the session is already ended) → `markDayEnded(closingBalance: kept)`.
- **Save/delete:** `saveEODReport` (`eod_service.dart:402-417`) replaces a report with the same `sessionId`. After a restore the rows have int keys, so `deleteEODReport(reportId)` misses (matters only if a restored session is re-closed).
- **Serialization:** `toMap`/`fromMap` cover all fields; the adapter hard-casts f17-f27 (old records throw).
- **Where used:** store `domain/store/restaurant/eod_store.dart`; repo `data/repositories/restaurant/eod_repository.dart`; legacy static `database/hive_eod.dart:21`.
- Retail view: [Retail §35](../retail/02_RETAIL_DATABASE_MODELS.md#35-endofdayreport--embedded-summaries-shared-model).

## 37. CashMovementModel (shared)

**What it is.** One line in the cash-drawer ledger: cash in, cash out (petty payout, safe drop), opening float, or adjustment.

**Why the app needs it.** Expected cash at EOD and the cash-drawer screen.

| Fact | Value |
|---|---|
| Class / file | `CashMovementModel extends HiveObject`, `.../cash_movement_model.dart:14-48` |
| typeId | **128** `restaurantCashMovement` (`hive_type_ids.dart:92`) |
| Box | `'cashMovementsBox'` (`hive_box_names.dart:213`), shared; restaurant open `hive_init.dart:810` |
| Hive key | `id` (`cash_movement_repository.dart:13,18`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning (restaurant) |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | timestamp | DateTime | req | – | required | Device clock |
| 2 | type | String | req | – | required | `in`, `out`, `opening`, `adjustment` |
| 3 | amount | double | req | – | required | Positive for `in`/`out`/`opening`. **`adjustment` rows store a SIGNED amount** (negative = shortage, `cash_movement_store.dart:139-146`) |
| 4 | reason | String | req | – | required | e.g. `Safe drop - End of Day` |
| 5 | note | String? | opt | – | – | Opening row: `Session ID: <id>` |
| 6 | staffName | String | req | – | required | Name snapshot |
| 7 | sessionId | String? | opt | – | – | **Null on the opening row and on EOD safe-drop rows** |

- **Writers:** `CashMovementStore.addMovement` (`cash_movement_store.dart:84-121`; refuses when EOD is strictly pending unless `systemClose`), `addAdjustment` (`:131-157`), the opening row (`day_management_service.dart:72-85`), EOD safe drop (`endday.dart:895-926`).
- **Sign hazard:** the `signedAmount` getter (`cash_movement_model.dart:89`) treats any non-`in` row as cash-out, so it double-negates an adjustment. EOD sums only `in`/`out` (`eod_service.dart:217-218`); EOD recognises the opening row by its note (`:209`).
- **Other readers:** `DayManagementService` (`:77,273,336`), `eod_service.dart:204,557`, `cash_drawer_history_screen.dart:179`.
- **Update/delete:** append-only. Backed up (`cashMovements`).
- Retail view: [Retail §36](../retail/02_RETAIL_DATABASE_MODELS.md#36-cashmovementmodel-shared).

## 38. CashHandoverModel

**What it is.** A two-step drawer handover between staff: outgoing cashier counts and closes, incoming cashier counts and receives.

**Why the app needs it.** Accountability between shifts. It does not feed expected cash or EOD.

| Fact | Value |
|---|---|
| Class / file | `CashHandoverModel extends HiveObject`, `.../cash_handover_model.dart:19-87` |
| typeId | **129** `restaurantCashHandover` (`hive_type_ids.dart:93`) |
| Box | `'cashHandoversBox'` (`hive_box_names.dart:219`), opened `hive_init.dart:812` (restaurant only) |
| Hive key | `id` (`cash_handover_repository.dart:16,21,45`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (`cash_handover_store.dart:73,104`) / key |
| 1 | closedBy | String | req | – | required | Outgoing staff name (snapshot) |
| 2 | closedAt | DateTime | req | – | required | Step 1 time |
| 3 | closedAmount | double | req | – | required | Cash counted by outgoing staff |
| 4 | closedNote | String? | opt | – | – | |
| 5 | receivedBy | String? | opt | – | – | Incoming staff; null while PENDING; `'System'` marks a single-step record |
| 6 | receivedAt | DateTime? | opt | – | – | |
| 7 | receivedAmount | double? | opt | – | – | Counted by incoming staff |
| 8 | receivedNote | String? | opt | – | – | |
| 9 | status | String | req | – | required | `PENDING` / `MATCHED` / `DISCREPANCY` (±1.0 tolerance in `withReceived`) |
| 10 | variance | double? | opt | – | – | `receivedAmount − closedAmount` (+ = more found) |

- **Flow:** `createHandover` (`cash_drawer_screen.dart:1909`) → `receiveHandover` (`:2410`). `withReceived` builds the completed copy; no `copyWith`. `recordShiftEnd` (`cash_handover_store.dart:62-89`) has no callers and would invert the variance sign.
- **Serialization:** `toMap`/`fromMap` keys match; `fromMap` defaults status to `'PENDING'`. Backed up (`cashHandovers`, `:850/:2319`).
- **Update/delete:** step 2 replaces the row; never deleted.

## 39. ExpenseCategory (shared model)

**What it is / why.** A category for restaurant expenses (gas, vegetables bought in cash, repairs).

| Fact | Value |
|---|---|
| Class / file | `ExpenseCategory extends HiveObject`, `.../expensemodel_315.dart:8-18` |
| typeId | **115** `restaurantExpense` (misnamed: this is the CATEGORY) |
| Box | `'restaurant_expenseCategory'` (`hive_box_names.dart:194`), opened `hive_init.dart:793`. Retail uses `'expenseCategory'` |
| Hive key | `id` (`expense_category_repository.dart:14,19,34,39`; `hive_expensecategory.dart:30`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (`Expense/managecategory.dart:55`) / key |
| 1 | name | String | req | – | required | |
| 2 | isEnabled | bool | req (mutable) | – | `true` | |

- `fromMap` reads `isEnabled` with no fallback.
- Backup goes through the mode-aware static `HiveExpenseCat` (`unified_backup_service.dart:749-750, 2253`): the box is resolved from the **current** `AppConfig.isRetail` at restore time, so restoring a restaurant backup on a retail-mode install would write into the retail box **(inferred)**.
- Repo `expense_category_repository.dart`, store `ExpenseCategoryStore` (DI `service_locator.dart:414/488`). Screen `Expense/managecategory.dart`.

## 40. Expense (shared model)

**What it is.** One money-out expense entry ("₹450 gas cylinder, cash").

**Why the app needs it.** EOD subtracts cash expenses from expected cash; restaurant is the only vertical with an expense entry UI.

| Fact | Value |
|---|---|
| Class / file | `Expense extends HiveObject`, `.../expensel_316.dart:8-29` |
| typeId | **116** `restaurantExpense1` |
| Box | `'restaurant_expenseBox'` (`hive_box_names.dart:197`), opened `hive_init.dart:794`. Retail uses `'expenseBox'` |
| Hive key | `id` (`expense_repository.dart:13,18,33,38`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (`Expense/addexpence.dart:117`) / key |
| 1 | dateandTime | DateTime | req | – | required | EOD window fallback |
| 2 | amount | double | req | – | required | Positive |
| 3 | categoryOfExpense | String? | opt | – | – | ExpenseCategory **id** |
| 4 | reason | String? | opt | – | – | |
| 5 | paymentType | String? | opt | – | – | From a dropdown; lower-case `'cash'` counts toward `cashExpenses` |
| 6 | sessionId | String? | opt | – | – | Current session (`addexpence.dart:114,125`) |

- Writer `presentation/screens/restaurant/Expense/addexpence.dart:116-128`. Readers EOD (`eod_service.dart:171-197`), `DayManagementService` (`:292,341`). Legacy static `HiveExpenceL`. Same mode-aware backup caveat as §39.

## 41. StaffModel (shared)

**What it is.** A restaurant user who logs in with a PIN: Manager, Cashier or Waiter.

**Why the app needs it.** Login, role permissions, shifts, attendance, Captain-app PIN auth.

| Fact | Value |
|---|---|
| Class / file | `StaffModel extends HiveObject`, `lib/data/models/common/staffModel_310.dart` |
| typeId | **110** `HiveTypeIds.staff` (`hive_type_ids.dart:67`) |
| Box | `'staffBox'`, shared; restaurant open `hive_init.dart:783` |
| Hive key | `id` (`staff_repository.dart:16,21`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | userName | String | req | – | required | |
| 2 | firstName | String | req | – | required | |
| 3 | lastName | String | req | – | required | |
| 4 | isCashier | String | req | – | required | **Holds the role name**: `Manager`, `Cashier`, `Waiter` in restaurant (`lib/util/common/staff_roles.dart:19`; `Chef` is in the icon map but not offered) |
| 5 | mobileNo | String | req | – | required | |
| 6 | emailId | String | req | – | required | |
| 7 | pinNo | String | req | – | required | SHA-256(pin + salt), verified by `RestaurantAuthHelper.verifyPassword` (also used by `/captain/auth`, `captain_handler.dart:59-62`) |
| 8 | createdAt | DateTime | req | – | required | |
| 9 | isActive | bool | req | – | `true` | Soft disable |

- **Permissions:** `RestaurantSession.canAccess` (`lib/util/restaurant/restaurant_session.dart:268-285`): Admin and Manager can do everything; Cashier has a denylist (`reports`, `manageStaff`, `cashDrawer`, `settings`, `taxSettings`, `:213-219`); **Waiter can only `startOrder`**; not signed in fails CLOSED. The role is cached in prefs at login (`:139,143`).
- **Identifier / validation / delete:** UUID, PIN unique across staff and the admin PIN (UI), `isActive` soft disable, hard delete without history guard, shared screen `presentation/screens/common/staff/manage_staff_screen.dart`. Orders reference staff by **name** only.
- The restaurant Admin is not a StaffModel: its hashed PIN is in SharedPreferences `restaurant_admin_password`.
- Retail view: [Retail §39](../retail/02_RETAIL_DATABASE_MODELS.md#39-staffmodel-shared).

## 42. ShiftModel (shared)

**What it is / why.** One staff member's working shift; the Shift report totals sales per shift.

| Fact | Value |
|---|---|
| Class / file | `ShiftModel extends HiveObject`, `lib/data/models/common/shift_model.dart` |
| typeId | **127** `shift` (`hive_type_ids.dart:89`), registered in the common block |
| Box | `'shiftBox'` (`hive_box_names.dart:210`), common open `hive_init.dart:190` |
| Hive key | `id` (`shift_repository.dart:19,24,63`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | staffId | String | req | – | required | FK → StaffModel |
| 2 | staffName | String | req | – | required | Snapshot |
| 3 | startTime | DateTime | req | – | required | |
| 4 | endTime | DateTime? | opt | – | – | |
| 5 | status | String | req | – | `'open'` | `open`, `closed`, or composite like `closed:auto_closed:…` (`isClosed` uses `startsWith`) |
| 6 | orderCount | int | req | – | `0` | Cached; recomputed at close |
| 7 | totalSales | double | req | – | `0` | Cached Σ `ShiftTxn.amount` |

- **Restaurant attribution:** `ShiftRepository._restaurantTxns` (`shift_repository.dart:85-113`) turns past orders into `ShiftTxn` with `amount = totalPrice − refundAmount`, excluding `VOID/VOIDED/FULLY_REFUNDED` (it keeps `CANCELLED`), attributed by `PastOrderModel.shiftId`, else by `orderAt` inside the shift window. Because `orderAt` is creation time and `_moveOrderToPast` writes no `shiftId`, a dine-in bill served in a later shift is credited to the shift in which it was **ordered**.
- EOD closes open shifts (`endday.dart:826-843`). Current shift id lives in `RestaurantSession` (prefs `restaurant_current_shift_id`). `ShiftStore` also reads `restaurantAttendanceBox` directly (`shift_store.dart:249,287`).
- Retail view: [Retail §40](../retail/02_RETAIL_DATABASE_MODELS.md#40-shiftmodel-shared).

## 43. AttendanceModel (shared)

**What it is / why.** A clock-in/clock-out record with breaks, for staff hours.

| Fact | Value |
|---|---|
| Class / file | `AttendanceModel extends HiveObject`, `lib/data/models/common/attendance_model.dart` |
| typeId | **132** `attendance` (`hive_type_ids.dart:101`) |
| Box | `'restaurantAttendanceBox'` (`hive_box_names.dart:230`), common open `hive_init.dart:191` |
| Hive key | `id` (`attendance_repository.dart:7,36,46`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | staffName | String | req | – | required | Snapshot; legacy match key |
| 2 | staffRole | String | req | – | required | |
| 3 | clockIn | DateTime | req (mutable) | – | required | |
| 4 | clockOut | DateTime? | opt (mutable) | – | – | Null = still clocked in |
| 5 | totalMinutes | int? | opt (mutable) | – | – | Filled at clock-out |
| 6 | date | String | req | – | required | `YYYY-MM-DD` |
| 7 | sessionId | String? | opt | – | – | Session FK |
| 8 | breakStartTime | DateTime? | opt (mutable) | – | – | |
| 9 | breakTotalMinutes | int? | opt (mutable) | – | – | |
| 10 | staffId | String? | opt (mutable) | – | – | Preferred match key; old rows fall back to `staffName` |

- EOD clocks out open attendance (`endday.dart:785-791`; also direct box access at `endday.dart:749`). `RestaurantSession.onAttendanceAutoClockOut` hook (`service_locator.dart:474-476`). Backed up (`restaurantAttendance`).
- Retail view: [Retail §41](../retail/02_RETAIL_DATABASE_MODELS.md#41-attendancemodel-shared).

## 44. AppNotificationModel (shared)

**What it is / why.** An in-app notification such as "Low stock: Paneer" or "End of Day pending".

| Fact | Value |
|---|---|
| Class / file | `AppNotificationModel extends HiveObject`, `lib/data/models/common/app_notification_model.dart` |
| typeId | **133** `appNotification` (`hive_type_ids.dart:103`) |
| Box | `'restaurantNotificationsBox'` (`hive_box_names.dart:24`), common open `hive_init.dart:184` |
| Hive key | `id` (`notification_repository.dart:7,35,43`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID / key |
| 1 | eventCode | String | req | – | required | e.g. low stock, `pending_eod` |
| 2 | subjectType | String? | opt | – | – | |
| 3 | subjectId | String? | opt | – | – | Restaurant low stock: the item id **(unverified)** |
| 4 | data | String? | opt (mutable) | – | – | JSON context |
| 5 | timestamp | DateTime | req (mutable) | – | required | |
| 6 | isRead | bool | req (mutable) | – | `false` | |
| 7 | isResolved | bool | req (mutable) | – | `false` | |
| 8 | source | String | req | – | `'local'` | `local` / `remote` |

- `raiseEvent` updates the active row matching `(eventCode, subjectType, subjectId)` instead of inserting a duplicate. Restaurant low-stock alerts are reconciled by `LowStockSyncService`, triggered from `applyStockDelta`'s `finally` (`item_store.dart:389-393`).
- **Not backed up** (history lost on restore).
- Retail view: [Retail §42](../retail/02_RETAIL_DATABASE_MODELS.md#42-appnotificationmodel-shared).

---

# Settings & singletons

A **singleton** box holds exactly one record under a fixed string key. Backup restores the three singletons with `clear` + `add()` (`unified_backup_service.dart:1960-2012`), so after a restore the record sits under an int key and `get('<fixed key>')` returns null until the data is saved again.

## 45. BusinessDetails (shared singleton)

**What it is.** The restaurant profile: name, address, GSTIN, logo, country, tax flags and the **food licence (FSSAI) number**.

**Why the app needs it.** Bill header and footer, country-aware rules, the tax switch.

| Fact | Value |
|---|---|
| Class / file | `BusinessDetails extends HiveObject`, `lib/data/models/common/business_details.dart` |
| typeId | **4** `businessDetails` |
| Box | `'businessDetailsBox'` (common, `hive_init.dart:172`) |
| Hive key | fixed `'businessDetails'` (`business_details_repository.dart:8`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | businessTypeId | String? | opt | – | – | |
| 1 | businessTypeName | String? | opt | – | – | |
| 2 | storeName | String? | opt | – | – | Printed on the bill |
| 3 | ownerName | String? | opt | – | – | |
| 4 | phone | String? | opt | – | – | |
| 5 | email | String? | opt | – | – | |
| 6 | address | String? | opt | – | – | |
| 7 | gstin | String? | opt | – | – | Snapshotted as `PastOrderModel.storeGstNumber` |
| 8 | pan | String? | opt | – | – | |
| 9 | city | String? | opt | – | – | |
| 10 | state | String? | opt | – | – | |
| 11 | country | String? | opt | – | – | Drives country-aware rules (food licence label, phone, tax) |
| 12 | pincode | String? | opt | – | – | |
| 13 | logo | Uint8List? | opt | – | – | Receipt logo bytes (`printerSetting/customization.dart`) |
| 14 | isSetupComplete | bool | req | **false** | `false` | |
| 15 | createdAt | DateTime | req | – | now | |
| 16 | updatedAt | DateTime | req | – | now | |
| 17 | taxEnabled | bool | req | **false** | **true** | Behaviour switch; snapshotted as `PastOrderModel.taxEnabled` |
| 18 | isRegisteredForTax | bool | req | **false** | **true** | Legal status, kept separate from behaviour |
| 19 | retailStoreType | String? | opt | – | – | Retail only |
| 20 | foodLicenseNo | String? | opt | – | – | **FSSAI / food licence number** (`business_details.dart:85-86`) |

- **Food licence (f20):** stored in Hive only (no prefs mirror for restaurant). Rules in `lib/core/config/food_license_rule.dart`: country-aware label (`:43-62`); India requires exactly 14 digits (`:29-30,75-83`), other countries free text up to 30 chars; always optional; `FoodLicenseRule.number` reads it live (`:101-104`). The restaurant thermal receipt prints it live, **not** gated on `taxEnabled` (`esc_pos_receipt_builder.dart:278-284`); the KOT never prints it. **Only the setup wizard writes it** (`stores/setup_wizard_store.dart:84,337,553,668`; field in `onboarding/storeDetailsScreen.dart:1080-1096`); restaurant has no post-setup editor.
- **Inconsistency:** f17/f18 read `false` from Hive for an old record, but the constructor and `fromMap` default to `true`.
- `copyWith` clear flags: `clearLogo`, `clearRetailStoreType`.
- Retail view: [Retail §43](../retail/02_RETAIL_DATABASE_MODELS.md#43-businessdetails-shared-singleton).

## 46. BusinessType (shared singleton)

**What it is / why.** The business category chosen in onboarding (restaurant = code 3).

| Fact | Value |
|---|---|
| File | `lib/data/models/common/business_type.dart` |
| typeId | **3** `businessType` |
| Box / key | `'businessTypeBox'` (common, `hive_init.dart:171`), fixed key `'selectedBusinessType'` (`business_type_repository.dart:8`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String? | opt | – | – | |
| 1 | name | String? | opt | – | – | |
| 2 | description | String? | opt | – | – | |
| 3 | iconName | String? | opt | – | – | |
| 4 | isSelected | bool | req | – | `false` | |
| 5 | createdAt | DateTime | req | – | now | |
| 6 | updatedAt | DateTime | req | – | now | |

Same restore int-key defect as §45. The runtime mode switch is `appConfigBox['businessMode']`, not this record.

## 47. TaxDetails (shared singleton)

**What it is / why.** Shop-wide tax settings (on/off, inclusive/exclusive, default rate).

| Fact | Value |
|---|---|
| File | `lib/models/tax_details.dart` |
| typeId | **2** `taxDetails` (live via `TaxDetailsRepository`) |
| Box / key | `'taxBox'` (common, `hive_init.dart:170`), fixed key `'taxDetails'` (`tax_details_repository.dart:8`) |
| Retired index | **7** (`taxRates`; read-only legacy adapter on typeId 5) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | isEnabled | bool | req | – | `true` | |
| 1 | isInclusive | bool | req | – | `true` | |
| 2 | defaultRate | double | req | – | `0.0` | |
| 3 | taxName | String | req | – | `'GST'` | |
| 4 | placeOfSupply | String? | opt | – | – | |
| 5 | applyOnDelivery | bool | req | – | `false` | |
| 6 | notes | String? | opt | – | – | |

Restaurant billing takes the inclusive/exclusive mode from the SharedPreferences toggle `Tax Is Inclusive` (`AppSettings`, `staticswitch.dart`), frozen per order in `OrderModel.isTaxInclusive`, and the rate from `Items.taxRate`. Whether any restaurant billing path reads `TaxDetails` is **(unverified)**. Same restore int-key defect as §45.

## 48. SavedPrinterModel (shared)

**What it is.** A paired printer: a Bluetooth/Wi-Fi/USB thermal printer or a Windows queue, with its role (KOT, receipt, or both).

**Why the app needs it.** KOT and bill printing pick a printer by role.

| Fact | Value |
|---|---|
| Class / file | `SavedPrinterModel extends HiveObject`, `.../saved_printer_model.dart:6-7` |
| typeId | **130** `savedPrinter` (`hive_type_ids.dart:96`) |
| Box | `'restaurantPrintersBox'` (`hive_box_names.dart:222`), registered and opened in the **common** phase (`hive_init.dart:143,179`), so it exists in both modes |
| Hive key | `id` (`printer_repository.dart:22,27,102`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (`printer_store.dart:171,205,312,335`) / key |
| 1 | name | String | req | – | required | |
| 2 | type | String | req | – | required | `bluetooth`, `wifi`, `usb`, `windows` (raw ESC/POS via the spooler) or `windows_pdf` (`:14-19`) |
| 3 | address | String | req | – | required | MAC, `IP:port`, `vendorId:productId`, or a Windows queue name. **Never split a queue name on a colon** (`:22-25`) |
| 4 | paperSize | int | req | – | `80` | 58 or 80 mm |
| 5 | role | String | req | – | `'both'` | `kot`, `receipt` or `both` |
| 6 | isDefault | bool | req | – | `false` | Written as `savedPrinters.isEmpty`; **never read** |
| 7 | createdAt | DateTime | req | – | now | Sort order, newest first (`printer_repository.dart:36-40`) |

- **Default slots** are SharedPreferences `default_kot_printer_id` / `default_receipt_printer_id` (`printer_repository.dart:17-18`); `getDefaultPrinterForRole` clears a stale or role-incompatible reference (`:47-69`); `deletePrinter` clears both references first (`:91-103`).
- **Store:** `lib/domain/store/restaurant/printer_store.dart`, lazy singleton outside the business graph (`service_locator.dart:189`), eager `loadSavedPrinters` (`:226`).
- **Backup:** the box is exported and restored with id keys (`unified_backup_service.dart:895, 2346`), but the default-slot prefs are denylisted (`:161`), so pairings come back without defaults **(inferred)**. Printers are device-bound.

## 49. Raw untyped boxes (`appCounters`, `dayManagementBox`, `app_state`, `appConfigBox`, `storebox`)

These are `Box` without a model class. Values are plain primitives.

| Box | Key(s) | Semantics | Writer |
|---|---|---|---|
| `appCounters` (common, `hive_init.dart:175`) | `lastKotNumber` + `lastKotDate` (`yyyy-MM-dd`) | KOT number, **resets per calendar day** (device date, not session) | `order_repository.dart:71-86` |
| | `lastKotNumber` (no date check) | **Same key, never resets**: the Captain append path | `hive_order.dart:46-55` via `updateOrderWithNewItems` (`:215`) |
| | `lastBillNumber` + `lastBillResetYear` | Bill number, resets per **financial year** (`FiscalYearRule.startOfCurrent.year`) | `order_repository.dart:93-110` |
| | `lastBillNumber` + `lastBillDate` | Daily-reset variant in `HiveOrders.getNextBillNumber`, **no callers** (would clobber the FY counter) | `hive_order.dart:59-90` |
| | `lastOrderNumber` + `lastOrderDate` | Order number, resets per calendar day | `order_repository.dart:119-144` (unused duplicate `hive_order.dart:94-125`) |
| | `<CODE>_lastFy`, `<CODE>_lastSeq`, `<CODE>_prefix` for `PO`, `GRN`, `PR`, `CLM`, `LOSS`, `ST` | Document numbers, FY-scoped; `PO`/`GRN` shared with retail | `document_number_service.dart:32,49-53,68-100` |
| `dayManagementBox` (business phase, `hive_init.dart:800`) | `openingBalance`, `dayStarted`, `lastDayDate`, `dayStartTimestamp`, `closingBalance` (kept cash), `currentSessionId` | Day state; `currentSessionId` points at the open session and is deleted at close | `day_management_service.dart:18-23, 60-67, 119-121` |
| `app_state` (common, `:169`) | `auto_backup_enabled`, `last_backup_date` | Auto-backup (default off, once per day) | `auto_backup_service.dart:20-21` |
| `appConfigBox` (`app_config.dart:54`) | `businessMode`, `isSetupComplete`, `appVersion`, `firstLaunchDate` | Mode and setup | `app_config.dart:45-48` |
| `storebox` (common, `:168`) | none found | Legacy; backup only | – |

- Numbers are **reserved before use**: abandoned flows leave gaps (cancel-KOT prints, the print-only temp KOT at `restaurant_print_helper.dart:692`). Bill numbers are plain ints, unique only within a financial year.
- `appCounters` is backed up whole (`unified_backup_service.dart:801-807`, restored `:2271-2281`). **`dayManagementBox` is not backed up**.
- `AppSettings` does **not** use `app_state` (it is SharedPreferences only).

---

# Dead / legacy

## 50. TestBillModel / TestBillItem (dead)

**What it is.** An old test-bill record. **Nothing writes or reads it.**

| Fact | Value |
|---|---|
| File | `.../testbillmodel_318.dart` (`TestBillModel` `:6-37`, `TestBillItem` `:76-95`) |
| typeId | **122** `TestBill` (`hive_type_ids.dart:82`; the registration comment "TestBill - 118" at `hive_init.dart:663` is wrong) and **123** `TestBillItem` (`:83`) |
| Box | `'testBillBox'` (`hive_box_names.dart:204`), opened `hive_init.dart:802` |
| Hive key | auto-int (`database/hive_testbill.dart:16-23`, zero callers) |

`TestBillModel` (all required, no defaults):

| # | Name | Dart type | Req? | Hive default | Ctor default |
|---|---|---|---|---|---|
| 0 | billNo | String | req | – | required |
| 1 | dateTime | DateTime | req | – | required |
| 2 | tableNo | **int** | req | – | required |
| 3 | totalAmount | double | req | – | required |
| 4 | itemList | List<TestBillItem> | req | – | required |
| 5 | paymentType | String | req | – | required |
| 6 | customerName | String | req | – | required |

`TestBillItem` (embedded): 0 itemName String · 1 quantity int · 2 price double · 3 totalPrice double (all req).

- **Latent crash:** `TestBillItemAdapter` (123) is **never registered**. Writing or restoring a bill with a non-empty `itemList` throws `HiveError: Cannot write, unknown type: TestBillItem`. The backup still exports/restores the box (`unified_backup_service.dart:816-817, 2288`, `addAll`, error caught); it is always empty in practice.
- Candidate for retirement: delete the box opening and helper, but keep typeIds 122 and 123 reserved forever.

## 51. Retired and legacy items

| Item | Status | Evidence |
|---|---|---|
| typeId 101 (`Company` / `companyBox`) | Retired; never reuse | `hive_type_ids.dart:55-58` |
| typeId 5 `LegacyTaxRateItem` | Read-only adapter so old `taxBox` records still open (replaced by the shared `Tax`) | `lib/models/legacy/legacy_tax_rate_item.dart`; registered in common `hive_init.dart:114-161` |
| `OrderModel.kotNumber` f10, `PastOrderModel.kotNumber` f5 | Deprecated, never written; superseded by `kotNumbers` | `ordermodel_309.dart:41`, `pastordermodel_313.dart:32` |
| `PastOrderModel.isRefunded` f13 | Dead (only the demo generator writes it) | `comprehensive_data_generator.dart:236` |
| `ItemCancellationModel.billNumber` f7 | Never written | `takeaway.dart:1136-1160, 1761-1793` |
| `CartItem.discount` f10 | No production writer | `cartmodel_308.dart:86` |
| `Items.recipeId` f29 | Written, never read | `edit_item.dart:517-519` |
| `Extramodel.isEnabled` f2, `SavedPrinterModel.isDefault` f6 | Written, never read | §6, §48 |
| `ItemVariante.trackInventory` f2 | Ignored by stock logic | `itemmodel_302.dart:186-191` |
| `TableModel.currentOrderId` f3 | Only server paths set it | `captain_handler.dart:283` |
| `CartItem` index 2, `Category` index 2 | Retired field indices | `cartmodel_308.dart:11-14`, `categorymodel_300.dart:13` |
| License data | **Not Hive.** License token/manifest live in `flutter_secure_storage` (`license_store.dart:35-51`); no `@HiveType` exists for it (grep of `@HiveType` across `lib/`) | – |
| Legacy static helpers `HiveOrders`, `HiveCart`, `HiveDb`, `HiveChoice`, `HiveExtra`, `HiveTable`, `HiveVariante`, `HivePastOrder`, `HiveEod`, `HiveExpenseCat`, `HiveExpenceL`, `HiveTestBill` | Bypass the store/repo layer. `HiveOrders` is still used by the local server; the expense helpers by backup | `lib/data/models/restaurant/db/database/*` |
| `HiveBoxNames.allRestaurantBoxes` | Lists 40 names, omits `dayManagementBox` and `restaurantNotificationsBox`; no consumers | `hive_box_names.dart:353-394` |
| Hive encryption (`hive_key`, `HiveAesCipher`, `import.dart`) | Gone; nothing is encrypted at rest | grep = 0 hits |

---

# Serialization & schema evolution

### How data is written
- **Normal path:** repositories call `box.put(id, model)`; the generated adapter writes `fieldIndex → value` pairs. The cart and `PaymentMethod` use `add()` (int keys) and position-based `putAt`/`deleteAt`.
- **Local server path:** the shelf server on `0.0.0.0:9090` (`server/server.dart:64-95`) writes orders, KOT statuses, tables, counters and stock **directly** through the static `HiveOrders` helper and stores, outside the store→repo rule. `POST /orders` is not licensing-gated and there is no authentication.
- **Backup path:** `UnifiedBackupService` exports each box with `toMap()` into an encrypted archive and restores with `fromMap()`. Restaurant restore uses batch writes: `restoreBoxWithId` = `clear` + `putAll` keyed by id, `restoreBox` = `clear` + `addAll` (int keys) (`unified_backup_service.dart:2175-2207`). Both **return without clearing when the key is absent** from an older backup, leaving device rows mixed with restored ones. The first block (categories → orders, `:2209-2261`) has **no try/catch**: a `fromMap` throw after a `clear()` aborts the restore with boxes half-written. Settings restore ends with `exit(0)` and relies on a cold start.

### Schema evolution rules in use
1. **Add new fields as nullable** (the norm: almost every late field on `OrderModel` f25-f36 and `PastOrderModel` f20-f39).
2. **Non-nullable late additions get `defaultValue`** (`Items` f23/f24, `EndOfDayReport` f28, `RecipeModel` f9, `RecipeIngredientModel` f3/f5, `RestaurantSupplierModel` f8, `RestaurantSupplierLedgerEntryModel` f13, `Customer` f15-f19, `BusinessDetails` f14/f17/f18). Exceptions that have none: `Items` f16/f20, `Category` f6, `OrderModel` f22, `CartItem` f15, `EndOfDayReport` f17-f27.
3. **Never reuse** a typeId or field index. The next free restaurant typeId is **186**; the next free `CartItem` index is 17.
4. **No migration framework** and no stored schema version. Pre-release policy accepts breaking local data. No startup fixups run in the restaurant phase except payment-method seeding.
5. **Do not change a field's Dart type** (int ↔ double is always breaking).

### Known serialization defects

| # | Model | Defect | Effect |
|---|---|---|---|
| S1 | OrderModel | `toMap`/`fromMap` omit `billNumber`, `sessionId`, `lastModifiedBy`, `lastModifiedAt`, `kotTimestamps` (`ordermodel_309.dart:306-396`) | Restored open orders lose their session (EOD cannot attribute them) and pre-assigned bill numbers; add-on KOT times fall back to the order time |
| S2 | Extramodel | Restored with `addAll` (int keys) while the repo reads by `Id` | Every extra vanishes from the POS dialog after a restore; edits duplicate, deletes do not stick |
| S3 | EndOfDayReport | Restored with `addAll` | `deleteEODReport(reportId)` misses restored rows |
| S4 | BusinessDetails, BusinessType, TaxDetails | Restored with `add()` while repos read fixed keys | The singleton reads null after a restore (logo, FSSAI number, tax flags) until re-saved |
| S5 | Boxes not restored | `dayManagementBox`, `stockMovementsBox`, `restaurantItemCancellationsBox`, `restaurantNotificationsBox` | Stock history, cancellation audit and notifications are lost; `currentSessionId` can dangle |
| S6 | ExpenseCategory, Expense | Restored into the box of the **current** mode | Cross-mode restore writes to the wrong box **(inferred)** |
| S7 | Items | Photos travel as `item_img_<id>` ZIP entries (always, including auto-backup); web export drops them; restore leaves copies in `<AppDocs>/product_images/` | Photos can be stored twice in later manual backups **(inferred)** |
| S8 | TestBillModel | `TestBillItem` adapter unregistered | Any non-empty write/restore throws |
| S9 | Extramodel, Topping, TableModel, Items, ChoiceOption | `fromMap` hard casts / no int→double coercion (`Topping.price`, `Extramodel.minimum/maximum`, `TableModel.tableCapacity`, `Items.editCount`); `DateTime.parse` in Items, VariantModel, ChoicesModel, Extramodel, Topping | A hand-edited or foreign JSON backup can abort the restore |
| S10 | PastOrderModel / OrderModel | `kotNumbers` elements cast `as int` | JSON doubles would throw |

### `copyWith` behaviour (how to set a nullable field back to null)

`copyWith(x: null)` keeps the old value, because the code uses `x ?? this.x`.

| Model | Clear flags | Notes |
|---|---|---|
| Items | none | Edit Item assigns clearable fields directly after `copyWith` |
| ChoicesModel | none | **`option` parameter ignored** (body reads the field) |
| Extramodel | none | No `isEnabled` parameter |
| PastOrderModel | none | **`customername` parameter ignored** |
| OrderModel, CartItem, RecipeModel, RestaurantPurchaseOrderModel (cannot clear `notes`), Category, Tax, StaffModel | none | |
| RestaurantSupplierModel | `clearPhone`, `clearAddress`, `clearGstNumber` | `copyWith` re-stamps `updatedAt` |
| Customer | `clearEmail`, `clearAddress`, `clearGstNumber`, `clearNotes`, `clearFoodPrefrence` | |
| BusinessDetails | `clearLogo`, `clearRetailStoreType` | |
| ItemVariante, TableModel, CashHandoverModel, PO/GRN/return/claim item models | no `copyWith` at all | Rebuilt or recreated |

---

# Model gotchas

1. **Filename suffix ≠ typeId.** `itemmodel_302.dart` is 102, `testbillmodel_318.dart` is 122. Always check `HiveTypeIds`.
2. **One `Items` class for everything.** Decide behaviour with `effectiveProductType` and `sellsAtPos`, never by checking the category.
3. **Stock is on the item or on its embedded variants, governed by the item's `trackInventory`.** `ItemVariante.trackInventory` is ignored. Recipe-Based items have no own stock; use `InventoryService.effectiveAvailableStock`.
4. **`Items.taxRate` is a decimal sum (0.05), `Tax.taxperecentage` a percent (5).** Editing or deleting a Tax does not re-cache onto items; deleted taxes keep billing.
5. **Order lines are frozen snapshots.** Reprints, refunds and EOD must read `CartItem` fields, never the live menu.
6. **There is no KOT record.** Slice `items` by `kotBoundaries`; keep `kotBoundaries.last == items.length` when editing lines, or `OrderModel.getItemsByKot` throws.
7. **Grand total = stored `totalPrice`**; net = `totalPrice − refundAmount`. Do not recompute from lines.
8. **`VOID` ≠ `VOIDED`.** Use `OrderStatusFilter.isVoided` (`contains('VOID')`). `CANCELLED` is never written.
9. **Payment leg `amount` = money moved; `totalPaid` = tendered.** Quick Settle writes no legs; readers must fall back to `paymentmode` + `totalPrice`.
10. **No credit in restaurant.** `amountDue > 0` can survive on a COMPLETED past order after EOD "complete service".
11. **`PastOrderModel.orderAt` is creation time**, not settlement. Shift attribution and the refund window use it.
12. **`gstRate` is always 0** on orders, so the restaurant EOD `taxSummaries` is always empty.
13. **Bill numbers re-issue:** every pre-serve settle and every `completeOrder` takes a new number; gaps are normal. Bill numbers are unique only within a financial year.
14. **Two writers of `lastKotNumber`** with different reset rules (POS daily vs Captain never).
15. **Table id = table name.** Renaming an occupied table orphans its running order.
16. **Order ids are UUID on POS, epoch-ms on Captain/KDS**; both reach `pastorderBox`.
17. **Recipes are found by `RecipeModel.itemId`**; `Items.recipeId` is write-only. Deleting an item orphans its recipe and silently breaks recipes that use it.
18. **Recipe deduction is one level deep and happens at order/KOT placement.** There is no "stock deducted" marker; a crash after the order save loses the deduction.
19. **Cost = last purchase cost**, overwritten by GRN and production, and (defect) re-seeded from the price field by Edit Item for Raw Materials. No weighted average.
20. **Only `applyStockDelta` is a safe stock writer.** Manual adjust, Low Stock add, stock take and Edit Item use the plan-gated `updateItem`, ignore its result, and can lose concurrent sale deductions.
21. **GRN bills damaged units but stocks only accepted units**; returns, claims and losses never move stock. GRN confirm is not resumable.
22. **Supplier balance changes only through `recordBalanceMovement`** (ledger row first, then balance), plus the opening-row exceptions.
23. **Restaurant `EndOfDayReport.closingBalance` is EXPECTED drawer cash; `CashReconciliation.systemExpectedCash` is cash SALES only; `session.closingCash` is COUNTED cash; `dayManagementBox.closingBalance` is KEPT cash.** Four different numbers.
24. **Cash `adjustment` rows are signed**; do not use `signedAmount` on them. EOD safe-drop rows have no `sessionId`.
25. **Staff are referenced by name** on orders and cash records; renaming a staff member breaks history matching.
26. **`PaymentMethod` is keyed by auto-int, and restaurant's edit dialog rewrites `value` (the bucket key) even for built-ins.**
27. **Restored boxes with int keys** (extras, EOD, singletons) misbehave on update/delete until the data is re-created. Stock movements and item cancellations are not restored at all.
28. **Stale comments in code:** EOD sub-type "18-22", "TestBill - 118", PO/PR/CLM/LOSS/ST daily number formats, `PastOrderModel.billNumber` "Daily", PO item "must be a Raw Material", `category_repository.dart:17-19` item-delete step, `item_store.dart:55` veg filter values. Trust this document's citations over those comments.
