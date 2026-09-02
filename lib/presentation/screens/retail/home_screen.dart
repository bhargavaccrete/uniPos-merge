import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/notification_bell.dart';
import 'package:billberrylite/presentation/screens/retail/expiry_alerts_screen.dart';
import 'package:billberrylite/domain/services/retail/expiry_alert_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/presentation/screens/retail/ex/posscreen.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/dashboard_menu_card.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';

import 'package:billberrylite/presentation/screens/retail/product_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/customer_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/reports_screen.dart';
import 'package:billberrylite/presentation/screens/retail/stock_alerts_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_order_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/damaged_goods_hub_screen.dart';
import 'package:billberrylite/presentation/screens/retail/sales_history_screen.dart';
import 'package:billberrylite/presentation/screens/retail/cash_drawer_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings_screen.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
    // The desktop sidebar's Customers stat reads customerStore.customers, and
    // CustomerStore is the one store here that does NOT hydrate in its
    // constructor — sale/product/stockAlert all call _init(). Without this the
    // stat sat at 0 until the user opened Customers and came back.
    customerStore.loadCustomers();
  }

  Future<void> _loadStoreName() async {
    final name = await StoreSettingsService().getStoreName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _storeName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final isDesktop = AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      // Desktop keeps its sidebar + content header; mobile/tablet use the
      // unified primary AppBar so retail matches the restaurant standard.
      appBar: isDesktop
          ? null
          : buildPrimaryAppBar(
              automaticallyImplyLeading: false,
              titleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 22 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _storeName.isNotEmpty ? _storeName : 'Bill Berry Lite',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              actions: _buildDashboardAppBarActions(context),
            ),
      body: SafeArea(
        child: isDesktop
            // No AppBar on this branch, so nothing sets the status-bar style —
            // declare it here (dark icons over the light background).
            ? AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark,
                child: _buildDesktopLayout(context),
              )
            : _buildCardGrid(context),
      ),
    );
  }

  // ==================== CARD GRID ====================
  /// One self-adapting grid for every breakpoint (2/3/4 columns via
  /// [AppResponsive.gridColumns]) — replaces the old three hardcoded layouts.
  /// Mirrors the restaurant dashboard: stretch the rows to fill the viewport
  /// when they fit, otherwise fall back to scrolling at the natural ratio.
  Widget _buildCardGrid(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final isDesktop = AppResponsive.isDesktop(context);

    final cards = _buildAllMenuCards(context);
    final columns = AppResponsive.gridColumns(context);
    final rows = (cards.length / columns).ceil();

    final spacing = isDesktop
        ? 20.0
        : isTablet
        ? 16.0
        : 12.0;
    final padH = isDesktop
        ? 28.0
        : isTablet
        ? 24.0
        : 16.0;
    final padTop = isDesktop
        ? 12.0
        : isTablet
        ? 8.0
        : 4.0;
    final pad = EdgeInsets.fromLTRB(padH, padTop, padH, padH);

    // The densest the cards should ever be.
    final naturalRatio = isDesktop
        ? 1.4
        : isTablet
        ? 1.3
        : 1.2;

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth - padH * 2;
        final availH = constraints.maxHeight - padTop - padH;
        final cellW = (availW - (columns - 1) * spacing) / columns;
        final naturalGridH =
            (cellW / naturalRatio) * rows + (rows - 1) * spacing;

        // Taller than the viewport (e.g. phone, many rows) → scroll.
        if (naturalGridH > availH) {
          return SingleChildScrollView(
            padding: pad,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: naturalRatio,
              children: cards,
            ),
          );
        }

        // Fits → stretch the rows to fill the leftover vertical space.
        final cellH = (availH - (rows - 1) * spacing) / rows;
        final fillRatio = (cellW / cellH).clamp(0.85, naturalRatio);
        return Padding(
          padding: pad,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: fillRatio,
            children: cards,
          ),
        );
      },
    );

    // Constrain OUTSIDE the LayoutBuilder — measuring the full screen width and
    // then discarding part of it would silently skew every cell.
    final maxWidth = AppResponsive.maxContentWidth(context);
    if (maxWidth == double.infinity) return grid;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: grid,
      ),
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        _buildDesktopSidebar(context),
        Expanded(
          child: Column(
            children: [
              _buildDesktopHeader(context),
              // Inside the content Expanded, so the 280px sidebar is already
              // excluded from the width the grid measures.
              Expanded(child: _buildCardGrid(context)),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HEADERS ====================
  /// Action widgets shown on the right of the dashboard AppBar (mobile/tablet).
  List<Widget> _buildDashboardAppBarActions(BuildContext context) {
    // Notification bell. White tint to read on the primary AppBar.
    return [
      NotificationBell(
        iconSize: AppResponsive.isMobile(context) ? 22 : 24,
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(
                      context,
                      mobile: 26.0,
                      tablet: 30.0,
                      desktop: 34.0,
                    ),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your business operations',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Desktop renders a sidebar + this header instead of an AppBar, so
          // the bell has to be placed here too — same control, primary tint
          // against the light header.
          const NotificationBell(tint: AppColors.primary, iconSize: 24),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ==================== DESKTOP SIDEBAR ====================
  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Brand section
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bill Berry Lite',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.headingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_storeName.isNotEmpty)
                        Text(
                          _storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Stats',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Observer(
                  builder: (context) {
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final todaySales = saleStore.sales.where((sale) {
                      try {
                        final saleDate = DateTime.parse(sale.createdAt);
                        return saleDate.isAfter(todayStart) ||
                            saleDate.isAtSameMomentAs(todayStart);
                      } catch (_) {
                        return false;
                      }
                    });
                    final total = todaySales.fold(
                      0.0,
                      (sum, sale) =>
                          sum + (sale.grandTotal ?? sale.totalAmount),
                    );
                    // MoneyScope so the figure re-renders if the store's
                    // currency or decimal precision is changed in Settings —
                    // this is the only money on the dashboard.
                    return MoneyScope(
                      child: _buildSidebarStat(
                        Icons.receipt_long_rounded,
                        'Today\'s Sales',
                        formatMoney(total),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Observer(
                  builder: (context) => _buildSidebarStat(
                    Icons.inventory_2_rounded,
                    'Products',
                    '${productStore.products.length}',
                  ),
                ),
                const SizedBox(height: 12),
                Observer(
                  builder: (context) => _buildSidebarStat(
                    Icons.people_rounded,
                    'Customers',
                    '${customerStore.customers.length}',
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Text(
                  '© 2025 Bill Berry Lite',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: AppResponsive.captionFontSize(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stat block for the primary-coloured sidebar. Deliberately keeps its
  /// white/white70 text and translucent fills hardcoded — the AppColors text
  /// and divider tokens are dark-on-light and would vanish or glare here.
  Widget _buildSidebarStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // ==================== MENU CARDS ====================
  /// Wrap a card's tap in its plan gate. DashboardMenuCard is deliberately
  /// presentational ("pass an already-guarded onTap"), so the guard lives here —
  /// the same place restaurant's welcome_Admin puts it. Show-and-block: the card
  /// stays visible and the upgrade sheet explains why.
  VoidCallback _gated(
    BuildContext context,
    String entitlementKey,
    String featureName,
    VoidCallback go,
  ) {
    return () {
      if (!PlanGuard.allowedOr(
        context,
        entitlementKey,
        featureName: featureName,
      )) {
        return;
      }
      go();
    };
  }

  /// Built fresh on every build so the reactive Stock Alerts tile keeps
  /// tracking its observables — never hoist or memoise this list.
  List<Widget> _buildAllMenuCards(BuildContext context) {
    return [
      DashboardMenuCard(
        icon: Icons.point_of_sale_rounded,
        title: 'Billing',
        color: Colors.blue,
        onTap: _gated(
          context,
          RetailEntKeys.billing,
          'Billing',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RetailPosScreen()),
          ),
        ),
      ),
      // One card for the whole catalog — products, their categories and the
      // attributes that build variants all live behind the Products hub.
      DashboardMenuCard(
        icon: Icons.inventory_2_rounded,
        title: 'Products',
        color: Colors.amber,
        onTap: _gated(
          context,
          RetailEntKeys.catalog,
          'Products',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductManagementScreen(),
            ),
          ),
        ),
      ),
      DashboardMenuCard(
        icon: Icons.people_rounded,
        title: 'Customers',
        color: Colors.indigo,
        onTap: _gated(
          context,
          RetailEntKeys.customers,
          'Customers',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerListScreen()),
          ),
        ),
      ),
      DashboardMenuCard(
        icon: Icons.storefront_rounded,
        title: 'Suppliers',
        color: Colors.brown,
        onTap: _gated(
          context,
          RetailEntKeys.suppliers,
          'Suppliers',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SupplierListScreen()),
          ),
        ),
      ),
      DashboardMenuCard(
        icon: Icons.assignment_rounded,
        title: 'Purchase Orders',
        color: Colors.cyan,
        onTap: _gated(
          context,
          RetailEntKeys.purchase,
          'Purchase Orders',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PurchaseOrderListScreen(),
            ),
          ),
        ),
      ),
      // Returns, claims and write-offs raised from damaged goods on a GRN.
      DashboardMenuCard(
        icon: Icons.assignment_return_rounded,
        title: 'Returns & Claims',
        color: Colors.deepPurple,
        onTap: _gated(
          context,
          RetailEntKeys.purchaseDamaged,
          'Returns & Claims',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DamagedGoodsHubScreen(),
            ),
          ),
        ),
      ),
      DashboardMenuCard(
        icon: Icons.receipt_long_rounded,
        title: 'Sales',
        color: Colors.green,
        onTap: _gated(
          context,
          RetailEntKeys.reports,
          'Sales',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
          ),
        ),
      ),
      DashboardMenuCard(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Cash Drawer',
        color: const Color(0xFF00897B),
        onTap: _gated(
          context,
          RetailEntKeys.cashDrawer,
          'Cash Drawer',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CashDrawerScreen()),
          ),
        ),
      ),
      DashboardMenuCard(
        icon: Icons.bar_chart_rounded,
        title: 'Reports',
        color: Colors.orange,
        onTap: _gated(
          context,
          RetailEntKeys.reports,
          'Reports',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportsScreen()),
          ),
        ),
      ),
      _buildStockAlertCard(context),
      _buildExpiryAlertCard(context),
      DashboardMenuCard(
        icon: Icons.settings_rounded,
        title: 'Settings',
        color: Colors.blueGrey,
        onTap: _gated(
          context,
          RetailEntKeys.settings,
          'Settings',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ),

      // DashboardMenuCard(
      //   icon: Icons.settings_rounded,
      //   title: 'ex pos',
      //   color: Colors.blueGrey,
      //   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RetailPosScreen())),
      // ),
    ];
  }

  /// Expiry counterpart to the stock-alert card.
  ///
  /// The count is DERIVED from live variant data inside the Observer rather
  /// than held in a store — there is no expiry alert state to keep in sync, so
  /// re-opening the app can never inflate the badge.
  Widget _buildExpiryAlertCard(BuildContext context) {
    return Observer(
      builder: (_) {
        // Touch the observables so MobX re-runs this when the catalogue changes.
        productStore.products.length;
        productStore.variants.length;

        final summary = ExpiryAlertService.getExpirySummary();
        final alertCount = summary['totalAlerts'] as int;
        final hasExpired = (summary['expiredCount'] as int) > 0;

        return DashboardMenuCard(
          icon: Icons.event_busy_rounded,
          title: 'Expiry Alerts',
          color: hasExpired ? AppColors.danger : Colors.deepOrange,
          badge: alertCount > 0
              ? DashboardCardBadge(
                  count: alertCount,
                  color: hasExpired
                      ? AppColors.danger
                      : const Color(0xFFFF9800),
                )
              : null,
          onTap: _gated(
            context,
            RetailEntKeys.inventory,
            'Expiry Alerts',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExpiryAlertsScreen(),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The whole card sits inside the Observer — the accent colour is reactive
  /// too, not just the badge count.
  Widget _buildStockAlertCard(BuildContext context) {
    return Observer(
      builder: (_) {
        final alertCount = stockAlertStore.totalAlerts;
        final hasCritical = stockAlertStore.hasCriticalAlerts;
        return DashboardMenuCard(
          icon: Icons.notifications_active_rounded,
          title: 'Stock Alerts',
          color: hasCritical ? AppColors.danger : Colors.deepOrange,
          badge: alertCount > 0
              ? DashboardCardBadge(
                  count: alertCount,
                  color: hasCritical
                      ? AppColors.danger
                      : const Color(0xFFFF9800),
                )
              : null,
          onTap: _gated(
            context,
            RetailEntKeys.inventory,
            'Stock Alerts',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StockAlertsScreen(),
              ),
            ),
          ),
        );
      },
    );
  }
}
