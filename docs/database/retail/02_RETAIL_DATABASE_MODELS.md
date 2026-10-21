# Retail Database Models (Hive)

> Bill Berry Lite, **retail mode**. Branch `refactor/shared-code-consolidation`, checked on 2026-10-19.
> This is a static reading of the code. Nothing was run.
> Every statement is confirmed from code at the cited `path:line` unless it is marked **(inferred)** (a conclusion drawn from code) or **(unverified)** (not checked).
> Paths are relative to `D:\flutter\UniPOSs\`. When a path starts with `.../`, it means `lib/data/models/retail/hive_model/`.

---

## How to read this document

### What a "Hive model" is in this project

Hive is the only database the app uses. There is no SQL. Each kind of record is a Dart class that looks like this:

```dart
@HiveType(typeId: HiveTypeIds.retailProduct)   // 150: a number that identifies the CLASS on disk
class ProductModel extends HiveObject {        // HiveObject lets you call .save() / .delete() on it
  @HiveField(0) final String productId;        // 0: a number that identifies the FIELD on disk
  @HiveField(1) final String productName;
  ...
}
part 'product_model_200.g.dart';                // generated adapter (build_runner) that reads/writes bytes
```

- **`typeId`** is written into every stored record. When Hive reads the bytes, it uses the typeId to choose the adapter (the class). All typeIds are constants in `lib/core/constants/hive_type_ids.dart`.
- **`@HiveField(n)`** gives each field a number. Hive stores `n → value`, not the field name. You can rename a Dart field safely, but you must never change its number.
- **The generated adapter** (`*.g.dart`) is the ground truth. Its `read()` method shows exactly what happens when a field is missing from an old record.
- **A box** is one file on disk (`<name>.hive`) that holds records of one type. Box names are constants in `lib/core/constants/hive_box_names.dart`. Boxes are opened in `lib/core/init/hive_init.dart` (retail boxes at `:479-566`, adapters registered at `:267-458`).
- **The Hive key** is the key you pass to `box.put(key, value)`. In retail, it is almost always the record's own string id. When code uses `box.add(value)`, Hive assigns an auto-increment **int** key instead. Mixing the two is the source of several bugs (see "Serialization & schema evolution").

### The rules you must follow

| Rule | Why |
|---|---|
| **Never reuse a typeId.** Retired retail ids: 156, 157, 158, 165, 167, 172. Retired shared id: 101. The next free retail id is **200** (`hive_type_ids.dart:140-162,196-197`). | Old records on a device still carry the old id. Hive would decode them with the wrong class. |
| **Never reuse a field index.** Retired indices: `VarianteModel` 2, 3, 4 (old size/color/weight); `Category` 2 (old imagePath); `CartItemModel` 4, 5, 6; `HoldSaleItemModel` 5, 6, 7; `TaxDetails` 7. | An old record still has bytes under that index. A new field with the same index would read garbage. |
| **Hive `defaultValue` vs constructor default.** `@HiveField(22, defaultValue: false)` is used when an OLD record has no field 22. A constructor default (`this.isDefault = false`) is **not** used when Hive reads; the adapter calls the constructor with `fields[n] as T`, so a missing field becomes `null`. | A non-nullable field added later **without** `defaultValue` makes old records throw a cast error on read. Add new fields as nullable, or give them `defaultValue`. |
| **The filename suffix is not the typeId.** `product_model_200.dart` is typeId **150**; files `_200` to `_221` are offset by −50. `categorymodel_300.dart` is 100, `staffModel_310.dart` is 110, `taxmodel_314.dart` is 114. Only the `_173` to `_181` files match. | Always look up `HiveTypeIds`, not the filename. |
| **int ↔ double is always a breaking change** in Hive. | Changing `int qty` to `double qty` makes old records fail to read. |
| **Only these fields have a Hive `defaultValue`** in the models below: `VarianteModel` f22; `RetailKitAssemblyModel` f8; `SaleModel` f11, f22, f23, f24; `Customer` f15-f19; `EndOfDayReport` f28; `BusinessDetails` f14, f17, f18. Every other field has none (grep of `HiveField(n, defaultValue` across `lib/`). | Use this list when you reason about old data. |

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
| **Stock lives only on `VarianteModel.stockQty`** (double). The product has no stock field. Stock can go negative; it is never clamped. | `variante_model_201.dart` f9; `inventory_service.dart:74-78` |
| **`ProductModel.stockMode` is the real product-type switch** (`standard` / `bundle` / `repack`). `productType` and `hasVariants` do not drive any sale or stock behaviour. | `product_model_200.dart:77-88,128-144`; comment at `retail/add_product_screen.dart:853-855` |
| **`VarianteModel.isDecimalQuantity` is the one switch for fractional quantities** (loose goods, kg/litre). | `variante_model_201.dart:81-91` |
| **Price = `priceOverride ?? sellingPrice ?? mrp ?? 0`.** It never falls back to `costPrice`. | `cart_store.dart:465`; `effectivePrice` `variante_model_201.dart:189` |
| **Tax rate: the variant's cached `taxRate` beats the product's cached `gstRate`**, which beats the shop default. | `cart_store.dart:820-834`; `gst_service.dart:20-31` |
| **A return is its own `SaleModel`** with `isReturn = true`. Its header money fields are **negated**; its lines (`SaleItemModel`) stay **positive**. | `return_service.dart:313,413-452`; `sale_item_model_204.dart:38-40` |
| **`discountAmount` = TOTAL discount; `lineDiscountAmount` / `lineDiscountTotal` = the per-line SUBSET.** Never add the two. | `sale_item_model_204.dart:119-140` |
| **A payment leg's `amount` = money actually moved** (`settledAmount`), not the bill allocation. | `split_payment_widget.dart:63-91` |
| **`invoiceNumber` (`INV-00001`, `CRN-00001` for returns) is for display and restarts every financial year.** The real key is `saleId`, a UUID. | `sale_store.dart:52,58`; `document_number_service.dart` |
| **PO received quantity is never stored.** It is derived from the lines of CONFIRMED GRNs. | `purchase_order_item_model_212.dart:9-10`; `purchase_order_store.dart:554-607` |
| **Retail has no VOID.** A sale is reversed by a return document, never edited or voided. | `SaleStatus` in `sale_model_203.dart:12-16` |

---

## Table of contents

**Catalog**
1. [ProductModel](#1-productmodel) · 2. [VarianteModel](#2-variantemodel) · 3. [AttributeModel](#3-attributemodel) · 4. [AttributeValueModel](#4-attributevaluemodel) · 5. [ProductAttributeModel](#5-productattributemodel) · 6. [RetailBundleModel](#6-retailbundlemodel) · 7. [BundleComponentModel](#7-bundlecomponentmodel) · 8. [RetailKitAssemblyModel](#8-retailkitassemblymodel) · 9. [Category](#9-category-shared) · 10. [Tax](#10-tax-shared)

**Sales & POS**
11. [CartItemModel](#11-cartitemmodel) · 12. [BillingTabModel](#12-billingtabmodel) · 13. [SaleModel](#13-salemodel) · 14. [SaleItemModel](#14-saleitemmodel) · 15. [HoldSaleModel](#15-holdsalemodel) · 16. [HoldSaleItemModel](#16-holdsaleitemmodel) · 17. [PaymentMethod](#17-paymentmethod-shared)

**Customers & Credit**
18. [Customer](#18-customer-shared) · 19. [CreditPaymentModel](#19-creditpaymentmodel)

**Purchasing**
20. [SupplierModel](#20-suppliermodel) · 21. [SupplierLedgerEntryModel](#21-supplierledgerentrymodel) · 22. [PurchaseOrderModel](#22-purchaseordermodel) · 23. [PurchaseOrderItemModel](#23-purchaseorderitemmodel) · 24. [GRNModel](#24-grnmodel) · 25. [GRNItemModel](#25-grnitemmodel) · 26. [PurchaseReturnModel](#26-purchasereturnmodel) · 27. [PurchaseReturnItemModel](#27-purchasereturnitemmodel) · 28. [SupplierClaimModel](#28-supplierclaimmodel) · 29. [SupplierClaimItemModel](#29-supplierclaimitemmodel)

**Inventory**
30. [StockMovementModel](#30-stockmovementmodel-shared) · 31. [InventoryLossModel](#31-inventorylossmodel) · 32. [StockTakeModel](#32-stocktakemodel) · 33. [StockTakeItemModel](#33-stocktakeitemmodel)

**Day / Cash / EOD / Staff**
34. [RestaurantSessionModel](#34-restaurantsessionmodel-shared-the-business-day) · 35. [EndOfDayReport + embedded summaries](#35-endofdayreport--embedded-summaries-shared-model) · 36. [CashMovementModel](#36-cashmovementmodel-shared) · 37. [ExpenseCategory](#37-expensecategory-shared-model) · 38. [Expense](#38-expense-shared-model) · 39. [StaffModel](#39-staffmodel-shared) · 40. [ShiftModel](#40-shiftmodel-shared) · 41. [AttendanceModel](#41-attendancemodel-shared) · 42. [AppNotificationModel](#42-appnotificationmodel-shared)

**Settings & Singletons**
43. [BusinessDetails](#43-businessdetails-shared-singleton) · 44. [BusinessType](#44-businesstype-shared-singleton) · 45. [TaxDetails](#45-taxdetails-shared-singleton) · 46. [RetailPrinterSettings (not Hive)](#46-retailprintersettings-not-hive) · 47. [Raw untyped boxes](#47-raw-untyped-boxes-daymanagementbox-appcounters)

**Dead / legacy**
48. [PaymentEntryModel (dead)](#48-paymententrymodel-dead) · 49. [Retired and legacy items](#49-retired-and-legacy-items)

Then: [Serialization & schema evolution](#serialization--schema-evolution) · [Model gotchas](#model-gotchas)

### Quick index

| # | Model | typeId (constant) | Box string | Hive key |
|---|---|---|---|---|
| 1 | ProductModel | 150 `retailProduct` | `products` | `productId` |
| 2 | VarianteModel | 151 `retailVariant` | `variants` | `varianteId` |
| 3 | AttributeModel | 169 `retailAttribute` | `attributes` | `attributeId` |
| 4 | AttributeValueModel | 170 `retailAttributeValue` | `attribute_values` | `valueId` |
| 5 | ProductAttributeModel | 171 `retailProductAttribute` | `product_attributes` | `id` (int after restore) |
| 6 | RetailBundleModel | 182 `retailBundle` | `bundles` | `id` |
| 7 | BundleComponentModel | 183 `retailBundleComponent` | embedded | – |
| 8 | RetailKitAssemblyModel | 184 `retailKitAssembly` | `kitAssemblies` | `id` |
| 9 | Category | 100 `category` | `categories` (shared) | `id` |
| 10 | Tax | 114 `tax` | `taxes` (shared) | `id` |
| 11 | CartItemModel | 152 `retailCart` | `cartItems` + embedded in tabs | `cartItemId` |
| 12 | BillingTabModel | 173 `retailBillingTab` | `billingTabs` | `id` |
| 13 | SaleModel | 153 `retailSale` | `sales` | `saleId` |
| 14 | SaleItemModel | 154 `retailSaleItem` | `saleItems` | `saleItemId` |
| 15 | HoldSaleModel | 159 `retailHoldSale` | `holdSales` | `holdSaleId` |
| 16 | HoldSaleItemModel | 160 `retailHoldSaleItem` | `holdSaleItems` | `holdSaleItemId` |
| 17 | PaymentMethod | **literal 6** | `paymentMethodsBox` (shared) | auto-int |
| 18 | Customer | 125 `customer` | `customers` (shared) | `customerId` |
| 19 | CreditPaymentModel | 168 `retailCreditPayment` | `credit_payments` | `paymentId` |
| 20 | SupplierModel | 155 `retailSupplier` | `suppliers` | `supplierId` |
| 21 | SupplierLedgerEntryModel | 179 `retailSupplierLedgerEntry` | `supplierLedger` | `entryId` |
| 22 | PurchaseOrderModel | 161 `retailPurchaseOrder` | `purchaseOrders` | `poId` |
| 23 | PurchaseOrderItemModel | 162 `retailPurchaseOrderItem` | `purchaseOrderItems` | `poItemId` |
| 24 | GRNModel | 163 `retailGrn` | `grns` | `grnId` |
| 25 | GRNItemModel | 164 `retailGrnItem` | `grnItems` | `grnItemId` |
| 26 | PurchaseReturnModel | 174 `retailPurchaseReturn` | `purchaseReturns` | `returnId` |
| 27 | PurchaseReturnItemModel | 175 `retailPurchaseReturnItem` | `purchaseReturnItems` | `returnItemId` |
| 28 | SupplierClaimModel | 176 `retailSupplierClaim` | `supplierClaims` | `claimId` |
| 29 | SupplierClaimItemModel | 177 `retailSupplierClaimItem` | `supplierClaimItems` | `claimItemId` |
| 30 | StockMovementModel | 126 `restaurantStockLog` | `stockMovementsBox` (shared) | `id` |
| 31 | InventoryLossModel | 178 `retailInventoryLoss` | `inventoryLosses` | `lossId` |
| 32 | StockTakeModel | 180 `retailStockTake` | `stockTakes` | `takeId` |
| 33 | StockTakeItemModel | 181 `retailStockTakeItem` | `stockTakeItems` | `takeItemId` |
| 34 | RestaurantSessionModel | 131 `restaurantSession` | `restaurantSessionsBox` (shared) | `sessionId` |
| 35 | EndOfDayReport | 117 `restaurantEod` (+118-121, 124 embedded) | `eodBox` (retail only) | `reportId` |
| 36 | CashMovementModel | 128 `restaurantCashMovement` | `cashMovementsBox` (shared) | `id` |
| 37 | ExpenseCategory | 115 `restaurantExpense` | `expenseCategory` (retail only) | `id` |
| 38 | Expense | 116 `restaurantExpense1` | `expenseBox` (retail only) | `id` |
| 39 | StaffModel | 110 `staff` | `staffBox` (shared) | `id` |
| 40 | ShiftModel | 127 `shift` | `shiftBox` (shared) | `id` |
| 41 | AttendanceModel | 132 `attendance` | `restaurantAttendanceBox` (shared) | `id` |
| 42 | AppNotificationModel | 133 `appNotification` | `restaurantNotificationsBox` (shared) | `id` |
| 43 | BusinessDetails | 4 `businessDetails` | `businessDetailsBox` | `'businessDetails'` |
| 44 | BusinessType | 3 `businessType` | `businessTypeBox` | `'selectedBusinessType'` |
| 45 | TaxDetails | 2 `taxDetails` | `taxBox` | `'taxDetails'` |
| 46 | RetailPrinterSettings | not Hive | SharedPreferences `retail_printer_settings` | – |
| 48 | PaymentEntryModel (dead) | 166 `retailPaymentEntry` | `paymentEntries` | never written |

"Shared" means the restaurant mode uses the **same physical box file** (`hive_box_names.dart`, verified per box). `eodBox`, `expenseCategory` and `expenseBox` are retail-only; restaurant uses `restaurant_eodBox`, `restaurant_expenseCategory`, `restaurant_expenseBox`.

---

# Catalog

## 1. ProductModel

**What it is.** A product family the shop sells, for example "Cotton T-Shirt" or "Basmati Rice". It holds the name, brand, category and tax. It does **not** hold price or stock; those are on its variants.

**Why the app needs it.** It groups the sellable SKUs (variants) under one name, category and tax, and it decides whether the product is a normal item, a bundle, or a repack/kit (`stockMode`).

| Fact | Value |
|---|---|
| Class | `ProductModel extends HiveObject` |
| File | `.../product_model_200.dart` (generated `product_model_200.g.dart`) |
| typeId | **150** `HiveTypeIds.retailProduct` (`product_model_200.dart:8`, `hive_type_ids.dart:134`) |
| Box | `HiveBoxNames.products` = `'products'` (`hive_box_names.dart:49`), opened `hive_init.dart:487`. The repo uses the literal string (`product_repository.dart:13`) |
| Hive key | `productId` (`product_repository.dart:25-34`) |

### Fields

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | productId | String | req | – | required | Primary id and Hive key |
| 1 | productName | String | req | – | required | Display name |
| 2 | brandName | String? | opt | – | – | Free-text brand. There is no Brand model. Bulk import writes `''` (`bulk_import_store.dart:458`) |
| 3 | category | String | req | – | required | **Category id** (not the name). `''` = uncategorised |
| 4 | subCategory | String? | opt | – | – | Written only by onboarding Add Product (`onboarding/add_product_screen.dart:386,411`). No retail reader |
| 5 | imagePath | String? | opt | – | – | Legacy, unused; replaced by f17 (`:71-74`) |
| 6 | description | String? | opt | – | – | Free text |
| 7 | hasVariants | bool | req | – | required | "More than one variant". Kept in sync by `ProductStore._syncVariantFlags` (`product_store.dart:462-471`). Display/routing only |
| 8 | createdAt | String (ISO) | req | – | required | Creation time |
| 9 | updateAt | String (ISO) | req | – | required | Last update. `copyWith` always sets it to now (`:295`) |
| 10 | gstRate | double? | opt | – | – | **Cached** percent from the chosen Tax (f16). Product-level fallback rate |
| 11 | hsnCode | String? | opt | – | – | HSN/tariff code. Also used to suggest a tax (`product_store.dart:296-306`) |
| 12 | productType | String | req | – | `'simple'` | `'simple'`/`'variable'`. **No runtime behaviour reads it** |
| 13 | defaultPrice | double? | opt | – | – | Only onboarding/bulk paths write it; main Add Product never does |
| 14 | defaultMrp | double? | opt | – | – | Same as f13 |
| 15 | defaultCostPrice | double? | opt | – | – | Same as f13 |
| 16 | taxId | String? | opt | – | – | FK → `Tax.id` |
| 17 | imageBytes | Uint8List? | opt | – | – | Product photo as bytes (works on web) |
| 18 | stockMode | String? | opt | – | – | **The real type switch**: `null`/`'standard'`, `'bundle'`, `'repack'` (`:77-88`) |
| 19 | allowOrderWhenOutOfStock | bool? | opt | – | – | Allow selling at zero stock. Null = false (`sellsWhenOutOfStock`, `:135`) |

Generated adapter: no Hive defaults, `writeByte(20)`. Old records without f18/f19 read as null, which is safe.

### Validation rules and defaults
- There is **no stock field**. Product total stock is derived: `ProductStore.totalStockFor` (`product_store.dart:354-355`).
- Getters (`:128-144`): `isVariable` (= `productType=='variable' || hasVariants`), `isSimple`, `sellsWhenOutOfStock`, `effectiveStockMode` (null → `'standard'`), `isBundle`, `isRepack`, `isStandardStock`, `needsBundleComponents` (bundle or repack).
- The repository validates nothing (no name uniqueness, no category check).
- Plan gate: `ProductStore.canAddProduct` checks `RetailEntKeys.catalog`, `catalogProductsAdd`, `catalogProductsMax` (`product_store.dart:98-101`).
- Bundle/repack products must have at least one variant (`add_product_screen.dart:544-552`).

### Identifier
UUID v4 everywhere: main Add Product `_uuid.v4()` (`retail/add_product_screen.dart:850`); POS quick-create `ProductStore.createSimpleProduct` (`product_store.dart:129-130`); bulk import (`bulk_import_store.dart:449`). Dead sample data used `'p$index'` (`product_store.dart:600-658`).

### References
- `category` → `Category.id` (resolved by `categoryStore.displayNameFor`; unknown or `''` shows "Uncategorized", `category_store.dart:80-95`).
- `taxId` → `Tax.id`; `gstRate` is a cached copy of that tax's percent.
- Referenced by: `VarianteModel.productId`, `RetailBundleModel.productId`, `ProductAttributeModel.productId`, and (as dangling-safe ids) sale/hold/PO/GRN lines and stock movements (`itemId`).

### Serialization
- `fromProduct(...)` factory (`:147-190`) stamps both timestamps with now.
- `toProduct()` (`:193-217`) is the backup map. It writes the name under key **`'name'`**, and replaces a null `imagePath` with a placeholder URL (`:200`).
- `fromMap` (`:220-243`) accepts `name ?? productName`, defaults `productType` to `'simple'`, converts numbers defensively, decodes `imageBytes` from a `List<int>` (`_bytesFrom`, `:247-252`). `productId`, `category`, `hasVariants`, `createdAt` are hard casts.
- `copyWith` (`:254-308`) clear flags: `clearBrandName`, `clearDescription`, `clearHsnCode`, `clearTax` (clears **both** `gstRate` and `taxId`), `clearImage`, `clearStockMode`. No way to clear `subCategory`, `imagePath`, `default*` prices, or `allowOrderWhenOutOfStock`.

### Where it is created and read
- Repository `lib/data/repositories/retail/product_repository.dart`: `getAllProducts`, `addProduct`/`updateProduct` (`put(productId)`), `deleteProduct`, `getProductById`, `findByBarcode` (no trim; the store uses the variant repo instead), `getProductsByCategory`, `getProductsWith(out)Variants`.
- Store `lib/domain/store/retail/product_store.dart` (`products`, `variants`, computed `variantsByProduct`). Actions: `addProduct`, `createSimpleProduct` (refuses a taken barcode before writing), `updateProduct`, `applyTaxToProducts`/`clearTaxFromProducts`, `deleteProduct`.
- Screens: `retail/add_product_screen.dart` (route `/add-product`), `inventory_screen.dart`, `product_detail_screen.dart`, `product_management_screen.dart`, `bundles_screen.dart`, `assemble_kit_screen.dart`, `apply_tax_to_products_screen.dart`, POS `ex/posscreen.dart`, onboarding add product, bulk import (`stores/import_product/bulk_import_store.dart`).

### Update and delete
- **Update** (`_updateProduct`, `add_product_screen.dart:529-664`) goes through `copyWith`, so id, createdAt, imagePath, productType and default prices are kept. Switching **into** Bundle is refused while any variant has stock (`:560-574`). Switching **out of** Bundle resets each variant's stock to 0 and logs "Stock edited" (`:575,624-637`). Unit, decimal and expiry are edited at product level in the form but stored per variant; a change is pushed to every variant (`:612-639`).
- **Delete** is a hard delete. `ProductRepository.deleteProduct` (`:38-50`) **cascades a hard delete of all variants** directly on the variants box. `ProductStore._dropOwnedRecords` (`:246-260`) then removes the variants' bundle rows and the product's `ProductAttributeModel` rows. The UI refuses if a variant is a component of another bundle (`inventory_screen.dart:245-258`) and is plan-gated (`catalogProductsDelete`). There is **no guard against sales, PO, GRN or movement history**; those keep the dangling ids plus their own name snapshots.

---

## 2. VarianteModel

**What it is.** One sellable SKU of a product, for example "T-Shirt / Red / L" or "Rice 1 kg". It has its own barcode, price, cost and **stock**.

**Why the app needs it.** It is the unit the POS scans and sells, and the only place stock is kept. Even a "simple" product has exactly one variant.

| Fact | Value |
|---|---|
| Class | `VarianteModel extends HiveObject` |
| File | `.../variante_model_201.dart` |
| typeId | **151** `HiveTypeIds.retailVariant` (`:7`, `hive_type_ids.dart:135`) |
| Box | `variants` (`hive_box_names.dart:52`), opened `hive_init.dart:488`; repo literal `variant_repository.dart:32` |
| Hive key | `varianteId` (`variant_repository.dart:96,130`) |
| Retired indices | **2, 3, 4** (old `size`/`color`/`weight`). Never reuse |

### Fields

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | varianteId | String | req | – | required | Primary id and Hive key |
| 1 | productId | String | req | – | required | FK → `ProductModel.productId` |
| 5 | sku | String? | opt | – | – | Optional stock code. **Not unique** (two generators, see below) |
| 6 | barcode | String? | opt | – | – | Scannable code. **Unique, trimmed, auto-minted** by `VariantRepository` |
| 7 | mrp | double? | opt | – | – | Printed MRP; price fallback |
| 8 | costPrice | double? | opt | – | – | Purchase cost. Null = unknown (excluded from profit). Updated by GRN weighted average and kit assembly |
| 9 | stockQty | double | req | **none** | `0` | **On-hand stock. The only stock field in retail.** Can go negative |
| 10 | minStock | double? | opt | – | – | Reorder point. **Beats the global threshold** (`ProductStore.reorderPointFor`, `product_store.dart:398-399`) |
| 11 | taxRate | double? | opt | – | – | Cached percent from f21. **Wins over the product's `gstRate`** |
| 12 | createdAt | String (ISO) | req | – | required | |
| 13 | updateAt | String? | opt | – | – | `copyWith` sets it to now (`:369`) |
| 14 | customAttributes | Map<String,String>? | opt | – | – | Free-text descriptors, e.g. `{"Size":"L"}`. Used for display names |
| 15 | sellingPrice | double? | opt | – | – | **What the cart bills** |
| 16 | hsnCode | String? | opt | – | – | Variant-level HSN override |
| 17 | attributeValueIds | Map<String,String>? | opt | – | – | `{attributeId: valueId}`. Wins over f14 in `attributeStore.attributesOf` (`attribute_store.dart:646-671`) |
| 18 | imagePath | String? | opt | – | – | Per-variant image path (`variant_picker_dialog.dart:543`) |
| 19 | isDefault | bool | req | **none** | `false` | Written but **never read** (cards use `variants.first`, `product_store.dart:359-362`) |
| 20 | status | String | req | **none** | `'active'` | `'active'`/`'inactive'`. **Soft-hide flag**: POS refuses inactive (`ex/posscreen.dart:713`) |
| 21 | taxId | String? | opt | – | – | FK → `Tax.id` |
| 22 | isDecimalQuantity | bool | req | **false** | `false` | **The fractional-quantity switch.** Step 0.25 vs 1 (`quantityStep`, `:197`) |
| 23 | unit | String? | opt | – | – | One of `kItemUnits = ['kg','gm','liter','ml','piece']` (`core/constants/item_units.dart:5`). Null reads as `'piece'` |
| 24 | expiryDate | String? (ISO, local midnight) | opt | – | – | Expiry. Null = never expires. One date per variant (no batches/FEFO) (`:98-111`) |

Adapter check: `isDecimalQuantity: fields[22] == null ? false : …`; `stockQty`, `isDefault`, `status` are plain hard casts (no default), `writeByte(22)`.

### Validation rules and defaults
- `effectivePrice` = `sellingPrice ?? mrp ?? 0` (`:189`); the cart adds `priceOverride` in front (`cart_store.dart:465`). **Never `costPrice`.**
- `isAvailable` = active && stock > 0; `isInStock` (`:310-313`); `expiryDateTime` uses `tryParse`, so a bad date reads as null (`:208-212`).
- Stock status: `ProductStore.statusFor(qty, reorderPoint)` (`:383-394`); critical band = `ceil(reorderPoint/3)` clamped to [1, reorderPoint]. Global threshold from `stockAlertStore.threshold` (`:371`).
- **Barcode uniqueness** is enforced only in `VariantRepository` (`variant_repository.dart:52-160`): trim, `''` → null, refuse duplicates (`VariantWriteResult.failure`, `:143-154`). `ProductStore.isBarcodeTaken` (`:409-414`) is only a UI pre-check over the in-memory list.
- **Bundle mode**: a bundle variant's own `stockQty` is meaningless and saved as 0 (`add_product_screen.dart:892,932-934`). Sellable quantity is derived (`inventory_service.dart:160-184`).

### Identifier
- `varianteId`: UUID v4 (Add Product `:908`; `VariantGeneratorService` keeps an existing id or makes a new UUID, `variant_generator_service.dart:114`; quick-create `product_store.dart:148`; bulk import `bulk_import_store.dart:590`).
- **Barcode** (`BarcodeGeneratorService`, `barcode_generator_service.dart`): `'BB' + 10 zero-padded digits` (`:27-31,73-74`) from counter `appCounters['lastBarcodeSequence']`, skipping taken codes (up to 100000 tries, `:47-69`). Minted only by `addVariant` when the barcode is blank (`variant_repository.dart:105-119`); **never regenerated**, and `updateVariant` never mints.
- **SKU** has two formats and no uniqueness check: `SkuGeneratorService.generate` → `<3 letters of category | GEN>-<6 digits>` from `appCounters['lastSkuSequence']` (`sku_generator_service.dart:12-31`); or `VariantGeneratorService._generateSku` → first 4 chars of a **draft** productId + value slugs (`variant_generator_service.dart:168-175`, `add_product_screen.dart:290-295`). The main Add Product leaves a blank SKU null (`:914-916`).

### References
- `productId` → ProductModel; `taxId` → Tax; `attributeValueIds` keys → AttributeModel, values → AttributeValueModel.
- Referenced by: bundle rows and components, PO/GRN/return/claim/loss/stock-take lines (`variantId`), sale/cart/hold lines, StockMovementModel `variantId`, notifications `subjectId`.

### Serialization
- `toMap`/`fromMap` (`:249-307`) are defensive: `num→double`, `stockQty ?? 0.0`, `isDefault ?? false`, `status ?? 'active'`, `isDecimalQuantity ?? false`, missing `expiryDate` → null.
- `copyWith` (`:316-383`) clear flags: `clearMrp`, `clearMinStock`, `clearBarcode` (doc comment: confirm with user, printed labels get stranded), `clearExpiryDate`, `clearTax` (clears `taxRate` **and** `taxId`). **Cannot clear** `sku`, `costPrice`, `sellingPrice`, `hsnCode`, `unit`, `customAttributes`, `attributeValueIds`, `imagePath`.

### Where it is created and read
- Repository `lib/data/repositories/retail/variant_repository.dart` (the uniqueness layer): `addVariant`, `updateVariant`, `putVariantUnchecked` (documented restore-only, **no callers**), `deleteVariant`, `deleteVariantsByProductId`, `getVariantById` (key, then field scan), `findByBarcode` (trims), `findBySku`, `updateStock` (key only, no fallback), `updateCostPrice`.
- Store `ProductStore`: `addVariant` (`:490-514`) writes, re-reads the box (to pick up a minted barcode) and logs **"Opening stock"** when `stockQty > 0`; `updateVariant` (`:516-542`) logs any stock delta as **"Stock edited"** and schedules notification sync; `updateVariantStock` (`:557-566`) is the stock primitive used by all stock writers; `updateVariantCostPrice` (`:569-574`).
- Screens: `product_detail_screen.dart` (add `:1135`, delete `:270-306`, active toggle `:1361,1534`), Add Product, barcode labels, POS.

### Update and delete
- **Update** = whole-record `put`. Stock delta logged. Barcode uniqueness enforced.
- **Soft hide** = `status: 'inactive'`. Keeps stock and history, hidden from POS.
- **Hard delete**: UI refuses the last variant (`product_detail_screen.dart:270-276`) and any variant used as a bundle component (`:280-291`). Its own bundle row is dropped (`_dropOwnedRecords`). No history guard.
- **Stock writers** (all go through `updateVariantStock` and log a StockMovementModel): GRN receive, stock adjustment / stock take, POS sale, bundle component deduction, sale return restock, exchange, kit assemble/disassemble, opening stock, whole-record edits. Backup restore writes stock without a movement (by design).

---

## 3. AttributeModel

**What it is.** A global attribute name such as "Color" or "Size".

**Why the app needs it.** The variant generator combines attribute values (Red × L, Red × M, ...) to create variants, and the values label each variant.

| Fact | Value |
|---|---|
| Class / file | `AttributeModel extends HiveObject`, `.../attribute_model_219.dart` |
| typeId | **169** `retailAttribute` (`hive_type_ids.dart:158`). The doc comment "TypeId: 21" (`:7`) is stale |
| Box | `attributes` (`hive_box_names.dart:137`), opened `hive_init.dart:518` |
| Hive key | `attributeId` (`attribute_repository.dart:149-158`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | attributeId | String | req | – | required | Id / key |
| 1 | name | String | req | – | required | "Color". Unique case-insensitively (store check) |
| 2 | slug | String | req | – | required | `generateSlug(name)` (`:65-71`) |
| 3 | sortOrder | int | req | – | `0` | Display order |
| 4 | isActive | bool | req | – | `true` | Soft-delete flag; `getAllAttributes` hides inactive (`attribute_repository.dart:105`) |
| 5 | createdAt | String | req | – | required | |
| 6 | updatedAt | String? | opt | – | – | |

- **Validation:** `AttributeStore.addAttribute` (`attribute_store.dart:181-219`) and `updateAttribute` (`:222-258`) refuse duplicate names; rename regenerates the slug. `ensureBaseAttributes` (`:603-629`) seeds starter attributes per store type, continuing `sortOrder` from max+1.
- **Identifier:** `_uuid.v4()` (`attribute_store.dart:198-206`).
- **References:** referenced by `AttributeValueModel.attributeId`, `ProductAttributeModel.attributeId`, and keys of `VarianteModel.attributeValueIds`.
- **Serialization:** `toMap`/`fromMap` default `sortOrder ?? 0`, `isActive ?? true`. `copyWith` has no clear flags.
- **Where used:** repo `lib/data/repositories/retail/attribute_repository.dart` (reads are corruption-tolerant via `_safeValues`, `:37-48`); store `lib/domain/store/retail/attribute_store.dart`; screens `retail/attributes_screen.dart`, Simple Product Fields settings, `product_attribute_selector.dart`.
- **Update/delete:** `AttributeStore.deleteAttribute` (`:261-278`) is blocked if `isAttributeInUse`, which checks **only `ProductAttributeModel` rows** (`attribute_repository.dart:339-352`). Repo `deleteAttribute` (`:161-170`) cascades to its values and all ProductAttributeModel rows. Because only bulk import writes ProductAttributeModel, an attribute used by UI-created variants can be deleted; `attributesOf` then silently skips the dangling ids (`attribute_store.dart:652-656`). `deactivateAttribute` (soft delete, `:173-181`) has no UI caller.

---

## 4. AttributeValueModel

**What it is.** One value of an attribute, such as "Red" or "XL".

**Why the app needs it.** Variants point at value ids to describe themselves, and the generator multiplies values into variants.

| Fact | Value |
|---|---|
| Class / file | `AttributeValueModel extends HiveObject`, `.../attribute_value_model_220.dart` |
| typeId | **170** `retailAttributeValue` (`hive_type_ids.dart:159`). Comment "TypeId: 22" is stale |
| Box | `attributeValues` = `'attribute_values'` (`hive_box_names.dart:140`), opened `hive_init.dart:519` |
| Hive key | `valueId` (`attribute_repository.dart:229-265`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | valueId | String | req | – | required | Id / key |
| 1 | attributeId | String | req | – | required | FK → AttributeModel |
| 2 | value | String | req | – | required | "Red". Unique per attribute (store check) |
| 3 | slug | String | req | – | required | Used by the variant SKU generator |
| 4 | colorCode | String? | opt | – | – | Hex swatch; seeds from `kSeedAttributeColorCodes` (`attribute_store.dart:105-108`) |
| 5 | sortOrder | int | req | – | `0` | |
| 6 | isActive | bool | req | – | `true` | Filtered in `getValuesForAttribute` (`attribute_repository.dart:190`) |
| 7 | createdAt | String | req | – | required | |
| 8 | updatedAt | String? | opt | – | – | |

- **Validation:** `addValue` (`attribute_store.dart:283-321`) refuses duplicates; `addMultipleValues` (`:324-365`) skips them.
- **Identifier:** `_uuid.v4()` (`attribute_store.dart:297,340`).
- **References:** `attributeId` → AttributeModel. Referenced by `VarianteModel.attributeValueIds` values and `ProductAttributeModel.selectedValueIds`.
- **Serialization:** `copyWith` cannot clear `colorCode`.
- **Update/delete:** `deleteValue` (`:421-442`) is a **hard delete with no in-use check** — variants keep the dangling id.

---

## 5. ProductAttributeModel

**What it is.** A link row "product P uses attribute A with values [v1, v2]".

**Why the app needs it.** It records which attributes drive a product's variants. In practice only bulk import writes it.

| Fact | Value |
|---|---|
| Class / file | `ProductAttributeModel extends HiveObject`, `.../product_attribute_model_221.dart` |
| typeId | **171** `retailProductAttribute` (`hive_type_ids.dart:160`). Comment "TypeId: 23" is stale |
| Box | `productAttributes` = `'product_attributes'` (`hive_box_names.dart:143`), opened `hive_init.dart:520` |
| Hive key | `id` (`attribute_repository.dart:295-304`) — **but auto-int after a backup restore** (see below) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id (intended key) |
| 1 | productId | String | req | – | required | FK → ProductModel |
| 2 | attributeId | String | req | – | required | FK → AttributeModel |
| 3 | selectedValueIds | List<String> | req | – | required | FK list → AttributeValueModel |
| 4 | usedForVariants | bool | req | – | `true` | Whether this attribute generates variants |
| 5 | isVisible | bool | req | – | `true` | Not read anywhere relevant |
| 6 | position | int | req | – | `0` | Order |
| 7 | createdAt | String | req | – | required | |
| 8 | updatedAt | String? | opt | – | – | |

- **Identifier:** `_uuid.v4()` in `AttributeStore.assignAttributesToProduct` (`attribute_store.dart:452-482`), which replaces all of the product's rows.
- **Only writer:** bulk import (`bulk_import_store.dart:743`). Main Add Product and Product Detail never create rows.
- **Serialization:** `copyWith` deep-copies `selectedValueIds` (`:71`).
- **Delete:** product delete → `ProductStore._dropOwnedRecords` → `attributeStore.removeAttributesFromProduct` (`product_store.dart:254-256`). Repo deletes with `box.delete(pa.id)` (`attribute_repository.dart:307-336`).
- **Restore defect:** backup restores this box with `box.add()` (`unified_backup_service.dart:2942`, helper `:2562-2581`), giving int keys. After a restore, `box.delete(pa.id)` silently misses, so product-delete leaves orphan rows and `isAttributeInUse` stays true forever.

---

## 6. RetailBundleModel

**What it is.** The recipe of a bundle or repack/kit variant: "this variant = 2 × soap + 1 × towel".

**Why the app needs it.** A **bundle** (`stockMode='bundle'`) has no stock; selling it deducts its components. A **repack/kit** (`stockMode='repack'`) has its own stock that is built by assembling components. Both use this recipe.

| Fact | Value |
|---|---|
| Class / file | `RetailBundleModel extends HiveObject`, `.../bundle_model.dart` |
| typeId | **182** `retailBundle` (`hive_type_ids.dart:189`) |
| Box | `bundles` (`hive_box_names.dart:91`), opened `hive_init.dart:501` |
| Hive key | `id` (`bundle_repository.dart:25`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | productId | String | req | – | required | FK → the bundle/repack ProductModel |
| 2 | variantId | String | req | – | required | FK → the bundle/repack VarianteModel. **One row per variant** |
| 3 | components | List<BundleComponentModel> | req | – | `const []` | Embedded component lines |
| 4 | createdAt | String | req | – | required | |
| 5 | updatedAt | String | req | – | required | `copyWith` sets it to now |

- **Validation:** components can only be `isStandardStock` products (`bundle_builder_widget.dart:133`), so bundles are one level deep. A bundle with no components is refused by the cart (`isUnconfiguredBundle`, `inventory_service.dart:189-193`).
- **Identifier:** `_uuid.v4()`; the id is reused across edits via `_bundleRowIdByVariant` (`add_product_screen.dart:346-349,648,976`). One-row-per-variant is only by that convention.
- **Getters:** `hasComponents`; `estimatedCost(costOf)` (`:46-55`).
- **Serialization:** `toMap`/`fromMap` handle a null component list (`:89-91`).
- **Where used:** repo `lib/data/repositories/retail/bundle_repository.dart` (`getBundleForVariant`, `saveBundle`, `deleteBundle`, `deleteBundleForVariant`). **No MobX store.** Readers: `RetailInventoryService` (`_deductBundleComponents` `inventory_service.dart:110-153`, `calculateAvailableToSell` `:160-184`, returns, `assembleKit`/`disassembleKit`), `ProductStore.bundlesUsing` (delete guard, `:229-238`), `report_service.dart:1705-1733`. Screens: `bundles_screen.dart`, `bundle_builder_widget.dart`, `assemble_kit_screen.dart`.
- **Update/delete:** saved per variant on product save when there are components, deleted otherwise (`add_product_screen.dart:641-659`). Deleted when its variant/product is deleted.

## 7. BundleComponentModel

**What it is.** One line inside a bundle recipe: "consume 2 of variant X".

**Why the app needs it.** It tells the sale/assembly code which component stock to move.

| Fact | Value |
|---|---|
| Class / file | `BundleComponentModel extends HiveObject` (never stored on its own), `.../bundle_component_model.dart` |
| typeId | **183** `retailBundleComponent` (`hive_type_ids.dart:190`), registered `hive_init.dart:329` |
| Box / key | None — embedded in `RetailBundleModel.components` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | componentVariantId | String | req | – | required | FK → VarianteModel consumed |
| 1 | quantity | **int** | req | – | required | Units consumed per bundle/kit |
| 2 | note | String? | opt | – | – | |

- `quantity` is an **int**, so a loose-goods component cannot be 0.5 kg. The comment "retail sells whole units only" (`:8-11`) is stale now that `isDecimalQuantity` exists. Changing it to double would be a breaking Hive change.
- `fromMap` coerces `num→int` (`:50`). `copyWith` cannot clear `note`.

## 8. RetailKitAssemblyModel

**What it is.** A log line: "assembled (or disassembled) N kits of variant K on date D".

**Why the app needs it.** It is the audit trail for repack/kit production and links to the stock movements it created.

| Fact | Value |
|---|---|
| Class / file | `RetailKitAssemblyModel extends HiveObject`, `.../kit_assembly_model.dart` |
| typeId | **184** `retailKitAssembly` (`hive_type_ids.dart:194`) |
| Box | `kitAssemblies` (`hive_box_names.dart:94`), opened `hive_init.dart:502` |
| Hive key | `id` (`kit_assembly_repository.dart:19`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | bundleId | String | req | – | required | FK → RetailBundleModel.id (the recipe used) |
| 2 | variantId | String | req | – | required | FK → the kit variant |
| 3 | productName | String | req | – | required | Name snapshot |
| 4 | batchQty | **int** | req | – | required | Units assembled (always positive) |
| 5 | assembledTime | DateTime | req | – | required | |
| 6 | assembledBy | String? | opt | – | – | Staff username |
| 7 | movementIds | List<String> | req | – | `const []` | FK list → StockMovementModel ids |
| 8 | isReversal | bool | req | **false** | `false` | true = disassembly |

- **Identifier:** `Uuid().v4()` (`inventory_service.dart:449,554`).
- **Writers:** `RetailInventoryService.assembleKit` (`inventory_service.dart:329-461`): validates all component stock first, deducts components, adds kit stock, weighted-averages kit cost (`unitCost` null if any component cost is unknown), writes the assembly row **last**. `disassembleKit` (`:470-567`) reverses stock using the **current** recipe and does not reverse the cost average.
- **Serialization:** `toMap`/`fromMap` (`:62-87`). No `copyWith` (append-only).
- **Update/delete:** never updated or deleted; repo has no delete. No crash-resume: a crash mid-loop leaves components deducted without kit credit or log row.
- Screen: `assemble_kit_screen.dart` (history `:764`).

---

## 9. Category (shared)

**What it is.** A product group such as "Groceries" or "Footwear".

**Why the app needs it.** Browsing/filtering in POS and catalogue, reports by category, and SKU prefixes.

| Fact | Value |
|---|---|
| Class / file | `Category` — a **plain class, not HiveObject**. `lib/data/models/common/categorymodel_300.dart` |
| typeId | **100** `HiveTypeIds.category` (`hive_type_ids.dart:54`). Old retail 165 is retired |
| Box | `HiveBoxNames.category` = `'categories'` (`hive_box_names.dart:121-123`), **one physical box for both modes**, retail open `hive_init.dart:515` |
| Hive key | `id` (`category_repository.dart:43-50`) |
| Retired index | **2** (old imagePath) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | name | String | req | – | required | Display name |
| 3 | createdTime | DateTime? | opt | – | – | |
| 4 | lastEditedTime | DateTime? | opt | – | – | Set on rename (`category_management_screen.dart:428-432`) |
| 5 | editedBy | String? | opt | – | – | Not set by retail |
| 6 | editCount | int | req | – | `0` | Incremented on rename |

- **Validation:** duplicate names refused case-insensitively **on add only** (`category_store.dart:150-159`); rename is not checked. Plan-gated via `ModeKeys.categoriesAdd/Edit/Delete` (`:136-253`).
- **Identifier:** retail "Add Category" uses `DateTime.now().millisecondsSinceEpoch.toString()` (`category_management_screen.dart:395-399`); first-run seeds (Electronics, Clothing, Groceries, Footwear, Cosmetics, Uncategorized) use UUID v4 (`category_repository.dart:164-184`). So retail ids are mixed.
- **References:** referenced by `ProductModel.category` (id; `''` = none).
- **Serialization:** `fromMap` defaults `editCount ?? 0`; DateTimes stored as ISO in `toMap`. `copyWith` has no clear flags.
- **Where used:** repo `lib/data/repositories/common/category_repository.dart`; store `lib/domain/store/common/category_store.dart`; screen `retail/category_management_screen.dart`.
- **Delete:** `deleteCategory` (`category_repository.dart:72-99`) **never deletes products**; it re-parents them to `''` via `product.copyWith(category: '')` (which also bumps `updateAt`). The store mirrors this in memory (`category_store.dart:234-241`).
- **Legacy:** a separate `Box<String>('retail_categories')` is still opened (`hive_init.dart:510-513`) but only backup touches it (see §49).

## 10. Tax (shared)

**What it is.** A named tax rate, e.g. "GST 18%".

**Why the app needs it.** Products and variants pick a Tax; its percent is copied onto them and used in billing.

| Fact | Value |
|---|---|
| Class / file | `Tax extends HiveObject` (mutable fields), `lib/data/models/common/taxmodel_314.dart` |
| typeId | **114** `HiveTypeIds.tax` (`hive_type_ids.dart:71`) |
| Box | `HiveBoxNames.tax` = `'taxes'` (`hive_box_names.dart:149-151`), shared, opened `hive_init.dart:523` |
| Hive key | `id` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | taxname | String | req | – | required | "GST 18%" |
| 2 | taxperecentage (sic) | double? | opt | – | – | Rate in percent |

- **Validation:** retail Tax Settings requires 0-100 (`tax_settings_screen.dart:527`). The store itself validates nothing.
- **Identifier:** `Uuid().v4()` (`tax_settings_screen.dart:539-541`).
- **References:** referenced by `ProductModel.taxId` (f16) and `VarianteModel.taxId` (f21); the percent is **cached** in `gstRate` (f10) / `taxRate` (f11). Billing reads only the cached rates: variant `taxRate > 0` → product `gstRate > 0` → shop default (`cart_store.dart:820-834`, `gst_service.dart:20-31`).
- **Serialization:** `fromMap` defaults id and name to `''`; `copyWith` cannot clear the rate.
- **Where used:** repo `lib/data/repositories/common/tax_repository.dart`; store `lib/domain/store/common/tax_store.dart`; screens `tax_settings_screen.dart`, `apply_tax_to_products_screen.dart`.
- **Update:** editing a rate does **not** re-cache it onto products/variants; they keep the old rate until "Apply to products" runs again (`ProductStore.applyTaxToProducts`).
- **Delete:** unguarded; products keep their cached rate but `taxId` dangles (the dialog says so, `tax_settings_screen.dart:447-461`).
- **Gotcha:** a deliberately chosen **0%** tax is cached as 0, and the `> 0` checks then fall through to the default rate.

---

# Sales & POS

## 11. CartItemModel

**What it is.** One line in the live POS cart while the cashier is still billing.

**Why the app needs it.** It keeps the cart alive across app restarts and lets several bills be open at once (each tab embeds its own list of cart items).

| Fact | Value |
|---|---|
| Class / file | `CartItemModel extends HiveObject`, `.../cart_model_202.dart` |
| typeId | **152** `retailCart` (`hive_type_ids.dart:136`) |
| Box | `cartItems` (`hive_box_names.dart:59`), opened `hive_init.dart:489`; **also embedded** in `BillingTabModel.items` |
| Hive key | `cartItemId` (`cart_repository.dart:29`) |
| Retired indices | **4, 5, 6** (old size/color/weight, `:98-99`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | cartItemId | String | req | – | required | Id. Also seeds the stock-movement idempotency id `sale_<saleId>_<cartItemId>` |
| 1 | variantId | String | req | – | required | FK → VarianteModel (or a quick-item id) |
| 2 | productId | String | req | – | required | FK → ProductModel |
| 3 | productName | String | req | – | required | Snapshot |
| 7 | price | double | req | – | required | Charged unit price (override included) |
| 8 | qty | double | req | – | required | Quantity (fractional for loose goods) |
| 9 | total | double | req | – | required | **Inclusive mode:** gross after line discount (tax inside). **Exclusive mode:** taxable amount **without GST**. The comment `// price * qty` (`:32`) is wrong |
| 10 | barcode | String? | opt | – | – | Snapshot |
| 11 | addedAt | String (ISO) | req | – | required | |
| 12 | gstRate | double? | opt | – | – | Percent |
| 13 | taxableAmount | double? | opt | – | – | Add-time value; ignores order discount, so checkout ignores it (`checkout_screen.dart:470-475`) |
| 14 | gstAmount | double? | opt | – | – | Add-time GST |
| 15 | cgstAmount | double? | opt | – | – | Half split |
| 16 | sgstAmount | double? | opt | – | – | Half split |
| 17 | hsnCode | String? | opt | – | – | Snapshot |
| 18 | discountAmount | double? | opt | – | – | **Dead**: never written with meaning, never read (`:101-103`) |
| 19 | categoryName | String? | opt | – | – | For GST lookup / display |
| 20 | tabIndex | int? | opt | – | `1` in `create` (`:191`) | Vestigial: tab membership is by embedding |
| 21 | attributes | Map<String,String>? | opt | – | – | Variant descriptors |
| 22 | originalPrice | double? | opt | – | – | Catalogue price when overridden; null = not overridden |
| 23 | overrideReason | String? | opt | – | – | Code |
| 24 | overrideNote | String? | opt | – | – | Text |
| 25 | lineDiscountType | String? | opt | – | – | `percentage`/`amount`; kept so a % can be re-derived |
| 26 | lineDiscountValue | double? | opt | – | – | Raw input |
| 27 | lineDiscountAmount | double? | opt | – | – | Resolved line discount; null = none |
| 28 | lineDiscountReason | String? | opt | – | – | Code |
| 29 | lineDiscountNote | String? | opt | – | – | Text |

- **Identifier:** `'${variantId}_${millisecondsSinceEpoch}'` (`cart_store.dart:477,563`).
- **Getters:** `isPriceOverridden`, `hasLineDiscount`, `grossAmount = price*qty`, `netAmount` (`:161-175`).
- **Money rule:** the authoritative bill is `CartStore.bill` → `RetailBillingService.compute(...)` (`cart_store.dart:132-138`). `CartStore.setTaxMode` is the only writer of the tax mode (`:166-173`). The POS must use the `*InTab` wrappers (tab-snapshot rule).
- **Serialization:** `toMap` (`:264`) **omits `tabIndex`**, but `fromMap` (`:317`) reads it, so it is lost on round-trip. No `copyWith`.
- **Where used:** repo `lib/data/repositories/retail/cart_repository.dart` (`saveCartItem`, `deleteCartItem`, `clearCartItems`); store `lib/domain/store/retail/cart_store.dart`; POS screens.
- **Update/delete:** working rows; cleared after checkout (`clearCartAndSave`, `checkout_screen.dart:564`).

## 12. BillingTabModel

**What it is.** A POS "tab": one of several bills the cashier can switch between.

**Why the app needs it.** Busy counters keep several customers' bills open at the same time.

| Fact | Value |
|---|---|
| Class / file | `BillingTabModel extends HiveObject`, `.../billing_tab_model_173.dart` |
| typeId | **173** `retailBillingTab` (`hive_type_ids.dart:163`) |
| Box | `billingTabs` (`hive_box_names.dart:152`), opened `hive_init.dart:527` with a delete-and-recreate fallback if opening throws (`:525-543`, held tabs lost silently) |
| Hive key | `id` (`cart_repository.dart:50`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Id / key |
| 1 | name | String | req (mutable) | – | required | `'Tab N'` at creation. Goes stale when a middle tab closes; UI uses `CartStore.tabLabel(index)` (`:61-65`) |
| 2 | items | List<CartItemModel> | req (mutable) | – | required | **Embedded snapshot** of the tab's cart |
| 3 | createdAt | DateTime | req (mutable) | – | required | |
| 4 | updatedAt | DateTime | req (mutable) | – | required | |
| 5 | customerName | String? | opt | – | – | Display only |
| 6 | customerPhone | String? | opt | – | – | Display only |

- **Identifier:** `Uuid().v4()` (`cart_store.dart:212,1246`).
- **Getters:** `totalItems`, `totalPrice` (sum of `CartItemModel.total`, so ex-GST in exclusive mode), `isEmpty`, `displayName`.
- **Serialization:** `copyWith` uses `??`, so a customer name cannot be cleared through it.
- **Where used:** `cart_repository.dart:46-61`; store actions `createNewTab` (`:1238`), `switchTab` (`:1262`), `closeTab` (`:1275`, last tab is cleared not deleted), `updateTabCustomerInfo` (`:1309`), `clearAllTabs` (`:1499`). `_saveCurrentTabItems` writes the snapshot on switch/create (`:1293-1306`).

## 13. SaleModel

**What it is.** The header of a finished bill. The same class also stores a **return (credit note)** and each leg of an **exchange**.

**Why the app needs it.** It is the permanent financial record: totals, tax, payment legs, credit due, and links to the shift and the customer. Every report, EOD and the cash drawer read it.

| Fact | Value |
|---|---|
| Class / file | `SaleModel extends HiveObject`, `.../sale_model_203.dart` (`:18-19`) |
| typeId | **153** `retailSale` (`hive_type_ids.dart:137`) |
| Box | `sales` (`hive_box_names.dart:62`), opened `hive_init.dart:490`; repo literal `sale_repository.dart:11` |
| Hive key | `saleId` (`sale_repository.dart:30,35`) |

### Fields

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | saleId | String | req | – | required | Primary key. UUID for sales; `RTN_<uuid>` for returns |
| 1 | customerId | String? | opt | – | – | FK → Customer (`CUST-000042`). Required for credit sales |
| 2 | totalItems | double | req | – | required | Sum of quantities. **Stays positive** on returns |
| 3 | subtotal | double | req | – | required | Gross item total before discount (`bill.itemTotal`). Negated on returns |
| 4 | discountAmount | double | req | – | required | **TOTAL** discount (order + line) in money. Negated on returns |
| 5 | taxAmount | double | req | – | required | Legacy total tax (= `totalGstAmount`). Negated on returns |
| 6 | totalAmount | double | req | – | required | **Canonical grand total** that reports sum. Negated on returns |
| 7 | paymentType | String | req | – | required | `cash`/`card`/`upi`/`credit`/`split`/custom value. Refund method on a return; rewritten to money-leg method or `exchange_credit` on an exchange return |
| 8 | date | String (ISO) | req | – | required | Invoice date (= createdAt at creation) |
| 9 | createdAt | String (ISO) | req | – | required | Creation instant; date ranges and shift attribution use it |
| 10 | updatedAt | String (ISO) | req | – | required | `copyWith` stamps now |
| 11 | isReturn | bool? | opt | **false** | `?? false` (`:239`) | True on a return/credit note |
| 12 | originalSaleId | String? | opt | – | – | On a return: the sale being reversed |
| 13 | totalTaxableAmount | double? | opt | – | – | Sum of line taxable values. Negated on returns |
| 14 | totalGstAmount | double? | opt | – | – | Sum of line GST. Negated on returns |
| 15 | totalCgstAmount | double? | opt | – | – | `TaxSplit.halves(totalGst).cgst` |
| 16 | totalSgstAmount | double? | opt | – | – | `.sgst` |
| 17 | grandTotal | double? | opt | – | – | Same value as `totalAmount` |
| 18 | paymentListJson | String? | opt | – | – | JSON array of payment legs `{method, amount, ref?, received?, cashInDrawer?, change?}`. **Leg `amount` = money actually moved.** Credit sale: `[{method:'credit', amount: grandTotal}]`. Null on a plain return |
| 19 | changeReturn | double? | opt | – | – | Change handed back |
| 20 | totalPaid | double? | opt | – | – | What the customer **tendered** (can exceed total). 0 on credit sale |
| 21 | isSplitPayment | bool? | opt | – | – | More than one leg |
| 22 | paidAmount | double | req | **0.0** | `?? totalAmount` (`:240`) | Settlement toward the bill, clamped to [0, grandTotal]. Rises with credit collections and write-offs. `-totalAmount` on a return header |
| 23 | dueAmount | double | req | **0.0** | – | Receivable left. Full total on a credit sale. Always 0 on a return |
| 24 | status | String | req | **'paid'** | – | `paid` / `partially_paid` / `due` (`SaleStatus`, `:12-16`) |
| 25 | discountType | String? | opt | – | – | `amount`/`percentage` of the **order-level** discount only |
| 26 | discountValue | double? | opt | – | – | Raw order-level input (10 for 10%) |
| 27 | discountReason | String? | opt | – | – | |
| 28 | loyaltyPointsUsed | int? | opt | – | – | Points redeemed |
| 29 | roundOff | double? | opt | – | – | Rounding already inside `totalAmount` (can be negative) |
| 30 | isTaxInclusive | bool? | opt | – | – | Tax mode frozen at sale time. Return copies the original's |
| 31 | lineDiscountTotal | double? | opt | – | – | Part of f4 that came from line discounts. **A subset of f4.** Null = all order-level |
| 32 | exchangeGroupId | String? | opt | – | – | `EXC-00001`; links an exchange's return leg and replacement sale |
| 33 | shiftId | String? | opt | – | – | `RestaurantSession.currentShiftId` at write time → ShiftModel |
| 34 | returnReason | String? | opt | – | – | `SaleReturnReason` code (returns) |
| 35 | returnNote | String? | opt | – | – | Required when reason = `other` |
| 36 | invoiceNumber | String? | opt | – | – | `INV-00001` / `CRN-00001`. Display only, repeats across FYs |
| 37 | taxEnabled | bool? | opt | – | – | Was tax on at sale time |
| 38 | storeGstNumber | String? | opt | – | – | GSTIN snapshot. `''` = none; null = written before this field existed |

### Validation rules and defaults
- **Sign convention:** a return header has negated money fields (f3-f6, f13-f17, f22 = `-totalAmount`), positive `totalItems`, `dueAmount` 0. Header sums therefore net returns automatically (EOD `totalSales` is a plain sum, `eod_service.dart:505-506`).
- `paymentType = 'split'` when there is more than one leg. `createWithSplitPayment` **sorts the caller's leg list in place** by amount descending (`:382`).
- `status` is recomputed by `calculateStatus(paid, due)` (`:642-646`).
- Getters: `paymentList` (falls back to one leg `{paymentType, totalAmount}` when JSON is null, `:428-443`), `displayNumber` (`invoiceNumber` or `saleRef(saleId)`, `:522-525`), `hasDue`, `isCreditSale` (`paymentType == 'credit'`), `statusDisplayText`.
- There is **no** `sessionId` and **no** cashier field. Sales tie to the day only by time window (`eod_service.dart:459-482`) and to staff only through `shiftId → ShiftModel.staffId`.

### Identifier
- `saleId = Uuid().v4()` for sales (`checkout_screen.dart:384` credit, `:649` paid; `exchange_service.dart:459` replacement); `'RTN_${uuid.v4()}'` for returns (`return_service.dart:309`).
- `invoiceNumber` from `saleStore.nextInvoiceNumber()` (`sale_store.dart:52`) → `DocumentNumberService.next('INV')`; returns use `nextCreditNoteNumber()` (`:58`) → `'CRN'`. Format `PREFIX-00001`, resets each financial year.
- `exchangeGroupId` = `DocumentNumberService.next('EXC')` (`exchange_service.dart:429`) → `EXC-00001`. (Comment at `exchange_service.dart:175` saying `EXC-YYYYMMDD-NNN` is stale.)

### Factories
- `create` (`:244`), `createWithGst` (`:288`): legacy, not used by checkout.
- `createWithSplitPayment` (`:333`): paid and partially-paid sales and exchange replacements. `amountCollected` (partial mode only) sets paid/due/status.
- `createCreditSale` (`:446`): `paymentType 'credit'`, paid 0, due = grandTotal, status `due`, totalPaid 0.
- Return header: raw constructor in `ReturnService._buildReturnHeader` (`return_service.dart:401-450`).

### References
- **Live references:** `customerId` → Customer; `originalSaleId` → SaleModel; `shiftId` → ShiftModel; `exchangeGroupId` → sibling SaleModel (a group label, not a key).
- **Snapshots:** all money fields, `isTaxInclusive`, `taxEnabled`, `storeGstNumber`, `roundOff`, discount composition, `invoiceNumber`.
- Referenced by: `SaleItemModel.saleId`, `CreditPaymentModel.saleId`, StockMovement ids `sale_<saleId>_...`.

### Serialization
- **Known bug:** `toMap` (`:648`) writes the decoded legs under key **`'paymentList'`**, but `fromMap` (`:693`) reads **`'paymentListJson'`** (`:668` vs `:724`). The backup uses exactly this pair (`unified_backup_service.dart:1097` export, `:2694-2696` restore). After a restore every sale has `paymentListJson = null`: split sales collapse to one leg, short-paid cash legs become the full total, exchange returns lose their stamped legs. This affects the cash drawer, EOD payment buckets and reprints.
- `toMap` also defaults `totalPaid` to `totalAmount` and `changeReturn` to 0 (`:669-671`).
- `fromMap` makes `date` and `createdAt` fall back to each other (`:701-703`), money defaults to 0, `saleId` is a hard cast.
- `copyWith` (`:548`) copies all fields with `??` (no clear flags), and always refreshes `updatedAt`.

### Where it is created and read
- Repository `lib/data/repositories/retail/sale_repository.dart`: CRUD plus `getSalesByDateRange`, `getSalesByCustomerId`, `getCreditSales`, `getSalesWithDue`, `getCustomerSalesWithDue` (oldest first, for FIFO), `getTotalDueAmount`, `getSalesByStatus`, `getOutstandingReport`, etc.
- Store `lib/domain/store/retail/sale_store.dart`: **`addSaleWithItems`** (`:88`) is the single write entry for checkout, returns and exchanges.
- Writers: `checkout_screen.dart`, `ReturnService`, `ExchangeService`, `CreditStore`. Readers: sales history/detail, return/exchange screens, customer ledger, credit reports, EOD, cash drawer, reports, `ShiftRepository._retailTxns`.

### Update and delete
- **Never deleted in the app** (`SaleStore.deleteSale` and `clearAllSales` have no callers).
- Updated only for settlement or linking: (1) credit collection — paid += x, due −= x, status (`credit_store.dart:192-203`); (2) write-off — same, paid raised (`:292-309`); (3) return against a due invoice — due and status change, `paidAmount` unchanged (`return_service.dart:549-555`); (4) exchange stamping on the RETURN doc — `exchangeGroupId`, `paymentType`, `paymentListJson`, `isSplitPayment` (`exchange_service.dart:525-530`).

## 14. SaleItemModel

**What it is.** One line of a sale or return: what was sold, at what price, with what tax and discount.

**Why the app needs it.** Receipts, GST reports, profit (frozen cost) and returns (how much of each line can still be returned) all read stored lines, never the live catalogue.

| Fact | Value |
|---|---|
| Class / file | `SaleItemModel extends HiveObject`, `.../sale_item_model_204.dart` (`:12-13`) |
| typeId | **154** `retailSaleItem` (`hive_type_ids.dart:138`) |
| Box | `saleItems` (`hive_box_names.dart:65`), opened `hive_init.dart:491` |
| Hive key | `saleItemId` (`sale_item_repository.dart:29,36,42`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | saleItemId | String | req | – | required | UUID key |
| 1 | saleId | String | req | – | required | FK → SaleModel (a return line points at the `RTN_` doc) |
| 2 | varianteId | String | req | – | required | FK → VarianteModel (quick items use a synthetic id) |
| 3 | productId | String | req | – | required | FK → ProductModel |
| 4 | productName | String? | opt | – | – | Snapshot |
| 5 | size | String? | opt | – | – | Legacy descriptor snapshot |
| 6 | color | String? | opt | – | – | Legacy descriptor snapshot |
| 7 | price | double | req | – | required | **Charged** unit price (override applied). Tax-inclusive shelf price in inclusive mode, despite the "before tax" comment |
| 8 | qty | double | req | – | required | Quantity. **Positive on return lines** |
| 9 | total | double | req | – | required | Line total after discount (engine `line.total`) |
| 10 | discountAmount | double? | opt | – | – | **TOTAL** line discount = own discount + share of order discount (`:119-124`) |
| 11 | taxAmount | double? | opt | – | – | Legacy copy of `gstAmount` |
| 12 | barcode | String? | opt | – | – | Snapshot |
| 13 | gstRate | double? | opt | – | – | Percent |
| 14 | taxableAmount | double? | opt | – | – | Taxable value after full discount share |
| 15 | gstAmount | double? | opt | – | – | GST |
| 16 | hsnCode | String? | opt | – | – | Snapshot (TariffCodeRule; name frozen) |
| 17 | cgstAmount | double? | opt | – | – | `TaxSplit.halves(gst).cgst` |
| 18 | sgstAmount | double? | opt | – | – | `.sgst` |
| 19 | weight | String? | opt | – | – | Legacy descriptor |
| 20 | attributes | Map<String,String>? | opt | – | – | All variant descriptors at sale time (`:77-85`) |
| 21 | costPrice | double? | opt | – | – | Unit cost **frozen at sale** (`checkout_screen.dart:489-496`). Return copies the original line's cost. Null = unknown (≠ 0) |
| 22 | originalPrice | double? | opt | – | – | Catalogue price when overridden |
| 23 | overrideReason | String? | opt | – | – | `PriceOverrideReason.code` |
| 24 | overrideNote | String? | opt | – | – | |
| 25 | lineDiscountType | String? | opt | – | – | `DiscountType.name` of the line's OWN discount |
| 26 | lineDiscountValue | double? | opt | – | – | Raw input |
| 27 | lineDiscountAmount | double? | opt | – | – | Line's own discount after cap. **SUBSET of f10 — never add the two** (`:134-140`) |
| 28 | lineDiscountReason | String? | opt | – | – | `LineDiscountReason.code` |
| 29 | lineDiscountNote | String? | opt | – | – | |

- **Identifier:** `Uuid().v4()` inside both factories (`:270`, `:337`).
- **Getters:** `hasLineDiscount`, `billDiscountShare = discountAmount − lineDiscountAmount` (`:188`), `isPriceOverridden`, `overrideDeltaPerUnit`.
- **Factories:** `create` (`:200`) re-derives tax and treats inclusive only in restaurant mode (`:229-230`) — retail never uses it. Retail uses `fromCalculated` (`:304`), which stores the billing engine's numbers as given.
- **References:** live `saleId`, `varianteId`, `productId`; everything else is a snapshot.
- **Serialization:** `toMap`/`fromMap` (`:374`, `:410`); `fromMap` hard-casts the identity fields and defaults money to 0. No `copyWith`.
- **Where used:** repo `lib/data/repositories/retail/sale_item_repository.dart` (`addSaleItem(s)`, `getItemsBySaleId` full scan, top-seller analytics `:159-246`, `isBarcodeEverSold` `:254`). Written only through `SaleStore.addSaleWithItems`.
- **Update/delete:** never edited or deleted (`updateSaleItem`, `deleteSaleItem`, `deleteItemsBySaleId` have no callers).

## 15. HoldSaleModel

**What it is.** A parked (held) bill header — the cashier puts a bill aside to serve someone else.

**Why the app needs it.** To resume the bill later without re-scanning.

| Fact | Value |
|---|---|
| Class / file | `HoldSaleModel extends HiveObject`, `.../hold_sale_model_209.dart` |
| typeId | **159** `retailHoldSale` (`hive_type_ids.dart:145`) |
| Box | `holdSales` (`hive_box_names.dart:113`), opened `hive_init.dart:504` |
| Hive key | `holdSaleId` (`hold_sale_repository.dart:19,41`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | holdSaleId | String | req | – | required | Key |
| 1 | customerId | String? | opt | – | – | **Never set by `HoldSaleService.park`** |
| 2 | customerName | String? | opt | – | – | Never set by `park` |
| 3 | note | String? | opt | – | – | Why it was parked |
| 4 | totalItems | double | req | – | required | Qty sum |
| 5 | subtotal | double | req | – | required | **The payable GRAND TOTAL at park time** (`park` passes `bill.grandTotal`, `hold_sale_service.dart:34`) despite the name |
| 6 | createdAt | String | req | – | required | ISO |
| 7 | updatedAt | String | req | – | required | ISO |
| 8 | itemTotal | double? | opt | – | – | Gross before discount |
| 9 | discountAmount | double? | opt | – | – | Total discount; replayed as an order-level amount on restore (`:170-175`) |
| 10 | taxableAmount | double? | opt | – | – | |
| 11 | gstAmount | double? | opt | – | – | |
| 12 | isTaxInclusive | bool? | opt | – | – | Mode at park time |

- **Identifier:** `'HOLD_${Uuid().v4()}'` (`hold_sale_service.dart:28`).
- **Serialization:** `toMap`/`fromMap` (`:99`, `:117`); no `copyWith`.
- **Where used:** repo `lib/data/repositories/retail/hold_sale_repository.dart`; store `hold_sale_store.dart`; service `HoldSaleService.park` (`:22`) / `restore` (`:81`); screen `parked_sales_screen.dart`.
- **Update/delete:** restore replays lines into the cart, then **hard-deletes** the hold. A customer attached at park time is lost (not stored, and `resetBillingInputs` clears it).

## 16. HoldSaleItemModel

**What it is.** One line of a parked bill.

**Why the app needs it.** Restore needs the exact price, tax rate, overrides and line discounts to rebuild the cart.

| Fact | Value |
|---|---|
| Class / file | `HoldSaleItemModel extends HiveObject`, `.../hold_sale_item_model_210.dart` |
| typeId | **160** `retailHoldSaleItem` (`hive_type_ids.dart:146`) |
| Box | `holdSaleItems` (`hive_box_names.dart:116`), opened `hive_init.dart:505` |
| Hive key | `holdSaleItemId` (`hold_sale_repository.dart:54,60,79`) |
| Retired indices | **5, 6, 7** (`:65-66`). f17 is declared out of order |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | holdSaleItemId | String | req | – | required | Key |
| 1 | holdSaleId | String | req | – | required | FK → HoldSaleModel |
| 2 | variantId | String | req | – | required | FK → variant (or quick-item id) |
| 3 | productId | String | req | – | required | FK |
| 4 | productName | String | req | – | required | Snapshot |
| 8 | price | double | req | – | required | Charged unit price |
| 9 | qty | double | req | – | required | |
| 10 | total | double | req | – | required | `price * qty` (gross, `:160`) |
| 11 | barcode | String? | opt | – | – | |
| 12 | createdAt | String | req | – | required | ISO |
| 13 | gstRate | double? | opt | – | – | Replayed via `gstRateOverride` on restore |
| 14 | taxableAmount | double? | opt | – | – | |
| 15 | gstAmount | double? | opt | – | – | |
| 16 | discountAmount | double? | opt | – | – | TOTAL line discount share |
| 17 | attributes | Map<String,String>? | opt | – | – | Descriptors |
| 18 | originalPrice | double? | opt | – | – | Override audit |
| 19 | overrideReason | String? | opt | – | – | |
| 20 | overrideNote | String? | opt | – | – | |
| 21 | lineDiscountType | String? | opt | – | – | Replayed by type+value |
| 22 | lineDiscountValue | double? | opt | – | – | |
| 23 | lineDiscountAmount | double? | opt | – | – | |
| 24 | lineDiscountReason | String? | opt | – | – | |
| 25 | lineDiscountNote | String? | opt | – | – | |

- **Identifier:** `'${holdSaleId}_${variantId}_${millisecondsSinceEpoch}'` (`:149`) — two lines of the same variant in the same millisecond would collide.
- **Gotcha:** quick items are restored with `qty.round()` (`hold_sale_service.dart:102`), losing fractions.
- **Delete:** hard-deleted together with the header on restore.

## 17. PaymentMethod (shared)

**What it is.** A tender type the shop accepts: Cash, Card, UPI, Wallet, Credit, Other, or a custom one.

**Why the app needs it.** It drives the checkout payment buttons and the reporting buckets.

| Fact | Value |
|---|---|
| Class / file | `PaymentMethod extends HiveObject`, `lib/models/payment_method.dart` |
| typeId | **literal `6`** (`:5`). Constant `HiveTypeIds.paymentMethod = 6` exists (`hive_type_ids.dart:47`) but is not used here |
| Box | `paymentMethods` = `'paymentMethodsBox'` (`hive_box_names.dart:40`), shared, opened `hive_init.dart:194` |
| Hive key | **auto-int** (`box.add`, `payment_method_repository.dart:74-76,110-113`). The `id` field is NOT the key |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID (not the key) |
| 1 | name | String | req | – | required | Display name |
| 2 | value | String | req | – | required | **Reporting bucket key** (`cash`, `card`, `upi`, `wallet`, `credit`, `other`, or a slug). Sales store this string, not the id |
| 3 | iconName | String | req | – | required | |
| 4 | isEnabled | bool | req | – | `true` | |
| 5 | sortOrder | int | req | – | `0` | |

- **Seeds:** Cash, Card, UPI enabled; Wallet, Credit, Other disabled (`hive_init.dart:197-198,206-264`; duplicate seeder in `payment_method_repository.dart:9-19`).
- **Identifier:** `id` = UUID; new `value` = `name.toLowerCase().replaceAll(' ', '_')`; `sortOrder` = length + 1 (`lib/stores/payment_method_store.dart`).
- **Update/delete:** `update`, `delete`, `toggleEnabled` find the position by `id` and use `putAt`/`deleteAt` (`:116-143`). Built-in methods keep their `value` on edit (`payment_methods_screen.dart:255-262`). Delete is a hard delete with no history guard; past sales keep the value string.

---

# Customers & Credit

## 18. Customer (shared)

**What it is.** A shop customer: name, phone, GSTIN, loyalty points and credit (amount owed).

**Why the app needs it.** Named bills, B2B GST invoices, loyalty, and selling on credit with collections.

| Fact | Value |
|---|---|
| Class / file | `Customer extends HiveObject`, `lib/data/models/common/customer_model_125.dart` |
| typeId | **125** `HiveTypeIds.customer` (`hive_type_ids.dart:85`). Old retail 158 retired |
| Box | `HiveBoxNames.customer` = `'customers'` (`hive_box_names.dart:63-66`), **one shared physical box**, opened `hive_init.dart:503`. The class comment "each mode keeps its own box" (`:6-7`) is stale |
| Hive key | `customerId` (`customer_repository.dart:19-21,55-57`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | customerId | String | req | – | required | Id / key |
| 1 | name | String? | opt | – | – | |
| 2 | phone | String? | opt | – | – | Unique by UI pre-check only (`customer_list_screen.dart:226-234`) |
| 3 | totalVisites (sic) | int | req | – | `0` | Visit count |
| 4 | lastVisitAt | String? | opt | – | – | Sorts `recentCustomers` |
| 5 | lastorderType | String? | opt | – | – | Restaurant only |
| 6 | favoriteItems | String? | opt | – | – | Restaurant |
| 7 | foodPrefrence (sic) | String? | opt | – | – | Restaurant |
| 8 | notes | String? | opt | – | – | |
| 9 | loyaltyPoints | int | req | – | `0` | Current points balance |
| 10 | createdAt | String | req | – | required | |
| 11 | updatedAt | String? | opt | – | – | `copyWith` sets now |
| 12 | email | String? | opt | – | – | |
| 13 | address | String? | opt | – | – | |
| 14 | gstNumber | String? | opt | – | – | Upper-cased by retail UI |
| 15 | totalPurchaseAmount | double | req | **0.0** | `0.0` | Lifetime spend, net of returns |
| 16 | totalPointEarned | int | req | **0** | `0` | |
| 17 | totalPointRedeemed | int | req | **0** | `0` | |
| 18 | creditBalance | double | req | **0.0** | `0.0` | Credit owed now. `Customer.create(openingBalance:)` sets it (`:129`) |
| 19 | creditLimit | double | req | **0.0** | `0.0` | 0 = unlimited (`customer_store.dart:348,357`) |

- **Identifier (retail):** `CustomerIdGeneratorService.generate()` → `CUST-<6 digits>` from `appCounters['lastCustomerSequence']`, skipping ids already in the box (`lib/domain/services/retail/customer_id_generator_service.dart:20-45`). Callers `customer_list_screen.dart:240`, `customer_selection_screen.dart:231`. Restaurant uses UUIDs.
- **References:** referenced by `SaleModel.customerId`, `CreditPaymentModel.customerId`.
- **Serialization:** `fromMap` (`:160-183`) fully defensive (`createdAt ?? now`). `copyWith` (`:185-236`) never changes id/createdAt; clear flags `clearEmail`, `clearAddress`, `clearGstNumber`, `clearNotes`, `clearFoodPrefrence`.
- **Where used:** repo `lib/data/repositories/common/customer_repository.dart` (counters `incrementVisitCount`, `updatePurchaseAmount`, `addLoyaltyPoints`, `redeemPoints` with over-redeem guard, `updateCredit`, `updateCreditLimit`); store `lib/domain/store/common/customer_store.dart` (`addCustomer` plan-gated; `updateAfterPurchase`, `updateAfterReturn` (no visit), `updateAfterCreditSale`, `canMakeCreditPurchase`, `reduceCredit`). Screens may need to call `loadCustomers()` themselves (the store does not self-hydrate). Screens: `customer_list_screen.dart`, `customer_selection_screen.dart`, `customer_detail_screen.dart`.
- **Delete:** retail has **no delete UI**; no soft-delete flag.

## 19. CreditPaymentModel

**What it is.** One row in the customer receivables ledger: a collection against an invoice, a write-off, or a return offset.

**Why the app needs it.** It explains every change in a customer's credit balance and feeds collection totals into EOD.

| Fact | Value |
|---|---|
| Class / file | `CreditPaymentModel extends HiveObject`, `.../credit_payment_model_218.dart` |
| typeId | **168** `retailCreditPayment` (`hive_type_ids.dart:157`) |
| Box | `creditPayments` = `'credit_payments'` (`hive_box_names.dart:132`), opened `hive_init.dart:517` |
| Hive key | `paymentId` (`credit_payment_repository.dart:35`) — **auto-int after restore** |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | paymentId | String | req | – | required | Key |
| 1 | customerId | String | req | – | required | FK → Customer |
| 2 | saleId | String | req | – | required | FK → the INVOICE settled. For a return offset it is the ORIGINAL sale |
| 3 | amount | double | req | – | required | Amount applied (positive) |
| 4 | paymentMode | String | req | – | required | `cash`/`card`/`upi`/…, `'write_off'`, `'return_adjustment'`. Lower-cased in `create` |
| 5 | date | String (ISO) | req | – | required | = createdAt |
| 6 | referenceId | String? | opt | – | – | UPI/card ref; for a return offset the `RTN_` id |
| 7 | note | String? | opt | – | – | |
| 8 | createdAt | String (ISO) | req | – | required | |
| 9 | balanceBefore | double | req | – | required | Customer `creditBalance` before |
| 10 | balanceAfter | double | req | – | required | `balanceBefore − amount` |
| 11 | isWriteOff | bool? | opt | – | `false` in `create` | |

- **Identifier:** `Uuid().v4()` (`credit_store.dart:175,277`; `return_service.dart:537`).
- **Getters:** `isDebtWriteOff`, `isReturnAdjustment`, **`isCollection`** = not write-off and not return adjustment (`:109`) — the one definition of "money received".
- **Writers:** `CreditStore.receivePayment` (FIFO across due invoices, one row per invoice, `credit_store.dart:167-209`; a cash collection also writes a CashMovement `in` "Credit collection", `:225-232`); `writeOffDebt` (`:254-325`); `ReturnService._settle` (`return_service.dart:516-547`).
- **Known bug:** in `receivePayment` `balanceBefore` is not advanced per invoice (`:165,176`), so rows 2+ of a multi-invoice payment have wrong before/after balances.
- **Inconsistency:** a write-off raises the sale's `paidAmount`; a return offset does not.
- **Update/delete:** never edited or deleted (`deletePayment` has no callers). Screens: `receive_payment_screen.dart`, `customer_ledger_screen.dart`, `credit_reports_screen.dart`.

---

# Purchasing

Shared facts for this group:
- None of these models has a Hive `defaultValue`. Status enums are stored as a **String** (`enum.name`) and parsed with `firstWhere(orElse: default)`, so adding a new enum value needs no migration.
- Document numbers come from `DocumentNumberService.next(prefix, isTaken:)` (`lib/domain/services/common/document_number_service.dart:68-74`): format `PREFIX-00001`, reset each financial year, `isTaken` skips numbers already in the box so a new-year `PO-00001` does not clash with last year's. Counters live in the raw `appCounters` box and are shared between modes. The number is reserved when the form opens, so an abandoned form leaves a gap. Model comments that show `PO-20250101-001` style are stale.
- In the "Ctor default" column, "create: x" means the default is set by the `create(...)` factory, not the plain constructor.

| Document | Prefix | Called from | `isTaken` source |
|---|---|---|---|
| Purchase order | `PO` | `purchase_order_repository.dart:109-114` | `purchaseOrders` box |
| GRN | `GRN` | `grn_repository.dart:98-103` | `grns` box |
| Purchase return | `PR` | `damaged_goods_store.dart:165-168` | in-memory list |
| Supplier claim | `CLM` | `damaged_goods_store.dart:203-206` | in-memory list |
| Inventory loss | `LOSS` | `damaged_goods_store.dart:246-249,372-375,516-519,618-621` | in-memory list |
| Stock take | `ST` | `stock_take_store.dart:184-187` | in-memory `takes` |

## 20. SupplierModel

**What it is.** A vendor the shop buys from, with the running balance the shop owes them.

**Why the app needs it.** Purchase orders, goods receipts and the supplier ledger all hang off a supplier.

| Fact | Value |
|---|---|
| Class / file | `SupplierModel extends HiveObject`, `.../supplier_model_205.dart` |
| typeId | **155** `retailSupplier` (`hive_type_ids.dart:139`) |
| Box | `suppliers` (`hive_box_names.dart:69`), opened `hive_init.dart:492`. Restaurant has its own separate supplier model/box |
| Hive key | `supplierId` (`supplier_repository.dart:26-34`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | supplierId | String | req | – | required | Key |
| 1 | name | String | req | – | required | |
| 2 | phone | String? | opt | – | – | |
| 3 | address | String? | opt | – | – | |
| 4 | gstNumber | String? | opt | – | – | Upper-cased by UI |
| 5 | openingBalance | double | req | – | `0` | Balance at creation |
| 6 | currentBalance | double | req | – | `0` | Owed (+) or advance (−). **Moves only through `SupplierStore.recordBalanceMovement`** |
| 7 | createdAt | String | req | – | required | |
| 8 | updatedAt | String | req | – | required | |

- No email and no soft-delete flag.
- **Identifier:** `SupplierModel.create` → `_uuid.v4()` (`:50-71`).
- **Serialization:** `copyWith` (`:73-99`) cannot change id/createdAt; clear flags `clearPhone`, `clearAddress`, `clearGstNumber`. `toMap`/`fromMap` (`:101-128`).
- **Balance rule:** `recordBalanceMovement` (`supplier_store.dart:166-206`) writes a ledger row first, then calls `SupplierRepository.updateSupplierBalance` (its only caller). `addSupplier` (`:53-71`) writes an `opening` ledger row when the opening balance is non-zero (the model already has `currentBalance = opening`).
- **Where used:** repo `lib/data/repositories/retail/supplier_repository.dart`; store `lib/domain/store/retail/supplier_store.dart` (`totalOutstanding`, `canAddSupplier` plan gate, `getLedger`); screens `supplier_list_screen.dart`, `supplier_detail_screen.dart`, `supplier_payment_dialog.dart`.
- **Update:** edit (`supplier_list_screen.dart:220-232`) cannot change balances, but it writes a full `copyWith` snapshot including the in-memory `currentBalance` (stale-snapshot risk, doc R-52).
- **Delete:** `deleteBlockers` (`supplier_store.dart:283-307`) blocks on POs, GRNs, purchase returns, claims, any non-opening ledger row, or `|currentBalance| > 0.009`. If allowed, `deleteSupplier` (`:94-105`) deletes the supplier **and all its ledger rows**.

## 21. SupplierLedgerEntryModel

**What it is.** One line in the supplier's account statement: opening balance, purchase (GRN), return credit, claim credit, payment, or manual adjustment.

**Why the app needs it.** It is the audit trail behind `SupplierModel.currentBalance`.

| Fact | Value |
|---|---|
| Class / file | `.../supplier_ledger_entry_model_179.dart` |
| typeId | **179** `retailSupplierLedgerEntry` |
| Box | `supplierLedger` (`hive_box_names.dart:77`), opened `hive_init.dart:493` |
| Hive key | `entryId` (`supplier_ledger_repository.dart:15`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | entryId | String | req | – | required | Key (UUID, `:126`) |
| 1 | supplierId | String | req | – | required | FK → SupplierModel |
| 2 | date | String | req | – | required | Business date (may be back-dated; GRN uses `receivedDate`) |
| 3 | type | String | req | – | required | `SupplierLedgerType`: `opening, purchase, returnCredit, claimCredit, payment, adjustment` (`:17-24`) |
| 4 | amount | double | req | – | required | **Signed**: + raises payable, − reduces |
| 5 | balanceAfter | double | req | – | required | Balance after this row at entry time (audit only) |
| 6 | description | String | req | – | required | |
| 7 | docNumber | String? | opt | – | – | `GRN-`/`PR-`/`CLM-` number |
| 8 | docId | String? | opt | – | – | grnId/returnId/claimId. Used for idempotency (`hasEntryForDoc`) |
| 9 | paymentMode | String? | opt | – | – | For payments |
| 10 | referenceNo | String? | opt | – | – | Cheque/UTR/CN number |
| 11 | note | String? | opt | – | – | |
| 12 | createdAt | String | req | – | required | Entry time |

- **Helpers:** `summariseLedger` (closing = Σ amounts, `:259-300`), `compareLedgerOrder` (day, then createdAt, `:306-313`), `ledgerRunningBalances` (`:319-330`).
- **Writers:** `SupplierStore.recordBalanceMovement` (GRN receive, credit note, claim settle, payment/adjustment dialog) and `addSupplier` (opening). `getLedger` synthesises "Balance brought forward" when empty (`supplier_store.dart:241`).
- **Crash window:** row saved first, balance second; a crash between leaves balance ≠ ledger sum, and resume skips because the row exists.
- **Delete:** only when the supplier is deleted.

## 22. PurchaseOrderModel

**What it is.** An order the shop sends to a supplier: "please deliver these items by this date".

**Why the app needs it.** Every goods receipt (GRN) must be raised against a PO; there is no standalone GRN.

| Fact | Value |
|---|---|
| Class / file | `PurchaseOrderModel extends HiveObject`, `.../purchase_order_model_211.dart` |
| typeId | **161** `retailPurchaseOrder` (`hive_type_ids.dart:147`) — file suffix 211 is not the typeId |
| Box | `purchaseOrders` (`hive_box_names.dart:84`), opened `hive_init.dart:506` |
| Hive key | `poId` (`purchase_order_repository.dart:26`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | poId | String | req | – | required | Key — **millisecond timestamp string**, not UUID |
| 1 | poNumber | String | req | – | required | `PO-00001` |
| 2 | supplierId | String | req | – | required | FK → SupplierModel |
| 3 | supplierName | String? | opt | – | – | Snapshot |
| 4 | expectedDeliveryDate | String | req | – | required | ISO date (UI default today+7) |
| 5 | totalItems | double | req | – | create: 0 | Σ orderedQty (recomputed by store) |
| 6 | estimatedTotal | double | req | – | create: 0 | Σ line estimatedTotal |
| 7 | status | String | req | – | create: `draft` | `POStatus` |
| 8 | notes | String? | opt | – | – | |
| 9 | createdAt | String | req | – | required | ISO |
| 10 | updatedAt | String | req | – | required | `copyWith` always sets now (`:179`) |

- **POStatus** (`:15-22`): `draft, sent, partiallyCompleted, fullyCompleted, cancelled, closed`. Unknown → draft. `canEdit` = draft; `canReceive` = sent or partiallyCompleted; `isCompleted` = fully/cancelled/closed.
- **Identifier:** `poId = DateTime.now().millisecondsSinceEpoch.toString()` (`:84`) — two POs in the same millisecond would collide. `poNumber` via `DocumentNumberService.next('PO')`, reserved when the form opens (`add_purchase_order_screen.dart:46-59`).
- **Received quantity is not stored.** It is derived from CONFIRMED GRN lines (`getTotalReceivedQtyForPOItem`, `getPOItemReceipts`, `progressFor`, `purchase_order_store.dart:554-607`).
- **Serialization:** `copyWith` cannot null `supplierName`/`notes`.
- **Where used:** repos `purchase_order_repository.dart`, `purchase_order_item_repository.dart`; store `PurchaseOrderStore` (`lib/domain/store/retail/purchase_order_store.dart`); screens `purchase_order_list_screen.dart`, `add_purchase_order_screen.dart`, `purchase_order_detail_sheet.dart`, `supplier_detail_screen.dart`.
- **Create:** plan key `purchaseCreate`, supplier and ≥1 line required; header written first, then lines (no transaction) (`purchase_order_store.dart:94-110`).
- **Status changes:** draft → sent ("Mark Sent"); draft → cancelled; sent/partial → partially/fullyCompleted on GRN confirm (`_updatePOStatusAfterGRN`, `:462-500`, line complete when received ≥ ordered − 1e-6; never reopens closed/cancelled); sent/partial → closed (short-close, terminal, `:254-260`). No way back to draft; a sent order cannot be cancelled, only closed.
- **Update (draft only):** every save creates lines with **new UUIDs**: new lines added first, old lines deleted, header last (`:112-141`). A crash leaves duplicate lines, never zero.
- **Delete:** only draft and only with no GRNs (`canDeletePurchaseOrder`, `:265-271`); header deleted first, then lines (a crash leaves orphan lines).

## 23. PurchaseOrderItemModel

**What it is.** One line of a PO: which variant, how many, estimated price.

**Why the app needs it.** Receiving works line by line against these.

| Fact | Value |
|---|---|
| File | `.../purchase_order_item_model_212.dart` |
| typeId | **162** `retailPurchaseOrderItem` |
| Box | `purchaseOrderItems` (`hive_box_names.dart:104`), opened `hive_init.dart:507` |
| Hive key | `poItemId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | poItemId | String | req | – | required | UUID key (`:68`) |
| 1 | poId | String | req | – | required | FK → PurchaseOrderModel |
| 2 | variantId | String | req | – | required | FK → VarianteModel |
| 3 | productId | String | req | – | required | FK → ProductModel |
| 4 | productName | String? | opt | – | – | Snapshot |
| 5 | variantInfo | String? | opt | – | – | Snapshot, e.g. "Size: L, Color: Red" |
| 6 | orderedQty | double | req | – | required | |
| 7 | estimatedPrice | double? | opt | – | – | Unit estimate |
| 8 | estimatedTotal | double? | opt | – | – | `orderedQty × estimatedPrice`, null if no price (`:76`) |
| 9 | createdAt | String | req | – | required | |

- No receiving fields by design (`:9-10`). Bundles cannot be added to a PO (picker excludes them).
- Lines are replaced (new ids) on every PO edit; deleted with the PO.

## 24. GRNModel

**What it is.** A Goods Received Note: "on this date we received these quantities against PO X". It is the only way stock enters the shop from a supplier.

**Why the app needs it.** It adds stock, updates weighted average cost, bills the supplier, and records damaged goods.

| Fact | Value |
|---|---|
| File | `.../grn_model_213.dart` |
| typeId | **163** `retailGrn` |
| Box | `grns` (`hive_box_names.dart:107`), opened `hive_init.dart:508` |
| Hive key | `grnId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | grnId | String | req | – | required | UUID key (`:104`) |
| 1 | grnNumber | String | req | – | required | `GRN-00001` |
| 2 | poId | String | req | – | required | FK → PO (required; no standalone GRN) |
| 3 | poNumber | String | req | – | required | Snapshot |
| 4 | supplierId | String | req | – | required | FK → supplier (copied from PO) |
| 5 | supplierName | String? | opt | – | – | Snapshot |
| 6 | receivedDate | String | req | – | required | ISO; picker allows today−30 days to today; also the ledger date |
| 7 | totalOrderedQty | double | req | – | required | Σ line orderedQty — **the REMAINING qty at receipt time** |
| 8 | totalReceivedQty | double | req | – | required | Σ receivedQty |
| 9 | totalAmount | double? | opt | – | – | **Billable** total = Σ receivedQty × costPrice (**damaged included**). This is what the supplier is owed |
| 10 | status | String | req | – | create: `draft` | `GRNStatus`: `draft, confirmed, cancelled` |
| 11 | notes | String? | opt | – | – | |
| 12 | invoiceNumber | String? | opt | – | – | Supplier's invoice number |
| 13 | createdAt | String | req | – | required | |
| 14 | updatedAt | String | req | – | required | `copyWith` sets now |

- `draft` exists only as the "receipt in progress" marker written first by `GrnReceivingService`. Getters: `canEdit`, `isConfirmed`, `isFullyReceived`, `isPartiallyReceived`, `shortageQty`.
- **Receive flow** (`lib/domain/services/retail/grn_receiving_service.dart`): guard double-tap and duplicate number → (1) `createGRN` writes draft header + lines → (2) per line: stock += acceptedQty, cost = weighted average, StockMovement `in` / "Goods received" with id `grn_<grnItemId>` and `unitCost` → (3) supplier ledger `purchase` for `totalAmount` → (4) damaged-goods documents → (5) `confirmGRN` + PO status. Each step is idempotent, so `resumeInterrupted()` (run when the PO list, receiving screen or close-order opens) can finish a crashed receipt. Residual windows: crash between stock write and its movement row → double stock on resume; partial damaged docs → the rest are never created.
- **Update/delete:** in practice never. `updateGRN`, `deleteGRN`, `cancelGRN`, `prepareGRNItemsFromPO`, `loadDraftGRNs` exist in `PurchaseOrderStore` without UI callers or status guards (R-49).

## 25. GRNItemModel

**What it is.** One received line: ordered vs received vs accepted vs damaged, and the unit cost.

**Why the app needs it.** It is the source of stock-in, cost averaging, PO progress, and damaged-goods documents.

| Fact | Value |
|---|---|
| File | `.../grn_item_model_214.dart` |
| typeId | **164** `retailGrnItem` |
| Box | `grnItems` (`hive_box_names.dart:110`), opened `hive_init.dart:509` |
| Hive key | `grnItemId` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | grnItemId | String | req | – | required | UUID key (`:122`); also seeds movement id `grn_<grnItemId>` |
| 1 | grnId | String | req | – | required | FK → GRNModel |
| 2 | poItemId | String | req | – | required | FK → PO line (drives received totals) |
| 3 | variantId | String | req | – | required | FK → variant (stock target) |
| 4 | productId | String | req | – | required | FK → product |
| 5 | productName | String? | opt | – | – | Snapshot |
| 6 | variantInfo | String? | opt | – | – | Snapshot |
| 7 | orderedQty | double | req | – | required | **Remaining** qty when receiving started |
| 8 | receivedQty | double | req | – | required | Physical units delivered (incl. damaged) |
| 9 | acceptedQty | double | req | – | required | received − damaged → enters stock |
| 10 | damagedQty | double? | opt | – | – | Null when 0 |
| 11 | damagedHandling | String? | opt | – | – | `DamagedHandling`: `none, keepForClaim, returnToSupplier, writeOff` |
| 12 | costPrice | double? | opt | – | – | Unit cost; UI blocks ≤ 0 on received lines |
| 13 | totalAmount | double? | opt | – | – | **Inventory value** = acceptedQty × costPrice (`:135`). Not billable |
| 14 | remarks | String? | opt | – | – | |
| 15 | createdAt | String | req | – | required | |
| 16 | damagedAmount | double? | opt | – | – | damagedQty × costPrice (`:136`) |

- Getters: `billableQty = receivedQty`, `billableAmount = receivedQty × costPrice` (`:163-167`), `goodQty = received − damaged` (`:155`).
- Damaged units **never enter stock** but **are billed**. The comment at `hive_type_ids.dart:165-167` saying they are never billed is stale.
- Never updated after confirm.

## 26. PurchaseReturnModel

**What it is.** A document sending damaged goods back to the supplier and tracking the supplier's credit note.

**Why the app needs it.** To reduce what the shop owes once the supplier issues a credit note.

| Fact | Value |
|---|---|
| File | `.../purchase_return_model_174.dart` |
| typeId | **174** `retailPurchaseReturn` |
| Box | `purchaseReturns` (`hive_box_names.dart:87`), opened `hive_init.dart:494` |
| Hive key | `returnId` (UUID, `:138`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | returnId | String | req | – | required | Key |
| 1 | returnNumber | String | req | – | required | `PR-00001` |
| 2 | grnId | String | req | – | required | Source GRN |
| 3 | grnNumber | String | req | – | required | Snapshot |
| 4 | poId | String | req | – | required | |
| 5 | poNumber | String | req | – | required | |
| 6 | supplierId | String | req | – | required | |
| 7 | supplierName | String? | opt | – | – | Snapshot |
| 8 | returnDate | String | req | – | required | = createdAt |
| 9 | totalQty | double | req | – | `0` | Σ damagedQty |
| 10 | totalAmount | double | req | – | `0` | Σ damagedAmount |
| 11 | status | String | req | – | required | `PurchaseReturnStatus`: `pending, creditReceived, cancelled` |
| 12 | creditNoteNumber | String? | opt | – | – | Supplier's CN number |
| 13 | creditNoteDate | String? | opt | – | – | |
| 14 | creditNoteAmount | double? | opt | – | – | Face value (may be < totalAmount) |
| 15 | notes | String? | opt | – | – | e.g. "Raised automatically from GRN-…" |
| 16 | createdAt | String | req | – | required | |
| 17 | updatedAt | String | req | – | required | |
| 18 | creditApplied | bool? | opt | – | – | Exactly-once guard for the balance credit |

- **Created** only by `DamagedGoodsStore.recordFromGRN` → `_createReturn` (one per GRN for `returnToSupplier` lines, `damaged_goods_store.dart:163-200`).
- **Credit note:** `recordCreditNote` (`:286-340`) — amount must be 0..totalAmount; saves status `creditReceived` with `creditApplied`, **then** posts ledger `returnCredit` of `-amount`. `creditAdjustment` (`:176-179`) returns 0 if already applied.
- **Cancel:** `cancelPurchaseReturn` (`:353-403`), pending only; status saved, then each line becomes an `InventoryLossModel` (`return_cancelled`). No balance movement.
- **Never touches stock.** No delete.

## 27. PurchaseReturnItemModel

**What it is / why.** One returned line, tied to the GRN line it came from.

| Fact | Value |
|---|---|
| File | `.../purchase_return_item_model_175.dart` |
| typeId | **175** `retailPurchaseReturnItem` |
| Box | `purchaseReturnItems` (`hive_box_names.dart:88`), opened `hive_init.dart:495` |
| Hive key | `returnItemId` (UUID) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | returnItemId | String | req | – | required | Key |
| 1 | returnId | String | req | – | required | FK → PurchaseReturnModel |
| 2 | grnItemId | String | req | – | required | Source GRN line |
| 3 | variantId | String | req | – | required | |
| 4 | productId | String | req | – | required | |
| 5 | productName | String? | opt | – | – | Snapshot |
| 6 | variantInfo | String? | opt | – | – | Snapshot |
| 7 | returnedQty | double | req | – | required | = damagedQty |
| 8 | costPrice | double? | opt | – | – | |
| 9 | totalAmount | double? | opt | – | – | returnedQty × costPrice |
| 10 | remarks | String? | opt | – | – | |
| 11 | createdAt | String | req | – | required | |

`returnedQtyForGRNItem` (`purchase_return_repository.dart:51-62`) supports partial returns, but no UI creates a second return.

## 28. SupplierClaimModel

**What it is.** A claim to the supplier for damaged goods the shop keeps (e.g. asking for a discount instead of sending them back).

**Why the app needs it.** To track the claim and credit the supplier balance when it is settled.

| Fact | Value |
|---|---|
| File | `.../supplier_claim_model_176.dart` |
| typeId | **176** `retailSupplierClaim` |
| Box | `supplierClaims` (`hive_box_names.dart:89`), opened `hive_init.dart:496` |
| Hive key | `claimId` (UUID) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | claimId | String | req | – | required | Key |
| 1 | claimNumber | String | req | – | required | `CLM-00001` |
| 2 | grnId | String | req | – | required | Source GRN |
| 3 | grnNumber | String | req | – | required | |
| 4 | poId | String | req | – | required | |
| 5 | poNumber | String | req | – | required | |
| 6 | supplierId | String | req | – | required | |
| 7 | supplierName | String? | opt | – | – | |
| 8 | claimDate | String | req | – | required | = createdAt |
| 9 | totalQty | double | req | – | `0` | |
| 10 | totalAmount | double | req | – | `0` | Value claimed; **credited on settle** (the "never posted" comment at `:72-73` is stale) |
| 11 | status | String | req | – | required | `SupplierClaimStatus`: `pending, approved, rejected, settled` |
| 12 | resolutionNote | String? | opt | – | – | |
| 13 | resolvedAt | String? | opt | – | – | Set on rejected/settled |
| 14 | notes | String? | opt | – | – | |
| 15 | createdAt | String | req | – | required | |
| 16 | updatedAt | String | req | – | required | |
| 17 | creditApplied | bool? | opt | – | – | Exactly-once settle credit |
| 18 | lossRecorded | bool? | opt | – | – | Exactly-once write-off of a rejected claim |

- **Transitions** (`updateClaimStatus`, `damaged_goods_store.dart:434-487`): pending→approved; pending/approved→rejected; approved→settled. Settle posts ledger `claimCredit` of `-totalAmount` (`claimBalanceAdjustment`, `:185-192`).
- `writeOffRejectedClaim` (`:501-554`) writes losses (`claim_rejected`) first, then sets `lossRecorded` (a crash between would duplicate losses on retry).
- Never touches stock. No delete.

## 29. SupplierClaimItemModel

| Fact | Value |
|---|---|
| File | `.../supplier_claim_item_model_177.dart` |
| typeId | **177** `retailSupplierClaimItem` |
| Box | `supplierClaimItems` (`hive_box_names.dart`), opened `hive_init.dart:497` |
| Hive key | `claimItemId` (UUID) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | claimItemId | String | req | – | required | Key |
| 1 | claimId | String | req | – | required | FK → SupplierClaimModel |
| 2 | grnItemId | String | req | – | required | Source GRN line |
| 3 | variantId | String | req | – | required | |
| 4 | productId | String | req | – | required | |
| 5 | productName | String? | opt | – | – | |
| 6 | variantInfo | String? | opt | – | – | |
| 7 | claimedQty | double | req | – | required | |
| 8 | costPrice | double? | opt | – | – | |
| 9 | totalAmount | double? | opt | – | – | |
| 10 | remarks | String? | opt | – | – | |
| 11 | createdAt | String | req | – | required | |

---

# Inventory

## 30. StockMovementModel (shared)

**What it is.** One line in the stock history: "+5 of variant V, reason 'Goods received', balance after 25".

**Why the app needs it.** It is the audit trail for every stock change, and its deterministic ids make sale, GRN and stock-take writes safe to repeat.

| Fact | Value |
|---|---|
| Class / file | `StockMovementModel`, `lib/data/models/restaurant/db/stock_movement_model.dart` (restaurant model reused by retail) |
| typeId | **126** `restaurantStockLog` (`hive_type_ids.dart:86`) |
| Box | `restaurantStockMovements` = `'stockMovementsBox'` (`hive_box_names.dart:216`), **shared**, retail open `hive_init.dart:563` |
| Hive key | `id` (`stock_movement_repository.dart:13-16`, `put` = upsert) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning (retail) |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID, or deterministic: `grn_<grnItemId>`, `st_<takeItemId>`, `sale_<saleId>_<cartItemId>[_<componentVariantId>]` |
| 1 | timestamp | DateTime | req | – | required | Write time (device clock), not the GRN date |
| 2 | itemId | String | req | – | required | Retail: the **productId** |
| 3 | variantId | String? | opt | – | – | Retail: the varianteId |
| 4 | itemName | String | req | – | required | Name snapshot ("Name (variant desc)") |
| 5 | type | String | req | – | required | `'in'` / `'out'` |
| 6 | quantity | double | req | – | required | Always positive |
| 7 | balanceAfter | double | req | – | required | Variant stock after the move (can be negative) |
| 8 | reason | String | req | – | required | `Goods received`, `Sale`, `Sale (bundle: X)`, `Return`, `Exchange`, `Opening stock`, `Stock edited`, `Assembly (X)`, `Assembly batch`, `Disassembly batch`, `Disassembly (X)`, or a `StockAdjustmentReason.label` |
| 9 | note | String? | opt | – | – | e.g. `GRN-00012 · PO-00007`, `Stock take ST-00003 - …` |
| 10 | unit | String | req | – | required | Variant unit if decimal, else `pcs` (kit rows always `pcs`) |
| 11 | staffName | String | req | – | required | `authService.currentUsername` |
| 12 | sessionId | String? | opt | – | – | Current day session |
| 13 | unitCost | double? | opt | – | – | **Only GRN rows set it** |

- **Writers** (see §2 for the full list): GRN receive, stock adjustment/stock take, POS sale and bundle components, return restock, exchange, kit assemble/disassemble, opening stock, "Stock edited". The older note "GRN/returns/opening write NO movement" is **stale**.
- **Idempotency:** writers check `StockMovementRepository.contains(id)` before applying a change. Stock is written first, movement second, so a crash between them can cause a double apply on retry.
- Repository `lib/data/repositories/restaurant/stock_movement_repository.dart` (`saveMovement`, `contains`, `movementsForItem`, `allMovements`), created directly (not DI) in `grn_receiving_service.dart:48`, `inventory_service.dart:29`, `stock_adjustment_service.dart:83`.
- Append-only: never updated or deleted.

## 31. InventoryLossModel

**What it is.** A record of stock value lost: damaged on receipt, return cancelled, claim rejected, adjustment loss (theft, expiry…), or unsellable customer returns.

**Why the app needs it.** Loss reporting. It **never moves stock** itself.

| Fact | Value |
|---|---|
| File | `.../inventory_loss_model_178.dart` |
| typeId | **178** `retailInventoryLoss` |
| Box | `inventoryLosses` (`hive_box_names.dart:91`), opened `hive_init.dart:498` |
| Hive key | `lossId` (UUID) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | lossId | String | req | – | required | Key |
| 1 | lossNumber | String | req | – | required | `LOSS-00001` |
| 2 | source | String | req | – | create: `grn_damage` | `InventoryLossSource` |
| 3 | grnId | String? | opt | – | – | Null for stock_adjustment / sale_return |
| 4 | grnNumber | String? | opt | – | – | |
| 5 | grnItemId | String? | opt | – | – | |
| 6 | poId | String? | opt | – | – | |
| 7 | supplierId | String? | opt | – | – | |
| 8 | supplierName | String? | opt | – | – | |
| 9 | variantId | String | req | – | required | |
| 10 | productId | String | req | – | required | |
| 11 | productName | String? | opt | – | – | |
| 12 | variantInfo | String? | opt | – | – | |
| 13 | quantity | double | req | – | required | |
| 14 | costPrice | double? | opt | – | – | |
| 15 | lossValue | double | req | – | `0` | quantity × costPrice; 0 if no cost (`:174`) |
| 16 | reason | String | req | – | required | e.g. "Damaged on receipt" |
| 17 | note | String? | opt | – | – | |
| 18 | recordedAt | String | req | – | required | ISO now |

- **Sources** (`:11-34`): `grn_damage` (`_createLosses`), `return_cancelled` (`cancelPurchaseReturn`), `claim_rejected` (`writeOffRejectedClaim`), `stock_adjustment` (`recordAdjustmentLoss`, after `StockAdjustmentService` already reduced stock), `sale_return` (`return_service.dart:335-352`, unsellable returned units simply not restocked).
- Terminal on write: no update; repo `delete` exists only for cleanup with no callers.

## 32. StockTakeModel

**What it is.** A physical stock count session ("count aisle 3"), header level.

**Why the app needs it.** Shops periodically count shelves and correct the system stock to match.

| Fact | Value |
|---|---|
| File | `.../stock_take_model_180.dart` |
| typeId | **180** `retailStockTake` |
| Box | `stockTakes` (`hive_box_names.dart:94`), opened `hive_init.dart:499` |
| Hive key | `takeId` (UUID) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | takeId | String | req | – | required | Key |
| 1 | takeNumber | String | req | – | required | `ST-00001` |
| 2 | status | String | req | – | create: `draft` | `StockTakeStatus`: `draft, completed, cancelled` |
| 3 | scopeNote | String? | opt | – | – | e.g. "Aisle 3" |
| 4 | varianceReason | String? | opt | – | – | `StockAdjustmentReason.code` applied to all lines at commit |
| 5 | note | String? | opt | – | – | |
| 6 | countedBy | String | req | – | required | Username snapshot |
| 7 | createdAt | String | req | – | required | |
| 8 | updatedAt | String | req | – | required | Bumped by every `copyWith` (`:163`) |
| 9 | completedAt | String? | opt | – | – | |
| 10 | committedLineCount | int? | opt | – | – | Lines applied |
| 11 | committedNetQty | double? | opt | – | – | Σ appliedQty |

- **`cancelled` is never written**: `cancelTake` hard-deletes the take and its lines (`stock_take_store.dart:322-325`).
- **Flow** (`lib/domain/store/retail/stock_take_store.dart`): `startTake` (needs `canAdjust`) → `countVariant` (draft only, counted ≥ 0, snapshots `systemQty`) → `commit` (`:354-468`): per variance line, `target = variant.stockQty + variance` (so sales between count and commit are kept), then `StockAdjustmentService.adjust(... movementId: 'st_<takeItemId>')`, then `appliedQty` saved. The take becomes `completed` only when every variance line is applied. Bundle variants fail ("A bundle holds no stock of its own").
- Screens: `stock_take_list_screen.dart`, `stock_take_screen.dart`.

## 33. StockTakeItemModel

| Fact | Value |
|---|---|
| File | `.../stock_take_item_model_181.dart` |
| typeId | **181** `retailStockTakeItem` |
| Box | `stockTakeItems`, opened `hive_init.dart:500` |
| Hive key | `takeItemId` (UUID); also seeds movement id `st_<takeItemId>` |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | takeItemId | String | req | – | required | Key |
| 1 | takeId | String | req | – | required | FK → StockTakeModel |
| 2 | variantId | String | req | – | required | |
| 3 | productId | String | req | – | required | |
| 4 | productName | String? | opt | – | – | Snapshot |
| 5 | variantInfo | String? | opt | – | – | Snapshot |
| 6 | systemQty | double | req | – | required | System stock snapshot when counted (re-snapshotted on recount) |
| 7 | countedQty | double | req | – | required | Physically counted |
| 8 | costPrice | double? | opt | – | – | Count-time cost |
| 9 | countedAt | String | req | – | required | Re-stamped only when system/counted qty changes (`:133-135`) |
| 10 | appliedQty | double? | opt | – | – | Null until committed; the delta actually applied |

- Derived: `variance = countedQty − systemQty` (`:104`), `varianceValue` (`:112`).
- One line per variant (`findLine`, `stock_take_repository.dart:72-77`). An applied line cannot be recounted or removed.

---

# Day / Cash / EOD / Staff

Retail reuses the restaurant day-management mechanism. Most of these models live under `lib/data/models/restaurant/db/` or `lib/data/models/common/` even though retail writes them.

## 34. RestaurantSessionModel (shared) — the business day

**What it is.** One trading session ("the day"), from Start Day to End of Day, with opening and closing cash.

**Why the app needs it.** It defines the EOD window, and its id is stamped on EOD, expenses, cash and stock movements, and attendance.

| Fact | Value |
|---|---|
| Class / file | `RestaurantSessionModel extends HiveObject`, `lib/data/models/restaurant/db/session_model.dart` |
| typeId | **131** `restaurantSession` (`hive_type_ids.dart:96`) |
| Box | `restaurantSessions` = `'restaurantSessionsBox'` (`hive_box_names.dart:225`), shared, retail open `hive_init.dart:554` |
| Hive key | `sessionId` (`day_management_service.dart:60`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | sessionId | String | req | – | required | Key |
| 1 | startTime | DateTime | req | – | required | Day start; EOD window start and report date |
| 2 | endTime | DateTime? | opt (mutable) | – | – | Set at close |
| 3 | openingCash | double | req | – | required | Opening float |
| 4 | closingCash | double? | opt (mutable) | – | – | Retail passes the **kept** cash (after the safe drop) |
| 5 | isClosed | bool | req (mutable) | – | `false` | |

- **Identifier:** `Uuid().v4()` (`day_management_service.dart:51`).
- **Serialization:** `fromMap` uses `DateTime.parse(map['startTime'])` (hard), `sessionId ?? ''`, `isClosed ?? false`. `copyWith` cannot clear nullable fields.
- **Where used:** static `DayManagementService` (`lib/domain/services/restaurant/day_management_service.dart`: `startSession`, `endSession`, `getCurrentSession`, `hasPendingEOD`, `isEodStrictlyPending`). The pointer to the open session is `dayManagementBox['currentSessionId']` (§47).
- **Update:** updated in place with `session.save()` at close (`:109-116`). Never deleted.
- **Backup gap:** this box is **not** in the retail backup. After a restore, `currentSessionId` points at a session that does not exist.

## 35. EndOfDayReport + embedded summaries (shared model)

**What it is.** The day-close report: sales, refunds, tax, payment buckets, expected vs counted cash, credit collections, profit, and the safe drop.

**Why the app needs it.** It closes the day, is printed as the settlement slip, and gives history of each day.

| Fact | Value |
|---|---|
| Class / file | `EndOfDayReport extends HiveObject`, `lib/data/models/restaurant/db/eodmodel_317.dart` |
| typeId | **117** `restaurantEod` (`hive_type_ids.dart:74`) |
| Box | retail `retailEOD` = `'eodBox'` (`hive_box_names.dart:155`); restaurant uses `'restaurant_eodBox'`. Opened `hive_init.dart:546` |
| Hive key | `reportId` (`eod_repository.dart:18,62`) — **auto-int after restore** |

| # | Name | Dart type | Req? | Hive default | Ctor default | Retail meaning |
|---|---|---|---|---|---|---|
| 0 | date | DateTime | req | – | required | Trading day = **session start time** (`eod_service.dart:479`) |
| 1 | openingBalance | double | req | – | required | Opening float |
| 2 | orderSummaries | List<OrderTypeSummary> | req | – | required | **Always `[]` in retail** |
| 3 | totalDiscount | double | req | – | required | Σ `discountAmount`, returns netted |
| 4 | totalTax | double | req | – | required | Σ `totalGstAmount ?? taxAmount`, netted |
| 5 | categorySales | List<CategorySales> | req | – | required | **Always `[]` in retail** |
| 6 | paymentSummaries | List<PaymentSummary> | req | – | required | Buckets over forward sales + exchange returns; plain returns excluded; `exchange_credit` suppressed |
| 7 | cashReconciliation | CashReconciliation | req | – | required | Expected vs counted |
| 8 | totalSales | double | req | – | required | Plain Σ `totalAmount` (returns net out) |
| 9 | closingBalance | double | req | – | required | **System-EXPECTED cash** = opening + cash sales + cash in − cash out − cash expenses − cash refunds. Not counted, not kept |
| 10 | taxSummaries | List<TaxSummary> | req | – | required | CGST/SGST rows, netted |
| 11 | totalOrderCount | int | req | – | required | Count of non-return sales |
| 12 | totalRefunds | double | req | – | required | **Positive** Σ \|totalAmount\| of returns |
| 13 | reportId | String | req | – | required | Key (UUID) |
| 14 | totalExpenses | double | req | – | required | |
| 15 | cashExpenses | double | req | – | required | Expenses paid in cash |
| 16 | mode | String? | opt | – | – | `'retail'`; null = restaurant/legacy |
| 17 | roundOff | double | req | – | `0` | Not set by retail |
| 18 | cancelledOrderCount | int | req | – | `0` | Always 0 in retail (no void) |
| 19 | cancelledOrderAmount | double | req | – | `0` | Always 0 in retail |
| 20 | sessionId | String? | opt | – | – | FK → RestaurantSessionModel |
| 21 | cashCollections | double | req | – | `0` | Credit repayments in cash (`isCollection` rows) — not part of totalSales |
| 22 | cardCollections | double | req | – | `0` | Same, card |
| 23 | upiCollections | double | req | – | `0` | Same, UPI |
| 24 | totalCost | double | req | – | `0` | COGS from frozen line costs, returns netted |
| 25 | grossProfit | double | req | – | `0` | Ex-tax revenue − cost |
| 26 | customersWithDue | int | req | – | `0` | |
| 27 | totalOutstanding | double | req | – | `0` | `saleStore.getTotalDueAmount()` at close |
| 28 | cashWithdrawn | double | req | **0.0** | `0` | Safe Drop amount taken to the safe |

- **Getters (not stored):** `cashKept = cashReconciliation.actualCash − cashWithdrawn` (`:123`), `totalCollections` (`:129`), `profitMargin` (`:140-143`).
- **Read risk:** the adapter hard-casts f17-f27 (`eodmodel_317.g.dart:37-47`); only f28 has a default. An old record missing them throws on read (accepted pre-release).
- **Identifier:** `_uuid.v4()` (`eod_service.dart:636`).
- **Writer:** `EODService.generateRetailEODReport` (`lib/domain/services/restaurant/eod_service.dart:436-666`) — the only retail EOD engine.
- **Close flow** (`presentation/screens/retail/eod_screen.dart:219-280`): generate → save → cash movements (variance `adjustment`, safe-drop `out` "Safe drop - End of Day") → mark day completed → close staff hours → `DayManagementService.markDayEnded(closingBalance: keptInDrawer)` → print slip.
- **Save/delete:** `saveEODReport` (`:402-417`) de-duplicates **by sessionId** (date fallback for old rows): an existing report for that session is deleted and replaced. That is the only EOD delete.
- **Two "last closing balance" sources disagree:** `DayManagementService.getLastClosingBalance` returns **kept** cash; `EODService.getLastClosingBalance` returns the latest `closingBalance` (**expected**). (Which one the retail Start-Day dialog reads is **unverified**.)
- **Serialization:** `toMap`/`fromMap` (`:179`, `:213`) cover all fields with 0 defaults; `CashReconciliation.fromMap(map['cashReconciliation'])` has no null guard.

**Embedded types** — all `extends HiveObject` but stored only inside the EOD (no box, no key):

| Type (typeId) | Fields |
|---|---|
| OrderTypeSummary (118) | 0 orderType String · 1 orderCount int · 2 totalAmount double · 3 averageOrderValue double |
| CategorySales (119) | 0 categoryName String · 1 totalAmount double · 2 itemsSold int · 3 percentage double |
| PaymentSummary (120) | 0 paymentType String (bucket key) · 1 totalAmount double · 2 transactionCount int · 3 percentage double |
| CashReconciliation (121) | 0 systemExpectedCash double (= closingBalance) · 1 actualCash double (counted) · 2 difference double (actual − expected) · 3 reconciliationStatus String `Balanced`/`Overage`/`Shortage` (tolerance `kCashReconciliationTolerance`) · 4 remarks String? |
| TaxSummary (124) | 0 taxName String · 1 taxRate double · 2 taxAmount double · 3 taxableAmount double |

The registration comments at `hive_init.dart:411-429` say "18-22"; the real ids are 118-121 and 124.

## 36. CashMovementModel (shared)

**What it is.** One line in the cash-drawer ledger: cash in, cash out, opening float, adjustment, or refund audit.

**Why the app needs it.** Expected cash at EOD and the cash-drawer screen are computed from it.

| Fact | Value |
|---|---|
| Class / file | `CashMovementModel extends HiveObject`, `lib/data/models/restaurant/db/cash_movement_model.dart` |
| typeId | **128** `restaurantCashMovement` (`hive_type_ids.dart:92`) |
| Box | `restaurantCashMovements` = `'cashMovementsBox'` (`hive_box_names.dart:213`), shared, retail open `hive_init.dart:562` |
| Hive key | `id` (`cash_movement_repository.dart:18`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | UUID key |
| 1 | timestamp | DateTime | req | – | required | Device clock |
| 2 | type | String | req | – | required | `in`, `out`, `opening`, `adjustment` (audit only), `refund` (audit only — refunds are derived from return sales) |
| 3 | amount | double | req | – | required | Always positive; direction from `type` |
| 4 | reason | String | req | – | required | e.g. `Credit collection`, `Sale Refund`, `Safe drop - End of Day`, `EOD Shortage`/`EOD Overage`, `Session Start — Carry Forward` |
| 5 | note | String? | opt | – | – | Return rows hold `Return RTN_...` |
| 6 | staffName | String | req | – | required | From `RestaurantSession`, or `'System'` for the opening row |
| 7 | sessionId | String? | opt | – | – | Current session. **The opening row from `startSession` has none** (`day_management_service.dart:78-86`) |

- Getters: `isCashIn`, `signedAmount`, `label`. EOD sums only `in`/`out` (`eod_service.dart:548-549`).
- Store `lib/domain/store/restaurant/cash_movement_store.dart`: `addMovement` (`:84`, refuses once EOD is strictly pending unless `systemClose`), `addAdjustment`. Retail screen `cash_drawer_screen.dart`.
- **Append-only:** never deleted; correct with a counter-entry (`:158-159`).

## 37. ExpenseCategory (shared model)

**What it is / why.** A category for shop expenses (rent, tea, transport). Retail stores them in its own box.

| Fact | Value |
|---|---|
| Class / file | `ExpenseCategory extends HiveObject`, `lib/data/models/restaurant/db/expensemodel_315.dart` |
| typeId | **115** `restaurantExpense` (the name is misleading — this is the CATEGORY) |
| Box | retail `'expenseCategory'` (`hive_box_names.dart:158`), opened `hive_init.dart:557` |
| Hive key | `id` (`hive_expensecategory.dart:30`) — **auto-int after restore** |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Key |
| 1 | name | String | req | – | required | |
| 2 | isEnabled | bool | req (mutable) | – | `true` | |

- `fromMap` reads `map['isEnabled']` without a fallback; a missing value would throw.
- Retail reaches it through the static `HiveExpenseCat` helper (`database/hive_expensecategory.dart`); `ExpenseCategoryRepository` is registered only for restaurant.

## 38. Expense (shared model)

**What it is.** One money-out expense entry.

**Why the app needs it.** EOD subtracts cash expenses from expected cash; the cash drawer shows them.

| Fact | Value |
|---|---|
| Class / file | `Expense extends HiveObject`, `lib/data/models/restaurant/db/expensel_316.dart` |
| typeId | **116** `restaurantExpense1` |
| Box | retail `'expenseBox'` (`hive_box_names.dart:161`), opened `hive_init.dart:558` |
| Hive key | `id` (`expense_repository.dart:18,33`) — **auto-int after restore** |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Key |
| 1 | dateandTime | DateTime | req | – | required | Used for the EOD window |
| 2 | amount | double | req | – | required | Positive |
| 3 | categoryOfExpense | String? | opt | – | – | ExpenseCategory **id** |
| 4 | reason | String? | opt | – | – | |
| 5 | paymentType | String? | opt | – | – | `'cash'` counts toward `cashExpenses` |
| 6 | sessionId | String? | opt | – | – | Session link |

- **Retail readers:** EOD (`eod_service.dart:526-537`) and `cash_drawer_screen.dart:159-178`.
- **No retail screen creates an Expense** (the only creator found is the restaurant `Expense/addexpence.dart:116-128`). So retail `'expenseBox'` is empty in practice **(inferred from grep; confirm before documenting it as a feature)**.

## 39. StaffModel (shared)

**What it is.** A shop user who logs in with a PIN (Manager or Cashier in retail).

**Why the app needs it.** Login, role permissions, shifts and attendance.

| Fact | Value |
|---|---|
| Class / file | `StaffModel extends HiveObject`, `lib/data/models/common/staffModel_310.dart` |
| typeId | **110** `HiveTypeIds.staff` (`hive_type_ids.dart:67`). Old retail 172 retired |
| Box | `HiveBoxNames.staff` = `'staffBox'` (`hive_box_names.dart:145-147`), shared, opened `hive_init.dart:521` |
| Hive key | `id` (`staff_repository.dart:21`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Key |
| 1 | userName | String | req | – | required | |
| 2 | firstName | String | req | – | required | |
| 3 | lastName | String | req | – | required | |
| 4 | isCashier | String | req | – | required | **Holds the role name** (`'Manager'`/`'Cashier'`; restaurant adds `'Waiter'`). Field name is historical (`lib/util/common/staff_roles.dart:6-21`) |
| 5 | mobileNo | String | req | – | required | |
| 6 | emailId | String | req | – | required | |
| 7 | pinNo | String | req | – | required | **SHA-256(pin + `'unipos_restaurant_salt_2024'`)**, 64 hex chars (`restaurant_auth_helper.dart:7,16-19`). Verification has a plaintext fallback for legacy rows (`:23-33`) |
| 8 | createdAt | DateTime | req | – | required | |
| 9 | isActive | bool | req | – | `true` | Soft disable (Enable/Disable toggle) |

- **Identifier:** `Uuid().v4()` (`lib/presentation/screens/common/staff/manage_staff_screen.dart:166-177`); PIN hashed on add (`:174`) and on edit when changed (`:805-807`).
- **Validation:** PIN unique across all staff **and** the admin PIN (`_isPinTaken`, `:183-202`) — UI only. `addStaff` plan-gated via `ModeKeys.users/usersMax` (`staff_store.dart:93-119`).
- **Serialization:** `copyWith`'s createdAt parameter is named **`dateTime`** (`:61,73`); no clear flags. `fromMap` defaults strings to `''`, `isActive` to true.
- **Delete:** hard delete (`manage_staff_screen.dart:240-241,1140`); no history guard (shifts/attendance keep the name snapshot).
- The retail Admin is not a StaffModel: its PIN hash is in SharedPreferences `restaurant_admin_password`.

## 40. ShiftModel (shared)

**What it is.** One staff member's working shift at the till.

**Why the app needs it.** Shift reports (sales per cashier). `SaleModel.shiftId` points here.

| Fact | Value |
|---|---|
| Class / file | `ShiftModel extends HiveObject`, `lib/data/models/common/shift_model.dart` |
| typeId | **127** `shift` (`hive_type_ids.dart:89`) |
| Box | `shift` = `'shiftBox'` (`hive_box_names.dart:210`), shared, opened as a common box (`hive_init.dart:190`) |
| Hive key | `id` (`shift_repository.dart:24`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Key |
| 1 | staffId | String | req | – | required | FK → StaffModel |
| 2 | staffName | String | req | – | required | Snapshot |
| 3 | startTime | DateTime | req | – | required | |
| 4 | endTime | DateTime? | opt | – | – | |
| 5 | status | String | req | – | `'open'` | `'open'`, `'closed'`, or composite like `'closed:auto_closed:previous_day_detected:system'`; so `isClosed` uses `startsWith`, `isAutoClosed` uses `contains` |
| 6 | orderCount | int | req | – | `0` | Cached; recomputed at close |
| 7 | totalSales | double | req | – | `0` | Cached Σ `ShiftTxn.amount` (net of returns) |

- **Identifier:** UUID (`shift_store.dart:157`). The current shift id is held by `RestaurantSession` (memory + prefs `restaurant_current_shift_id`).
- **Sale attribution** (`ShiftRepository.getTxnsForShift`, `:152+`): matching `shiftId` → included; other shiftId → excluded; no shiftId → included if inside the shift's time window. Retail txns come from `_retailTxns` (`:118-138`): signed `totalAmount`, `refund` = magnitude for returns.

## 41. AttendanceModel (shared)

**What it is / why.** A clock-in/clock-out record with breaks, for staff hours.

| Fact | Value |
|---|---|
| Class / file | `AttendanceModel extends HiveObject`, `lib/data/models/common/attendance_model.dart` |
| typeId | **132** `attendance` (`hive_type_ids.dart:101`) |
| Box | `attendance` = `'restaurantAttendanceBox'` (`hive_box_names.dart:230`), shared, common open `hive_init.dart:191` |
| Hive key | `id` (`attendance_repository.dart:36`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Key |
| 1 | staffName | String | req | – | required | Snapshot; legacy match key |
| 2 | staffRole | String | req | – | required | |
| 3 | clockIn | DateTime | req (mutable) | – | required | |
| 4 | clockOut | DateTime? | opt (mutable) | – | – | Null = still clocked in |
| 5 | totalMinutes | int? | opt (mutable) | – | – | Filled at clock-out |
| 6 | date | String | req | – | required | `"YYYY-MM-DD"` day key |
| 7 | sessionId | String? | opt | – | – | Session FK |
| 8 | breakStartTime | DateTime? | opt (mutable) | – | – | |
| 9 | breakTotalMinutes | int? | opt (mutable) | – | – | |
| 10 | staffId | String? | opt (mutable) | – | – | Preferred match key; old rows fall back to `staffName` (`attendance_store.dart:45-50`) |

- **Identifier:** UUID (`attendance_store.dart:73`). At EOD, retail runs `_closeStaffHours` (`eod_screen.dart:258`) to close stale shifts and attendance.

## 42. AppNotificationModel (shared)

**What it is.** An in-app notification such as "Low stock: Rice 1 kg" or "Expiring soon".

**Why the app needs it.** The notification bell and local alerts.

| Fact | Value |
|---|---|
| Class / file | `AppNotificationModel extends HiveObject`, `lib/data/models/common/app_notification_model.dart` |
| typeId | **133** `appNotification` (`hive_type_ids.dart:103`) |
| Box | `appNotifications` = `'restaurantNotificationsBox'` (`hive_box_names.dart:24`), shared, common open `hive_init.dart:184` |
| Hive key | `id` (`notification_repository.dart:35`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String | req | – | required | Key |
| 1 | eventCode | String | req | – | required | Retail: `'low_stock'`, `'expiry_alert'`; shared: `pending_eod`, … |
| 2 | subjectType | String? | opt | – | – | Retail: `'variant'` |
| 3 | subjectId | String? | opt | – | – | Retail: the variantId |
| 4 | data | String? | opt (mutable) | – | – | JSON context (e.g. `expiryDate`) |
| 5 | timestamp | DateTime | req (mutable) | – | required | |
| 6 | isRead | bool | req (mutable) | – | `false` | |
| 7 | isResolved | bool | req (mutable) | – | `false` | Set when the condition stops being true (reconciling sync) |
| 8 | source | String | req | – | `'local'` | `'local'` / `'remote'` |

- **Identifier:** UUID (`notification_store.dart:84`). `raiseEvent` updates the active row matching `(eventCode, subjectType, subjectId)` instead of inserting a duplicate (`:80-96`). Retail sync: `retail_notification_sync_service.dart`.
- Not included in any backup.

---

# Settings & Singletons

A **singleton** box holds exactly one record under a fixed string key.

## 43. BusinessDetails (shared singleton)

**What it is.** The shop profile: name, owner, address, GSTIN, logo, country, tax flags, store type, food licence.

**Why the app needs it.** Receipts, country-aware rules (tax, phone, tariff code), and the tax switch.

| Fact | Value |
|---|---|
| Class / file | `BusinessDetails extends HiveObject`, `lib/data/models/common/business_details.dart` |
| typeId | **4** `businessDetails` |
| Box | `businessDetailsBox` (common, `hive_init.dart:172`) |
| Hive key | fixed `'businessDetails'` (`lib/data/repositories/business_details_repository.dart:7-15`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | businessTypeId | String? | opt | – | – | |
| 1 | businessTypeName | String? | opt | – | – | |
| 2 | storeName | String? | opt | – | – | |
| 3 | ownerName | String? | opt | – | – | |
| 4 | phone | String? | opt | – | – | |
| 5 | email | String? | opt | – | – | |
| 6 | address | String? | opt | – | – | |
| 7 | gstin | String? | opt | – | – | |
| 8 | pan | String? | opt | – | – | |
| 9 | city | String? | opt | – | – | |
| 10 | state | String? | opt | – | – | |
| 11 | country | String? | opt | – | – | Drives country-aware rules |
| 12 | pincode | String? | opt | – | – | |
| 13 | logo | Uint8List? | opt | – | – | Receipt logo bytes |
| 14 | isSetupComplete | bool | req | **false** | `false` | |
| 15 | createdAt | DateTime | req | – | now | |
| 16 | updatedAt | DateTime | req | – | now | `copyWith` sets now |
| 17 | taxEnabled | bool | req | **false** | **true** | Behaviour switch: is tax applied |
| 18 | isRegisteredForTax | bool | req | **false** | **true** | Legal status (kept separate from behaviour) |
| 19 | retailStoreType | String? | opt | – | – | `RetailStoreTypes` key |
| 20 | foodLicenseNo | String? | opt | – | – | FSSAI etc. |

- **Inconsistency:** f17/f18 Hive default is `false`, but the constructor, `fromMap` and `BusinessDetailsRepository.isTaxEnabled` fallback are `true` (`:65-71,104-105,214-215`; repo `:24`). An old record missing f17 reads **false** from Hive.
- `copyWith` clear flags: `clearLogo`, `clearRetailStoreType`. `saveTaxRegistration` sets both flags together (`business_details_repository.dart:29-38`).
- **Writers:** setup wizard (`stores/setup_wizard_store.dart:540-560,658`), retail Store Info (`store_info_settings_screen.dart:182,212`), `StoreSettingsService`.
- **Dual storage:** retail store text fields live primarily in SharedPreferences (`store_name`, …); `StoreSettingsService.saveAllSettings` mirrors them here (`store_settings_service.dart:278-294`). The logo lives only here.
- **Restore defect:** restored with `box.add()` (int key), so `get('businessDetails')` reads null after a restore (logo, tax flags, store type lost until re-saved).

## 44. BusinessType (shared singleton)

**What it is / why.** The business category chosen in onboarding.

| Fact | Value |
|---|---|
| File | `lib/data/models/common/business_type.dart` |
| typeId | **3** `businessType` |
| Box / key | `businessTypeBox`, fixed key `'selectedBusinessType'` (`business_type_repository.dart`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | id | String? | opt | – | – | |
| 1 | name | String? | opt | – | – | |
| 2 | description | String? | opt | – | – | |
| 3 | iconName | String? | opt | – | – | |
| 4 | isSelected | bool | req | – | `false` | |
| 5 | createdAt | DateTime | req | – | now | |
| 6 | updatedAt | DateTime | req | – | now | |

Same restore int-key defect as BusinessDetails.

## 45. TaxDetails (shared singleton)

**What it is / why.** Shop-wide tax settings: on/off, inclusive or exclusive, the default rate used when a product has no rate.

| Fact | Value |
|---|---|
| File | `lib/models/tax_details.dart` |
| typeId | **2** `taxDetails` |
| Box / key | `taxBox`, fixed key `'taxDetails'` (`tax_details_repository.dart`) |
| Retired index | **7** (`taxRates`, replaced by the shared `Tax` entity; read-only legacy adapter on typeId 5) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | isEnabled | bool | req | – | `true` | |
| 1 | isInclusive | bool | req | – | `true` | |
| 2 | defaultRate | double | req | – | `0.0` | Fallback GST when product/variant rate ≤ 0 |
| 3 | taxName | String | req | – | `'GST'` | |
| 4 | placeOfSupply | String? | opt | – | – | |
| 5 | applyOnDelivery | bool | req | – | `false` | |
| 6 | notes | String? | opt | – | – | |

Note: retail billing also reads SharedPreferences `gst_tax_inclusive` / `gst_default_rate` through `GstService` (`gst_service.dart:12-13`). Which of the two wins in every path is **(unverified)**. Same restore int-key defect as BusinessDetails.

## 46. RetailPrinterSettings (not Hive)

**What it is / why.** Receipt layout options for retail (paper size, which lines to show, copies, logo path).

- File `lib/data/models/retail/printer_settings_model.dart`; plain immutable class with 50+ fields and enums `PaperSize {mm58, mm80, a4}`, `FontSize {small, medium, large}`, `BillTemplate {simple, paperSaver}` (`:4-25`).
- Stored as JSON in SharedPreferences key `'retail_printer_settings'` by the singleton `RetailPrinterSettingsService` (`lib/domain/services/retail/retail_printer_settings_service.dart:7-55`), loaded once.
- `toJson` stores enums **by index**. `fromJson` clamps `billTemplate` (`:246-248`) but **not** `paperSize`/`fontSize` (`:242,291`) — a bad index throws `RangeError`.
- Defaults (`:105-180`): 80 mm, logo/name/address/phone/GST shown; MRP and barcode lines hidden; `showPoweredBy` false; `numberOfCopies` 1 (clamped 1..5). `setPaperSize` derives width 58/80/210.
- The logo file (`<AppDocs>/logos/store_logo.<ext>`) is not in the backup, so the path dangles after a restore **(inferred)**.
- Physical printers are `SavedPrinterModel` (typeId 130, box `restaurantPrintersBox`), shared with restaurant and outside this document.

## 47. Raw untyped boxes (`dayManagementBox`, `appCounters`)

These are `Box` without a model class. Values are plain maps/primitives.

| Box | Keys | Owner |
|---|---|---|
| `dayManagementBox` (shared, `hive_init.dart:549`) | `openingBalance`, `dayStarted`, `lastDayDate`, `dayStartTimestamp`, `closingBalance` (the **kept** cash), `currentSessionId` (pointer to the open session; deleted at close, `:123`) | `day_management_service.dart:17-23` |
| `appCounters` (common, `hive_init.dart:175`) | `lastSkuSequence`, `lastBarcodeSequence`, `lastCustomerSequence` (read `as int`), and per document code `<CODE>_lastFy`, `<CODE>_lastSeq`, `<CODE>_prefix` for `INV`, `CRN`, `EXC`, `PO`, `GRN`, `PR`, `CLM`, `LOSS`, `ST` | `sku_generator_service.dart`, `barcode_generator_service.dart`, `customer_id_generator_service.dart`, `document_number_service.dart` |

`DocumentNumberService` notes: the counter is reserved before use (gaps possible, duplicates impossible); renaming a display prefix (INV → BILL) keeps the series because the key uses the original code (`:54-61`); `peekNext` (`:78`) previews; `setNext` (`:87`) continues an existing series mid-year.

---

# Dead / legacy

## 48. PaymentEntryModel (dead)

**What it is.** An intended per-payment record for split payments. **It is never written.**

| Fact | Value |
|---|---|
| File | `.../payment_entry_model_216.dart` (`:47-48`) |
| typeId | **166** `retailPaymentEntry` (`hive_type_ids.dart:153`) |
| Box | `paymentEntries` (`hive_box_names.dart:126`), opened `hive_init.dart:516` |
| Hive key | none in practice (backup restores with `add()`) |

| # | Name | Dart type | Req? | Hive default | Ctor default | Meaning |
|---|---|---|---|---|---|---|
| 0 | paymentEntryId | String | req | – | required | |
| 1 | saleId | String | req | – | required | FK → SaleModel |
| 2 | paymentMethod | String | req | – | required | Lower-cased in `create` (`:91`) |
| 3 | amount | double | req | – | required | |
| 4 | referenceId | String? | opt | – | – | |
| 5 | timestamp | String (ISO) | req | – | required | |
| 6 | note | String? | opt | – | – | |

- The adapter is registered (`hive_init.dart:370`), the box opened and backed up (`unified_backup_service.dart:1354,2916`), but **no code writes it**. Real payment legs live in `SaleModel.paymentListJson`, built from the non-Hive UI class `PaymentEntry` (`split_payment_widget.dart:15`) — a different class with a similar name.
- The file also defines an enum `PaymentMethod` (`:7-45`) that clashes by name with the Hive `PaymentMethod` class (§17). Import carefully.
- `toMap` uses key `'method'` for `paymentMethod` (`:125`).
- Candidate for retirement: keep a read-only adapter on 166 if old backups must restore; never reuse 166.

## 49. Retired and legacy items

| Item | Status | Evidence |
|---|---|---|
| typeIds 156, 157 (Purchase/PurchaseItem) | Retired; replaced by PO + GRN | `hive_type_ids.dart:140-142`; old backup keys ignored (`unified_backup_service.dart:1135-1137,2746-2748`) |
| typeId 158 (retailCustomer) | Retired → shared `Customer` 125 | `:143-144` |
| typeId 165 (retailCategory) | Retired → shared `Category` 100 | `:151-152` |
| typeId 167 (retailAdmin) and box `admin_box` | Retired → SharedPreferences `restaurant_admin_password` (salted SHA-256) | `:154-156`; `hive_box_names.dart:127-128` |
| typeId 172 (retailStaff) | Retired → shared `StaffModel` 110 | `:161-162` |
| typeId 5 `LegacyTaxRateItem` | Read-only adapter so old `taxBox` records still open | `hive_init.dart:127-133` |
| Box `retail_categories` (`Box<String>`) | Opened (`hive_init.dart:510-513`), no runtime reader/writer; export key is overwritten by the real categories | `unified_backup_service.dart:1223-1230,1343-1346,2675-2689` |
| Boxes `attributeValues` / `productAttributes` (camelCase) | Deleted from disk on **every** cold start | `hive_init.dart:462-476` |
| Boxes `purchases` / `purchaseItems` | Retired names; old files may remain on disk | `hive_box_names.dart:79-81` |
| `CartItemModel.discountAmount` (f18), `CartItemModel.tabIndex` (f20), `VarianteModel.isDefault` (f19), `ProductModel.imagePath` (f5), `ProductModel.productType` (f12) | Written but no meaningful reader | see their sections |
| No Unit model, no Brand model | Unit = `VarianteModel.unit` + `kItemUnits`; Brand = free-text `ProductModel.brandName` | `item_units.dart:5,19-56` |

---

# Serialization & schema evolution

### How data is written
- **Normal path:** repositories call `box.put(id, model)`; the generated adapter writes `fieldIndex → value` pairs.
- **Backup path:** `UnifiedBackupService` (`lib/domain/services/common/unified_backup_service.dart`) exports each box with the model's `toMap()` into an encrypted JSON (`data.json` inside an AES + password-ZIP + `BBLTENC1` envelope) and restores with `fromMap()`. Restore = `clear()` then per-row `put`/`add`. There is **no transaction**, so a throw mid-box leaves it partly written. A key absent from an older backup leaves that box's device rows as they were (except `supplierLedger` and `cashMovements`, which are cleared).

### Schema evolution rules in use
1. **Add new fields as nullable** (most common: `ProductModel` f16-f19, `VarianteModel` f23-f24, many `SaleModel` fields). Old records read null.
2. **Non-nullable late additions get `defaultValue`** (`VarianteModel` f22, `SaleModel` f11/f22/f23/f24, `Customer` f15-f19, `RetailKitAssemblyModel` f8, `EndOfDayReport` f28, `BusinessDetails` f14/f17/f18).
3. **Never reuse** a typeId or field index. Retired types keep a read-only adapter when old data must still open.
4. **No migration framework** and no stored schema version (`AppConfig.appVersion` is never written). Pre-release policy accepts breaking local data.
5. **Do not change a field's Dart type** (especially int ↔ double).

### Known serialization defects

| # | Model | Defect | Effect |
|---|---|---|---|
| S1 | SaleModel | `toMap` writes `'paymentList'`, `fromMap` reads `'paymentListJson'` (`sale_model_203.dart:668` vs `:724`) | After a backup restore every sale loses its payment legs |
| S2 | ProductAttributeModel, CartItemModel, BillingTabModel, HoldSaleModel, HoldSaleItemModel, EndOfDayReport, ExpenseCategory, Expense, CreditPaymentModel, PaymentEntryModel | Restored with `box.add()` (int keys) while repos use string ids | After restore, delete is a no-op and update writes a duplicate |
| S3 | BusinessDetails, BusinessType, TaxDetails | Restored with `add()` while repos read fixed string keys | After restore, the singleton reads null |
| S4 | CartItemModel | `toMap` omits `tabIndex` | Lost on round-trip (vestigial field) |
| S5 | EndOfDayReport | Adapter hard-casts f17-f27 | Old records throw on read |
| S6 | RetailPrinterSettings | `paperSize`/`fontSize` index not clamped | Bad JSON throws `RangeError` |
| S7 | ProductModel | `toProduct()` uses key `'name'`, placeholder URL for null `imagePath` | Harmless; `fromMap` accepts both keys |
| S8 | Boxes not backed up | `restaurantSessionsBox`, `restaurantNotificationsBox`, `restaurantPrintersBox`, printer logo file | Session history lost; `currentSessionId` dangles |

### `copyWith` clear flags (how to set a nullable field back to null)

`copyWith(x: null)` keeps the old value, because the code uses `x ?? this.x`. To clear, use a `clearX` flag where one exists:

| Model | Clear flags | Cannot be cleared via copyWith |
|---|---|---|
| ProductModel | `clearBrandName`, `clearDescription`, `clearHsnCode`, `clearTax` (both rate and id), `clearImage`, `clearStockMode` | `subCategory`, `imagePath`, `default*` prices, `allowOrderWhenOutOfStock` |
| VarianteModel | `clearMrp`, `clearMinStock`, `clearBarcode`, `clearExpiryDate`, `clearTax` | `sku`, `costPrice`, `sellingPrice`, `hsnCode`, `unit`, `customAttributes`, `attributeValueIds`, `imagePath` |
| SupplierModel | `clearPhone`, `clearAddress`, `clearGstNumber` | – |
| Customer | `clearEmail`, `clearAddress`, `clearGstNumber`, `clearNotes`, `clearFoodPrefrence` | others |
| BusinessDetails | `clearLogo`, `clearRetailStoreType` | others |
| SaleModel, PurchaseOrderModel, BillingTabModel, AttributeModel, AttributeValueModel, Category, Tax, StaffModel, BundleComponentModel | none | all nullable fields |

---

# Model gotchas

1. **Filename suffix ≠ typeId.** `product_model_200.dart` is 150, `purchase_order_model_211.dart` is 161. Always check `HiveTypeIds`.
2. **Stock is only on `VarianteModel.stockQty`** (double, can be negative). Never add a stock field to ProductModel. A bundle variant's stock is meaningless (saved 0).
3. **`stockMode` decides behaviour**, not `productType`/`hasVariants`.
4. **Price never falls back to cost**: `priceOverride ?? sellingPrice ?? mrp ?? 0`.
5. **Tax rates are cached copies.** Editing or deleting a Tax does not update products/variants. A 0% tax falls through to the default rate because of `> 0` checks.
6. **Returns are negated headers with positive lines.** Sum headers directly; do not re-negate. Only line-level code needs `revenueSign`.
7. **`discountAmount` is the total; `lineDiscountAmount`/`lineDiscountTotal` is a subset.** Never add them.
8. **Payment leg `amount` = money moved**; `totalPaid` = tendered; `paidAmount` = settled toward the bill.
9. **`invoiceNumber` is not unique across years.** Use `saleId` as the key; use `displayNumber` for display.
10. **`HoldSaleModel.subtotal` is actually the grand total.** `CartItemModel.total` excludes GST in exclusive mode.
11. **PO received quantities are derived** from confirmed GRN lines; there is no stored received field. `GRNModel.totalOrderedQty` is the remaining quantity, not the PO quantity.
12. **GRN bills damaged units** (`totalAmount` = received × cost) but only accepted units enter stock. `GRNItemModel.totalAmount` is inventory value, not billable.
13. **Purchase returns, claims and losses never move stock.**
14. **Supplier balance changes only through `SupplierStore.recordBalanceMovement`** (ledger row first, then balance).
15. **`EndOfDayReport.closingBalance` is EXPECTED cash**, not counted and not kept. Kept cash = `actualCash − cashWithdrawn`, and that is what goes into `dayManagementBox.closingBalance` and `session.closingCash`.
16. **Barcode uniqueness lives in `VariantRepository`**, not in the store. Barcodes are minted once (`BB` + 10 digits) and never regenerated. Backup restore bypasses the uniqueness guard.
17. **SKU is not unique** and has two formats.
18. **`PaymentMethod` is keyed by auto-int**, not by its `id`; sales store its `value`. A name clash exists with the `PaymentMethod` enum in `payment_entry_model_216.dart`.
19. **IDs are mixed:** UUID (most), ms-timestamp (`PurchaseOrderModel.poId`, retail Category ids), composite (`CartItemModel`, `HoldSaleItemModel`, `HOLD_`, `RTN_`), counters (`CUST-000042`, `BB…`, document numbers). Timestamp and composite ids can collide within one millisecond.
20. **Hard deletes have no history guard** for products, variants, attribute values, payment methods and staff. Documents keep dangling ids plus their own name snapshots; always render history from snapshots.
21. **`BundleComponentModel.quantity` and `RetailKitAssemblyModel.batchQty` are int**, so decimal components are impossible without a breaking change.
22. **Several restored boxes get int keys** (see S2/S3). After a restore, deletes and updates on those boxes misbehave until the data is re-created.
23. **`BusinessDetails.taxEnabled` reads false from Hive for old records** but true everywhere else.
24. **Retail has no Expense creation UI** (inferred); `expenseBox` is effectively empty.
25. **Stale comments in code:** attribute "TypeId 21/22/23", Customer "own physically-separate box", `hive_init.dart:514` "own box", `bundle_component_model.dart:8-11`, EOD sub-type "18-22", supplier claim "never posted to a ledger", "damaged units are never billed", PO/GRN number formats `PO-20250101-001`, `EXC-YYYYMMDD-NNN`. Trust this document's citations over those comments.
