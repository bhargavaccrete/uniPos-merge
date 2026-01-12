
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';
import 'package:unipos/core/constants/hive_box_names.dart';

// Common Models
import 'package:unipos/models/payment_method.dart' as pm;
import 'package:unipos/models/tax_details.dart';
import 'package:unipos/data/models/common/business_type.dart';
import 'package:unipos/data/models/common/business_details.dart';

// Retail Models
import 'package:unipos/data/models/retail/hive_model/product_model_200.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';
import 'package:unipos/data/models/retail/hive_model/cart_model_202.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:unipos/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_Item_model_206.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_model_207.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_model_209.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_item_model_210.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:unipos/data/models/retail/hive_model/grn_model_213.dart';
import 'package:unipos/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:unipos/data/models/retail/hive_model/category_model_215.dart';
import 'package:unipos/data/models/retail/hive_model/payment_entry_model_216.dart';
import 'package:unipos/data/models/retail/hive_model/admin_model_217.dart';
import 'package:unipos/data/models/retail/hive_model/credit_payment_model_218.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_model_219.dart';
import 'package:unipos/data/models/retail/hive_model/attribute_value_model_220.dart';
import 'package:unipos/data/models/retail/hive_model/product_attribute_model_221.dart';
import 'package:unipos/data/models/retail/hive_model/staff_model_222.dart';
import 'package:unipos/data/models/retail/hive_model/billing_tab_model_173.dart';

// Restaurant Models
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/companymodel_301.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/data/models/restaurant/db/extramodel_303.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/data/models/restaurant/db/choicemodel_306.dart';
import 'package:unipos/data/models/restaurant/db/choiceoptionmodel_307.dart';
import 'package:unipos/data/models/restaurant/db/cartmodel_308.dart';
import 'package:unipos/data/models/restaurant/db/ordermodel_309.dart';
import 'package:unipos/data/models/restaurant/db/staffModel_310.dart';
import 'package:unipos/data/models/restaurant/db/table_Model_311.dart';
import 'package:unipos/data/models/restaurant/db/itemvariantemodel_312.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/data/models/restaurant/db/testbillmodel_318.dart';
import 'package:unipos/data/models/restaurant/db/customer_model_125.dart';

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
      print('⚠️ HiveInit.init() already called - skipping');
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
    // TaxRateItem - typeId: 5
    if (!Hive.isAdapterRegistered(HiveTypeIds.taxRateItem)) {
      Hive.registerAdapter(TaxRateItemAdapter());
    }
    // PaymentMethod - typeId: 6
    if (!Hive.isAdapterRegistered(HiveTypeIds.paymentMethod)) {
      Hive.registerAdapter(pm.PaymentMethodAdapter());
    }
  }

  /// Open common boxes (needed regardless of business mode)
  static Future<void> openCommonBoxes() async {
    if (_areCommonBoxesOpen) {
      print('⚠️ Common boxes already open - skipping');
      return;
    }
    await Hive.openBox(HiveBoxNames.storeBox);
    await Hive.openBox(HiveBoxNames.appState);
    await Hive.openBox<TaxDetails>(HiveBoxNames.taxBox);
    await Hive.openBox<BusinessType>(HiveBoxNames.businessTypeBox);
    await Hive.openBox<BusinessDetails>(HiveBoxNames.businessDetailsBox);

    // Open and initialize payment methods box with defaults
    final paymentBox = await Hive.openBox<pm.PaymentMethod>(HiveBoxNames.paymentMethods);
    print('📦 HiveInit: Opened paymentMethodsBox, has ${paymentBox.length} items');

    // Initialize with defaults if empty
    if (paymentBox.isEmpty) {
      print('📦 HiveInit: Payment box is empty, initializing defaults...');
      await _initializeDefaultPaymentMethods(paymentBox);
      print('📦 HiveInit: Initialized ${paymentBox.length} default payment methods');
    } else {
      print('📦 HiveInit: Payment box already has ${paymentBox.length} methods');
    }

    _areCommonBoxesOpen = true;
    print('✅ Common boxes opened and guard flag set');
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
    // PurchaseItem - 156
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPurchaseItem)) {
      Hive.registerAdapter(PurchaseItemModelAdapter());
    }
    // Purchase - 157
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPurchase)) {
      Hive.registerAdapter(PurchaseModelAdapter());
    }
    // Customer - 158
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailCustomer)) {
      Hive.registerAdapter(CustomerModelAdapter());
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
    // Category - 165
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailCategory)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    // PaymentEntry - 166
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailPaymentEntry)) {
      Hive.registerAdapter(PaymentEntryModelAdapter());
    }
    // Admin - 167
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailAdmin)) {
      Hive.registerAdapter(AdminModelAdapter());
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
    // RetailStaff - 172
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailStaff)) {
      Hive.registerAdapter(RetailStaffModelAdapter());
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
        print('🗑️ Deleted old attribute box: $boxName');
      }
    } catch (e) {
      print('⚠️ Error cleaning up old boxes (may not exist): $e');
      // It's okay if boxes don't exist
    }
  }

  /// Open all retail Hive boxes
  static Future<void> openRetailBoxes() async {
    if (_areRetailBoxesOpen) {
      print('⚠️ Retail boxes already open - skipping');
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
    await Hive.openBox<PurchaseItemModel>(HiveBoxNames.purchaseItems);
    await Hive.openBox<PurchaseModel>(HiveBoxNames.purchases);
    await Hive.openBox<CustomerModel>(HiveBoxNames.customers);
    await Hive.openBox<HoldSaleModel>(HiveBoxNames.holdSales);
    await Hive.openBox<HoldSaleItemModel>(HiveBoxNames.holdSaleItems);
    await Hive.openBox<PurchaseOrderModel>(HiveBoxNames.purchaseOrders);
    await Hive.openBox<PurchaseOrderItemModel>(HiveBoxNames.purchaseOrderItems);
    await Hive.openBox<GRNModel>(HiveBoxNames.grns);
    await Hive.openBox<GRNItemModel>(HiveBoxNames.grnItems);
    // Note: Retail categories use Box<String> named 'retail_categories' to avoid conflict
    await Hive.openBox<String>(HiveBoxNames.retailCategories);
    // CategoryModel box for GST support
    await Hive.openBox<CategoryModel>(HiveBoxNames.categoryModels);
    await Hive.openBox<PaymentEntryModel>(HiveBoxNames.paymentEntries);
    await Hive.openBox<AdminModel>(HiveBoxNames.adminBox);
    await Hive.openBox<CreditPaymentModel>(HiveBoxNames.creditPayments);
    await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
    await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
    await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);
    await Hive.openBox<RetailStaffModel>(HiveBoxNames.retailStaff);

    // Fix for typeId 252 corruption - delete and recreate billingTabs box
    try {
      await Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs);
    } catch (e) {
      print('⚠️ billingTabs box corrupted (typeId 252 error), fixing...');
      try {
        // Close the box if it's somehow open
        if (Hive.isBoxOpen(HiveBoxNames.billingTabs)) {
          await Hive.box(HiveBoxNames.billingTabs).close();
          print('✅ Closed corrupted billingTabs box');
        }

        // Delete the corrupted box from disk
        await Hive.deleteBoxFromDisk(HiveBoxNames.billingTabs);
        print('✅ Deleted corrupted billingTabs box');

        // Create a fresh box
        await Hive.openBox<BillingTabModel>(HiveBoxNames.billingTabs);
        print('✅ Recreated billingTabs box');
      } catch (deleteError) {
        print('❌ Failed to fix billingTabs: $deleteError');
        print('💡 Please manually delete: C:\\Users\\Hp\\OneDrive - Accrete Infosolution Technologies llp\\Documents\\billingtabs.hive');
        rethrow;
      }
    }

    // EOD box (shared with restaurant mode)
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.retailEOD);

    // Day Management box (for opening balance tracking)
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    // Expense boxes (shared with restaurant mode - needed for EOD)
    await Hive.openBox<ExpenseCategory>(HiveBoxNames.retailExpenseCategory);
    await Hive.openBox<Expense>(HiveBoxNames.retailExpense);

    _areRetailBoxesOpen = true;
    print('✅ All retail boxes opened successfully and guard flag set');
  }

  /// Register all restaurant adapters (typeIds: 100-149)
  static Future<void> registerRestaurantAdapters() async {
    // Category - 100
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCategory)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    // Company - 101
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantCompany)) {
      Hive.registerAdapter(CompanyAdapter());
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
    // Staff - 110
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantStaff)) {
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
      Hive.registerAdapter(pastOrderModelAdapter());
    }
    // Tax - 114
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantTax)) {
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
    // RestaurantCustomer - 125
    if (!Hive.isAdapterRegistered(HiveTypeIds.RestaurantCustomer)) {
      Hive.registerAdapter(RestaurantCustomerAdapter());
    }
  }

  /// Open all restaurant Hive boxes
  static Future<void> openRestaurantBoxes() async {
    if (_areRestaurantBoxesOpen) {
      print('⚠️ Restaurant boxes already open - skipping');
      return;
    }

    // Core restaurant boxes - use actual box names from database files
    await Hive.openBox<Category>(HiveBoxNames.restaurantCategories);
    await Hive.openBox<Company>(HiveBoxNames.restaurantCompany);
    await Hive.openBox<Items>(HiveBoxNames.restaurantItems);
    await Hive.openBox<Extramodel>(HiveBoxNames.restaurantExtras);
    await Hive.openBox<VariantModel>(HiveBoxNames.restaurantVariants);
    await Hive.openBox<ChoicesModel>(HiveBoxNames.restaurantChoices);

    // Restaurant cart
    await Hive.openBox<CartItem>(HiveBoxNames.restaurantCart);

    // Orders
    await Hive.openBox<OrderModel>(HiveBoxNames.restaurantOrders);
    await Hive.openBox(HiveBoxNames.appCounters);

    await Hive.openBox<StaffModel>(HiveBoxNames.restaurantStaff);
    await Hive.openBox<TableModel>(HiveBoxNames.restaurantTables);

    // Past Orders
    await Hive.openBox<pastOrderModel>(HiveBoxNames.restaurantPastOrders);

    // Tax - use unique name to avoid conflict with retail 'taxBox'
    await Hive.openBox<Tax>(HiveBoxNames.restaurantTaxes);

    // Expenses (restaurant-specific)
    await Hive.openBox<ExpenseCategory>(HiveBoxNames.restaurantExpenseCategory);
    await Hive.openBox<Expense>(HiveBoxNames.restaurantExpense);

    // EOD (restaurant-specific)
    await Hive.openBox<EndOfDayReport>(HiveBoxNames.restaurantEOD);

    // Day Management (for opening balance tracking)
    await Hive.openBox(HiveBoxNames.dayManagementBox);

    await Hive.openBox<TestBillModel>(HiveBoxNames.testBillBox);

    // Restaurant Customer
    await Hive.openBox<RestaurantCustomer>(HiveBoxNames.restaurantCustomer);

    _areRestaurantBoxesOpen = true;
    print('✅ All restaurant boxes opened successfully with correct names and guard flag set');
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
      return Hive.isBoxOpen(HiveBoxNames.restaurantCategories) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantItems) &&
             Hive.isBoxOpen(HiveBoxNames.restaurantTaxes) &&
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
      print('🔄 Resetting attribute boxes...');

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
            print('  ✓ Cleared and closed: $boxName');
          }
          await Hive.deleteBoxFromDisk(boxName);
          print('  ✓ Deleted from disk: $boxName');
        } catch (e) {
          print('  ⚠️ Error with box $boxName: $e');
        }
      }

      // Re-register adapters
      await registerRetailAdapters();

      // Re-open the correct boxes
      await Hive.openBox<AttributeModel>(HiveBoxNames.attributes);
      await Hive.openBox<AttributeValueModel>(HiveBoxNames.attributeValues);
      await Hive.openBox<ProductAttributeModel>(HiveBoxNames.productAttributes);

      print('✅ Attribute boxes reset complete!');
    } catch (e) {
      print('❌ Error resetting attribute boxes: $e');
      rethrow;
    }
  }
}