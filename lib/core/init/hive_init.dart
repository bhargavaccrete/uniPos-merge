
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/constants/hive_type_ids.dart';

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
import 'package:unipos/data/models/retail/hive_model/billing_tab_model.dart';

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

/// Hive Initialization Class
/// Handles all adapter registrations and box openings
class HiveInit {
  HiveInit._();

  /// Initialize Hive with Flutter
  static Future<void> init() async {
    await Hive.initFlutter();
    await _registerCommonAdapters();
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
    await Hive.openBox('storebox');
    await Hive.openBox('app_state');
    await Hive.openBox<TaxDetails>('taxBox');
    await Hive.openBox<BusinessType>('businessTypeBox');
    await Hive.openBox<BusinessDetails>('businessDetailsBox');

    // Open and initialize payment methods box with defaults
    final paymentBox = await Hive.openBox<pm.PaymentMethod>('paymentMethodsBox');
    print('📦 HiveInit: Opened paymentMethodsBox, has ${paymentBox.length} items');

    // Initialize with defaults if empty
    if (paymentBox.isEmpty) {
      print('📦 HiveInit: Payment box is empty, initializing defaults...');
      await _initializeDefaultPaymentMethods(paymentBox);
      print('📦 HiveInit: Initialized ${paymentBox.length} default payment methods');
    } else {
      print('📦 HiveInit: Payment box already has ${paymentBox.length} methods');
    }
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
    // BillingTab - 220
    if (!Hive.isAdapterRegistered(HiveTypeIds.retailBillingTab)) {
      Hive.registerAdapter(BillingTabModelAdapter());
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
          await Hive.box(boxName).close();
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
    // Clean up old incorrectly-named boxes first (one-time migration)
    await _cleanupOldAttributeBoxes();

    await Hive.openBox<ProductModel>('products');
    await Hive.openBox<VarianteModel>('variants');
    await Hive.openBox<CartItemModel>('cartItems');
    await Hive.openBox<SaleModel>('sales');
    await Hive.openBox<SaleItemModel>('saleItems');
    await Hive.openBox<SupplierModel>('suppliers');
    await Hive.openBox<PurchaseItemModel>('purchaseItems');
    await Hive.openBox<PurchaseModel>('purchases');
    await Hive.openBox<CustomerModel>('customers');
    await Hive.openBox<HoldSaleModel>('holdSales');
    await Hive.openBox<HoldSaleItemModel>('holdSaleItems');
    await Hive.openBox<PurchaseOrderModel>('purchaseOrders');
    await Hive.openBox<PurchaseOrderItemModel>('purchaseOrderItems');
    await Hive.openBox<GRNModel>('grns');
    await Hive.openBox<GRNItemModel>('grnItems');
    // Note: Retail categories use Box<String> named 'categories', not CategoryModel
    await Hive.openBox<String>('categories');
    // CategoryModel box for GST support
    await Hive.openBox<CategoryModel>('category_models');
    await Hive.openBox<PaymentEntryModel>('paymentEntries');
    await Hive.openBox<AdminModel>('admin_box');
    await Hive.openBox<CreditPaymentModel>('credit_payments');
    await Hive.openBox<AttributeModel>('attributes');
    await Hive.openBox<AttributeValueModel>('attribute_values');
    await Hive.openBox<ProductAttributeModel>('product_attributes');
    await Hive.openBox<RetailStaffModel>('retail_staff');
    await Hive.openBox<BillingTabModel>('billingTabs');

    print('✅ All retail boxes opened successfully');
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
    // TestBill - 118
    if (!Hive.isAdapterRegistered(HiveTypeIds.restaurantTestBill)) {
      Hive.registerAdapter(TestBillModelAdapter());
    }
  }

  /// Open all restaurant Hive boxes
  static Future<void> openRestaurantBoxes() async {
    // Core restaurant boxes - use actual box names from database files
    await Hive.openBox<Category>('categories');  // ✅ Actual name used in HiveBoxes
    await Hive.openBox<Company>('companyBox');
    await Hive.openBox<Items>('itemBoxs');
    await Hive.openBox<Extramodel>('extra');  // ✅ Changed from 'extras' to 'extra'
    await Hive.openBox<VariantModel>('variante');  // ✅ Changed from 'variants' to 'variante'
    await Hive.openBox<ChoicesModel>('choice');  // ✅ Changed from 'choices' to 'choice'

    // Restaurant cart
    await Hive.openBox<CartItem>('cart_box');  // ✅ Fixed: actual name is 'cart_box'

    // Orders
    await Hive.openBox<OrderModel>('orderBox');
    await Hive.openBox('appCounters');  // ✅ Added: order counter box

    await Hive.openBox<StaffModel>('staffBox');
    await Hive.openBox<TableModel>('tablesBox');

    // Past Orders
    await Hive.openBox<pastOrderModel>('pastorderBox');

    // Tax - use unique name to avoid conflict with retail 'taxBox'
    await Hive.openBox<Tax>('restaurant_taxes');

    // Expenses
    await Hive.openBox<ExpenseCategory>('expenseCategory');
    await Hive.openBox<Expense>('expenseBox');

    // EOD
    await Hive.openBox<EndOfDayReport>('eodBox');

    await Hive.openBox<TestBillModel>('testBillBox');

    print('✅ All restaurant boxes opened successfully with correct names');
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
      return Hive.isBoxOpen('products') &&
             Hive.isBoxOpen('attributes') &&
             Hive.isBoxOpen('attribute_values') &&
             Hive.isBoxOpen('product_attributes');
    } catch (_) {
      return false;
    }
  }

  /// Check if restaurant boxes are open
  static bool get areRestaurantBoxesOpen {
    try {
      return Hive.isBoxOpen('categories') &&
             Hive.isBoxOpen('itemBoxs') &&
             Hive.isBoxOpen('restaurant_taxes') &&
             Hive.isBoxOpen('extra') &&
             Hive.isBoxOpen('variante') &&
             Hive.isBoxOpen('choice');
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
      await Hive.openBox<AttributeModel>('attributes');
      await Hive.openBox<AttributeValueModel>('attribute_values');
      await Hive.openBox<ProductAttributeModel>('product_attributes');

      print('✅ Attribute boxes reset complete!');
    } catch (e) {
      print('❌ Error resetting attribute boxes: $e');
      rethrow;
    }
  }
}