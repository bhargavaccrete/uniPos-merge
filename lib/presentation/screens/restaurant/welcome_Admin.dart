import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/notification_bell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/util/color.dart';
import '../../../core/routes/routes_name.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/plan/entitlement_keys.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../core/plan/plan_guard.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../domain/services/common/start_of_day_backup_prompt.dart';
import '../../../domain/services/restaurant/day_management_service.dart';
import '../../../domain/services/restaurant/stock_adjust_service.dart';
import '../../../domain/services/retail/store_settings_service.dart';
import '../../../domain/store/restaurant/license_store.dart';
import '../../../util/restaurant/restaurant_session.dart';
import '../../widget/componets/restaurant/componets/drawer.dart';
import '../../widget/componets/common/primary_app_bar.dart';
import '../../widget/componets/common/dashboard_menu_card.dart';
import '../../widget/restaurant/opening_balance_dialog.dart';
import '../../../util/common/app_responsive.dart';

class AdminWelcome extends StatefulWidget {
  const AdminWelcome({super.key});

  @override
  State<AdminWelcome> createState() => _AdminWelcomeState();
}

class _AdminWelcomeState extends State<AdminWelcome> {
  DateTime? _lastBackPress;
  String _storeName = '';
  bool _hasPendingEOD = false;
  bool _dayNotStarted = false; // day closed/not started → show a non-blocking banner
  bool _isEodStrictlyPending = false;
  int _openTableCount = 0; // active orders awaiting resolution (locked state)

  DateTime? _snoozeDayStartUntil;
  DateTime? _snoozeEodUntil;
  DateTime? _snoozeLicenseUntil;

  @override
  void initState() {
    super.initState();
    _loadSnoozeStates();
    _loadStoreName();

    // Load items so the Inventory tile's low-stock badge is accurate on open.
    itemStore.loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkDayStarted();
      await _startShiftIfNeeded();
      // Always check backup prompt — has its own date guard so it's idempotent.
      // Previously only ran inside _checkDayStarted → missed returning users.
      if (mounted) await StartOfDayBackupPrompt.show(context);
    });
  }

  Future<void> _loadStoreName() async {
    final name = await StoreSettingsService().getStoreName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _storeName = name);
    }
  }

  Future<void> _loadSnoozeStates() async {
    final prefs = await SharedPreferences.getInstance();
    final dayStartStr = prefs.getString('snooze_day_start_until');
    final eodStr = prefs.getString('snooze_eod_until');
    final licenseStr = prefs.getString('snooze_license_until');

    if (mounted) {
      setState(() {
        if (dayStartStr != null) {
          final parsed = DateTime.tryParse(dayStartStr);
          if (parsed != null && parsed.isAfter(DateTime.now())) {
            _snoozeDayStartUntil = parsed;
          }
        }
        if (eodStr != null) {
          final parsed = DateTime.tryParse(eodStr);
          if (parsed != null && parsed.isAfter(DateTime.now())) {
            _snoozeEodUntil = parsed;
          }
        }
        if (licenseStr != null) {
          final parsed = DateTime.tryParse(licenseStr);
          if (parsed != null && parsed.isAfter(DateTime.now())) {
            _snoozeLicenseUntil = parsed;
          }
        }
      });
    }
  }

  Future<void> _snoozeAlert(String key, Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(duration);
    await prefs.setString(key, until.toIso8601String());
    await _loadSnoozeStates();
  }

  Future<void> _checkDayStarted() async {
    final isStrictlyPending = await DayManagementService.isEodStrictlyPending();
    if (mounted) {
      setState(() => _isEodStrictlyPending = isStrictlyPending);
    }
    if (isStrictlyPending) {
      // Session went stale → freeze staff hours NOW (once) at the latest business
      // activity, so completing EOD later can never extend them. Idempotent and
      // exits fast when no shift is open.
      await shiftStore.freezeStaleShiftsAndAttendance();
      await orderStore.loadOrders();
      final count = orderStore.orders.where((o) {
        final s = o.status.toLowerCase();
        return s != 'void' &&
            s != 'voided' &&
            s != 'cancelled' &&
            s != 'completed';
      }).length;
      if (mounted) setState(() => _openTableCount = count);
      return;
    }

    // Check if there's a pending EOD from yesterday (midnight crossed without completing EOD)
    final pendingEOD = await DayManagementService.hasPendingEOD();
    if (pendingEOD && mounted) {
      setState(() => _hasPendingEOD = true);
      // Don't block — user can still access dashboard, orders, reports
      // Only new order placement is blocked (checked in menu.dart)
      return; // Skip opening balance dialog — day is technically still "started" from yesterday
    }

    if (mounted) setState(() => _hasPendingEOD = false);

    // Don't force the opening-balance dialog on open — just flag it so a small
    // non-blocking banner shows. The day starts when the first order is placed
    // (promptStartDay, called from the order screens), or via the banner button.
    final isDayStarted = await DayManagementService.isDayStarted();
    if (mounted) setState(() => _dayNotStarted = !isDayStarted);
  }

  Future<void> _startShiftIfNeeded() async {
    final isStrictlyPending = await DayManagementService.isEodStrictlyPending();
    if (isStrictlyPending) return;

    // Shifts are a licensed module — skip auto-start when the plan omits it.
    if (!PlanEnforce.allows(EntKeys.shifts)) return;
    final staffId = RestaurantSession.isAdmin
        ? 'admin'
        : (RestaurantSession.staffName ?? 'staff');
    final staffName = RestaurantSession.staffName ??
        (RestaurantSession.isAdmin ? 'Admin' : 'Staff');

    // Restore from Hive in case of hot-restart
    await shiftStore.loadActiveShiftForStaff(staffId);
    if (shiftStore.hasOpenShift) {
      // Re-persist the shift ID into session so currentShiftId is always set
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

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final isDesktop = AppResponsive.isDesktop(context);

    return PopScope(
      canPop: !_isEodStrictlyPending,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isEodStrictlyPending) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(

              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Press back again to exit',textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: _isEodStrictlyPending
          ? null
          : const Drawerr(showClearCart: false, showGridDuplicates: false, showChangePin: true, showHome: false),
      appBar: _isEodStrictlyPending
          ? null
          : buildPrimaryAppBar(
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
              _storeName.isNotEmpty ? _storeName : 'Restaurant',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          NotificationBell(iconSize: isTablet ? 24 : 22),
        ],
      ),
      body: Stack(children: [
          Column(
              children: [
          // License expiry warning banner (7 days or less remaining)
          Observer(
            builder: (_) {
              final licStore = locator<LicenseStore>();
              if (!licStore.isExpiringSoon || licStore.licenseInfo == null) return const SizedBox.shrink();
              final days = licStore.licenseInfo!.daysRemaining;
              
              // If not expired yet (days > 0), check if snoozed
              if (days > 0) {
                if (_snoozeLicenseUntil != null && _snoozeLicenseUntil!.isAfter(DateTime.now())) {
                  return const SizedBox.shrink();
                }
              }
              
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: days <= 0 ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: days <= 0 ? Colors.red.shade200 : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: days <= 0 ? Colors.red.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        days <= 0 ? Icons.error_outline_rounded : Icons.timer_outlined,
                        color: days <= 0 ? Colors.red.shade700 : Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            days <= 0
                                ? 'License expired!'
                                : days == 0
                                    ? 'License expires today!'
                                    : 'License expires in $days day${days == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: days <= 0 ? Colors.red.shade800 : Colors.orange.shade800),
                          ),
                          Text(
                            'Renew your license to avoid service interruption.',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: days <= 0 ? Colors.red.shade700 : Colors.orange.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, RouteNames.restaurantLicensing),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        backgroundColor: days <= 0 ? Colors.red.shade100 : Colors.orange.shade100,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Renew',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: days <= 0 ? Colors.red.shade800 : Colors.orange.shade800)),
                    ),
                    // If not expired, show the snooze button
                    if (days > 0) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.orange.shade800, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _snoozeAlert('snooze_license_until', const Duration(hours: 24)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Pending EOD warning banner
          if (_hasPendingEOD && (_snoozeEodUntil == null || _snoozeEodUntil!.isBefore(DateTime.now())))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End of Day Pending', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade800)),
                            Text('Previous day session is still open.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.red.shade800, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          await DayManagementService.snoozeEODAlert();
                          await _snoozeAlert('snooze_eod_until', const Duration(hours: 24));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await DayManagementService.snoozeEODAlert();
                            await _snoozeAlert('snooze_eod_until', const Duration(hours: 24));
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text('Continue Today', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red.shade700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await Navigator.pushNamed(context, RouteNames.restaurantEndDay);
                            if (mounted) _checkDayStarted();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text('Complete EOD', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Day-not-started banner (non-blocking). The day starts on the first
          // order; this just lets the user start it early if they want.
          if (_dayNotStarted && !_hasPendingEOD && (_snoozeDayStartUntil == null || _snoozeDayStartUntil!.isBefore(DateTime.now())))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Day not started',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('Starts automatically on your first order, or start it now.',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final started = await promptStartDay(context);
                      if (started && mounted) setState(() => _dayNotStarted = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text('Start Day',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.warning, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _snoozeAlert('snooze_day_start_until', const Duration(hours: 24)),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: Observer(
              builder: (_) => LayoutBuilder(
              builder: (context, constraints) {
                final cards = _getVisibleCards(context);
                // Single source of truth for column count (respects AppResponsive breakpoints).
                final columns = AppResponsive.gridColumns(context);
                final rows = (cards.length / columns).ceil();

                final spacing = isDesktop ? 20.0 : isTablet ? 16.0 : 12.0;
                final padH = isDesktop ? 28.0 : isTablet ? 24.0 : 16.0;
                final padTop = isDesktop ? 12.0 : isTablet ? 8.0 : 4.0;
                final pad = EdgeInsets.fromLTRB(padH, padTop, padH, padH);

                // The densest the cards should ever be (their current look).
                final naturalRatio = isDesktop ? 1.4 : isTablet ? 1.3 : 1.2;

                final availW = constraints.maxWidth - padH * 2;
                final availH = constraints.maxHeight - padTop - padH;
                final cellW = (availW - (columns - 1) * spacing) / columns;
                final naturalGridH =
                    (cellW / naturalRatio) * rows + (rows - 1) * spacing;

                final children = cards
                    .map((card) => DashboardMenuCard(
                          icon: card.icon,
                          title: card.title,
                          color: card.color,
                          compact: !isTablet,
                          onTap: () {
                            // Entitlement denied → show upgrade blocker
                            // instead of navigating.
                            if (card.entitlementKey != null &&
                                !PlanGuard.allowedOr(
                                    context, card.entitlementKey!,
                                    featureName: card.title)) {
                              return;
                            }
                            card.onTap();
                          },
                          // Low-stock count badge on the Inventory tile.
                          badge: card.title == 'Inventory'
                              ? Observer(
                                  builder: (_) {
                                    final count = StockAdjustService
                                        .lowStockEntries()
                                        .length;
                                    if (count == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return DashboardCardBadge(count: count);
                                  },
                                )
                              : null,
                        ))
                    .toList();

                // Content taller than the viewport (e.g. phone, many rows) → scroll.
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
                      children: children,
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
                    children: children,
                  ),
                );
              },
            ),
            ),
          ),
          ],
        ), // Column / body
        if (_isEodStrictlyPending)
          Positioned.fill(child: _buildLockedOverlay(context)),
      ]),
      ), // PopScope closing
    );
  }

  // Builds the list of dashboard cards visible to the current user.
  // Permissions are defined in RestaurantSession.canAccess() in restaurant_session.dart.
  // Admin and Manager see all cards. Other roles see only what canAccess() permits.
  List<_MenuCardData> _getVisibleCards(BuildContext context) {
    final all = [
      _MenuCardData('Start Order',   Icons.shopping_cart_rounded,       Colors.blue,           'startOrder',   () => Navigator.pushNamed(context, RouteNames.restaurantStartOrder), entitlementKey: EntKeys.billing),
      _MenuCardData('Manage Menu',   Icons.restaurant_menu_rounded,     Colors.purple,         'manageMenu',   () => Navigator.pushNamed(context, RouteNames.restaurantManageMenu), entitlementKey: EntKeys.manageMenu),
      _MenuCardData('Manage Staff',  Icons.people_rounded,              Colors.teal,           'manageStaff',  () => Navigator.pushNamed(context, RouteNames.restaurantStaff), entitlementKey: EntKeys.users),
      _MenuCardData('Customers',     Icons.person_outline_rounded,      Colors.indigo,         'customers',    () => Navigator.pushNamed(context, RouteNames.restaurantCustomers), entitlementKey: EntKeys.customers),
      _MenuCardData('Reports',       Icons.bar_chart_rounded,           Colors.orange,         'reports',      () => Navigator.pushNamed(context, RouteNames.restaurantReports), entitlementKey: EntKeys.reports),
      _MenuCardData('Tax Settings',  Icons.receipt_long_rounded,        Colors.green,          'taxSettings',  () => Navigator.pushNamed(context, RouteNames.restaurantTaxSettings), entitlementKey: EntKeys.settings),
      _MenuCardData('Expenses',      Icons.account_balance_wallet_rounded, Colors.red,         'expenses',     () => Navigator.pushNamed(context, RouteNames.restaurantExpenses), entitlementKey: EntKeys.expenses),
      _MenuCardData('Inventory',     Icons.inventory_2_rounded,         Colors.amber,          'inventory',    () => Navigator.pushNamed(context, RouteNames.restaurantInventory), entitlementKey: EntKeys.inventory),
      _MenuCardData('Settings',      Icons.settings_rounded,            Colors.blueGrey,       'settings',     () => Navigator.pushNamed(context, RouteNames.restaurantSettings), entitlementKey: EntKeys.settings),
      // Usage & Limits is read-only plan info — NOT a premium feature, so it
      // carries no entitlementKey (never plan-gated). 'settings' keeps it
      // admin/manager-only, matching its account-level nature.
      _MenuCardData('Usage & Limits', Icons.insights_rounded,           Colors.cyan,           'settings',     () => Navigator.pushNamed(context, RouteNames.restaurantUsageLimit)),
      // Day lifecycle follows billing: a day auto-opens on the first bill, so
      // Cash Drawer + End of Day must be available whenever billing is granted.
      _MenuCardData('Cash Drawer',   Icons.point_of_sale_rounded,       const Color(0xFF00897B), 'cashDrawer', () => Navigator.pushNamed(context, RouteNames.restaurantCashDrawer), entitlementKey: EntKeys.cashDrawer),
      _MenuCardData('End of Day',    Icons.nightlight_round,            Colors.deepOrange,     'cashDrawer',   () => Navigator.pushNamed(context, RouteNames.restaurantEndDay), entitlementKey: EntKeys.billing),
      _MenuCardData('Attendance',    Icons.access_time_rounded,         Colors.deepPurple,     'startOrder',   () => Navigator.pushNamed(context, RouteNames.restaurantAttendance), entitlementKey: EntKeys.attendance),
      _MenuCardData('Logout',        Icons.logout_rounded,              Colors.red.shade700,   'logout',       () => _showLogoutDialog(context)),
    ];
    // Role still hides; entitlement no longer hides — denied cards stay visible
    // and show the upgrade blocker on tap (see _buildMenuCard).
    return all
        .where((c) =>
            c.permission == 'logout' || RestaurantSession.canAccess(c.permission))
        .toList();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient Header ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade700,
                      Colors.red.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'End your current session',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Are you sure you want to logout? You will need to sign in again to continue.',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _clearLoginState();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  RouteNames.restaurantLogin,
                                  (route) => false,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Logout',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The lock as a DIALOG over the (blurred, non-interactive) dashboard.
  Widget _buildLockedOverlay(BuildContext context) {
    return GestureDetector(
      // Opaque → absorbs taps on the scrim so the blurred dashboard behind is
      // non-interactive (the card's own buttons still receive their taps).
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.black.withOpacity(0.30),
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildLockedDashboardLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedDashboardLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_clock_rounded,
                  size: 56,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'End of Day Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  "Your daily session has exceeded the maximum allowed duration. Complete End of Day to unlock — you'll be prompted to resolve any open orders.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Context card — so the lock screen isn't a bare wall.
              Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Session exceeded the maximum allowed duration.',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                    if (_openTableCount > 0) ...[
                      Divider(height: 18, color: Colors.orange.shade200),
                      Row(
                        children: [
                          Icon(Icons.table_restaurant_rounded,
                              size: 18, color: Colors.orange.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_openTableCount open table(s) still need settling.',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, RouteNames.restaurantEndDay);
                          _checkDayStarted();
                        },
                        icon: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'Complete End Day',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _clearLoginState();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              RouteNames.restaurantLogin,
                              (route) => false,
                            );
                          }
                        },
                        icon: Icon(Icons.logout_rounded, color: Colors.grey.shade700, size: 20),
                        label: Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restaurant_is_logged_in', false);
    await RestaurantSession.clearSession();
  }
}

/// Simple data holder for a dashboard menu card.
class _MenuCardData {
  final String title;
  final IconData icon;
  final Color color;
  final String permission;
  final VoidCallback onTap;

  /// Server entitlement key that gates this module. Null = not manifest-gated
  /// (role gating only). Cards are hidden only when a manifest is loaded AND it
  /// does not grant this key.
  final String? entitlementKey;

  const _MenuCardData(this.title, this.icon, this.color, this.permission,
      this.onTap,
      {this.entitlementKey});
}