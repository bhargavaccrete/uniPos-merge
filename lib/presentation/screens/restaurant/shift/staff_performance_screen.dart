import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/shift_model.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

// ── Computed data class ───────────────────────────────────────────────────────

class _StaffPerformance {
  final String staffName;
  final String role;
  final int totalShifts;
  final int totalOrders;
  final double totalSales;
  final int totalMinutes;
  final double totalDiscounts;
  final double totalRefunds;
  final double totalExpenses;
  final Map<String, int> orderTypes; // e.g. {'Dine In': 40, 'Takeaway': 12}
  final int rank;

  const _StaffPerformance({
    required this.staffName,
    required this.role,
    required this.totalShifts,
    required this.totalOrders,
    required this.totalSales,
    required this.totalMinutes,
    required this.totalDiscounts,
    required this.totalRefunds,
    required this.totalExpenses,
    required this.orderTypes,
    required this.rank,
  });

  double get avgOrderValue => totalOrders > 0 ? totalSales / totalOrders : 0;
  double get ordersPerHour =>
      totalMinutes > 0 ? totalOrders / (totalMinutes / 60.0) : 0;
  String get durationLabel {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes.remainder(60);
    return '${h}h ${m}m';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class StaffPerformanceScreen extends StatefulWidget {
  const StaffPerformanceScreen({super.key});

  @override
  State<StaffPerformanceScreen> createState() => _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState extends State<StaffPerformanceScreen> {
  bool _isLoading = true;
  String _filterPeriod = 'Week'; // All | Today | Week | Month | Custom
  DateTime? _customFrom;
  DateTime? _customTo;
  String _sortBy = 'sales'; // 'sales' | 'orders' | 'hours'

  List<_StaffPerformance> _perfList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await shiftStore.loadShifts();
    await pastOrderStore.loadPastOrders();
    await staffStore.loadStaff(); // needed for role lookup in _compute
    await expenseStore.loadExpenses();
    _compute();
  }

  void _compute() {
    final allShifts = shiftStore.shifts.toList();
    final allOrders = pastOrderStore.pastOrders.toList();

    // 1. Filter shifts by date period
    final now = DateTime.now();
    final filtered = allShifts.where((s) {
      switch (_filterPeriod) {
        case 'Today':
          return s.startTime.year == now.year &&
              s.startTime.month == now.month &&
              s.startTime.day == now.day;
        case 'Week':
          // FIX 1: Use calendar week (Monday start) not a rolling 7-day window.
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek = DateTime(monday.year, monday.month, monday.day);
          return !s.startTime.isBefore(startOfWeek);
        case 'Month':
          return s.startTime.year == now.year &&
              s.startTime.month == now.month;
        case 'Custom':
          if (_customFrom == null) return true;
          // FIX 2: Inclusive boundary — !isBefore is correct for same-day starts.
          final after = !s.startTime.isBefore(_customFrom!);
          final before = _customTo == null ||
              s.startTime.isBefore(_customTo!.add(const Duration(days: 1)));
          return after && before;
        default:
          return true; // All
      }
    }).toList();

    // 2. Group closed shifts by staffName
    final Map<String, List<ShiftModel>> byStaff = {};
    for (final s in filtered.where((s) => !s.isOpen)) {
      byStaff.putIfAbsent(s.staffName, () => []).add(s);
    }
    // Also include open shifts in the computation but mark separately
    for (final s in filtered.where((s) => s.isOpen)) {
      byStaff.putIfAbsent(s.staffName, () => []).add(s);
    }

    // 3. Build an index: shiftId → Set<staffName> for fast lookup
    final shiftIdToStaff = <String, String>{};
    for (final entry in byStaff.entries) {
      for (final s in entry.value) {
        shiftIdToStaff[s.id] = entry.key;
      }
    }

    // 4. Group orders by staffName via shiftId
    final Map<String, List<dynamic>> ordersByStaff = {};
    for (final o in allOrders) {
      final sid = o.shiftId;
      if (sid != null && shiftIdToStaff.containsKey(sid)) {
        final name = shiftIdToStaff[sid]!;
        ordersByStaff.putIfAbsent(name, () => []).add(o);
      }
    }

    // 5. Compute metrics per staff
    final allExpenses = expenseStore.expenses.toList();
    final raw = byStaff.entries.map((entry) {
      final name = entry.key;
      final shifts = entry.value;
      final orders = ordersByStaff[name] ?? [];

      // Shift-level aggregates
      final totalShifts = shifts.length;
      final totalOrders =
          shifts.fold<int>(0, (s, sh) => s + sh.orderCount);
      final totalSales =
          shifts.fold<double>(0.0, (s, sh) => s + sh.totalSales);
      final totalMinutes =
          shifts.fold<int>(0, (s, sh) => s + sh.duration.inMinutes);

      // Expense aggregates: sum expenses during each shift's time window
      double totalExpenses = 0;
      final Set<String> countedExpenseIds = {};
      for (final shift in shifts) {
        final shiftEnd = shift.endTime ?? DateTime.now();
        for (final e in allExpenses) {
          // FIX 3: Precise inclusive boundary — no off-by-one-second tricks.
          if (!countedExpenseIds.contains(e.id) &&
              !e.dateandTime.isBefore(shift.startTime) &&
              !e.dateandTime.isAfter(shiftEnd)) {
            totalExpenses += e.amount;
            countedExpenseIds.add(e.id);
          }
        }
      }

      // Order-level aggregates
      double totalDiscounts = 0;
      double totalRefunds = 0;
      final Map<String, int> orderTypes = {};

      for (final o in orders) {
        // FIX 4: Skip fully cancelled orders — they inflate discounts/refunds/type counts.
        final status = (o.orderStatus as String?) ?? '';
        if (status == 'VOIDED' || status == 'VOID' || status == 'FULLY_REFUNDED') continue;
        totalDiscounts += (o.Discount as double?) ?? 0.0;
        totalRefunds += (o.refundAmount as double?) ?? 0.0;
        final type = (o.orderType as String?) ?? 'Unknown';
        orderTypes[type] = (orderTypes[type] ?? 0) + 1;
      }

      // Resolve role from staffStore; Admin is a special case (no StaffModel entry)
      String role = 'Staff';
      if (name == 'Admin') {
        role = 'Admin';
      } else {
        try {
          final nameLower = name.trim().toLowerCase();
          final match = staffStore.staff.where((s) {
            final full = '${s.firstName} ${s.lastName}'.trim().toLowerCase();
            final user = s.userName.trim().toLowerCase();
            return full == nameLower || user == nameLower;
          }).firstOrNull;
          if (match != null) role = match.isCashier;
        } catch (_) {}
      }

      return _StaffPerformance(
        staffName: name,
        role: role,
        totalShifts: totalShifts,
        totalOrders: totalOrders,
        totalSales: totalSales,
        totalMinutes: totalMinutes,
        totalDiscounts: totalDiscounts,
        totalRefunds: totalRefunds,
        totalExpenses: totalExpenses,
        orderTypes: orderTypes,
        rank: 0, // assigned after sort
      );
    }).toList();

    // 6. Sort
    raw.sort((a, b) {
      switch (_sortBy) {
        case 'orders':
          return b.totalOrders.compareTo(a.totalOrders);
        case 'hours':
          return b.totalMinutes.compareTo(a.totalMinutes);
        default:
          return b.totalSales.compareTo(a.totalSales);
      }
    });

    // 7. Assign rank
    final ranked = List.generate(
      raw.length,
      (i) => _StaffPerformance(
        staffName: raw[i].staffName,
        role: raw[i].role,
        totalShifts: raw[i].totalShifts,
        totalOrders: raw[i].totalOrders,
        totalSales: raw[i].totalSales,
        totalMinutes: raw[i].totalMinutes,
        totalDiscounts: raw[i].totalDiscounts,
        totalRefunds: raw[i].totalRefunds,
        totalExpenses: raw[i].totalExpenses,
        orderTypes: raw[i].orderTypes,
        rank: i + 1,
      ),
    );

    setState(() {
      _perfList = ranked;
      _isLoading = false;
    });
  }

  // ── Date pickers ─────────────────────────────────────────────────────────

  Future<void> _pickFrom() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (p != null) {
      setState(() => _customFrom = p);
      _compute();
    }
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _customTo ?? DateTime.now(),
      firstDate: _customFrom ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (p != null) {
      setState(() => _customTo = p);
      _compute();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0), Color(0xFF00695C), Color(0xFF6A1B9A),
      Color(0xFFD84315), Color(0xFF2E7D32), Color(0xFF0277BD),
      Color(0xFF4527A0), Color(0xFFC62828), Color(0xFF00838F),
      Color(0xFF558B2F),
    ];
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    return palette[idx];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    return parts.map((w) => w.isEmpty ? '' : w[0]).take(2).join().toUpperCase();
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // gold
    if (rank == 2) return const Color(0xFFC0C0C0); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return AppColors.textSecondary;
  }

  IconData _rankIcon(int rank) {
    if (rank <= 3) return Icons.emoji_events_rounded;
    return Icons.person_outline;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          _buildHeader(context),
          _buildFilterRow(context),
          if (_filterPeriod == 'Custom') _buildCustomDateRow(context),
          _buildSortRow(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _perfList.isEmpty
                    ? _buildEmpty(context)
                    : _buildBody(context, currency),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
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
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(Icons.arrow_back,
                  color: Colors.white,
                  size: AppResponsive.iconSize(context)),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Staff Performance',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.headingFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('${_perfList.length} staff member${_perfList.length != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppResponsive.borderRadius(context)),
              ),
              child: Icon(Icons.refresh,
                  color: AppColors.primary,
                  size: AppResponsive.iconSize(context)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────

  static const _periods = ['All', 'Today', 'Week', 'Month', 'Custom'];

  Widget _buildFilterRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _periods.map((p) {
            final isSelected = _filterPeriod == p;
            return Padding(
              padding:
                  EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _filterPeriod = p;
                    if (p != 'Custom') {
                      _customFrom = null;
                      _customTo = null;
                    }
                  });
                  _compute();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                      horizontal: AppResponsive.largeSpacing(context),
                      vertical: AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context)),
                    border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.divider),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ]
                        : [],
                  ),
                  child: Text(p,
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Custom date row ───────────────────────────────────────────────────────

  Widget _buildCustomDateRow(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.smallSpacing(context),
        AppResponsive.largeSpacing(context),
        0,
      ),
      child: Row(children: [
        Expanded(child: _datePicker(context, 'From',
            _customFrom != null ? fmt.format(_customFrom!) : null, _pickFrom)),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        Expanded(child: _datePicker(context, 'To',
            _customTo != null ? fmt.format(_customTo!) : null, _pickTo)),
      ]),
    );
  }

  Widget _datePicker(
      BuildContext context, String label, String? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context) + 2),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
              color: value != null ? AppColors.primary : AppColors.divider,
              width: value != null ? 1.5 : 1),
          borderRadius:
              BorderRadius.circular(AppResponsive.borderRadius(context)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: AppResponsive.smallIconSize(context),
              color:
                  value != null ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value ?? label,
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: value != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: value != null
                        ? FontWeight.w500
                        : FontWeight.w400)),
          ),
        ]),
      ),
    );
  }

  // ── Sort row ──────────────────────────────────────────────────────────────

  Widget _buildSortRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.largeSpacing(context),
          vertical: AppResponsive.mediumSpacing(context)),
      child: Row(children: [
        Text('Sort by:',
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        ...[
          ('sales', Icons.attach_money, 'Revenue'),
          ('orders', Icons.receipt_long, 'Orders'),
          ('hours', Icons.timer_outlined, 'Hours'),
        ].map((t) {
          final isActive = _sortBy == t.$1;
          return Padding(
            padding:
                EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
            child: GestureDetector(
              onTap: () {
                setState(() => _sortBy = t.$1);
                _compute();
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.mediumSpacing(context),
                    vertical: 5),
                decoration: BoxDecoration(
                  color:
                      isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.divider),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.$2,
                      size: AppResponsive.smallIconSize(context),
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(t.$3,
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary)),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, String currency) {
    // Summary totals across all filtered staff
    final totalRevenue =
        _perfList.fold<double>(0.0, (s, p) => s + p.totalSales);
    final totalOrders =
        _perfList.fold<int>(0, (s, p) => s + p.totalOrders);
    final totalShifts =
        _perfList.fold<int>(0, (s, p) => s + p.totalShifts);

    return Column(children: [
      // ── Team summary bar ──────────────────────────────────────────────────
      Padding(
        padding: EdgeInsets.fromLTRB(
          AppResponsive.largeSpacing(context),
          0,
          AppResponsive.largeSpacing(context),
          AppResponsive.mediumSpacing(context),
        ),
        child: Container(
          padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, const Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                BorderRadius.circular(AppResponsive.borderRadius(context)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryTile(context, '${_perfList.length}', 'Staff',
                    Icons.people_outline, Colors.white),
                _summaryTile(context, '$totalShifts', 'Shifts',
                    Icons.badge_outlined, Colors.white),
                _summaryTile(context, '$totalOrders', 'Orders',
                    Icons.receipt_long, Colors.white),
                _summaryTile(
                    context,
                    // FIX 5: Use DecimalSettings for consistent currency formatting.
                    '$currency${DecimalSettings.formatAmount(totalRevenue)}',
                    'Revenue',
                    Icons.attach_money,
                    Colors.white),
              ]),
        ),
      ),

      // ── Staff leaderboard ──────────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.largeSpacing(context)),
          itemCount: _perfList.length,
          itemBuilder: (context, index) =>
              _StaffCard(_perfList[index], currency, _avatarColor, _initials,
                  _rankColor, _rankIcon),
        ),
      ),
    ]);
  }

  Widget _summaryTile(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color.withValues(alpha: 0.8),
          size: AppResponsive.iconSize(context)),
      const SizedBox(height: 4),
      Text(value,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: AppResponsive.bodyFontSize(context),
              color: color)),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: color.withValues(alpha: 0.8))),
    ]);
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    final msg = _filterPeriod == 'Today'
        ? 'No staff shifts recorded today'
        : _filterPeriod == 'Week'
            ? 'No shifts this week'
            : _filterPeriod == 'Month'
                ? 'No shifts this month'
                : _filterPeriod == 'Custom'
                    ? 'No shifts in selected range'
                    : 'No shift data available yet';

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart,
            size: AppResponsive.largeIconSize(context) * 1.5,
            color: Colors.grey.shade300),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        Text(msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary)),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text('Shifts appear here once staff members log out',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary.withValues(alpha: 0.6))),
      ]),
    );
  }
}

// ── Staff Card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatefulWidget {
  final _StaffPerformance perf;
  final String currency;
  final Color Function(String) avatarColor;
  final String Function(String) initials;
  final Color Function(int) rankColor;
  final IconData Function(int) rankIcon;

  const _StaffCard(this.perf, this.currency, this.avatarColor, this.initials,
      this.rankColor, this.rankIcon);

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _expandAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animController.forward() : _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perf;
    final aColor = widget.avatarColor(p.staffName);
    final rankCol = widget.rankColor(p.rank);
    final isTop3 = p.rank <= 3;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius:
              BorderRadius.circular(AppResponsive.largeBorderRadius(context)),
          border: Border.all(
              color: isTop3
                  ? rankCol.withValues(alpha: 0.4)
                  : AppColors.divider,
              width: isTop3 ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: AppResponsive.shadowBlurRadius(context),
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top row ──────────────────────────────────────────────────────
            Row(children: [
              // Rank badge
              Container(
                width: AppResponsive.getValue<double>(context,
                    mobile: 32, tablet: 36, desktop: 40),
                height: AppResponsive.getValue<double>(context,
                    mobile: 32, tablet: 36, desktop: 40),
                decoration: BoxDecoration(
                  color: rankCol.withValues(alpha: isTop3 ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: isTop3
                    ? Icon(widget.rankIcon(p.rank),
                        size: AppResponsive.smallIconSize(context),
                        color: rankCol)
                    : Text('#${p.rank}',
                        style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),

              // Avatar
              Container(
                width: AppResponsive.getValue<double>(context,
                    mobile: 40, tablet: 44, desktop: 48),
                height: AppResponsive.getValue<double>(context,
                    mobile: 40, tablet: 44, desktop: 48),
                decoration: BoxDecoration(
                  color: aColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(widget.initials(p.staffName),
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: aColor)),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),

              // Name + role
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.staffName,
                          style: GoogleFonts.poppins(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(p.role,
                          style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary)),
                    ]),
              ),

              // Revenue (key metric always visible)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                    '${widget.currency}${DecimalSettings.formatAmount(p.totalSales)}',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Text('${p.totalOrders} orders',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary)),
              ]),

              SizedBox(width: AppResponsive.smallSpacing(context)),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
                size: AppResponsive.iconSize(context),
              ),
            ]),

            SizedBox(height: AppResponsive.smallSpacing(context)),

            // ── Quick KPI chips ───────────────────────────────────────────────
            Wrap(spacing: AppResponsive.smallSpacing(context), children: [
              _chip(context, Icons.badge_outlined,
                  '${p.totalShifts} shift${p.totalShifts != 1 ? 's' : ''}',
                  Colors.indigo),
              _chip(context, Icons.timer_outlined, p.durationLabel,
                  Colors.blue),
              _chip(context, Icons.trending_up,
                  'Avg ${widget.currency}${DecimalSettings.formatAmount(p.avgOrderValue)}/order',
                  Colors.green),
              _chip(context, Icons.speed,
                  '${p.ordersPerHour.toStringAsFixed(1)}/hr',
                  Colors.orange),
            ]),

            // ── Expanded detail ───────────────────────────────────────────────
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    Divider(color: AppColors.divider, height: 1),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),

                    // Revenue breakdown
                    _sectionTitle(context, 'Revenue Breakdown'),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    _detailRow(context, 'Total Sales',
                        '${widget.currency}${p.totalSales.toStringAsFixed(2)}',
                        Colors.green),
                    _detailRow(context, 'Expenses',
                        '- ${widget.currency}${p.totalExpenses.toStringAsFixed(2)}',
                        Colors.red),
                    _detailRow(context, 'Net Revenue',
                        '${widget.currency}${(p.totalSales - p.totalExpenses).toStringAsFixed(2)}',
                        Colors.teal),
                    _detailRow(context, 'Avg Order Value',
                        '${widget.currency}${p.avgOrderValue.toStringAsFixed(2)}',
                        Colors.teal),
                    _detailRow(context, 'Discounts Given',
                        '${widget.currency}${p.totalDiscounts.toStringAsFixed(2)}',
                        Colors.orange),
                    _detailRow(context, 'Refunds Handled',
                        '${widget.currency}${p.totalRefunds.toStringAsFixed(2)}',
                        Colors.red),

                    SizedBox(height: AppResponsive.mediumSpacing(context)),

                    // Productivity
                    _sectionTitle(context, 'Productivity'),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    _detailRow(context, 'Total Shifts', '${p.totalShifts}',
                        Colors.indigo),
                    _detailRow(context, 'Total Hours Worked', p.durationLabel,
                        Colors.blue),
                    _detailRow(context, 'Total Orders', '${p.totalOrders}',
                        AppColors.primary),
                    _detailRow(context, 'Orders / Hour',
                        p.ordersPerHour.toStringAsFixed(2), Colors.purple),

                    // Order type breakdown
                    if (p.orderTypes.isNotEmpty) ...[
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      _sectionTitle(context, 'Order Type Breakdown'),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      ...p.orderTypes.entries.map((e) {
                        final pct = p.totalOrders > 0
                            ? (e.value / p.totalOrders * 100)
                            : 0.0;
                        return _orderTypeBar(context, e.key, e.value, pct);
                      }),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon,
          size: AppResponsive.smallIconSize(context) * 0.85, color: color),
      const SizedBox(width: 3),
      Text(text,
          style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary)),
    ]);
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title,
        style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.3));
  }

  Widget _detailRow(
      BuildContext context, String label, String value, Color accent) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: AppResponsive.smallSpacing(context) * 0.4),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary)),
            ]),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ]),
    );
  }

  Widget _orderTypeBar(
      BuildContext context, String label, int count, double pct) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary)),
          Text('$count  (${pct.toStringAsFixed(0)}%)',
              style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: AppColors.divider,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
        ),
      ]),
    );
  }
}
