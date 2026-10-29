import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/attendance_model.dart';
import 'package:billberrylite/data/models/common/business_details.dart';
import 'package:billberrylite/data/models/common/business_type.dart';
import 'package:billberrylite/data/models/common/shift_model.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/models/legacy/legacy_tax_rate_item.dart';
import 'package:billberrylite/models/payment_method.dart' as pm;
import 'package:billberrylite/models/tax_details.dart';

/// BLK-05 registry: which Hive boxes each mode's backup carries (box name →
/// export key) and which are deliberately left out, with the reason.
///
/// The coverage tests fail when HiveInit opens a box that is in neither map,
/// so adding a box forces a backup decision here.

/// Common boxes every backup carries, restored by `_restoreAllData`.
final Map<String, String> commonBackedUp = {
  HiveBoxNames.appConfig: 'appConfig',
  HiveBoxNames.appState: 'appState',
  HiveBoxNames.storeBox: 'storeBox',
  HiveBoxNames.businessDetailsBox: 'businessDetails',
  HiveBoxNames.businessTypeBox: 'businessTypes',
  HiveBoxNames.taxBox: 'taxDetails',
  HiveBoxNames.paymentMethods: 'paymentMethods',
};

/// Restored by `_restoreRestaurantData`.
final Map<String, String> restaurantBackedUp = {
  HiveBoxNames.category: 'categories',
  HiveBoxNames.restaurantItems: 'items',
  HiveBoxNames.restaurantVariants: 'variants',
  HiveBoxNames.restaurantChoices: 'choices',
  HiveBoxNames.restaurantExtras: 'extras',
  HiveBoxNames.staff: 'staffBox',
  HiveBoxNames.tax: 'taxes',
  HiveBoxNames.restaurantExpenseCategory: 'expenseCategories',
  HiveBoxNames.restaurantExpense: 'expenses',
  HiveBoxNames.restaurantTables: 'tables',
  HiveBoxNames.restaurantEOD: 'eodReports',
  HiveBoxNames.restaurantOrders: 'orders',
  HiveBoxNames.restaurantCart: 'restaurantCart',
  HiveBoxNames.appCounters: 'appCounters',
  HiveBoxNames.testBillBox: 'testBillBox',
  HiveBoxNames.shift: 'shifts',
  HiveBoxNames.attendance: 'restaurantAttendance',
  HiveBoxNames.customer: 'customers',
  HiveBoxNames.restaurantPastOrders: 'pastOrders',
  HiveBoxNames.restaurantPrinters: 'printers',
  HiveBoxNames.restaurantSessions: 'restaurantSessions',
  HiveBoxNames.dayManagementBox: 'dayManagement',
  HiveBoxNames.restaurantItemCancellations: 'itemCancellations',
  HiveBoxNames.restaurantCashMovements: 'cashMovements',
  HiveBoxNames.restaurantCashHandovers: 'cashHandovers',
  HiveBoxNames.restaurantStockMovements: 'stockMovements',
  HiveBoxNames.restaurantRecipes: 'recipes',
  HiveBoxNames.restaurantRecipeProductions: 'recipeProductions',
  HiveBoxNames.restaurantSuppliers: 'restaurantSuppliers',
  HiveBoxNames.restaurantPurchaseOrders: 'restaurantPurchaseOrders',
  HiveBoxNames.restaurantPurchaseOrderItems: 'restaurantPurchaseOrderItems',
  HiveBoxNames.restaurantGrns: 'restaurantGrns',
  HiveBoxNames.restaurantGrnItems: 'restaurantGrnItems',
  HiveBoxNames.restaurantSupplierLedger: 'restaurantSupplierLedger',
  HiveBoxNames.restaurantPurchaseReturns: 'restaurantPurchaseReturns',
  HiveBoxNames.restaurantPurchaseReturnItems: 'restaurantPurchaseReturnItems',
  HiveBoxNames.restaurantSupplierClaims: 'restaurantSupplierClaims',
  HiveBoxNames.restaurantSupplierClaimItems: 'restaurantSupplierClaimItems',
  HiveBoxNames.restaurantInventoryLosses: 'restaurantInventoryLosses',
  HiveBoxNames.restaurantStockTakes: 'restaurantStockTakes',
  HiveBoxNames.restaurantStockTakeItems: 'restaurantStockTakeItems',
};

/// Restored by `_restoreRetailData`.
final Map<String, String> retailBackedUp = {
  HiveBoxNames.products: 'products',
  HiveBoxNames.variants: 'variants',
  HiveBoxNames.cartItems: 'cartItems',
  HiveBoxNames.sales: 'sales',
  HiveBoxNames.saleItems: 'saleItems',
  HiveBoxNames.customer: 'customers',
  HiveBoxNames.suppliers: 'suppliers',
  HiveBoxNames.supplierLedger: 'supplierLedger',
  HiveBoxNames.purchaseReturns: 'purchaseReturns',
  HiveBoxNames.purchaseReturnItems: 'purchaseReturnItems',
  HiveBoxNames.supplierClaims: 'supplierClaims',
  HiveBoxNames.supplierClaimItems: 'supplierClaimItems',
  HiveBoxNames.inventoryLosses: 'inventoryLosses',
  HiveBoxNames.stockTakes: 'stockTakes',
  HiveBoxNames.stockTakeItems: 'stockTakeItems',
  HiveBoxNames.bundles: 'bundles',
  HiveBoxNames.kitAssemblies: 'kitAssemblies',
  HiveBoxNames.holdSales: 'holdSales',
  HiveBoxNames.holdSaleItems: 'holdSaleItems',
  HiveBoxNames.purchaseOrders: 'purchaseOrders',
  HiveBoxNames.purchaseOrderItems: 'purchaseOrderItems',
  HiveBoxNames.grns: 'grns',
  HiveBoxNames.grnItems: 'grnItems',
  HiveBoxNames.category: 'categories',
  HiveBoxNames.paymentEntries: 'paymentEntries',
  HiveBoxNames.creditPayments: 'creditPayments',
  HiveBoxNames.attributes: 'attributes',
  HiveBoxNames.attributeValues: 'attributeValues',
  HiveBoxNames.productAttributes: 'productAttributes',
  HiveBoxNames.staff: 'staffBox',
  HiveBoxNames.shift: 'shifts',
  HiveBoxNames.attendance: 'restaurantAttendance',
  HiveBoxNames.tax: 'taxes',
  HiveBoxNames.billingTabs: 'billingTabs',
  HiveBoxNames.retailEOD: 'eodReports',
  HiveBoxNames.retailExpenseCategory: 'expenseCategories',
  HiveBoxNames.retailExpense: 'expenses',
  HiveBoxNames.appCounters: 'appCounters',
  HiveBoxNames.dayManagementBox: 'dayManagement',
  HiveBoxNames.restaurantSessions: 'restaurantSessions',
  HiveBoxNames.restaurantPrinters: 'printers',
  HiveBoxNames.restaurantStockMovements: 'stockMovements',
  HiveBoxNames.restaurantCashMovements: 'cashMovements',
};

final Map<String, String> commonExcluded = {
  HiveBoxNames.appNotifications:
      'device-local notification inbox: local events are re-derived by '
          'NotificationSync at startup, remote pushes belong to this device',
};

final Map<String, String> restaurantExcluded = {
  HiveBoxNames.restaurantStockJournal:
      'crash-recovery journal of in-flight Settles; its entries describe this '
          "device's pre-restore stock and must never replay onto restored data",
};

final Map<String, String> retailExcluded = {
  HiveBoxNames.retailCategories:
      'legacy String box superseded by the shared category box; restore '
          'repopulates it from the "categories" key',
};

/// Registers every adapter and opens exactly what the app opens for [mode]
/// in [dir]. Returns the boxes now on disk (Hive lower-cases file names).
///
/// HiveInit's open functions are guarded by static once-only flags, so call
/// this once per test file (each file runs in its own isolate).
Future<Set<String>> openBoxesFor(String mode, Directory dir) async {
  await initHiveForBackupTest(dir);
  await AppConfig.box.put('businessMode', mode);
  await HiveInit.openCommonBoxes();
  if (mode == 'restaurant') {
    await HiveInit.openRestaurantBoxes();
  } else {
    await HiveInit.openRetailBoxes();
  }
  return hiveFilesIn(dir);
}

/// Points Hive at [dir], registers every adapter and initialises AppConfig,
/// opening nothing else, so the business mode is still unset (a fresh install).
Future<void> initHiveForBackupTest(Directory dir) async {
  SharedPreferences.setMockInitialValues({});
  Hive.init(dir.path);

  void reg<T>(TypeAdapter<T> a) {
    if (!Hive.isAdapterRegistered(a.typeId)) Hive.registerAdapter(a);
  }

  reg(TaxDetailsAdapter());
  reg(BusinessTypeAdapter());
  reg(BusinessDetailsAdapter());
  reg(LegacyTaxRateItemAdapter());
  reg(pm.PaymentMethodAdapter());
  reg(SavedPrinterModelAdapter());
  reg(AppNotificationModelAdapter());
  reg(ShiftModelAdapter());
  reg(AttendanceModelAdapter());
  await HiveInit.registerRestaurantAdapters();
  await HiveInit.registerRetailAdapters();

  await AppConfig.init();
}

/// The Hive boxes that exist on disk in [dir] (Hive lower-cases file names).
Set<String> hiveFilesIn(Directory dir) {
  return dir
      .listSync()
      .whereType<File>()
      .map((f) => p.basename(f.path))
      .where((n) => n.endsWith('.hive'))
      .map((n) => n.substring(0, n.length - '.hive'.length))
      .toSet();
}

Set<String> lowerNames(Iterable<String> names) =>
    names.map((n) => n.toLowerCase()).toSet();

/// Every opened box is covered or excluded, and every registry entry is a box
/// the mode really opens, so the registry cannot drift in either direction.
void expectBoxCoverage({
  required Set<String> opened,
  required Map<String, String> backedUp,
  required Map<String, String> excluded,
}) {
  final covered = lowerNames(backedUp.keys);
  final skipped = lowerNames(excluded.keys);

  expect(covered.intersection(skipped), isEmpty,
      reason: 'a box is either backed up or excluded, never both');
  expect(opened.difference(covered.union(skipped)), isEmpty,
      reason: 'opened but neither backed up nor deliberately excluded');
  expect(covered.union(skipped).difference(opened), isEmpty,
      reason: 'listed in the registry but never opened by this mode');
}

/// Export, then the JSON round trip the backup file goes through.
Future<Map<String, dynamic>> exportedBackupData() async {
  final exported = await UnifiedBackupService.collectAllDataForTesting();
  final decoded = jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
  return decoded['data'] as Map<String, dynamic>;
}

/// Export keys whose value is a single key/value map (`[{...}]`) rather than
/// a list of records.
const Set<String> singleMapKeys = {'appCounters', 'dayManagement'};

/// A backup in which every key in [keys] is present but empty, so restoring
/// it wipes each of those boxes through the service's own restore path.
Map<String, dynamic> emptyBackupFor(Iterable<String> keys) => {
      for (final k in keys)
        k: singleMapKeys.contains(k) ? [<String, dynamic>{}] : <dynamic>[],
    };

/// True when [value] (an exported key) holds no records.
bool isEmptyExport(String key, dynamic value) {
  final list = value as List;
  if (singleMapKeys.contains(key)) {
    return list.isEmpty || (list.first as Map).isEmpty;
  }
  return list.isEmpty;
}
