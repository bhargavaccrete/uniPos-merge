import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/shift_model.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/currency_helper.dart';

class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Custom date range state (local — drives store via setFilter)
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    shiftStore.loadShifts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      shiftStore.setSearch(_searchController.text);
    });
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  Future<void> _pickCustomFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _customFrom = picked);
      shiftStore.setFilter('Custom', start: _customFrom, end: _customTo);
    }
  }

  Future<void> _pickCustomTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customTo ?? DateTime.now(),
      firstDate: _customFrom ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _customTo = picked);
      shiftStore.setFilter('Custom', start: _customFrom, end: _customTo);
    }
  }

  // ── Day grouping ──────────────────────────────────────────────────────────

  /// Groups a list of shifts by calendar date string (newest date first).
  Map<String, List<ShiftModel>> _groupByDay(List<ShiftModel> shifts) {
    final map = <String, List<ShiftModel>>{};
    for (final s in shifts) {
      final key = DateFormat('dd MMM yyyy').format(s.startTime);
      map.putIfAbsent(key, () => []).add(s);
    }
    // Sort keys newest first
    final sorted = map.keys.toList()
      ..sort((a, b) {
        final da = DateFormat('dd MMM yyyy').parse(a);
        final db = DateFormat('dd MMM yyyy').parse(b);
        return db.compareTo(da);
      });
    return {for (final k in sorted) k: map[k]!};
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyHelper.currentSymbol;
    final isTablet = AppResponsive.isTablet(context) || AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          _buildHeader(context, isTablet),
          _buildSearchBar(context),
          _buildFilterChips(context),
          Observer(builder: (_) {
            if (shiftStore.filterPeriod == 'Custom') {
              return _buildCustomDateRow(context);
            }
            return const SizedBox.shrink();
          }),
          Expanded(
            child: Observer(
              builder: (_) {
                if (shiftStore.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = shiftStore.filteredShifts;
                final closed = filtered.where((s) => !s.isOpen).toList();
                final open = filtered.where((s) => s.isOpen).toList();

                return Column(
                  children: [
                    _buildSummaryBar(context, currency, closed, open),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState(context)
                          : _buildGroupedList(context, currency, open, closed),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isTablet) {
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
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                ),
                child: Icon(Icons.arrow_back,
                    color: Colors.white, size: AppResponsive.iconSize(context)),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shift Report',
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.headingFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Observer(builder: (_) {
                    final openCount =
                        shiftStore.shifts.where((s) => s.isOpen).length;
                    return Text(
                      openCount > 0
                          ? '$openCount shift${openCount > 1 ? 's' : ''} currently active'
                          : 'No active shifts',
                      style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: openCount > 0 ? Colors.green : AppColors.textSecondary),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppResponsive.largeSpacing(context),
        AppResponsive.mediumSpacing(context),
        AppResponsive.largeSpacing(context),
        0,
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
        decoration: InputDecoration(
          hintText: 'Search staff name...',
          hintStyle: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search,
              color: AppColors.textSecondary, size: AppResponsive.iconSize(context)),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, val, __) => val.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      shiftStore.setSearch('');
                    },
                    child: Icon(Icons.close,
                        color: AppColors.textSecondary,
                        size: AppResponsive.iconSize(context)),
                  )
                : const SizedBox.shrink(),
          ),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: EdgeInsets.symmetric(
              horizontal: AppResponsive.largeSpacing(context),
              vertical: AppResponsive.mediumSpacing(context)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────

  static const _periods = ['All', 'Today', 'Week', 'Month', 'Custom'];

  Widget _buildFilterChips(BuildContext context) {
    return Observer(builder: (_) {
      final active = shiftStore.filterPeriod;
      return Padding(
        padding: EdgeInsets.symmetric(
            vertical: AppResponsive.mediumSpacing(context),
            horizontal: AppResponsive.largeSpacing(context)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _periods.map((p) {
              final isSelected = active == p;
              return Padding(
                padding: EdgeInsets.only(right: AppResponsive.smallSpacing(context)),
                child: GestureDetector(
                  onTap: () {
                    if (p != 'Custom') {
                      setState(() {
                        _customFrom = null;
                        _customTo = null;
                      });
                    }
                    shiftStore.setFilter(p);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.largeSpacing(context),
                        vertical: AppResponsive.smallSpacing(context)),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                      border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p == 'Custom')
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.date_range,
                                size: AppResponsive.smallIconSize(context),
                                color: isSelected ? Colors.white : AppColors.textSecondary),
                          ),
                        Text(p,
                            style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  // ── Custom date row ───────────────────────────────────────────────────────

  Widget _buildCustomDateRow(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppResponsive.largeSpacing(context),
          0,
          AppResponsive.largeSpacing(context),
          AppResponsive.mediumSpacing(context)),
      child: Row(
        children: [
          Expanded(
            child: _datePicker(
              context: context,
              label: 'From',
              value: _customFrom != null ? fmt.format(_customFrom!) : null,
              onTap: _pickCustomFrom,
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: _datePicker(
              context: context,
              label: 'To',
              value: _customTo != null ? fmt.format(_customTo!) : null,
              onTap: _pickCustomTo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker({
    required BuildContext context,
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
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
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: AppResponsive.smallIconSize(context),
                color: value != null ? AppColors.primary : AppColors.textSecondary),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                value ?? label,
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: value != null ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: value != null ? FontWeight.w500 : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary bar ───────────────────────────────────────────────────────────

  Widget _buildSummaryBar(
    BuildContext context,
    String currency,
    List<ShiftModel> closed,
    List<ShiftModel> open,
  ) {
    final allForSummary = [...closed, ...open];
    final totalSales = closed.fold<double>(0.0, (s, sh) => s + sh.totalSales);
    final totalOrders = closed.fold<int>(0, (s, sh) => s + sh.orderCount);
    final totalMins = closed.fold<int>(0, (s, sh) => s + sh.duration.inMinutes);

    return Container(
      margin: EdgeInsets.fromLTRB(
          AppResponsive.largeSpacing(context),
          0,
          AppResponsive.largeSpacing(context),
          AppResponsive.mediumSpacing(context)),
      padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryTile(context, '${allForSummary.length}', 'Shifts', Icons.badge_outlined),
          _summaryTile(context, '$totalOrders', 'Orders', Icons.receipt_long),
          _summaryTile(context, '$currency${totalSales.toStringAsFixed(0)}', 'Sales',
              Icons.attach_money),
          _summaryTile(
              context,
              '${totalMins ~/ 60}h ${totalMins.remainder(60)}m',
              'Hours',
              Icons.timer_outlined),
        ],
      ),
    );
  }

  Widget _summaryTile(BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: AppResponsive.iconSize(context)),
        SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textPrimary)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Grouped list ──────────────────────────────────────────────────────────

  Widget _buildGroupedList(
    BuildContext context,
    String currency,
    List<ShiftModel> open,
    List<ShiftModel> closed,
  ) {
    final grouped = _groupByDay([...open, ...closed]);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.largeSpacing(context)),
      children: [
        for (final entry in grouped.entries) ...[
          _dayHeader(context, entry.key, entry.value),
          ...entry.value.map((s) => _ShiftCard(s, currency)),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
        ],
      ],
    );
  }

  Widget _dayHeader(BuildContext context, String dateLabel, List<ShiftModel> shifts) {
    final totalSales = shifts.fold<double>(0.0, (s, sh) => s + sh.totalSales);
    final currency = CurrencyHelper.currentSymbol;
    return Padding(
      padding: EdgeInsets.only(
          top: AppResponsive.smallSpacing(context),
          bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: AppColors.divider, thickness: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppResponsive.mediumSpacing(context)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today,
                    size: AppResponsive.smallIconSize(context),
                    color: AppColors.primary),
                SizedBox(width: 6),
                Text(dateLabel,
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${shifts.length} shift${shifts.length > 1 ? 's' : ''}  •  $currency${totalSales.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final query = shiftStore.searchQuery;
    final period = shiftStore.filterPeriod;
    final msg = query.isNotEmpty
        ? 'No shifts found for "$query"'
        : period == 'Today'
            ? 'No shifts today'
            : period == 'Week'
                ? 'No shifts this week'
                : period == 'Month'
                    ? 'No shifts this month'
                    : period == 'Custom'
                        ? 'No shifts in selected range'
                        : 'No shifts yet';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule,
              size: AppResponsive.largeIconSize(context) * 1.5,
              color: Colors.grey.shade300),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(msg,
              style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Shift Card ──────────────────────────────────────────────────────────────

class _ShiftCard extends StatefulWidget {
  final ShiftModel shift;
  final String currency;
  const _ShiftCard(this.shift, this.currency);

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  bool _expanded = false;

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Generates a consistent avatar color from a staff name.
  Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0), Color(0xFF00695C), Color(0xFF6A1B9A),
      Color(0xFFD84315), Color(0xFF2E7D32), Color(0xFF0277BD),
      Color(0xFF4527A0), Color(0xFFC62828),
    ];
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shift;
    final dur = s.duration;
    final isOpen = s.isOpen;
    final statusColor = isOpen ? Colors.green : Colors.grey.shade600;
    final avatarColor = _avatarColor(s.staffName);
    final initials = s.staffName.trim().isEmpty
        ? '?'
        : s.staffName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppResponsive.largeBorderRadius(context)),
          border: Border.all(
              color: isOpen
                  ? Colors.green.withValues(alpha: 0.3)
                  : AppColors.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: AppResponsive.shadowBlurRadius(context),
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Staff avatar
                  Container(
                    width: AppResponsive.getValue<double>(context,
                        mobile: 36, tablet: 40, desktop: 44),
                    height: AppResponsive.getValue<double>(context,
                        mobile: 36, tablet: 40, desktop: 44),
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: avatarColor)),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),

                  // Name + time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.staffName,
                            style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        Text(
                          isOpen
                              ? 'Started ${_fmtTime(s.startTime)}'
                              : '${_fmtTime(s.startTime)} → ${_fmtTime(s.endTime!)}',
                          style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppResponsive.smallSpacing(context),
                        vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context)),
                    ),
                    child: Text(isOpen ? 'Active' : 'Closed',
                        style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                ],
              ),

              SizedBox(height: AppResponsive.smallSpacing(context)),

              // Chips
              Wrap(
                spacing: AppResponsive.smallSpacing(context),
                children: [
                  _chip(context, Icons.timer_outlined,
                      '${dur.inHours}h ${dur.inMinutes.remainder(60)}m', Colors.blue),
                  _chip(context, Icons.receipt_rounded,
                      '${s.orderCount} orders', Colors.indigo),
                  _chip(context, Icons.attach_money,
                      '${widget.currency}${s.totalSales.toStringAsFixed(0)}',
                      Colors.green),
                ],
              ),

              // Expanded detail
              if (_expanded && !isOpen) ...[
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Divider(color: AppColors.divider, height: 1),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                _detailRow(context, 'Total Sales',
                    '${widget.currency}${s.totalSales.toStringAsFixed(2)}'),
                _detailRow(context, 'Orders', '${s.orderCount}'),
                _detailRow(context, 'Duration',
                    '${dur.inHours}h ${dur.inMinutes.remainder(60)}m'),
                _detailRow(context, 'Started',
                    DateFormat('dd MMM yyyy, HH:mm').format(s.startTime)),
                _detailRow(context, 'Ended',
                    DateFormat('dd MMM yyyy, HH:mm').format(s.endTime!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context) * 0.85, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: AppResponsive.smallSpacing(context) * 0.4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
