/// Retail entitlement catalog — the retail half of the plan vocabulary.
///
/// Kept **separate** from restaurant's `EntKeys` (`entitlement_keys.dart`) on purpose:
/// every key here is `retail.`-prefixed so retail and restaurant keys can never be
/// confused in code or collide inside the one signed manifest the backend sends.
///
/// These strings are the contract — they must match the server Feature Catalog
/// exactly. Read through the SAME engine as restaurant (`PlanEnforce` /
/// `Entitlements.instance`), which is key-agnostic. Deny-by-default: a key absent
/// from a present manifest resolves to off/0 (no separate retail default map needed).
class RetailEntKeys {
  RetailEntKeys._();

  // ── Modules ─────────────────────────────────────────────────────────────────
  static const billing = 'retail.billing';
  static const catalog = 'retail.catalog'; // product catalog (retail's "menu")
  static const customers = 'retail.customers';
  static const users = 'retail.users'; // staff
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
  static const billingInvoice = 'retail.billing.invoice';
  static const catalogCategories = 'retail.catalog.categories';
  // No `retail.catalog.variants` submodule: retail's variant editors are dialogs
  // inside Product Detail, not a route of their own, so there is nothing for a
  // submodule flag to gate. The three variant ACTIONS below carry it instead.
  static const purchaseGrn = 'retail.purchase.grn';
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
  // NOTE: the Credit Reports tile deliberately has no key of its own — it reads
  // [billingCredit], the same key its route guard uses. One responsibility, one key.

  // ── Actions (add/edit/delete/create/void/print/export) ───────────────────────
  // Mirrors restaurant's action granularity (EntKeys). Bill actions:
  static const billingInvoiceCreate = 'retail.billing.invoice.create';
  static const billingInvoiceEdit = 'retail.billing.invoice.edit';
  static const billingInvoiceExport = 'retail.billing.invoice.export';
  static const billingInvoiceVoid = 'retail.billing.invoice.void';
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
  static const purchaseOrdersMax = 'retail.purchase.po.max';

  // ── Data scopes ──────────────────────────────────────────────────────────────
  static const reportsHistoryLimitDays = 'retail.reports.history_limit_days';
}
