/// Retail entitlement catalog — the retail half of the plan vocabulary.
///
/// Kept **separate** from restaurant's `EntKeys` (`entitlement_keys.dart`) on purpose:
/// every key here is `retail.`-prefixed so retail and restaurant keys can never be
/// confused in code or collide inside the one signed manifest the backend sends.
///
/// These strings are the contract — they must match the server Feature Catalog
/// exactly. Read through the SAME engine as restaurant (`PlanEnforce` /
/// `Entitlements.instance`), which is key-agnostic. A key absent from a present
/// manifest falls back to [kRetailEntitlementDefaults] (merged into
/// `kEntitlementDefaults`).
class RetailEntKeys {
  RetailEntKeys._();

  // ── Modules ─────────────────────────────────────────────────────────────────
  static const billing = 'retail.billing';
  static const catalog = 'retail.catalog'; // product catalog (retail's "menu")
  static const customers = 'retail.customers';
  static const users = 'retail.users'; // staff
  static const attendance = 'retail.attendance'; // clock-in/out
  static const shifts = 'retail.shifts'; // staff shift lifecycle
  static const inventory = 'retail.inventory';
  static const inventoryStockTake = 'retail.inventory.stock_take';
  static const suppliers = 'retail.suppliers';
  static const purchase = 'retail.purchase'; // PO + GRN
  static const reports = 'retail.reports';
  static const settings = 'retail.settings';
  static const cashDrawer = 'retail.cashdrawer';
  static const dataBackup = 'retail.data_backup';
  static const loyalty = 'retail.loyalty';

  // ── Submodules ───────────────────────────────────────────────────────────────
  static const billingReturns = 'retail.billing.returns';
  static const billingCredit = 'retail.billing.credit'; // pay-later (retail only)
  // Parent of [billingInvoicePrint] only — no screen of its own.
  static const billingInvoice = 'retail.billing.invoice';
  static const catalogProducts = 'retail.catalog.products';
  static const catalogCategories = 'retail.catalog.categories';
  // Variant editors are dialogs inside Product Detail, not a route, so this
  // parent is checked alongside each variant action at the dialog itself.
  static const catalogVariants = 'retail.catalog.variants';
  static const purchaseReturns = 'retail.purchase.returns';
  static const purchaseDamaged = 'retail.purchase.damaged';

  // ── Reports — one key per report, flat under `retail.reports` ───────────────
  // Mirrors restaurant's flat `reports.*` family. Without these the whole
  // Reports hub is one all-or-nothing flag, so no plan can grant sales reports
  // while withholding profit or purchasing. Names follow the hub's tiles.
  static const reportsDailySales = 'retail.reports.daily_sales';
  static const reportsMonthlySales = 'retail.reports.monthly_sales';
  static const reportsSaleByProduct = 'retail.reports.sale_by_product';
  static const reportsSaleByVariant = 'retail.reports.sale_by_variant';
  static const reportsSaleByCategory = 'retail.reports.sale_by_category';
  static const reportsTopSelling = 'retail.reports.top_selling';
  static const reportsProfit = 'retail.reports.profit';
  static const reportsGst = 'retail.reports.gst';
  // Covers all THREE give-away mechanisms the Discounts Given report totals —
  // bill/line discounts, price overrides and loyalty redemption — not just the
  // one that lands in `SaleModel.discountAmount`.
  //
  // Minted rather than reusing a billing key because discounting is gated by
  // ROLE, not entitlement: `LineDiscountService.canDiscount` reads
  // `RestaurantSession.canAccess('billingDiscount')` and there is no
  // `billingDiscount` entitlement to reuse. No existing key owns "reporting
  // what was given away".
  static const reportsDiscounts = 'retail.reports.discounts';
  // Ad-hoc lines typed at the POS. Minted rather than reused because adding
  // a quick item is deliberately UNGATED at the till — there is no billing
  // key that owns it, so nothing exists to point the report at.
  static const reportsQuickItems = 'retail.reports.quick_items';
  static const reportsLowStock = 'retail.reports.low_stock';
  static const reportsStockAdjustment = 'retail.reports.stock_adjustment';
  // Purchasing side
  static const reportsPurchaseSummary = 'retail.reports.purchase_summary';
  static const reportsSupplierPurchase = 'retail.reports.supplier_purchase';
  // One key for all three PO-status tiles — they are named constructors of the
  // same screen (pending / partially received / completed).
  static const reportsPoStatus = 'retail.reports.po_status';
  static const reportsGrn = 'retail.reports.grn';
  static const reportsDamagedItems = 'retail.reports.damaged_items';
  static const reportsPurchaseReturn = 'retail.reports.purchase_return';
  // Cash / day close
  static const reportsCashDrawerHistory = 'retail.reports.cash_drawer_history';
  static const reportsEodHistory = 'retail.reports.eod_history';

  // Staff reports — mirror restaurant's `reports.attendance`,
  // `reports.shift` and `reports.staff_performance`.
  static const reportsAttendance = 'retail.reports.attendance';
  static const reportsShift = 'retail.reports.shift';
  static const reportsStaffPerformance =
      'retail.reports.staff_performance';
  // NOTE: the Credit Reports tile deliberately has no key of its own — it reads
  // [billingCredit], the same key its route guard uses. One responsibility, one key.
  // The Sales Refunds report tile follows the same rule and reads
  // [billingReturns] — the key that already owns the refund responsibility and
  // guards the write path in `sale_return_screen.dart`.

  // ── Actions ──────────────────────────────────────────────────────────────────
  // No invoice create/edit/export/void: retail has returns, not void, and sales
  // aren't edited after the fact — nothing would read those keys.
  // Admin-controlled "Powered by Bill Berry Lite" footer (default shown).
  static const billingInvoicePrint = 'retail.billing.invoice.print';

  // Product catalog actions (retail analog of manage_menu.items.*):
  static const catalogProductsAdd = 'retail.catalog.products.add';
  static const catalogProductsEdit = 'retail.catalog.products.edit';
  static const catalogProductsDelete = 'retail.catalog.products.delete';

  static const catalogCategoriesAdd = 'retail.catalog.categories.add';
  static const catalogCategoriesEdit = 'retail.catalog.categories.edit';
  static const catalogCategoriesDelete = 'retail.catalog.categories.delete';

  // Variant actions — retail's analog of restaurant's manage_menu.variants.*.
  // A retail product's variants carry the barcode, price and stock, so these
  // are edits to sellable units, not cosmetic options.
  static const catalogVariantsAdd = 'retail.catalog.variants.add';
  static const catalogVariantsEdit = 'retail.catalog.variants.edit';
  static const catalogVariantsDelete = 'retail.catalog.variants.delete';

  // Supplier actions:
  static const suppliersAdd = 'retail.suppliers.add';
  static const suppliersEdit = 'retail.suppliers.edit';
  static const suppliersDelete = 'retail.suppliers.delete';

  // Purchase actions (PO create + GRN receive):
  static const purchaseCreate = 'retail.purchase.create';
  static const purchaseReceive = 'retail.purchase.receive';

  // ── Limits (0/absent = unlimited) ────────────────────────────────────────────
  static const billingPerDayMax = 'retail.billing.per_day_max';
  static const catalogProductsMax = 'retail.catalog.products.max';
  static const customersMax = 'retail.customers.max';
  static const usersMax = 'retail.users.max';
  static const suppliersMax = 'retail.suppliers.max';

  // ── Data scopes ──────────────────────────────────────────────────────────────
  static const reportsHistoryLimitDays = 'retail.reports.history_limit_days';
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

  // Per-report keys — TRUE until the server catalog has them, for the same
  // reason as restaurant's purchasing reports: no manifest sends them yet, so
  // `false` would lock every report on a licensed shop. A manifest value
  // always wins, so once the admin adds these they govern with no code edit —
  // then flip these to `false` to mirror the server again.
  RetailEntKeys.reportsDailySales: true,
  RetailEntKeys.reportsMonthlySales: true,
  RetailEntKeys.reportsSaleByProduct: true,
  RetailEntKeys.reportsSaleByVariant: true,
  RetailEntKeys.reportsSaleByCategory: true,
  RetailEntKeys.reportsTopSelling: true,
  RetailEntKeys.reportsProfit: true,
  RetailEntKeys.reportsGst: true,
  RetailEntKeys.reportsDiscounts: true,
  RetailEntKeys.reportsQuickItems: true,
  RetailEntKeys.reportsLowStock: true,
  RetailEntKeys.reportsStockAdjustment: true,
  RetailEntKeys.reportsPurchaseSummary: true,
  RetailEntKeys.reportsSupplierPurchase: true,
  RetailEntKeys.reportsPoStatus: true,
  RetailEntKeys.reportsGrn: true,
  RetailEntKeys.reportsDamagedItems: true,
  RetailEntKeys.reportsPurchaseReturn: true,
  RetailEntKeys.reportsCashDrawerHistory: true,
  RetailEntKeys.reportsEodHistory: true,
  RetailEntKeys.reportsAttendance: true,
  RetailEntKeys.reportsShift: true,
  RetailEntKeys.reportsStaffPerformance: true,

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
