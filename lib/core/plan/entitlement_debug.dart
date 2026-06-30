import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'entitlement_keys.dart';
import 'entitlements.dart';

/// DEBUG-ONLY diagnostics for the entitlements manifest. Prints, in one block:
///  1. raw API response `data`            5. Entitlements.instance loaded map
///  2. raw manifest string                6/7. keys missing → using defaults
///  3. parsed manifest                    8. effective value per catalog key
///  4. parsed entitlements map
///
/// No entitlement LOGIC here — it only reads and prints. Compiled out in release.
class EntitlementDebug {
  EntitlementDebug._();

  // Catalog grouped for readable output.
  static const _modules = [
    EntKeys.inventory, EntKeys.billing, EntKeys.reports,
    EntKeys.customers, EntKeys.users, EntKeys.settings,
    EntKeys.expenses, EntKeys.cashDrawer, EntKeys.attendance,
    EntKeys.shifts, EntKeys.kds, EntKeys.captain,
    EntKeys.dataBackup, EntKeys.manageMenu,
  ];
  static const _submodules = [
    EntKeys.billingInvoice, EntKeys.billingReturns, EntKeys.billingTables,
    EntKeys.manageMenuItems, EntKeys.manageMenuCategories,
    EntKeys.manageMenuVariants, EntKeys.manageMenuChoices, EntKeys.manageMenuExtras,
    EntKeys.reportsTotalSale, EntKeys.reportsSaleByItem, EntKeys.reportsSaleByCategory,
    EntKeys.reportsDailyClosing, EntKeys.reportsCustomerList, EntKeys.reportsCustomerRevenue,
    EntKeys.reportsComparisonWeek, EntKeys.reportsComparisonMonth,
    EntKeys.reportsComparisonYear, EntKeys.reportsComparisonProduct,
    EntKeys.reportsRefundDetails, EntKeys.reportsDiscountOrders, EntKeys.reportsVoidOrders,
    EntKeys.reportsItemCancellation, EntKeys.reportsPosEndDay, EntKeys.reportsExpense,
    EntKeys.reportsShift, EntKeys.reportsStaffPerformance, EntKeys.reportsAttendance,
    EntKeys.reportsCashDrawerHistory, EntKeys.reportsPerformanceStatistics,
  ];
  static const _actions = [
    EntKeys.billingInvoiceCreate, EntKeys.billingInvoiceEdit,
    EntKeys.billingInvoiceExport, EntKeys.billingInvoiceVoid,
    EntKeys.manageMenuItemsAdd, EntKeys.manageMenuItemsEdit, EntKeys.manageMenuItemsDelete,
    EntKeys.manageMenuCategoriesAdd, EntKeys.manageMenuCategoriesEdit, EntKeys.manageMenuCategoriesDelete,
    EntKeys.manageMenuVariantsAdd, EntKeys.manageMenuVariantsEdit, EntKeys.manageMenuVariantsDelete,
    EntKeys.manageMenuChoicesAdd, EntKeys.manageMenuChoicesEdit, EntKeys.manageMenuChoicesDelete,
    EntKeys.manageMenuExtrasAdd, EntKeys.manageMenuExtrasEdit, EntKeys.manageMenuExtrasDelete,
  ];
  static const _limits = [
    EntKeys.manageMenuItemsMax, EntKeys.billingInvoicePerDayMax,
    EntKeys.customersMax, EntKeys.usersMax,
  ];
  static const _scopes = [
    EntKeys.reportsHistoryLimitDays,
  ];

  /// [source] = 'ACTIVATE' or 'SYNC'. [data] = the server response `data` block.
  static void dump(String source, Map<String, dynamic> data) {
    if (!kDebugMode) return;
    final b = StringBuffer('\n');
    b.writeln('========== LICENSE MANIFEST [$source] ==========');

    // 1. raw response data
    b.writeln('--- 1. RAW RESPONSE (data) ---');
    b.writeln(_pretty(data));

    // 2. raw manifest string
    final raw = data['manifest'] as String?;
    b.writeln('--- 2. RAW MANIFEST STRING ---');
    b.writeln(raw ?? '(none — this response carried no manifest)');

    // 3 & 4. parsed manifest + entitlements
    Map<String, dynamic> manifest = {};
    Map<String, dynamic> ent = {};
    if (raw != null) {
      try {
        manifest = jsonDecode(raw) as Map<String, dynamic>;
        ent = (manifest['entitlements'] as Map?)?.cast<String, dynamic>() ?? {};
      } catch (e) {
        b.writeln('!! manifest parse error: $e');
      }
    }
    b.writeln('--- 3. PARSED MANIFEST ---');
    b.writeln('Plan: ${manifest['plancode']}    Version: ${manifest['version']}');
    b.writeln('License: ${manifest['license']}');
    b.writeln('--- 4. ENTITLEMENTS MAP (parsed from manifest, ${ent.length} keys) ---');
    for (final k in ent.keys.toList()..sort()) {
      b.writeln('${_pad(k)} -> ${ent[k]}');
    }

    // 5. Entitlements.instance loaded map (what's actually live in the app)
    final loaded = Entitlements.instance.debugSnapshot();
    b.writeln('--- 5. Entitlements.instance MAP (live, ${loaded.length} keys) ---');
    for (final k in loaded.keys.toList()..sort()) {
      b.writeln('${_pad(k)} -> ${loaded[k]}');
    }

    // 6/7. keys missing from the live map → fall back to catalog default
    final missing =
        kEntitlementDefaults.keys.where((k) => !loaded.containsKey(k)).toList();
    b.writeln('--- 6/7. MISSING FROM MANIFEST → using DEFAULT (${missing.length}) ---');
    if (missing.isEmpty) {
      b.writeln('(none — every catalog key is present)');
    } else {
      for (final k in missing) {
        b.writeln('${_pad(k)} -> ${kEntitlementDefaults[k]}   (DEFAULT)');
      }
    }

    // 8. effective value per catalog key, grouped (can() for bools, limit() for ints)
    b.writeln('--- 8. EFFECTIVE VALUES (what the app actually uses) ---');
    _group(b, 'Modules', _modules, loaded);
    _group(b, 'Submodules', _submodules, loaded);
    _group(b, 'Actions', _actions, loaded);
    _group(b, 'Limits', _limits, loaded);
    _group(b, 'Data Scopes', _scopes, loaded);

    b.writeln('================================================');

    // debugPrint truncates ~1000 chars/line — emit line by line.
    for (final line in b.toString().split('\n')) {
      debugPrint(line);
    }
  }

  static void _group(
      StringBuffer b, String title, List<String> keys, Map loaded) {
    b.writeln(title);
    for (final k in keys) {
      final src = loaded.containsKey(k) ? 'manifest' : 'DEFAULT';
      final v = Entitlements.instance.value(k); // effective (manifest or default)
      b.writeln('  ${_pad(k)} -> ${_fmt(v)}   ($src)');
    }
  }

  static String _fmt(dynamic v) =>
      v == true ? 'true' : (v == false ? 'false' : '$v');
  static String _pad(String s) => s.padRight(30);
  static String _pretty(Object o) {
    try {
      return const JsonEncoder.withIndent('  ').convert(o);
    } catch (_) {
      return '$o';
    }
  }
}
