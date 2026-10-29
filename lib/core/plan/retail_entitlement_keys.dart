/// Retail entitlement catalog — the retail half of the plan vocabulary.
///
/// Kept **separate** from restaurant's `EntKeys` (`entitlement_keys.dart`) on purpose:
/// every key here is `retail_`-prefixed so retail and restaurant keys can never be
/// confused in code or collide inside the one signed manifest the backend sends.
///
/// Underscore, not dot, after `retail`: the admin composes keys from a parent
/// key + code segment and the segment can't contain a dot, so the top-level
/// rows were entered as `retail_billing`, `retail_catalog`… Children still
/// join with dots (`retail_catalog.products.add`).
///
/// These strings are the contract — they must match the server Feature Catalog
/// exactly. Read through the SAME engine as restaurant (`PlanEnforce` /
/// `Entitlements.instance`), which is key-agnostic. A key absent from a present
/// manifest falls back to [kRetailEntitlementDefaults] (merged into
/// `kEntitlementDefaults`).
class RetailEntKeys {
  RetailEntKeys._();

  // ── Modules ─────────────────────────────────────────────────────────────────
  static const billing = 'retail_billing';
  static const catalog = 'retail_catalog'; // product catalog (retail's "menu")
  static const customers = 'retail_customers';
  static const users = 'retail_users'; // staff
  static const attendance = 'retail_attendance'; // clock-in/out
  static const shifts = 'retail_shifts'; // staff shift lifecycle
  static const inventory = 'retail_inventory';
  static const inventoryStockTake = 'retail_inventory.stock_take';
  static const suppliers = 'retail_suppliers';
  static const purchase = 'retail_purchase'; // PO + GRN
  static const reports = 'retail_reports';
  static const settings = 'retail_settings';
  static const cashDrawer = 'retail_cashdrawer';
  static const dataBackup = 'retail_data_backup';
  static const loyalty = 'retail_loyalty';

  // ── Submodules ───────────────────────────────────────────────────────────────
  static const billingReturns = 'retail_billing.returns';
  static const billingCredit = 'retail_billing.credit'; // pay-later (retail only)
  // Parent of [billingInvoicePrint] only — no screen of its own.
  static const billingInvoice = 'retail_billing.invoice';
  static const catalogProducts = 'retail_catalog.products';
  static const catalogCategories = 'retail_catalog.categories';
  // Variant editors are dialogs inside Product Detail, not a route, so this
  // parent is checked alongside each variant action at the dialog itself.
  static const catalogVariants = 'retail_catalog.variants';
  static const purchaseReturns = 'retail_purchase.returns';
  static const purchaseDamaged = 'retail_purchase.damaged';

  // ── Reports — one key per report, flat under `retail.reports` ───────────────
  // Mirrors restaurant's flat `reports.*` family. Without these the whole
  // Reports hub is one all-or-nothing flag, so no plan can grant sales reports
  // while withholding profit or purchasing. Names follow the hub's tiles.
  static const reportsDailySales = 'retail_reports.daily_sales';
  static const reportsMonthlySales = 'retail_reports.monthly_sales';
  static const reportsSaleByProduct = 'retail_reports.sale_by_product';
  static const reportsSaleByVariant = 'retail_reports.sale_by_variant';
  static const reportsSaleByCategory = 'retail_reports.sale_by_category';
  static const reportsTopSelling = 'retail_reports.top_selling';
  static const reportsProfit = 'retail_reports.profit';
  static const reportsGst = 'retail_reports.gst';
  // Covers all THREE give-away mechanisms the Discounts Given report totals —
  // bill/line discounts, price overrides and loyalty redemption — not just the
  // one that lands in `SaleModel.discountAmount`.
  //
  // Minted rather than reusing a billing key because discounting is gated by
  // ROLE, not entitlement: `LineDiscountService.canDiscount` reads
  // `RestaurantSession.canAccess('billingDiscount')` and there is no
  // `billingDiscount` entitlement to reuse. No existing key owns "reporting
  // what was given away".
  static const reportsDiscounts = 'retail_reports.discounts';
  // Ad-hoc lines typed at the POS. Minted rather than reused because adding
  // a quick item is deliberately UNGATED at the till — there is no billing
  // key that owns it, so nothing exists to point the report at.
  static const reportsQuickItems = 'retail_reports.quick_items';
  static const reportsLowStock = 'retail_reports.low_stock';
  static const reportsStockAdjustment = 'retail_reports.stock_adjustment';
  // Purchasing side
  static const reportsPurchaseSummary = 'retail_reports.purchase_summary';
  static const reportsSupplierPurchase = 'retail_reports.supplier_purchase';
  // One key for all three PO-status tiles — they are named constructors of the
  // same screen (pending / partially received / completed).
  static const reportsPoStatus = 'retail_reports.po_status';
  static const reportsGrn = 'retail_reports.grn';
  static const reportsDamagedItems = 'retail_reports.damaged_items';
  static const reportsPurchaseReturn = 'retail_reports.purchase_return';
  // Cash / day close
  static const reportsCashDrawerHistory = 'retail_reports.cash_drawer_history';
  static const reportsEodHistory = 'retail_reports.eod_history';

  // Staff reports — mirror restaurant's `reports.attendance`,
  // `reports.shift` and `reports.staff_performance`.
  static const reportsAttendance = 'retail_reports.attendance';
  static const reportsShift = 'retail_reports.shift';
  static const reportsStaffPerformance =
      'retail_reports.staff_performance';
  // NOTE: the Credit Reports tile deliberately has no key of its own — it reads
  // [billingCredit], the same key its route guard uses. One responsibility, one key.
  // The Sales Refunds report tile follows the same rule and reads
  // [billingReturns] — the key that already owns the refund responsibility and
  // guards the write path in `sale_return_screen.dart`.

  // ── Actions ──────────────────────────────────────────────────────────────────
  // No invoice create/edit/export/void: retail has returns, not void, and sales
  // aren't edited after the fact — nothing would read those keys.
  // Admin-controlled "Powered by Bill Berry Lite" footer (default shown).
  static const billingInvoicePrint = 'retail_billing.invoice.print';

  // Product catalog actions (retail analog of manage_menu.items.*):
  static const catalogProductsAdd = 'retail_catalog.products.add';
  static const catalogProductsEdit = 'retail_catalog.products.edit';
  static const catalogProductsDelete = 'retail_catalog.products.delete';

  static const catalogCategoriesAdd = 'retail_catalog.categories.add';
  static const catalogCategoriesEdit = 'retail_catalog.categories.edit';
  static const catalogCategoriesDelete = 'retail_catalog.categories.delete';

  // Variant actions — retail's analog of restaurant's manage_menu.variants.*.
  // A retail product's variants carry the barcode, price and stock, so these
  // are edits to sellable units, not cosmetic options.
  static const catalogVariantsAdd = 'retail_catalog.variants.add';
  static const catalogVariantsEdit = 'retail_catalog.variants.edit';
  static const catalogVariantsDelete = 'retail_catalog.variants.delete';

  // Supplier actions:
  static const suppliersAdd = 'retail_suppliers.add';
  static const suppliersEdit = 'retail_suppliers.edit';
  static const suppliersDelete = 'retail_suppliers.delete';

  // Purchase actions (PO create + GRN receive):
  static const purchaseCreate = 'retail_purchase.create';
  static const purchaseReceive = 'retail_purchase.receive';

  // ── Limits (0/absent = unlimited) ────────────────────────────────────────────
  static const billingPerDayMax = 'retail_billing.per_day_max';
  static const catalogProductsMax = 'retail_catalog.products.max';
  static const customersMax = 'retail_customers.max';
  static const usersMax = 'retail_users.max';
  static const suppliersMax = 'retail_suppliers.max';

  // ── Data scopes ──────────────────────────────────────────────────────────────
  static const reportsHistoryLimitDays = 'retail_reports.history_limit_days';
}

/// Server-mirrored defaults for [RetailEntKeys] — used only when a key is
/// missing from the manifest. Spread into `kEntitlementDefaults`.
const Map<String, Object> kRetailEntitlementDefaults = {
  // Modules
  RetailEntKeys.billing: false,
  RetailEntKeys.catalog: false,
  RetailEntKeys.customers: false,
  RetailEntKeys.users: false,
  RetailEntKeys.attendance: false,
  RetailEntKeys.shifts: true,
  RetailEntKeys.inventory: false,
  RetailEntKeys.suppliers: false,
  RetailEntKeys.purchase: false,
  RetailEntKeys.reports: false,
  RetailEntKeys.settings: true,
  RetailEntKeys.cashDrawer: false,
  RetailEntKeys.dataBackup: false,
  RetailEntKeys.loyalty: false,

  // Submodules
  RetailEntKeys.billingInvoice: false,
  RetailEntKeys.billingReturns: false,
  RetailEntKeys.billingCredit: false,
  RetailEntKeys.catalogProducts: false,
  RetailEntKeys.catalogCategories: false,
  RetailEntKeys.catalogVariants: false,
  RetailEntKeys.inventoryStockTake: false,
  RetailEntKeys.purchaseReturns: false,
  RetailEntKeys.purchaseDamaged: false,

  // Per-report keys
  RetailEntKeys.reportsDailySales: false,
  RetailEntKeys.reportsMonthlySales: false,
  RetailEntKeys.reportsSaleByProduct: false,
  RetailEntKeys.reportsSaleByVariant: false,
  RetailEntKeys.reportsSaleByCategory: false,
  RetailEntKeys.reportsTopSelling: false,
  RetailEntKeys.reportsProfit: false,
  RetailEntKeys.reportsGst: false,
  RetailEntKeys.reportsDiscounts: false,
  RetailEntKeys.reportsQuickItems: false,
  RetailEntKeys.reportsLowStock: false,
  RetailEntKeys.reportsStockAdjustment: false,
  RetailEntKeys.reportsPurchaseSummary: false,
  RetailEntKeys.reportsSupplierPurchase: false,
  RetailEntKeys.reportsPoStatus: false,
  RetailEntKeys.reportsGrn: false,
  RetailEntKeys.reportsDamagedItems: false,
  RetailEntKeys.reportsPurchaseReturn: false,
  RetailEntKeys.reportsCashDrawerHistory: false,
  RetailEntKeys.reportsEodHistory: false,
  RetailEntKeys.reportsAttendance: false,
  RetailEntKeys.reportsShift: false,
  RetailEntKeys.reportsStaffPerformance: false,

  // Actions
  RetailEntKeys.billingInvoicePrint: true, // footer shown unless admin hides it
  RetailEntKeys.catalogProductsAdd: false,
  RetailEntKeys.catalogProductsEdit: false,
  RetailEntKeys.catalogProductsDelete: false,
  RetailEntKeys.catalogCategoriesAdd: false,
  RetailEntKeys.catalogCategoriesEdit: false,
  RetailEntKeys.catalogCategoriesDelete: false,
  RetailEntKeys.catalogVariantsAdd: false,
  RetailEntKeys.catalogVariantsEdit: false,
  RetailEntKeys.catalogVariantsDelete: false,
  RetailEntKeys.suppliersAdd: false,
  RetailEntKeys.suppliersEdit: false,
  RetailEntKeys.suppliersDelete: false,
  RetailEntKeys.purchaseCreate: false,
  RetailEntKeys.purchaseReceive: false,

  // Limits (0 = unlimited)
  RetailEntKeys.billingPerDayMax: 0,
  RetailEntKeys.catalogProductsMax: 0,
  RetailEntKeys.customersMax: 0,
  RetailEntKeys.usersMax: 2,
  RetailEntKeys.suppliersMax: 0,

  // Data scopes
  RetailEntKeys.reportsHistoryLimitDays: 'all',
};
