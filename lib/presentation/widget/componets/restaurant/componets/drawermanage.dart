import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/restaurant/restaurant_auth_helper.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:unipos/util/restaurant/staticswitch.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import '../../../../screens/restaurant/welcome_Admin.dart';
import '../../../../screens/restaurant/AuthSelectionScreen.dart';
import '../../../../screens/restaurant/need help/needhelp.dart';
import '../../../../screens/retail/reports_screen.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

class DrawerManage extends StatelessWidget {
  final bool issync;
  final bool isDelete;
  final bool islogout;

  const DrawerManage({
    super.key,
    required this.issync,
    required this.isDelete,
    required this.islogout,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: isTablet ? 32 : 28,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'UniPOS',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 24 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Restaurant Management',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 12,
                  horizontal: isTablet ? 12 : 8,
                ),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigator.pushReplacement(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => AdminWelcome()),
                      //
                      // );
                      
                      Navigator.pushNamed(context, RouteNames.restaurantAdminWelcome);
                    },
                    isTablet: isTablet,
                  ),
                  if (RestaurantSession.canAccess('reports'))
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    onTap: () {

                      Navigator.pop(context);

                      Navigator.pushNamed(context, RouteNames.restaurantReports);


                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => ReportsScreen()),
                      //
                      //
                      // );
                    },
                    isTablet: isTablet,
                  ),
                  // End Shift — shown only when a shift is open AND handover is enabled
                  if (RestaurantSession.hasOpenShift && AppSettings.shiftHandover)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.lock_clock_rounded,
                      title: 'End Shift',
                      onTap: () {
                        Navigator.pop(context);
                        _showEndShiftDialog(context);
                      },
                      isTablet: isTablet,
                    ),
                  if (issync) ...[
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.sync_rounded,
                      title: 'Sync Data',
                      onTap: () {
                        Navigator.pop(context);
                        // Add sync functionality
                      },
                      isTablet: isTablet,
                    ),
                  ],
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    title: 'Need Help?',
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.pushNamed(context, RouteNames.restaurantNeedHelp);

                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => NeedhelpDrawer()),
                      // );
                    },
                    isTablet: isTablet,
                  ),

                  // Change PIN (staff only)
                  if (!RestaurantSession.isAdmin)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.lock_reset_rounded,
                      title: 'Change PIN',
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePinDialog(context);
                      },
                      isTablet: isTablet,
                    ),

                  // Divider before danger zone
                  if (isDelete || islogout) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.grey.shade200, thickness: 1),
                    ),
                  ],

                  // Danger zone (admin only)
                  if (isDelete && RestaurantSession.isAdmin)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete Account',
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteAccountDialog(context);
                      },
                      isTablet: isTablet,
                      isDanger: true,
                    ),
                  if (islogout)
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      onTap: () => _showLogoutDialog(context),
                      isTablet: isTablet,
                      isDanger: true,
                    ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
    bool isDanger = false,
  }) {
    final color = isDanger ? Colors.red : AppColors.primary;
    final bgColor = isDanger
        ? Colors.red.withValues(alpha: 0.1)
        : AppColors.primary.withValues(alpha: 0.1);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 14 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 22 : 20,
                    color: color,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w500,
                      color: isDanger ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Computes the expected cash in the drawer right now using the same formula
  /// as the Cash Drawer screen: opening + cashSales + cashIn − cashOut − cashExpenses
  Future<double> _loadExpectedBalance() async {
    final opening = await DayManagementService.getOpeningBalance();
    final dayStart = await DayManagementService.getDayStartTimestamp() ?? DateTime.now();

    await cashMovementStore.loadTodayMovements(dayStart);
    await pastOrderStore.loadPastOrders();
    await expenseStore.loadExpenses();

    double cashSales = 0;
    for (final o in pastOrderStore.pastOrders) {
      final status = (o.orderStatus ?? '').toUpperCase();
      if (status == 'VOIDED') continue;
      final isToday = o.orderAt?.isAfter(dayStart.subtract(const Duration(seconds: 1))) ?? false;
      if (!isToday) continue;
      final method = (o.paymentmode ?? '').toLowerCase().trim();
      if (method == 'cash') {
        cashSales += (o.totalPrice - (o.refundAmount ?? 0.0)).clamp(0.0, double.infinity);
      } else if (o.isSplitPayment == true) {
        for (final p in o.paymentList) {
          if ((p['method'] as String? ?? '').toLowerCase() == 'cash') {
            cashSales += (p['amount'] as num? ?? 0).toDouble();
          }
        }
      }
    }

    double cashExpenses = 0;
    for (final e in expenseStore.expenses) {
      final isC = (e.paymentType ?? '').toLowerCase().trim() == 'cash';
      final isToday = e.dateandTime.isAfter(dayStart.subtract(const Duration(seconds: 1)));
      if (isC && isToday) cashExpenses += e.amount;
    }

    return opening + cashSales + cashMovementStore.totalCashIn
        - cashMovementStore.totalCashOut - cashExpenses;
  }

  void _showEndShiftDialog(BuildContext context) {
    final shift = shiftStore.activeShift;
    if (shift == null) return;

    // Capture navigator before the drawer closes and its context becomes stale.
    // NavigatorState outlives the DrawerManage widget, so it's safe to use
    // across async gaps without a mounted check.
    final navigator = Navigator.of(context);

    final duration = DateTime.now().difference(shift.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    // Phase tracking
    bool isClosing = false;
    bool showCashCount = false;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSaving = false;
    // Loaded once when cash count begins
    Future<double>? balanceFuture;
    double? resolvedExpected;
    bool listenerAdded = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Register amount listener once so live diff updates on every keystroke
          if (!listenerAdded) {
            listenerAdded = true;
            amountCtrl.addListener(() => setS(() {}));
          }

          // ── Phase 2: Shift Cash Count ────────────────────────────────
          if (showCashCount) {
            final currency = CurrencyHelper.currentSymbol;
            final counted = double.tryParse(amountCtrl.text.trim());
            final diff = (counted != null && resolvedExpected != null)
                ? counted - resolvedExpected!
                : null;
            final isShort = diff != null && diff < -1.0;
            final isOver  = diff != null && diff > 1.0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: EdgeInsets.zero,
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Shift Cash Count',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('Count the cash in the drawer',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                        ]),
                      ),
                    ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Who is ending shift
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('Shift ended by: ${shift.staffName}',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      const SizedBox(height: 12),

                      // POS Expected balance
                      FutureBuilder<double>(
                        future: balanceFuture,
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Text('Calculating expected balance...',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade700)),
                              ]),
                            );
                          }
                          if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
                          final balance = snap.data!;
                          resolvedExpected = balance;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('POS expects in drawer',
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700)),
                                  Text('Based on sales, cash in/out',
                                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue.shade400)),
                                ]),
                                Text(
                                  '$currency ${balance.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.blue.shade800),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      Text('Cash you counted',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      AppTextField(
                        controller: amountCtrl,
                        hint: '0.00',
                        icon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      ),

                      // Live difference panel
                      if (diff != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isShort
                                ? Colors.red.shade50
                                : isOver
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isShort
                                  ? Colors.red.shade200
                                  : isOver
                                      ? Colors.orange.shade200
                                      : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isShort ? 'Short' : isOver ? 'Over' : 'Matched',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isShort
                                      ? Colors.red.shade700
                                      : isOver
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                ),
                              ),
                              Text(
                                isShort
                                    ? '-$currency ${diff.abs().toStringAsFixed(2)}'
                                    : isOver
                                        ? '+$currency ${diff.toStringAsFixed(2)}'
                                        : '$currency 0.00',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isShort
                                      ? Colors.red.shade700
                                      : isOver
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text('Note (optional)',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      AppTextField(
                        controller: noteCtrl,
                        hint: 'e.g. "All good" or explain any difference',
                        icon: Icons.note_alt_outlined,
                      ),
                    ]),
                  ),
                ]),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () async {
                    Navigator.pop(ctx);
                    await _clearLoginState();
                    navigator.pushNamedAndRemoveUntil(
                        RouteNames.restaurantLogin, (r) => false);
                  },
                  child: Text('Skip', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter the cash amount you counted')));
                      return;
                    }
                    setS(() => isSaving = true);
                    final expectedBalance = await (balanceFuture ?? Future.value(0.0));
                    await cashHandoverStore.recordShiftEnd(
                      closedBy: shift.staffName,
                      countedAmount: amount,
                      expectedAmount: expectedBalance,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _clearLoginState();
                    navigator.pushNamedAndRemoveUntil(
                        RouteNames.restaurantLogin, (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save & End Shift',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          }

          // ── Phase 1: End Shift confirm ──────────────────────────────
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  child: Row(children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.lock_clock_rounded, size: 28, color: Colors.orange),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text('End Shift',
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.person, 'Staff', shift.staffName),
                      SizedBox(height: 8),
                      _infoRow(Icons.timer, 'Duration', '${hours}h ${minutes}m'),
                      SizedBox(height: 8),
                      _infoRow(Icons.play_arrow, 'Started',
                          '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}'),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Orders during this shift will be tallied and saved to the Shift Report.',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: isClosing
                    ? null
                    : () async {
                        setS(() => isClosing = true);
                        final closed = await shiftStore.closeShift(shift.id);
                        if (closed != null) {
                          await RestaurantSession.clearShiftSession();
                          if (!AppSettings.shiftHandover) {
                            // Handover disabled — skip Phase 2, go straight to logout
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _clearLoginState();
                            navigator.pushNamedAndRemoveUntil(
                                RouteNames.restaurantLogin, (r) => false);
                            return;
                          }
                          // Switch to cash count phase; kick off balance load once
                          if (ctx.mounted) setS(() {
                            showCashCount = true;
                            balanceFuture ??= _loadExpectedBalance();
                          });
                        } else {
                          if (ctx.mounted) {
                            setS(() => isClosing = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Failed to end shift. Please try again.')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isClosing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('End Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        SizedBox(width: 8),
        Text('$label: ',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.lock_reset_rounded, color: Colors.teal),
            SizedBox(width: 10),
            Text('Change PIN',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMsg != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(errorMsg!,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.red.shade700)),
                  ),
                AppTextField(
                  controller: currentPinCtrl,
                  label: 'Current PIN',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter current PIN' : null,
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: newPinCtrl,
                  label: 'New PIN (4–6 digits)',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new PIN';
                    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) return 'PIN must be 4–6 digits';
                    return null;
                  },
                ),
                SizedBox(height: 12),
                AppTextField(
                  controller: confirmPinCtrl,
                  label: 'Confirm New PIN',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your new PIN';
                    if (v != newPinCtrl.text) return 'PINs do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await staffStore.loadStaff();
                final staff = staffStore.staff.where(
                  (s) => s.isActive && RestaurantAuthHelper.verifyPassword(currentPinCtrl.text.trim(), s.pinNo.trim()),
                ).firstOrNull;
                if (staff == null) {
                  setState(() => errorMsg = 'Current PIN is incorrect');
                  return;
                }
                final updated = staff.copyWith(pinNo: RestaurantAuthHelper.hashPassword(newPinCtrl.text.trim()));
                await staffStore.updateStaff(updated);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PIN changed successfully',
                          style: GoogleFonts.poppins()),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
              child: Text('Update PIN', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Account',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Add delete account logic here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Delete",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.divider),

            // Content
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Are you sure you want to logout?',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              "Logout",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
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