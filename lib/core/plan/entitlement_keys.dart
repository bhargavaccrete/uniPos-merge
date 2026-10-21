/// The entitlement catalog — the master vocabulary the server's manifest draws
/// from. These strings are the contract: they must match the server's Feature
/// Catalog exactly (same spelling on both sides).
///
/// [kEntitlementDefaults] mirrors each key's server-side default and is the
/// restrictive fallback used whenever a key is absent from the cached manifest
/// (older cache, partial plan, or offline). Default is off/0 except where the
/// server's own default differs (settings/shifts on, users.max 2).
///
/// Menu management lives under `manage_menu.*` (canonical). `inventory` is the
/// stock module only. Reports are flat (`reports.<report>`), with a single global
/// `reports.history_limit_days` window.
class EntKeys {
  EntKeys._();

  // ── Modules ─────────────────────────────────────────────────────────────────
  static const inventory = 'inventory'; // stock operations only
  static const billing = 'billing';
  static const reports = 'reports';
  static const customers = 'customers';
  static const users = 'users';
  static const settings = 'settings';
  static const expenses = 'expenses';
  static const cashDrawer = 'cashdrawer';
  static const attendance = 'attendance';
  static const shifts = 'shifts';
  static const kds = 'kds';
  static const captain = 'captain';
  static const dataBackup = 'data_backup';
  static const manageMenu = 'manage_menu';

  // ── Submodules ───────────────────────────────────────────────────────────────
  static const billingInvoice = 'billing.invoice';
  static const billingReturns = 'billing.returns';
  static const billingTables = 'billing.tables';
  static const billingKot = 'billing.kot'; // KOT generation (on/off)

  // Table actions (finer control within dine-in)
  static const billingTablesCreate = 'billing.tables.create';
  static const billingTablesMerge = 'billing.tables.merge';
  static const billingTablesTransfer = 'billing.tables.transfer';

  static const manageMenuItems = 'manage_menu.items';
  static const manageMenuCategories = 'manage_menu.categories';
  static const manageMenuVariants = 'manage_menu.variants';
  static const manageMenuChoices = 'manage_menu.choices';
  static const manageMenuExtras = 'manage_menu.extras';


  // Reports — one submodule per report (flat under `reports`)
  static const reportsTotalSale = 'reports.total_sale';
  static const reportsSaleByItem = 'reports.sale_by_item';
  static const reportsSaleByCategory = 'reports.sale_by_category';
  static const reportsDailyClosing = 'reports.daily_closing';
  static const reportsCustomerList = 'reports.customer_list';
  static const reportsCustomerRevenue = 'reports.customer_revenue';
  static const reportsComparisonWeek = 'reports.comparison_week';
  static const reportsComparisonMonth = 'reports.comparison_month';
  static const reportsComparisonYear = 'reports.comparison_year';
  static const reportsComparisonProduct = 'reports.comparison_product';
  static const reportsRefundDetails = 'reports.refund_details';
  static const reportsDiscountOrders = 'reports.discount_orders';
  static const reportsVoidOrders = 'reports.void_orders';
  static const reportsItemCancellation = 'reports.item_cancellation';
  static const reportsPosEndDay = 'reports.pos_end_day';
  static const reportsExpense = 'reports.expense';
  static const reportsShift = 'reports.shift';
  static const reportsStaffPerformance = 'reports.staff_performance';
  static const reportsAttendance = 'reports.attendance';
  static const reportsCashDrawerHistory = 'reports.cash_drawer_history';
  static const reportsPerformanceStatistics = 'reports.performance_statistics';
  static const reportsPaymentMode = 'reports.payment_mode';

  // Purchasing reports. Mirrors retail's `retail.reports.*` strings minus the
  // prefix, matching the existing reports.attendance <-> retail.reports.
  // attendance symmetry.
  //
  // ONE key for all three PO-status tiles — they are named constructors of a
  // single screen over the same data, so granting Pending but not Completed
  // would be indefensible.
  static const reportsPurchaseSummary = 'reports.purchase_summary';
  static const reportsSupplierPurchase = 'reports.supplier_purchase';
  static const reportsPoStatus = 'reports.po_status';
  static const reportsGrn = 'reports.grn';
  static const reportsDamagedItems = 'reports.damaged_items';
  static const reportsPurchaseReturn = 'reports.purchase_return';
  static const reportsStockAdjustment = 'reports.stock_adjustment';
  static const reportsLowStock = 'reports.low_stock';
  static const reportsSupplierStatement = 'reports.supplier_statement';

  // ── Actions ──────────────────────────────────────────────────────────────────
  static const billingInvoiceCreate = 'billing.invoice.create';
  static const billingInvoiceEdit = 'billing.invoice.edit';
  static const billingInvoiceExport = 'billing.invoice.export';
  static const billingInvoiceVoid = 'billing.invoice.void';
  // Admin-controlled: print the "Powered by Bill Berry Lite" footer on bills.
  // true ⇒ shown (default), false ⇒ hidden. Sole control — no shop-side toggle.
  static const billingInvoicePrint = 'billing.invoice.print';

  static const manageMenuItemsAdd = 'manage_menu.items.add';
  static const manageMenuItemsEdit = 'manage_menu.items.edit';
  static const manageMenuItemsDelete = 'manage_menu.items.delete';

  static const manageMenuCategoriesAdd = 'manage_menu.categories.add';
  static const manageMenuCategoriesEdit = 'manage_menu.categories.edit';
  static const manageMenuCategoriesDelete = 'manage_menu.categories.delete';

  static const manageMenuVariantsAdd = 'manage_menu.variants.add';
  static const manageMenuVariantsEdit = 'manage_menu.variants.edit';
  static const manageMenuVariantsDelete = 'manage_menu.variants.delete';

  static const manageMenuChoicesAdd = 'manage_menu.choices.add';
  static const manageMenuChoicesEdit = 'manage_menu.choices.edit';
  static const manageMenuChoicesDelete = 'manage_menu.choices.delete';

  static const manageMenuExtrasAdd = 'manage_menu.extras.add';
  static const manageMenuExtrasEdit = 'manage_menu.extras.edit';
  static const manageMenuExtrasDelete = 'manage_menu.extras.delete';

  // ── Limits ───────────────────────────────────────────────────────────────────
  static const billingInvoicePerDayMax = 'billing.invoice.per_day_max';
  static const customersMax = 'customers.max';
  static const usersMax = 'users.max';
  static const manageMenuItemsMax = 'manage_menu.items.max';
  // Server sends the tables cap under 'billing.table' (not the '.tables.max'
  // convention the other caps follow) — match it so the limit is read.
  static const billingTablesMax = 'billing.table';

  // ── Data scopes ──────────────────────────────────────────────────────────────
  static const reportsHistoryLimitDays = 'reports.history_limit_days';
}

/// Server-mirrored defaults — used only when a key is missing from the manifest.
const Map<String, Object> kEntitlementDefaults = {
  // Modules
  EntKeys.inventory: false,
  EntKeys.billing: false,
  EntKeys.reports: false,
  EntKeys.customers: false,
  EntKeys.users: false,
  EntKeys.settings: true,
  EntKeys.expenses: false,
  EntKeys.cashDrawer: false,
  EntKeys.attendance: false,
  EntKeys.shifts: true,
  EntKeys.kds: false,
  EntKeys.captain: false,
  EntKeys.dataBackup: false,
  EntKeys.manageMenu: false,

  // Submodules
  EntKeys.billingInvoice: false,
  EntKeys.billingReturns: false,
  EntKeys.billingTables: false,
  // Table/KOT capabilities default PERMISSIVE — these are existing features, so
  // admin RESTRICTS by sending false / a cap (like settings/shifts default-on).
  EntKeys.billingKot: true,
  EntKeys.billingTablesCreate: true,
  EntKeys.billingTablesMerge: true,
  EntKeys.billingTablesTransfer: true,
  EntKeys.manageMenuItems: false,
  EntKeys.manageMenuCategories: false,
  EntKeys.manageMenuVariants: false,
  EntKeys.manageMenuChoices: false,
  EntKeys.manageMenuExtras: false,
  EntKeys.reportsTotalSale: false,
  EntKeys.reportsSaleByItem: false,
  EntKeys.reportsSaleByCategory: false,
  EntKeys.reportsDailyClosing: false,
  EntKeys.reportsCustomerList: false,
  EntKeys.reportsCustomerRevenue: false,
  EntKeys.reportsComparisonWeek: false,
  EntKeys.reportsComparisonMonth: false,
  EntKeys.reportsComparisonYear: false,
  EntKeys.reportsComparisonProduct: false,
  EntKeys.reportsRefundDetails: false,
  EntKeys.reportsDiscountOrders: false,
  EntKeys.reportsVoidOrders: false,
  EntKeys.reportsItemCancellation: false,
  EntKeys.reportsPosEndDay: false,
  EntKeys.reportsExpense: false,
  EntKeys.reportsShift: false,
  EntKeys.reportsStaffPerformance: false,
  EntKeys.reportsAttendance: false,
  EntKeys.reportsCashDrawerHistory: false,
  EntKeys.reportsPerformanceStatistics: false,
  EntKeys.reportsPaymentMode: false,

  // Purchasing reports — TRUE, unlike every other report key, and deliberately.
  //
  // The server does not know these keys at all: they were added with the
  // reports and no manifest has ever sent them. `Entitlements.can` resolves
  // `_map[key] ?? kEntitlementDefaults[key]`, so a `false` here would hide a
  // shipped, working feature on every licensed shop to satisfy a contract the
  // backend has not entered into yet. `true` means "allowed until the server
  // has an opinion".
  //
  // **Nothing needs changing when the backend does ship them** — a manifest
  // value always wins over the catalog, so the day these keys appear in a
  // manifest they start governing, grant or deny, with no code edit. At that
  // point flip these to `false` so the catalog mirrors the server again.
  EntKeys.reportsPurchaseSummary: true,
  EntKeys.reportsSupplierPurchase: true,
  EntKeys.reportsPoStatus: true,
  EntKeys.reportsGrn: true,
  EntKeys.reportsDamagedItems: true,
  EntKeys.reportsPurchaseReturn: true,
  EntKeys.reportsStockAdjustment: true,
  EntKeys.reportsLowStock: true,
  EntKeys.reportsSupplierStatement: true,

  // Actions
  EntKeys.billingInvoiceCreate: false,
  EntKeys.billingInvoiceEdit: false,
  EntKeys.billingInvoiceExport: false,
  EntKeys.billingInvoiceVoid: false,
  // Powered-by footer: shown by default; admin sends false to hide it.
  EntKeys.billingInvoicePrint: true,
  EntKeys.manageMenuItemsAdd: false,
  EntKeys.manageMenuItemsEdit: false,
  EntKeys.manageMenuItemsDelete: false,
  EntKeys.manageMenuCategoriesAdd: false,
  EntKeys.manageMenuCategoriesEdit: false,
  EntKeys.manageMenuCategoriesDelete: false,
  EntKeys.manageMenuVariantsAdd: false,
  EntKeys.manageMenuVariantsEdit: false,
  EntKeys.manageMenuVariantsDelete: false,
  EntKeys.manageMenuChoicesAdd: false,
  EntKeys.manageMenuChoicesEdit: false,
  EntKeys.manageMenuChoicesDelete: false,
  EntKeys.manageMenuExtrasAdd: false,
  EntKeys.manageMenuExtrasEdit: false,
  EntKeys.manageMenuExtrasDelete: false,

  // Limits
  EntKeys.billingInvoicePerDayMax: 0,
  EntKeys.customersMax: 0,
  EntKeys.usersMax: 2,
  EntKeys.manageMenuItemsMax: 0,
  EntKeys.billingTablesMax: 0, // 0 = unlimited

  // Data scopes — 'all' = unlimited history by default
  EntKeys.reportsHistoryLimitDays: 'all',
};
