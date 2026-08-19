import '../config/app_config.dart';
import 'entitlement_keys.dart';
import 'retail_entitlement_keys.dart';

/// Mode-aware entitlement key resolution.
///
/// Restaurant and retail keep **separate** vocabularies (`EntKeys` vs
/// `RetailEntKeys`) so they can't collide inside one signed manifest. But a
/// handful of concepts exist in BOTH verticals and are enforced from **shared**
/// code — unified stores (`CategoryStore`, `CustomerStore`, `StaffStore`),
/// the shared report window, the shared receipt renderers. Those call sites
/// can't name a single key.
///
/// Each getter here is the ONE canonical resolution for such a concept. Never
/// inline `AppConfig.isRetail ? RetailEntKeys.x : EntKeys.x` at a call site —
/// that's how the same responsibility ends up answering to two keys.
///
/// Concepts that exist in only one vertical (KOT, tables, credit, purchase…)
/// are NOT here — those call sites name their key directly.
class ModeKeys {
  ModeKeys._();

  // ── Categories (unified CategoryStore) ─────────────────────────────────────
  static String get categoriesAdd => AppConfig.isRetail
      ? RetailEntKeys.catalogCategoriesAdd
      : EntKeys.manageMenuCategoriesAdd;

  static String get categoriesEdit => AppConfig.isRetail
      ? RetailEntKeys.catalogCategoriesEdit
      : EntKeys.manageMenuCategoriesEdit;

  static String get categoriesDelete => AppConfig.isRetail
      ? RetailEntKeys.catalogCategoriesDelete
      : EntKeys.manageMenuCategoriesDelete;

  // ── Unified records: module flag + cap ─────────────────────────────────────
  static String get customers =>
      AppConfig.isRetail ? RetailEntKeys.customers : EntKeys.customers;

  static String get customersMax =>
      AppConfig.isRetail ? RetailEntKeys.customersMax : EntKeys.customersMax;

  static String get users =>
      AppConfig.isRetail ? RetailEntKeys.users : EntKeys.users;

  static String get usersMax =>
      AppConfig.isRetail ? RetailEntKeys.usersMax : EntKeys.usersMax;

  // ── Shared report window (ReportHistoryWindow, both verticals' reports) ────
  static String get reportsHistoryLimitDays => AppConfig.isRetail
      ? RetailEntKeys.reportsHistoryLimitDays
      : EntKeys.reportsHistoryLimitDays;

  // ── "Powered by Bill Berry Lite" receipt footer ────────────────────────────
  // Read by both ESC/POS and PDF renderers, which serve both modes from the
  // same `ReceiptData`.
  static String get billingInvoicePrint => AppConfig.isRetail
      ? RetailEntKeys.billingInvoicePrint
      : EntKeys.billingInvoicePrint;
}
