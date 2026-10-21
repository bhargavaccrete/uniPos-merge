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
import 'package:billberrylite/presentation/screens/retail/login_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/screens/common/staff/manage_staff_screen.dart';
import 'package:billberrylite/presentation/screens/common/attendance/staff_attendance_screen.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/core/plan/mode_keys.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_order_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/damaged_goods_hub_screen.dart';
import 'package:billberrylite/presentation/screens/retail/sales_history_screen.dart';
import 'package:billberrylite/presentation/screens/retail/cash_drawer_screen.dart';
import 'package:billberrylite/presentation/screens/retail/settings_screen.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';

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
    _startShiftIfNeeded();
  }

  /// Open (or restore) this staff member's shift on dashboard load.
  ///
  /// Ported verbatim from restaurant's `welcome_Admin._startShiftIfNeeded` —
  /// same order of checks, same hot-restart restore, same session persistence.
  /// The one difference is `ModeKeys.shifts`, which resolves to
  /// `retail.shifts` here and `shifts` there.
  Future<void> _startShiftIfNeeded() async {
    // A stale session must freeze staff hours at the last real business
    // activity BEFORE anything else, or completing EOD later would extend
    // them — this is what stops a shift reading as 67 hours.
    if (await DayManagementService.isEodStrictlyPending()) {
      await shiftStore.freezeStaleShiftsAndAttendance();
      return;
    }

    // Shifts are a licensed module — skip auto-start when the plan omits it.
    if (!PlanEnforce.allows(ModeKeys.shifts)) return;

    final staffId = RestaurantSession.isAdmin
        ? 'admin'
        : (RestaurantSession.staffName ?? 'staff');
    final staffName =
        RestaurantSession.staffName ??
        (RestaurantSession.isAdmin ? 'Admin' : 'Staff');

    // Restore from Hive in case of hot-restart, so we never open a second
    // shift on top of one that is already running.
    await shiftStore.loadActiveShiftForStaff(staffId);
    if (shiftStore.hasOpenShift) {
      await RestaurantSession.saveShiftSession(shiftStore.activeShift!.id);
      return;
    }

    final ok = await shiftStore.startShift(
      staffId: staffId,
      staffName: staffName,
    );
    if (ok && shiftStore.activeShift != null && mounted) {
      await RestaurantSession.saveShiftSession(shiftStore.activeShift!.id);
      NotificationService.instance.showSuccess('Shift started');
    }
  }

  Future<void> _loadStoreName() async {
    final name = await StoreSettingsService().getStoreName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _storeName = name);
    }
  }

  /// Today's sale rows — the single source all three Quick Stats read, so the
  /// figures can never disagree about where "today" starts.
  ///
  /// Return rows are INCLUDED, and the two kinds of field behave differently.
  /// A return stores its MONEY negated (`return_service.dart`), so summing
  /// nets refunds out on its own. It stores its COUNTS positive, so anything
  /// counting units or customers has to exclude returns by hand.
  ///
  /// Called inside each Observer, not hoisted — the `saleStore.sales` read has
  /// to happen during the builder for MobX to track it.
  Iterable<SaleModel> _todaySales() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return saleStore.sales.where((sale) {
      try {
        return !DateTime.parse(sale.createdAt).isBefore(todayStart);
      } catch (_) {
        return false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      fontSize: AppResponsive.headingFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  // Secondary line under the title, so it snaps DOWN to
                  // smallFontSize rather than up — see the snapping table.
                  Text(
                    _storeName.isNotEmpty ? _storeName : 'Bill Berry Lite',
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

  // ==================== SHARED GUTTER ====================
  /// Horizontal gutter used by BOTH the desktop header and the card grid.
  ///
  /// These must stay equal. The header background is full-bleed while the
  /// grid is capped at [AppResponsive.maxContentWidth] and centred, so if the
  /// two gutters disagree the "Dashboard" title and the first card start at
  /// different x positions — a 40 vs 28 mismatch put them ~108px apart at
  /// 1920px.
  double _gutter(BuildContext context) => AppResponsive.padding(context).left;

  // ==================== GRID COLUMNS ====================
  /// Target width of one dashboard card. Column count is derived from this, so
  /// a card stays roughly the same size at every width instead of stretching.
  ///
  /// 155 is not arbitrary: it keeps a 1028px window on its existing 4 x 160
  /// layout, and stops the 1024px breakpoint dipping to 3 columns as the
  /// sidebar appears.
  static const double _targetCardWidth = 155;
  static const int _minColumns = 2;
  static const int _maxColumns = 6;

  /// How many cards fit across [availW] at about [_targetCardWidth] each.
  ///
  /// Takes the MEASURED pane width, never `AppResponsive.gridColumns` — that
  /// reads `MediaQuery` (the whole screen), but this grid lives in an
  /// `Expanded` beside a fixed 280px sidebar, so it was 280px optimistic on
  /// desktop. The symptom: a 768px tablet got 232px cards while a *wider*
  /// 1028px desktop got 160px ones, and a 1440px laptop stretched them to
  /// 263px around an icon and label that never grew.
  int _columnsFor(double availW, double spacing) {
    final fit = ((availW + spacing) / (_targetCardWidth + spacing)).floor();
    return fit.clamp(_minColumns, _maxColumns);
  }

  // ==================== CARD GRID ====================
  /// One self-adapting grid for every breakpoint — replaces the old three
  /// hardcoded layouts. Columns come from [_columnsFor] against the measured
  /// pane width, so card size stays flat as the window grows.
  /// Mirrors the restaurant dashboard: stretch the rows to fill the viewport
  /// when they fit, otherwise fall back to scrolling at the natural ratio.
  Widget _buildCardGrid(BuildContext context) {
    final cards = _buildAllMenuCards(context);

    final spacing = AppResponsive.gridSpacing(context);
    final padH = _gutter(context);
    // Content sets its own top padding under the flat AppBar; 4px left the
    // first card row jammed against it.
    final padTop = AppResponsive.mediumSpacing(context);
    final pad = EdgeInsets.fromLTRB(padH, padTop, padH, padH);

    // The densest the cards should ever be. A raw getValue is correct here:
    // an aspect ratio is not a step on any AppResponsive ladder.
    final naturalRatio = AppResponsive.getValue(
      context,
      mobile: 1.2,
      tablet: 1.3,
      desktop: 1.4,
    );

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth - padH * 2;
        final availH = constraints.maxHeight - padTop - padH;

        // Resolved HERE, from the measured pane — not hoisted out of the
        // LayoutBuilder, which is what made this read the screen instead.
        final columns = _columnsFor(availW, spacing);
        final rows = (cards.length / columns).ceil();

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
      NotificationBell(iconSize: AppResponsive.iconSize(context)),
      SizedBox(width: AppResponsive.smallSpacing(context)),
    ];
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      // Vertical padding only. The white background and its shadow stay
      // full-bleed; the CONTENT is capped and gutter-aligned with the card
      // grid below, so the title sits directly above the first card.
      padding: EdgeInsets.symmetric(
        vertical: AppResponsive.largeSpacing(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        // No-op today (the parent Column passes unbounded height so Align
        // shrink-wraps), but explicit so this band can never expand to fill if
        // the parent ever bounds it — see constrainedContent's doc.
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _gutter(context)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.poppins(
                        // Above the top of the font ladder (20), so a raw
                        // getValue is the sanctioned form here.
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
              // Desktop renders a sidebar + this header instead of an AppBar,
              // so the bell has to be placed here too — same control, primary
              // tint against the light header.
              NotificationBell(
                tint: AppColors.primary,
                iconSize: AppResponsive.iconSize(context),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DESKTOP SIDEBAR ====================
  /// Sidebar width, proportional and clamped.
  ///
  /// A frozen 280 was 27% of a 1024px screen but only 11% of a 2560px one.
  /// A breakpoint ladder cannot fix that — desktop is a RAY (1024 → ∞), so
  /// every width above 1024 would read the same value. Scale against the real
  /// width instead and clamp both ends.
  ///
  /// This feeds the grid: a narrower sidebar widens the pane, so [_columnsFor]
  /// reflows with it.
  /// Floor is 280 (the old fixed value) on purpose: it keeps every window up
  /// to ~1555px pixel-identical to the layout already signed off, so this only
  /// ever ADDS width on large monitors.
  double _sidebarWidth(BuildContext context) =>
      (AppResponsive.screenWidth(context) * 0.18).clamp(280.0, 340.0);

  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: _sidebarWidth(context),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            // Directional, not dimensional — a 2px sideways shadow does not
            // scale with the breakpoint.
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Brand section
          Container(
            padding: AppResponsive.cardPadding(context),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: AppColors.primary,
                    size: AppResponsive.largeIconSize(context),
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
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

          // Quick Stats.
          //
          // Expanded + scroll, NOT a bare `Spacer`: desktop guarantees WIDTH
          // (>=1024) but says nothing about height, and a window resized
          // shorter than ~500px overflowed this Column. Expanded still pushes
          // the footer to the bottom whenever there is surplus height, so the
          // normal-size layout is unchanged.
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: AppResponsive.padding(context),
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
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    Observer(
                      builder: (context) {
                        // Returns self-net here: their money is stored negated.
                        final total = _todaySales().fold<double>(
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
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    Observer(
                      builder: (context) {
                        // Returned units are subtracted BY HAND. Unlike the
                        // money total above, totalItems stays positive on a
                        // return row, so a blind sum counts a refund as a sale.
                        final sold = _todaySales().fold<double>(
                          0.0,
                          (sum, sale) => (sale.isReturn ?? false)
                              ? sum - sale.totalItems
                              : sum + sale.totalItems,
                        );
                        // formatQty, not toString — a loose-goods variant sells
                        // in fractional quantities.
                        return _buildSidebarStat(
                          Icons.inventory_2_rounded,
                          'Items Sold',
                          formatQty(sold),
                        );
                      },
                    ),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    Observer(
                      builder: (context) {
                        // Distinct NAMED customers: walk-ins carry no
                        // customerId, and a return-only visit is not a sale.
                        final served = <String>{};
                        for (final sale in _todaySales()) {
                          if (sale.isReturn ?? false) continue;
                          final id = sale.customerId;
                          if (id != null && id.isNotEmpty) served.add(id);
                        }
                        return _buildSidebarStat(
                          Icons.people_rounded,
                          'Customers Served',
                          '${served.length}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: AppResponsive.padding(context),
            child: Column(
              children: [
                const Divider(color: Colors.white24, height: 1),
                SizedBox(height: AppResponsive.largeSpacing(context)),
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
      padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: AppResponsive.smallIconSize(context),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
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

  /// Ask, then end the session and return to the login screen.
  ///
  /// `authService.logout()` clears RestaurantSession too, which auto-closes an
  /// open shift and clocks the staff member out — see the callbacks wired in
  /// `service_locator`'s retail branch.
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      accent: AppColors.danger,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Built fresh on every build so the reactive Stock Alerts tile keeps
  /// tracking its observables — never hoist or memoise this list.
  ///
  /// **Role HIDES a card; plan entitlement does not.** A card the plan doesn't
  /// cover stays visible and shows the upgrade sheet on tap (`_gated`), because
  /// that is a "you could buy this" message. A card the role doesn't cover is
  /// removed outright — no upgrade would grant it. Same split restaurant's
  /// `welcome_Admin._getVisibleCards` uses, and the contract `PlanGuard`
  /// documents.
  ///
  /// This filter is not belt-and-braces: the dashboard pushes with
  /// `MaterialPageRoute`, so `RetailGuard` never runs for a card tap. For Cash
  /// Drawer, Settings and Products this is the ONLY gate on that path.
  ///
  /// Attendance and Settings carry no permission by design — any role may clock
  /// in/out, and the Settings hub holds Start Day, End of Day and Logout, which
  /// a cashier must reach.
  List<Widget> _buildAllMenuCards(BuildContext context) {
    return [
      if (RestaurantSession.canAccess('billing'))
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
      if (RestaurantSession.canAccess('catalog'))
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
      if (RestaurantSession.canAccess('customers'))
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
              MaterialPageRoute(
                builder: (context) => const CustomerListScreen(),
              ),
            ),
          ),
        ),
      if (RestaurantSession.canAccess('suppliers'))
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
              MaterialPageRoute(
                builder: (context) => const SupplierListScreen(),
              ),
            ),
          ),
        ),
      if (RestaurantSession.canAccess('purchase'))
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
      if (RestaurantSession.canAccess('purchase'))
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
      if (RestaurantSession.canAccess('billing'))
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
              MaterialPageRoute(
                builder: (context) => const SalesHistoryScreen(),
              ),
            ),
          ),
        ),
      if (RestaurantSession.canAccess('cashDrawer'))
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
      if (RestaurantSession.canAccess('reports'))
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
      if (RestaurantSession.canAccess('inventory'))
        _buildStockAlertCard(context),
      if (RestaurantSession.canAccess('inventory'))
        _buildExpiryAlertCard(context),
      if (RestaurantSession.canAccess('manageStaff'))
        DashboardMenuCard(
          icon: Icons.people_rounded,
          title: 'Manage Staff',
          color: Colors.teal,
          onTap: _gated(
            context,
            RetailEntKeys.users,
            'Manage Staff',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageStaffScreen(),
              ),
            ),
          ),
        ),
      DashboardMenuCard(
        icon: Icons.access_time_rounded,
        title: 'Attendance',
        color: Colors.deepPurple,
        onTap: _gated(
          context,
          RetailEntKeys.attendance,
          'Attendance',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StaffAttendanceScreen(),
            ),
          ),
        ),
      ),
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
      // Deliberately carries NO permission: every role must be able to end
      // their own session in one tap. It used to live inside Settings, whose
      // sensitive tiles are Manager-only — burying the only sign-out behind a
      // gated hub is how a cashier ends up stuck signed in.
      DashboardMenuCard(
        icon: Icons.logout_rounded,
        title: 'Logout',
        color: Colors.red,
        onTap: () => _confirmLogout(context),
      ),
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
