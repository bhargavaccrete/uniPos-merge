-- =============================================================================
-- Migration: licensing catalog — FULL (catalog refactor + planentitlement backfill)
-- File:      migration_2026_06_29_licensing_catalog_full.sql
-- Target:    featuredefinition + planentitlement   (see FEATURE_CATALOG.md)
-- Source of truth: the Flutter application (repository-wide audit, 2026-06-29)
-- =============================================================================
--
-- This is the SINGLE, self-contained migration. It does everything in ONE
-- transaction (all INSERT/UPDATE, no DDL) so it is atomic — any failure rolls
-- the whole thing back. Run this one file; you do not need the split files.
--
-- ARCHITECTURE (no duplicate responsibilities):
--   manage_menu = canonical home for ALL menu management
--                 (items, categories, variants, choices, extras + add/edit/delete
--                  + the menu-item count cap).
--   inventory   = STOCK operations ONLY (stock adjustment, movement, low-stock).
--   reports     = one entry per report.
--   DAY LIFECYCLE: Start Day -> Billing -> Cash Drawer -> End Day. startday &
--                  endofday are ALWAYS-ON (not gated). cashdrawer is optional but
--                  REQUIRES billing. shifts REQUIRE billing. (See Section 1 + report.)
--
-- featurekey is immutable + UNIQUE, so moving menu mgmt out of inventory =
-- DEPRECATE old keys (isdeleted=1/status=3; never hard-delete) + use manage_menu.*.
-- Section 5 then copies any existing plan grants from the old inventory.* keys to
-- the new manage_menu.* keys so live licenses keep identical access.
--
-- SAFETY: idempotent (ON CONFLICT DO NOTHING; guarded UPDATEs; NOT EXISTS on
-- backfill). featureid omitted (SERIAL). Parent ids resolved by featurekey lookup.
--
-- SECTIONS:
--   1) Missing licensable features                 (10 inserts; endofday dropped — always-on)
--   2) manage_menu canonical menu tree             (1 revive + 21 inserts)
--   3) inventory refocus: clarify scope + deprecate menu sub-tree (7 updates)
--   4) Reports: one entry per report               (21 inserts)
--   5) planentitlement backfill inventory.* -> manage_menu.*  (back-compat)
--
-- ⚠ planentitlement SCHEMA ASSUMPTION (Section 5): planentitlement(planid,
--   featureid, value) unique on (planid, featureid). If your columns differ
--   (plan_id/feature_id) or there are extra NOT NULL columns, adjust Section 5's
--   INSERT list. Section 5 is a no-op on a greenfield DB (no existing grants).
-- =============================================================================

BEGIN;

-- #############################################################################
-- SECTION 1 — MISSING LICENSABLE FEATURES (11)
-- #############################################################################

-- DAY-LIFECYCLE DECISION (Start Day -> Billing -> Cash Drawer -> End Day):
--   * startday & endofday are ALWAYS AVAILABLE (data integrity / no lockout) and
--     are therefore NOT licensable catalog keys:
--       - startday: the day auto-starts on the first bill; no key is created.
--       - endofday: the in-app End Day route is ungated BY DESIGN (closing the day
--         must never be blockable, or an open day / pending EOD deadlocks). So
--         `endofday` is intentionally NOT inserted as a feature key.
--   * billing is the single gate for the transactional workflow (invoicing + the
--     day lifecycle entry). Granting billing implies start + close are available.
--   * cashdrawer is an OPTIONAL companion to billing (billing works without it;
--     see report). cashdrawer & shifts REQUIRE billing — never grant them alone.
INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
VALUES
    (NULL, 'expenses',   'expenses',   'Expenses',    'Expense tracking with categories.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2,  7, 0, now()),
    (NULL, 'cashdrawer', 'cashdrawer', 'Cash Drawer', 'Cash management (opening balance, cash in/out, handover). Optional companion to billing; requires billing.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2,  8, 0, now()),
    (NULL, 'attendance', 'attendance', 'Attendance',  'Staff clock-in / clock-out and attendance reporting.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2, 10, 0, now()),
    (NULL, 'shifts',     'shifts',     'Shifts',      'Staff sales shifts with per-shift totals.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2, 11, 0, now()),
    (NULL, 'loyalty',    'loyalty',    'Loyalty',     'Customer loyalty points: earn, redeem, refund-restore.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2, 12, 0, now()),
    (NULL, 'kds',        'kds',        'Kitchen Display (KDS)', 'Embedded KDS server: order feed and KOT status sync.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2, 13, 0, now()),
    (NULL, 'captain',    'captain',    'Captain App',  'Embedded captain (waiter) ordering API server.',
     1, 1, 'false', NULL, NULL, NULL, NULL, 2, 14, 0, now())
ON CONFLICT (featurekey) DO NOTHING;

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT p.featureid, 'tables', 'billing.tables', 'Dine-in Tables',
       'Dine-in table management and table-to-order linking.',
       2, 1, 'false', NULL, NULL, NULL, NULL, 2, 3, 0, now()
FROM featuredefinition p
WHERE p.featurekey = 'billing' AND p.isdeleted = 0
ON CONFLICT (featurekey) DO NOTHING;

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT p.featureid, v.code, v.featurekey, v.name, v.description,
       3, 1, 'false', NULL, NULL, NULL, NULL, 2, v.sortorder, 0, now()
FROM (
    VALUES
        ('void',     'billing.invoice.void',     'Void Invoice',   'Void a completed order (audited).',      5),
        ('discount', 'billing.invoice.discount', 'Apply Discount', 'Apply order/item discounts at billing.', 6)
) AS v(code, featurekey, name, description, sortorder)
CROSS JOIN featuredefinition p
WHERE p.featurekey = 'billing.invoice' AND p.isdeleted = 0
ON CONFLICT (featurekey) DO NOTHING;


-- #############################################################################
-- SECTION 2 — manage_menu = CANONICAL MENU MANAGEMENT
-- #############################################################################

UPDATE featuredefinition
SET isdeleted = 0, status = 2, sortorder = 15,
    name = 'Manage Menu',
    description = 'Canonical menu management (items, categories, variants, choices, extras).',
    updatedat = now()
WHERE featurekey = 'manage_menu';

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT p.featureid, v.code, v.featurekey, v.name, v.description,
       2, 1, 'false', NULL, NULL, NULL, NULL, 2, v.sortorder, 0, now()
FROM (
    VALUES
        ('items',      'manage_menu.items',      'Items',      'Menu items management.',            1),
        ('categories', 'manage_menu.categories', 'Categories', 'Menu categories management.',       2),
        ('variants',   'manage_menu.variants',   'Variants',   'Item variants (sizes/options).',    3),
        ('choices',    'manage_menu.choices',    'Choices',    'Choice groups and choice options.', 4),
        ('extras',     'manage_menu.extras',     'Extras',     'Extras / add-on toppings.',         5)
) AS v(code, featurekey, name, description, sortorder)
CROSS JOIN featuredefinition p
WHERE p.featurekey = 'manage_menu' AND p.isdeleted = 0
ON CONFLICT (featurekey) DO NOTHING;

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT s.featureid, a.code, s.featurekey || '.' || a.code,
       a.name || ' ' || s.name, a.name || ' ' || s.name || '.',
       3, 1, 'false', NULL, NULL, NULL, NULL, 2, a.sortorder, 0, now()
FROM featuredefinition s
CROSS JOIN (
    VALUES ('add', 'Add', 1), ('edit', 'Edit', 2), ('delete', 'Delete', 3)
) AS a(code, name, sortorder)
WHERE s.isdeleted = 0 AND s.featuretype = 2
  AND s.parentid = (SELECT featureid FROM featuredefinition
                    WHERE featurekey = 'manage_menu' AND isdeleted = 0)
ON CONFLICT (featurekey) DO NOTHING;

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT p.featureid, 'max', 'manage_menu.items.max', 'Max Items',
       'Maximum number of menu items.',
       4, 2, '0', 0, 100000, NULL, 'items', 2, 4, 0, now()
FROM featuredefinition p
WHERE p.featurekey = 'manage_menu.items' AND p.isdeleted = 0
ON CONFLICT (featurekey) DO NOTHING;


-- #############################################################################
-- SECTION 3 — inventory REFOCUSED ON STOCK ONLY
-- `inventory` stays an atomic module: a single on/off key covering stock tracking,
-- adjustments, movement history and low-stock (these are NOT separately licensable
-- and are not individually gated in the app). Only the duplicated menu sub-tree is
-- removed here.
-- #############################################################################

UPDATE featuredefinition
SET description = 'Stock operations only — stock tracking, adjustments, movement history, low-stock. (Menu management lives under manage_menu.)',
    updatedat = now()
WHERE featurekey = 'inventory';

-- Deprecate the duplicated inventory menu sub-tree (now owned by manage_menu).
UPDATE featuredefinition
SET isdeleted = 1, status = 3, updatedat = now()
WHERE featurekey IN (
        'inventory.items',
        'inventory.items.add',
        'inventory.items.edit',
        'inventory.items.delete',
        'inventory.items.export',   -- never implemented; no manage_menu replacement
        'inventory.items.max',      -- replaced by manage_menu.items.max
        'inventory.categories'
      )
  AND isdeleted = 0;


-- #############################################################################
-- SECTION 4 — REPORTS: ONE ENTRY PER REPORT (21)
-- #############################################################################

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT p.featureid, v.code, v.featurekey, v.name, v.description,
       2, 1, 'false', NULL, NULL, NULL, NULL, 2, v.sortorder, 0, now()
FROM (
    VALUES
        ('total_sales', 'reports.sales.total_sales', 'Total Sales',       'Total sales report.',         5),
        ('by_item',     'reports.sales.by_item',     'Sales by Item',     'Item-wise sales report.',     6),
        ('by_category', 'reports.sales.by_category', 'Sales by Category', 'Category-wise sales report.', 7)
) AS v(code, featurekey, name, description, sortorder)
CROSS JOIN featuredefinition p
WHERE p.featurekey = 'reports.sales' AND p.isdeleted = 0
ON CONFLICT (featurekey) DO NOTHING;

INSERT INTO featuredefinition
    (parentid, code, featurekey, name, description,
     featuretype, valuetype, defaultvalue, minvalue, maxvalue, valueoptions, unit,
     status, sortorder, isdeleted, createdat)
SELECT p.featureid, v.code, v.featurekey, v.name, v.description,
       2, 1, 'false', NULL, NULL, NULL, NULL, 2, v.sortorder, 0, now()
FROM (
    VALUES
        ('daily_closing',         'reports.daily_closing',         'Daily Closing Report',     'Daily closing summary.',                                          3),
        ('customer_list',         'reports.customer_list',         'Customer List',            'Customers with orders/spend.',                                    4),
        ('customer_revenue',      'reports.customer_revenue',      'Customer List by Revenue', 'Customers ranked by revenue.',                                    5),
        ('comparison_week',       'reports.comparison_week',       'Comparison by Week',       'This week vs previous week.',                                     6),
        ('comparison_month',      'reports.comparison_month',      'Comparison by Month',      'This month vs previous month.',                                   7),
        ('comparison_year',       'reports.comparison_year',       'Comparison by Year',       'This year vs previous year.',                                     8),
        ('comparison_product',    'reports.comparison_product',    'Comparison by Product',    'Per-product period comparison.',                                  9),
        ('refund_details',        'reports.refund_details',        'Refund Details',           'Refunded orders detail.',                                        10),
        ('discount_orders',       'reports.discount_orders',       'Discount Orders',          'Discounted orders detail.',                                      11),
        ('void_orders',           'reports.void_orders',           'Void Orders',              'Voided orders detail.',                                          12),
        ('item_cancellation',     'reports.item_cancellation',     'Item Cancellation',        'Cancelled KOT items + reasons.',                                 13),
        ('pos_end_day',           'reports.pos_end_day',           'POS End Day',              'EOD balances per session.',                                      14),
        ('expense',               'reports.expense',               'Expense Report',           'Expenses by category/period.',                                   15),
        ('shift',                 'reports.shift',                 'Shift Report',             'Per-shift sales/expense/net.',                                   16),
        ('staff_performance',     'reports.staff_performance',     'Staff Performance',        'Per-staff KPIs and ranking.',                                    17),
        ('attendance',            'reports.attendance',            'Attendance Report',        'Monthly staff attendance.',                                      18),
        ('cash_drawer_history',   'reports.cash_drawer_history',   'Cash Drawer History',      'Cash movements running balance.',                                19),
        ('performance_statistics','reports.performance_statistics','Performance Statistics',   'Database record counts, box sizes and performance diagnostics.', 20)
) AS v(code, featurekey, name, description, sortorder)
CROSS JOIN featuredefinition p
WHERE p.featurekey = 'reports' AND p.isdeleted = 0
ON CONFLICT (featurekey) DO NOTHING;


-- #############################################################################
-- SECTION 5 — BACK-COMPAT: planentitlement inventory.* -> manage_menu.*
-- Copies each plan's existing grant from the deprecated menu keys to the new
-- canonical keys (no-op on a greenfield DB). Deprecated rows still exist with
-- their featureid, so the old-key join resolves.
-- #############################################################################

INSERT INTO planentitlement (planid, featureid, value)
SELECT pe.planid, newf.featureid, pe.value
FROM planentitlement pe
JOIN featuredefinition oldf ON oldf.featureid = pe.featureid
JOIN (
    VALUES
        ('inventory.items',        'manage_menu.items'),
        ('inventory.items.add',    'manage_menu.items.add'),
        ('inventory.items.edit',   'manage_menu.items.edit'),
        ('inventory.items.delete', 'manage_menu.items.delete'),
        ('inventory.items.max',    'manage_menu.items.max'),
        ('inventory.categories',   'manage_menu.categories')
) AS m(oldkey, newkey) ON m.oldkey = oldf.featurekey
JOIN featuredefinition newf ON newf.featurekey = m.newkey AND newf.isdeleted = 0
WHERE NOT EXISTS (
    SELECT 1 FROM planentitlement x
    WHERE x.planid = pe.planid AND x.featureid = newf.featureid
);

COMMIT;

-- =============================================================================
-- VERIFY (optional):
--   -- manage_menu canonical (expect 22 = 1 module + 5 subs + 15 actions + 1 max):
--   SELECT count(*) FROM featuredefinition
--   WHERE (featurekey='manage_menu' OR featurekey LIKE 'manage_menu.%') AND isdeleted=0;
--   -- inventory has NO menu sub-tree (expect 0):
--   SELECT count(*) FROM featuredefinition
--   WHERE (featurekey LIKE 'inventory.item%' OR featurekey='inventory.categories') AND isdeleted=0;
--   -- inventory is now an atomic module with no active children (expect 0):
--   SELECT count(*) FROM featuredefinition
--   WHERE parentid=(SELECT featureid FROM featuredefinition WHERE featurekey='inventory')
--     AND isdeleted=0;
--   -- reports submodules (expect 23 = 2 pre-existing + 21 new):
--   SELECT count(*) FROM featuredefinition
--   WHERE featurekey LIKE 'reports.%' AND featuretype=2 AND isdeleted=0;
-- =============================================================================
