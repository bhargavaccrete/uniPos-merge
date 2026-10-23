
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';

// Common Models
import 'package:billberrylite/models/payment_method.dart' as pm;
import 'package:billberrylite/models/tax_details.dart';
import 'package:billberrylite/models/legacy/legacy_tax_rate_item.dart';
import 'package:billberrylite/data/models/common/business_type.dart';
import 'package:billberrylite/data/models/common/business_details.dart';

// Retail Models
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/data/models/retail/hive_model/cart_model_202.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_item_model_175.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_ledger_entry_model_179.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_model_180.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_component_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/kit_assembly_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/stock_take_item_model_181.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:billberrylite/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/payment_entry_model_216.dart';
import 'package:billberrylite/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:billberrylite/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:billberrylite/data/models/common/staffModel_310.dart';
import 'package:billberrylite/data/models/retail/hive_model/billing_tab_model_173.dart';

// Restaurant Models
import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_ingredient_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_model.dart';
import 'package:billberrylite/data/models/restaurant/db/recipe_production_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_grn_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_return_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_claim_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_inventory_loss_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_ledger_entry_model.dart';
import 'package:billberrylite/data/models/restaurant/db/extramodel_303.dart';
import 'package:billberrylite/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:billberrylite/data/models/restaurant/db/variantmodel_305.dart';
import 'package:billberrylite/data/models/restaurant/db/choicemodel_306.dart';
import 'package:billberrylite/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:billberrylite/data/models/restaurant/db/cartmodel_308.dart';
import 'package:billberrylite/data/models/restaurant/db/ordermodel_309.dart';
import 'package:billberrylite/data/models/restaurant/db/table_Model_311.dart';
import 'package:billberrylite/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:billberrylite/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/data/models/restaurant/db/expensemodel_315.dart';
import 'package:billberrylite/data/models/restaurant/db/expensel_316.dart';
import 'package:billberrylite/data/models/restaurant/db/eodmodel_317.dart';
import 'package:billberrylite/data/models/restaurant/db/testbillmodel_318.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/stock_movement_model.dart';
import 'package:billberrylite/data/models/restaurant/db/cash_handover_model.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/models/restaurant/db/session_model.dart';
import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/restaurant/db/item_cancellation_model_134.dart';

/// Hive Initialization Class
/// Handles all adapter registrations and box openings
class HiveInit {
  HiveInit._();

  // ⚠️ LIFECYCLE GUARDS - Prevent box re-opening during runtime
  static bool _isHiveInitialized = false;
  static bool _areCommonBoxesOpen = false;
  static bool _areRetailBoxesOpen = false;
  static bool _areRestaurantBoxesOpen = false;

  /// Initialize Hive with Flutter
  static Future<void> init() async {
    if (_isHiveInitialized) {
      return;
    }
    await Hive.initFlutter();
    await _registerCommonAdapters();
    _isHiveInitialized = true;
  }

  /// Register common adapters (needed regardless of business mode)
  static Future<void> _registerCommonAdapters() async {
    // TaxDetails - typeId: 2
    if (!Hive.isAdapterRegistered(HiveTypeIds.taxDetails)) {
      Hive.registerAdapter(TaxDetailsAdapter());
    }
    // BusinessType - typeId: 3
    if (!Hive.isAdapterRegistered(HiveTypeIds.businessType)) {
      Hive.registerAdapter(BusinessTypeAdapter());
    }
    // BusinessDetails - typeId: 4
    if (!Hive.isAdapterRegistered(HiveTypeIds.businessDetails)) {
      Hive.registerAdapter(BusinessDetailsAdapter());
    }
    // TaxRateItem - typeId: 5. Retired as a model, but pre-retirement taxBox
    // records still hold a List<TaxRateItem> in TaxDetails field 7, and Hive
    // resolves every field on disk before discarding unknown ones. This
    // read-only adapter lets those boxes open; the data is dropped on read.
    if (!Hive.isAdapterRegistered(HiveTypeIds.legacyTaxRateItem)) {
      Hive.registerAdapter(LegacyTaxRateItemAdapter());
    }
    // PaymentMethod - typeId: 6
    if (!Hive.isAdapterRegistered(HiveTypeIds.paymentMethod)) {
      Hive.registerAdapter(pm.PaymentMethodAdapter());
    }
    // SavedPrinterModel - typeId: 130. Lives in the restaurant typeId range for
    // historical reasons, but printer pairing is COMMON to both modes — retail
    // pairs through the same shared UI, so the adapter must be registered
    // regardless of business mode.
    if (!Hive.isAdapterRegistered(HiveTypeIds.savedPrinter)) {
      Hive.registerAdapter(SavedPrinterModelAdapter());
    }
    // AppNotificationModel - typeId: 133. Same story as SavedPrinterModel: it
    // sits in the restaurant range for historical reasons, but the notification
    // feed is COMMON to both modes (retail raises low-stock and expiry events
    // through the same store), so it registers regardless of business mode.
    if (!Hive.isAdapterRegistered(HiveTypeIds.appNotification)) {
      Hive.registerAdapter(AppNotificationModelAdapter());
    }
    // ShiftModel - 127 and AttendanceModel - 132. Both sit in the restaurant
    // typeId range for historical reasons, but staff shifts and clock-in/out
    // are COMMON to both modes, so they register regardless of business mode.
    if (!Hive.isAdapterRegistered(HiveTypeIds.shift)) {
      Hive.registerAdapter(ShiftModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.attendance)) {
      Hive.registerAdapter(AttendanceModelAdapter());
    }
  }

  /// Open common boxes (needed regardless of business mode)
  static Future<void> openCommonBoxes() async {
    if (_areCommonBoxesOpen) {
      return;
    }
    await Hive.openBox(HiveBoxNames.storeBox);
    await Hive.openBox(HiveBoxNames.appState);
    await Hive.openBox<TaxDetails>(HiveBoxNames.taxBox);
    await Hive.openBox<BusinessType>(HiveBoxNames.businessTypeBox);
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);
    // Generic named-sequence counters (bill/order/KOT numbers, SKU sequence,
    // etc.) — shared across both business modes.
    await Hive.openBox(HiveBoxNames.appCounters);
    // Saved thermal printers (Bluetooth/WiFi/USB) — one physical box for both
    // modes. PrinterRepository's constructor does a synchronous Hive.box()
    // lookup, so this must be open before the service locator builds it.
    await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);

    // Persisted app notifications — one physical box for both modes.
    // NotificationRepository does a synchronous Hive.box() lookup, so this
    // must be open before the service locator builds the store.
    await Hive.openBox<AppNotificationModel>(HiveBoxNames.appNotifications);

    // Staff shifts + attendance — one physical box each for both modes.
    // ShiftRepository / AttendanceRepository do synchronous Hive.box() lookups
    // in their constructors, so these must be open before the service locator
    // builds them.
    await Hive.openBox<ShiftModel>(HiveBoxNames.shift);
    await Hive.openBox<AttendanceModel>(HiveBoxNames.attendance);

    // Open and initialize payment methods box with defaults
    final paymentBox = await Hive.openBox<pm.PaymentMethod>(HiveBoxNames.paymentMethods);

    // Initialize with defaults if empty
    if (paymentBox.isEmpty) {
      await _initializeDefaultPaymentMethods(paymentBox);
    } else {
    }

    _areCommonBoxesOpen = true;
  }

  /// Initialize default payment methods
  static Future<void> _initializeDefaultPaymentMethods(Box<pm.PaymentMethod> box) async {
    // Import uuid
    const uuid = Uuid();

    final defaultMethods = [
      pm.PaymentMethod(
        id: uuid.v4(),
        name: 'Cash',
        value: 'cash',
        iconName: 'money',
        isEnabled: true,
        sortOrder: 1,
      ),
      pm.PaymentMethod(
        id: uuid.v4(),
        name: 'Card',
        value: 'card',
        iconName: 'credit_card',
        isEnabled: true,
        sortOrder: 2,
      ),
      pm.PaymentMethod(
        id: uuid.v4(),
        name: 'UPI',
        value: 'upi',
        iconName: 'qr_code_2',
        isEnabled: true,
        sortOrder: 3,
      ),
      pm.PaymentMethod(
        id: uuid.v4(),
        name: 'Wallet',
        value: 'wallet',
        iconName: 'account_balance_wallet',
        isEnabled: false,
        sortOrder: 4,
      ),
      pm.PaymentMethod(
        id: uuid.v4(),
        name: 'Credit',
        value: 'credit',
        iconName: 'receipt_long',
        isEnabled: false,
        sortOrder: 5,
      ),
      pm.PaymentMethod(
        id: uuid.v4(),
        name: 'Other',
        value: 'other',
        iconName: 'more_horiz',
        isEnabled: false,
        sortOrder: 6,
      ),
    ];

    for (var method in defaultMethods) {
      await box.add(method);
    }
  }

  /// Register all retail adapters (typeIds: 150-223)
  static Future<void> registerRetailAdapters() async {
    // Self-sufficient: a mode's adapters are meaningless without the common
    // ones (ShiftModel, AttendanceModel, SavedPrinterModel, AppNotification…).
    // `init()` normally runs this first and every registration is individually
    // guarded by isAdapterRegistered, so calling it again is a no-op.
    await _registerCommonAdapters();
    // Product - 150
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailProduct)) {
      Hive.registerAdapter(ProductModelAdapter());
    }
    // Variante - 151
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailVariant)) {
      Hive.registerAdapter(VarianteModelAdapter());
    }
    // Cart - 152
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailCart)) {
      Hive.registerAdapter(CartItemModelAdapter());
    }
    // Sale - 153
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailSale)) {
      Hive.registerAdapter(SaleModelAdapter());
    }
    // SaleItem - 154
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailSaleItem)) {
      Hive.registerAdapter(SaleItemModelAdapter());
    }
    // Supplier - 155
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailSupplier)) {
      Hive.registerAdapter(SupplierModelAdapter());
    }
    // Damaged-goods workflow raised from a GRN - 174..178
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPurchaseReturn)) {
      Hive.registerAdapter(PurchaseReturnModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPurchaseReturnItem)) {
      Hive.registerAdapter(PurchaseReturnItemModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailSupplierClaim)) {
      Hive.registerAdapter(SupplierClaimModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailSupplierClaimItem)) {
      Hive.registerAdapter(SupplierClaimItemModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailInventoryLoss)) {
      Hive.registerAdapter(InventoryLossModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailSupplierLedgerEntry)) {
      Hive.registerAdapter(SupplierLedgerEntryModelAdapter());
    }
    // Stock take - 180/181: physical count paperwork. Registered in retail only;
    // restaurant counts stock through its own StockMovement flow.
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailStockTake)) {
      Hive.registerAdapter(StockTakeModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailStockTakeItem)) {
      Hive.registerAdapter(StockTakeItemModelAdapter());
    }
    // Bundle/kit products - 182/183/184: see docs/retail_inventory_system_plan.md §3.2.
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailBundle)) {
      Hive.registerAdapter(RetailBundleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailBundleComponent)) {
      Hive.registerAdapter(BundleComponentModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailKitAssembly)) {
      Hive.registerAdapter(RetailKitAssemblyModelAdapter());
    }
    // Customer - shared with restaurant (typeId 125, see restaurant section
    // below) — same adapter, retail's own box.
    if (!Hive.isAdapterRegistered(HiveTypeIds.customer)) {
      Hive.registerAdapter(CustomerAdapter());
    }
    // HoldSale - 159
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailHoldSale)) {
      Hive.registerAdapter(HoldSaleModelAdapter());
    }
    // HoldSaleItem - 160
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailHoldSaleItem)) {
      Hive.registerAdapter(HoldSaleItemModelAdapter());
    }
    // PurchaseOrder - 161
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPurchaseOrder)) {
      Hive.registerAdapter(PurchaseOrderModelAdapter());
    }
    // PurchaseOrderItem - 162
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPurchaseOrderItem)) {
      Hive.registerAdapter(PurchaseOrderItemModelAdapter());
    }
    // GRN - 163
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailGrn)) {
      Hive.registerAdapter(GRNModelAdapter());
    }
    // GRNItem - 164
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailGrnItem)) {
      Hive.registerAdapter(GRNItemModelAdapter());
    }
    // Category - shared with restaurant (id/name only, no GST/HSN — those
    // live on the product/variant). Same adapter, retail's own box.
    if (!Hive.isAdapterRegistered(HiveTypeIds.category)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    // PaymentEntry - 166
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPaymentEntry)) {
      Hive.registerAdapter(PaymentEntryModelAdapter());
    }
    // CreditPayment - 168
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailCreditPayment)) {
      Hive.registerAdapter(CreditPaymentModelAdapter());
    }
    // Attribute - 169
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailAttribute)) {
      Hive.registerAdapter(AttributeModelAdapter());
    }
    // AttributeValue - 170
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailAttributeValue)) {
      Hive.registerAdapter(AttributeValueModelAdapter());
    }
    // ProductAttribute - 171
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailProductAttribute)) {
      Hive.registerAdapter(ProductAttributeModelAdapter());
    }
    // Staff - shared with restaurant (typeId 110, see restaurant section
    // below) — same adapter, retail's own box.
    if (!Hive.isAdapterRegistered(HiveTypeIds.staff)) {
      Hive.registerAdapter(StaffModelAdapter());
    }
    // Tax - shared with restaurant (typeId 114, see restaurant section
    // below) — same adapter, same box.
    if (!Hive.isAdapterRegistered(HiveTypeIds.tax)) {
      Hive.registerAdapter(TaxAdapter());
    }
    // BillingTab - 173
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailBillingTab)) {
      Hive.registerAdapter(BillingTabModelAdapter());
    }


    // EOD adapters (shared with restaurant mode)
    // EOD - 117
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantEod)) {
      Hive.registerAdapter(EndOfDayReportAdapter());
    }


    // OrderTypeSummary - 18
    if (!Hive.isAdapterRegistered(HiveTypeIds.OrderTypeSummary)) {
      Hive.registerAdapter(OrderTypeSummaryAdapter());
    }
    // CategorySales - 19
    if (!Hive.isAdapterRegistered(HiveTypeIds.CategorySales)) {
      Hive.registerAdapter(CategorySalesAdapter());
    }
    // PaymentSummary - 20
    if (!Hive.isAdapterRegistered(HiveTypeIds.PaymentSummary)) {
      Hive.registerAdapter(PaymentSummaryAdapter());
    }
    // TaxSummary - 21
    if (!Hive.isAdapterRegistered(HiveTypeIds.TaxSummary)) {
      Hive.registerAdapter(TaxSummaryAdapter());
    }
    // CashReconciliation - 22
    if (!Hive.isAdapterRegistered(HiveTypeIds.CashReconciliation)) {
      Hive.registerAdapter(CashReconciliationAdapter());
    }

    // Expense adapters (shared with restaurant mode - needed for EOD)
    // ExpenseCategory - 115
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExpense)) {
      Hive.registerAdapter(ExpenseCategoryAdapter());
    }
    // Expense - 116
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExpense1)) {
      Hive.registerAdapter(ExpenseAdapter());
    }

    // CashMovement - 128 (shared with restaurant mode - Cash Drawer + EOD reconciliation)
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCashMovement)) {
      Hive.registerAdapter(CashMovementModelAdapter());
    }

    // StockMovement - 126: manual stock add/remove log with reason + history
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantStockLog)) {
      Hive.registerAdapter(StockMovementModelAdapter());
    }

    // RestaurantSessionModel - 131 (shared with restaurant mode). The open
    // business day is stored as a session record, so Start Day and EOD need
    // this adapter in retail too.
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantSession)) {
      Hive.registerAdapter(RestaurantSessionModelAdapter());
    }
  }

  /// Clean up old incorrectly-named attribute boxes
  /// This is a one-time migration to fix box naming inconsistency
  static Future<void> _cleanupOldAttributeBoxes() async {
    try {
      // Delete old camelCase boxes if they exist
      final oldBoxNames = ['attributeValues', 'productAttributes'];
      for (final boxName in oldBoxNames) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
          // await Hive.box(boxName).close();
        }
        await Hive.deleteBoxFromDisk(boxName);
      }
    } catch (e) {
      // It's okay if boxes don't exist
    }
  }

  /// Open all retail Hive boxes
  static Future<void> openRetailBoxes() async {
    if (_areRetailBoxesOpen) {
      return;
    }

    // Clean up old incorrectly-named boxes first (one-time migration)
    await _cleanupOldAttributeBoxes();

    await Hive.openBox<ProductModel>(HiveBoxNames.products);
    await Hive.openBox<VarianteModel>(HiveBoxNames.variants);
    await Hive.openBox<CartItemModel>(HiveBoxNames.cartItems);
    await Hive.openBox<SaleModel>(HiveBoxNames.sales);
    await Hive.openBox<SaleItemModel>(HiveBoxNames.saleItems);
    await Hive.openBox<SupplierModel>(HiveBoxNames.suppliers);
    await Hive.openBox<SupplierLedgerEntryModel>(HiveBoxNames.supplierLedger);
    await Hive.openBox<PurchaseReturnModel>(HiveBoxNames.purchaseReturns);
    await Hive.openBox<PurchaseReturnItemModel>(HiveBoxNames.purchaseReturnItems);
    await Hive.openBox<SupplierClaimModel>(HiveBoxNames.supplierClaims);
    await Hive.openBox<SupplierClaimItemModel>(HiveBoxNames.supplierClaimItems);
    await Hive.openBox<InventoryLossModel>(HiveBoxNames.inventoryLosses);
    await Hive.openBox<StockTakeModel>(HiveBoxNames.stockTakes);
    await Hive.openBox<StockTakeItemModel>(HiveBoxNames.stockTakeItems);
    await Hive.openBox<RetailBundleModel>(HiveBoxNames.bundles);
    await Hive.openBox<RetailKitAssemblyModel>(HiveBoxNames.kitAssemblies);
    await Hive.openBox<Customer>(HiveBoxNames.customer);
    await Hive.openBox<HoldSaleModel>(HiveBoxNames.holdSales);
    await Hive.openBox<HoldSaleItemModel>(HiveBoxNames.holdSaleItems);
    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    // Legacy string-keyed category box — kept open only for not-yet-migrated
    // callers (bulk import, sample data, backup's legacy path). Not used by
    // the main Add Product / Category Management / Cart flows anymore.
    await Hive.openBox<String>(HiveBoxNames.retailCategories);
    // Retail categories — shared `Category` model (same as restaurant), own box.
    await Hive.openBox<Category>(HiveBoxNames.category);
    await Hive.openBox<PaymentEntryModel>(HiveBoxNames.paymentEntries);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox<StaffModel>(HiveBoxNames.staff);
    // Tax - shared with restaurant, same box.
    await Hive.openBox<Tax>(HiveBoxNames.tax);

    // Fix for typeId 252 corruption - delete and recreate billingTabs box
    try {
      await Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs);
    } catch (e) {
      try {
        // Close the box if it's somehow open
        if (Hive.isBoxOpen(HiveBoxNames.billingTabs)) {
          await Hive.box(HiveBoxNames.billingTabs).close();
        }

        // Delete the corrupted box from disk
        await Hive.deleteBoxFromDisk(HiveBoxNames.billingTabs);

        // Create a fresh box
        await Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs);
      } catch (deleteError) {
        rethrow;
      }
    }

    // EOD box (shared with restaurant mode)
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);

    // Day Management box (for opening balance tracking)
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    // Session box (shared with restaurant mode). DayManagementService stores the
    // open day as a session record, so Start Day / EOD need this box in retail
    // too — without it both throw "Box not found".
    await Hive.openBox<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);

    // Expense boxes (shared with restaurant mode - needed for EOD)
    await Hive.openBox<ExpenseCategory>(HiveBoxNames.retailExpenseCategory);
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);

    // Cash movements box (shared with restaurant mode - Cash In/Out powers the
    // Cash Drawer screen and makes EOD cash reconciliation accurate).
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);

    _areRetailBoxesOpen = true;
  }

  /// Register all restaurant adapters (typeIds: 100-149)
  static Future<void> registerRestaurantAdapters() async {
    // Self-sufficient: a mode's adapters are meaningless without the common
    // ones (ShiftModel, AttendanceModel, SavedPrinterModel, AppNotification…).
    // `init()` normally runs this first and every registration is individually
    // guarded by isAdapterRegistered, so calling it again is a no-op.
    await _registerCommonAdapters();
    // Category - 100
    if (!Hive.isAdapterRegistered(HiveTypeIds.category)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    // Items - 102
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantItem)) {
      Hive.registerAdapter(ItemsAdapter());
    }
    // Extra - 103
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExtra)) {
      Hive.registerAdapter(ExtramodelAdapter());
    }
    // Topping - 104
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantTopping)) {
      Hive.registerAdapter(ToppingAdapter());
    }
    // Variant - 105
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantVariant)) {
      Hive.registerAdapter(VariantModelAdapter());
    }
    // Choices - 106
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantChoice)) {
      Hive.registerAdapter(ChoicesModelAdapter());
    }
    // ChoiceOption - 107
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantChoiceOption)) {
      Hive.registerAdapter(ChoiceOptionAdapter());
    }
    // CartItem - 108
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCart)) {
      Hive.registerAdapter(CartItemAdapter());
    }
    // Order - 109
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantOrder)) {
      Hive.registerAdapter(OrderModelAdapter());
    }
    // Staff - 110, shared with retail (see retail section above)
    if (!Hive.isAdapterRegistered(HiveTypeIds.staff)) {
      Hive.registerAdapter(StaffModelAdapter());
    }
    // TableModel - 111
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantTable)) {
      Hive.registerAdapter(TableModelAdapter());
    }
    // ItemVariant - 112
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantItemVariant)) {
      Hive.registerAdapter(ItemVarianteAdapter());
    }
    // PastOrder - 113
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantPastOrder)) {
      Hive.registerAdapter(PastOrderModelAdapter());
    }
    // Tax - 114, shared with retail (see retail section above)
    if (!Hive.isAdapterRegistered(HiveTypeIds.tax)) {
      Hive.registerAdapter(TaxAdapter());
    }
    // ExpenseCategory - 115
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExpense)) {
      Hive.registerAdapter(ExpenseCategoryAdapter());
    }
    // Expense - 116
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantExpense1)) {
      Hive.registerAdapter(ExpenseAdapter());
    }
    // EOD - 117
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantEod)) {
      Hive.registerAdapter(EndOfDayReportAdapter());
    }
    // OrderTypeSummary - 18
    if (!Hive.isAdapterRegistered(HiveTypeIds.OrderTypeSummary)) {
      Hive.registerAdapter(OrderTypeSummaryAdapter());
    }
    // CategorySales - 19
    if (!Hive.isAdapterRegistered(HiveTypeIds.CategorySales)) {
      Hive.registerAdapter(CategorySalesAdapter());
    }
    // PaymentSummary - 20
    if (!Hive.isAdapterRegistered(HiveTypeIds.PaymentSummary)) {
      Hive.registerAdapter(PaymentSummaryAdapter());
    }
    // TaxSummary - 21
    if (!Hive.isAdapterRegistered(HiveTypeIds.TaxSummary)) {
      Hive.registerAdapter(TaxSummaryAdapter());
    }
    // CashReconciliation - 22
    if (!Hive.isAdapterRegistered(HiveTypeIds.CashReconciliation)) {
      Hive.registerAdapter(CashReconciliationAdapter());
    }
    // TestBill - 118
    if (!Hive.isAdapterRegistered(HiveTypeIds.TestBill)) {
      Hive.registerAdapter(TestBillModelAdapter());
    }
    // Customer - 125, shared with retail (see retail section above)
    if (!Hive.isAdapterRegistered(HiveTypeIds.customer)) {
      Hive.registerAdapter(CustomerAdapter());
    }
    // ShiftModel (127) moved to _registerCommonAdapters — shared with retail.
    // CashMovementModel - 128: records every Cash In / Cash Out during the day
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCashMovement)) {
      Hive.registerAdapter(CashMovementModelAdapter());
    }
    // StockMovementModel - 126: manual stock add/remove log with reason + history
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantStockLog)) {
      Hive.registerAdapter(StockMovementModelAdapter());
    }
    // CashHandoverModel - 129: 2-step shift handover between staff members
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCashHandover)) {
      Hive.registerAdapter(CashHandoverModelAdapter());
    }
    // SavedPrinterModel (130) moved to _registerCommonAdapters — printer
    // pairing is shared with retail.
    // RestaurantSessionModel - 131: Session-based day management
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantSession)) {
      Hive.registerAdapter(RestaurantSessionModelAdapter());
    }
    // AttendanceModel (132) moved to _registerCommonAdapters — shared with retail.
    // ItemCancellationModel - 134: item-level cancellation audit
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantItemCancellation)) {
      Hive.registerAdapter(ItemCancellationModelAdapter());
    }
    // RecipeIngredientModel - 136: embedded line in RecipeModel.ingredients
    // (registered before RecipeModel since RecipeModel embeds it)
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantRecipeIngredient)) {
      Hive.registerAdapter(RecipeIngredientModelAdapter());
    }
    // RecipeModel - 135: Bill of Materials for Semi-Finished/Recipe-Based items
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantRecipe)) {
      Hive.registerAdapter(RecipeModelAdapter());
    }
    // RecipeProductionModel - 137: "batch produced" log for Semi-Finished items
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantRecipeProduction)) {
      Hive.registerAdapter(RecipeProductionModelAdapter());
    }
    // RestaurantSupplierModel - 138: raw-material suppliers
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantSupplier)) {
      Hive.registerAdapter(RestaurantSupplierModelAdapter());
    }
    // RestaurantPurchaseOrderModel - 139
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantPurchaseOrder)) {
      Hive.registerAdapter(RestaurantPurchaseOrderModelAdapter());
    }
    // RestaurantPurchaseOrderItemModel - 140
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantPurchaseOrderItem)) {
      Hive.registerAdapter(RestaurantPurchaseOrderItemModelAdapter());
    }
    // RestaurantGRNModel - 141
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantGrn)) {
      Hive.registerAdapter(RestaurantGRNModelAdapter());
    }
    // RestaurantGRNItemModel - 142
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantGrnItem)) {
      Hive.registerAdapter(RestaurantGRNItemModelAdapter());
    }
    // RestaurantPurchaseReturnModel - 143
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantPurchaseReturn)) {
      Hive.registerAdapter(RestaurantPurchaseReturnModelAdapter());
    }
    // RestaurantPurchaseReturnItemModel - 144
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantPurchaseReturnItem)) {
      Hive.registerAdapter(RestaurantPurchaseReturnItemModelAdapter());
    }
    // RestaurantSupplierClaimModel - 145
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantSupplierClaim)) {
      Hive.registerAdapter(RestaurantSupplierClaimModelAdapter());
    }
    // RestaurantSupplierClaimItemModel - 146
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantSupplierClaimItem)) {
      Hive.registerAdapter(RestaurantSupplierClaimItemModelAdapter());
    }
    // RestaurantInventoryLossModel - 147
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantInventoryLoss)) {
      Hive.registerAdapter(RestaurantInventoryLossModelAdapter());
    }
    // RestaurantStockTakeModel - 148
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantStockTake)) {
      Hive.registerAdapter(RestaurantStockTakeModelAdapter());
    }
    // RestaurantStockTakeItemModel - 149
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantStockTakeItem)) {
      Hive.registerAdapter(RestaurantStockTakeItemModelAdapter());
    }
    // RestaurantSupplierLedgerEntryModel - 185: first model in the restaurant
    // overflow range (185-199); the 100-149 block is full. See HiveTypeIds.
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantSupplierLedgerEntry)) {
      Hive.registerAdapter(RestaurantSupplierLedgerEntryModelAdapter());
    }
  }

  /// Open all restaurant Hive boxes
  static Future<void> openRestaurantBoxes() async {
    if (_areRestaurantBoxesOpen) {
      return;
    }

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
    // appCounters is opened in openCommonBoxes() now (shared with retail).

    await Hive.openBox<StaffModel>(HiveBoxNames.staff);
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);

    // Past Orders
    await Hive.openBox<PastOrderModel>(HiveBoxNames.restaurantPastOrders);

    // Tax - shared with retail, same box.
    await Hive.openBox<Tax>(HiveBoxNames.tax);

    // Expenses (restaurant-specific)
    await Hive.openBox<ExpenseCategory>(HiveBoxNames.restaurantExpenseCategory);
    await Hive.openBox<Expense>(HiveBoxNames.restaurantExpense);

    // EOD (restaurant-specific)
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.restaurantEOD);

    // Day Management (for opening balance tracking)
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    await Hive.openBox<TestBillModel>(HiveBoxNames.testBillBox);

    // Restaurant Customer (shared Customer model, own box)
    await Hive.openBox<Customer>(HiveBoxNames.customer);

    // Shifts box moved to openCommonBoxes — shared with retail.

    // Cash Management — movements (Cash In/Out) and handovers (shift transfers)
    await Hive.openBox<CashMovementModel>(HiveBoxNames.restaurantCashMovements);
    await Hive.openBox<StockMovementModel>(HiveBoxNames.restaurantStockMovements);
    // Pending Settle stock work — see StockJournal. Restaurant only.
    await Hive.openBox(HiveBoxNames.restaurantStockJournal);
    await Hive.openBox<CashHandoverModel>(HiveBoxNames.restaurantCashHandovers);

    // Saved thermal printers box moved to openCommonBoxes — shared with retail.

    // Restaurant POS Sessions
    await Hive.openBox<RestaurantSessionModel>(HiveBoxNames.restaurantSessions);

    // Staff attendance box moved to openCommonBoxes — shared with retail.
    // Item-level cancellation audit
    await Hive.openBox<ItemCancellationModel>(HiveBoxNames.restaurantItemCancellations);

    // Recipes (BOM) and batch-production log — see docs/inventory_recipe_system_plan.md
    await Hive.openBox<RecipeModel>(HiveBoxNames.restaurantRecipes);
    await Hive.openBox<RecipeProductionModel>(HiveBoxNames.restaurantRecipeProductions);

    // Restaurant Purchase Order / GRN pipeline (raw-material procurement)
    await Hive.openBox<RestaurantSupplierModel>(HiveBoxNames.restaurantSuppliers);
    await Hive.openBox<RestaurantPurchaseOrderModel>(HiveBoxNames.restaurantPurchaseOrders);
    await Hive.openBox<RestaurantPurchaseOrderItemModel>(HiveBoxNames.restaurantPurchaseOrderItems);
    await Hive.openBox<RestaurantGRNModel>(HiveBoxNames.restaurantGrns);
    await Hive.openBox<RestaurantGRNItemModel>(HiveBoxNames.restaurantGrnItems);

    // Damaged-goods/loss/stock-take chain (returns, claims, write-offs, counts)
    await Hive.openBox<RestaurantPurchaseReturnModel>(HiveBoxNames.restaurantPurchaseReturns);
    await Hive.openBox<RestaurantPurchaseReturnItemModel>(HiveBoxNames.restaurantPurchaseReturnItems);
    await Hive.openBox<RestaurantSupplierClaimModel>(HiveBoxNames.restaurantSupplierClaims);
    await Hive.openBox<RestaurantSupplierClaimItemModel>(HiveBoxNames.restaurantSupplierClaimItems);
    await Hive.openBox<RestaurantInventoryLossModel>(HiveBoxNames.restaurantInventoryLosses);
    await Hive.openBox<RestaurantStockTakeModel>(HiveBoxNames.restaurantStockTakes);
    await Hive.openBox<RestaurantStockTakeItemModel>(HiveBoxNames.restaurantStockTakeItems);

    // Supplier balance journal — one row per balance movement.
    await Hive.openBox<RestaurantSupplierLedgerEntryModel>(
        HiveBoxNames.restaurantSupplierLedger);

    _areRestaurantBoxesOpen = true;
  }

  /// Initialize boxes based on business mode
  /// Call this after AppConfig.init() and when business mode is known
  static Future<void> initializeBusinessBoxes() async {
    if (AppConfig.isRetail) {
      await registerRetailAdapters();
      await openRetailBoxes();
    } else if (AppConfig.isRestaurant) {
      await registerRestaurantAdapters();
      await openRestaurantBoxes();
    }
    // If business mode is not set yet (during setup), we'll initialize later
  }

  /// Initialize boxes for a specific mode (used during setup wizard)
  /// Safe to call multiple times - will skip if already initialized
  static Future<void> initializeForMode(BusinessMode mode) async {
    if (mode == BusinessMode.retail) {
      // Only initialize if not already done
      if (!areRetailBoxesOpen) {
        await registerRetailAdapters();
        await openRetailBoxes();
      }
    } else if (mode == BusinessMode.restaurant) {
      // Only initialize if not already done
      if (!areRestaurantBoxesOpen) {
        await registerRestaurantAdapters();
        await openRestaurantBoxes();
      }
    }
  }

  /// Check if retail boxes are open
  static bool get areRetailBoxesOpen {
    try {
      return Hive.isBoxOpen(HiveBoxNames.products) &&
             Hive.isBoxOpen(HiveBoxNames.attributes) &&
             Hive.isBoxOpen(HiveBoxNames.attributeValues) &&
             Hive.isBoxOpen(HiveBoxNames.productAttributes) &&
             Hive.isBoxOpen(HiveBoxNames.dayManagementBox) &&
             Hive.isBoxOpen(HiveBoxNames.retailEOD) &&
             Hive.isBoxOpen(HiveBoxNames.retailExpenseCategory) &&
             Hive.isBoxOpen(HiveBoxNames.retailExpense);
    } catch (_) {
      return false;
    }
  }

  /// Check if restaurant boxes are open
  static bool get areRestaurantBoxesOpen {
    try {
      return Hive.isBoxOpen(HiveBoxNames.category) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantItems) &&
             Hive.isBoxOpen(HiveBoxNames.tax) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantExtras) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantVariants) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantChoices) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantEOD) &&
             Hive.isBoxOpen(HiveBoxNames.dayManagementBox) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantExpenseCategory) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantExpense);
    } catch (_) {
      return false;
    }
  }

  /// Force reset all attribute boxes (use this to fix "bad element" errors)
  /// WARNING: This will delete ALL attribute data!
  static Future<void> resetAttributeBoxes() async {
    try {

      final boxNames = [
        'attributes',
        'attribute_values',
        'product_attributes',
        'attributeValues',  // old name
        'productAttributes',  // old name
      ];

      for (final boxName in boxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            await box.close();
          }
          await Hive.deleteBoxFromDisk(boxName);
        } catch (e) {
        }
      }

      // Re-register adapters
      await registerRetailAdapters();

      // Re-open the correct boxes
      await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
      await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
      await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);

    } catch (e) {
      rethrow;
    }
  }
}