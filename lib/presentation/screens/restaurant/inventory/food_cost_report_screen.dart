import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/recipe_report_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_card.dart';
import 'package:billberrylite/presentation/widget/componets/common/report_summary_row.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';

/// Phase 6 capstone report — food-cost %, recipe margin %, ingredient usage,
/// and wastage, all sourced from [RecipeReportService]. Reached the same way
/// as Recipes/Raw Materials/Purchase Orders/Production: a plain icon button
/// on [ManageInventory]'s app bar (no plan gating — see
/// docs/inventory_recipe_system_plan.md §10, Phase 6).
class FoodCostReportScreen extends StatefulWidget {
  const FoodCostReportScreen({super.key});

  @override
  State<FoodCostReportScreen> createState() => _FoodCostReportScreenState();
}

/// Quick date-range presets shared by the Ingredient Usage and Wastage tabs.
enum _QuickRange {
  last7('Last 7 Days', 7),
  last30('Last 30 Days', 30),
  last90('Last 90 Days', 90),
  allTime('All Time', null),
  custom('Custom', null);

  final String label;
  final int? days;

  const _QuickRange(this.label, this.days);
}

class _FoodCostReportScreenState extends State<FoodCostReportScreen> {
  _QuickRange _selectedRange = _QuickRange.last30;
  DateTime? _customStart;
  DateTime? _customEnd;

  /// Shared by the hero and the Food Cost tab; dropped on any items-list change,
  /// the same signal both Observers rebuild on.
  List<RecipeCostReportRow>? _foodCostRows;
  late final void Function() _disposeItemsObserver;

  List<RecipeCostReportRow> get _foodCost =>
      _foodCostRows ??= RecipeReportService.foodCostReport();

  @override
  void initState() {
    super.initState();
    _disposeItemsObserver =
        itemStore.items.observe((_) => _foodCostRows = null);
    if (itemStore.items.isEmpty) {
      itemStore.loadItems();
    }
  }

  @override
  void dispose() {
    _disposeItemsObserver();
    super.dispose();
  }

  ({DateTime? from, DateTime? to}) get _effectiveRange {
    final now = DateTime.now();
    switch (_selectedRange) {
      case _QuickRange.allTime:
        return (from: null, to: null);
      case _QuickRange.custom:
        if (_customStart == null || _customEnd == null) {
          return (from: now.subtract(const Duration(days: 30)), to: now);
        }
        return (
          from: DateTime(
            _customStart!.year,
            _customStart!.month,
            _customStart!.day,
          ),
          to: DateTime(
            _customEnd!.year,
            _customEnd!.month,
            _customEnd!.day,
            23,
            59,
            59,
          ),
        );
      case _QuickRange.last7:
      case _QuickRange.last30:
      case _QuickRange.last90:
        return (
          from: now.subtract(Duration(days: _selectedRange.days!)),
          to: now,
        );
    }
  }

  String get _rangeLabel {
    if (_selectedRange != _QuickRange.custom) return _selectedRange.label;
    if (_customStart == null || _customEnd == null) {
      return 'Custom (pick dates)';
    }
    final fmt = DateFormat('dd MMM yyyy');
    return '${fmt.format(_customStart!)} – ${fmt.format(_customEnd!)}';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 29)),
              end: now,
            ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            surface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _customStart = picked.start;
      _customEnd = picked.end;
      _selectedRange = _QuickRange.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(
          title: 'Food Cost Report',
          bottom: TabBar(
            indicatorColor: AppColors.white,
            indicatorWeight: 3,
            labelColor: AppColors.white,
            unselectedLabelColor: AppColors.white.withValues(alpha: 0.65),
            labelStyle: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Food Cost & Margin'),
              Tab(text: 'Ingredient Usage'),
              Tab(text: 'Wastage'),
            ],
          ),
        ),
        body: Column(
          children: [
            Observer(
              builder: (_) {
                // Reads itemStore so live recipe/cost numbers refresh the hero.
                // ignore: unused_local_variable
                final _ = itemStore.items.length;
                final rows = _foodCost;
                final priced = rows
                    .where((r) => r.foodCostPercent != null)
                    .toList();
                final avgFoodCost = priced.isEmpty
                    ? null
                    : priced
                              .map((r) => r.foodCostPercent!)
                              .reduce((a, b) => a + b) /
                          priced.length;
                final avgMargin = priced.isEmpty
                    ? null
                    : priced
                              .where((r) => r.marginPercent != null)
                              .map((r) => r.marginPercent!)
                              .fold(0.0, (a, b) => a + b) /
                          (priced.where((r) => r.marginPercent != null).isEmpty
                              ? 1
                              : priced
                                    .where((r) => r.marginPercent != null)
                                    .length);

                return GradientHeroHeader(
                  title: 'Food Cost Report',
                  subtitle:
                      'Recipe cost %, margin, ingredient usage & wastage at a glance',
                  icon: Icons.query_stats_rounded,
                  accent: AppColors.primary,
                  stats: [
                    HeroStat(
                      icon: Icons.receipt_long_rounded,
                      value: '${rows.length}',
                      label: 'Recipes Tracked',
                    ),
                    HeroStat(
                      icon: Icons.pie_chart_rounded,
                      value: avgFoodCost == null
                          ? '—'
                          : '${avgFoodCost.toStringAsFixed(0)}%',
                      label: 'Avg Food Cost',
                    ),
                    HeroStat(
                      icon: Icons.trending_up_rounded,
                      value: avgMargin == null
                          ? '—'
                          : '${avgMargin.toStringAsFixed(0)}%',
                      label: 'Avg Margin',
                    ),
                  ],
                );
              },
            ),
            // Hero and TabBar stay full-bleed; capping here covers all tabs.
            Expanded(
              child: AppResponsive.constrainedContent(
                context: context,
                maxWidth: AppResponsive.maxContentWidth(context),
                alignment: Alignment.topCenter,
                child: TabBarView(
                  children: [
                    _FoodCostMarginTab(rows: () => _foodCost),
                    _IngredientUsageTab(
                      rangeLabel: _rangeLabel,
                      selectedRange: _selectedRange,
                      onRangeSelected: (r) {
                        if (r == _QuickRange.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() => _selectedRange = r);
                        }
                      },
                      range: _effectiveRange,
                    ),
                    _WastageTab(
                      rangeLabel: _rangeLabel,
                      selectedRange: _selectedRange,
                      onRangeSelected: (r) {
                        if (r == _QuickRange.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() => _selectedRange = r);
                        }
                      },
                      range: _effectiveRange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 1 — Food Cost & Margin
// ─────────────────────────────────────────────────────────────────────────

class _FoodCostMarginTab extends StatelessWidget {
  final List<RecipeCostReportRow> Function() rows;

  const _FoodCostMarginTab({required this.rows});

  Color _foodCostColor(double pct) {
    if (pct < 30) return AppColors.success;
    if (pct <= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        // Reads itemStore.items so this rebuilds when items change.
        // ignore: unused_local_variable
        final _ = itemStore.items.length;
        final rows = this.rows();

        if (rows.isEmpty) {
          return const AppEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No recipes configured yet',
            message:
                'Mark an item Semi-Finished or Recipe-Based and add ingredients to see cost & margin here.',
          );
        }

        final pricedRows = rows
            .where((r) => r.foodCostPercent != null)
            .toList();
        final unpricedCount = rows.length - pricedRows.length;
        final avgFoodCostPercent = pricedRows.isEmpty
            ? null
            : pricedRows
                      .map((r) => r.foodCostPercent!)
                      .reduce((a, b) => a + b) /
                  pricedRows.length;

        return ListView(
          padding: AppResponsive.padding(context),
          children: [
            ReportSummaryRow(
              cards: [
                ReportSummaryCard(
                  title: 'Recipes Tracked',
                  value: rows.length.toString(),
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
                ReportSummaryCard(
                  title: 'Avg Food Cost %',
                  value: avgFoodCostPercent == null
                      ? '—'
                      : '${avgFoodCostPercent.toStringAsFixed(1)}%',
                  icon: Icons.pie_chart_rounded,
                  color: avgFoodCostPercent == null
                      ? AppColors.textSecondary
                      : _foodCostColor(avgFoodCostPercent),
                ),
                ReportSummaryCard(
                  title: 'Not Priced',
                  value: unpricedCount.toString(),
                  icon: Icons.price_change_rounded,
                  color: unpricedCount > 0
                      ? AppColors.warning
                      : AppColors.success,
                  subtitle: unpricedCount > 0
                      ? 'Set a price to see margin'
                      : 'All priced',
                ),
              ],
            ),
            AppResponsive.verticalSpace(context, size: SpacingSize.large),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FoodCostCard(row: row, colorOf: _foodCostColor),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FoodCostCard extends StatelessWidget {
  final RecipeCostReportRow row;
  final Color Function(double) colorOf;

  const _FoodCostCard({required this.row, required this.colorOf});

  @override
  Widget build(BuildContext context) {
    final foodCostPercent = row.foodCostPercent;
    final marginPercent = row.marginPercent;
    final Color pillColor = foodCostPercent == null
        ? AppColors.textSecondary
        : colorOf(foodCostPercent);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (row.item.isSemiFinished
                                    ? AppColors.info
                                    : (row.item.isRecipeBased
                                          ? AppColors.orange
                                          : AppColors.success))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        row.item.isSemiFinished
                            ? 'Semi-Finished'
                            : (row.item.isRecipeBased
                                  ? 'Recipe-Based'
                                  : 'Finished Good'),
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w700,
                          color: row.item.isSemiFinished
                              ? AppColors.info
                              : (row.item.isRecipeBased
                                    ? AppColors.orange
                                    : AppColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      row.item.name,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.ingredientCount} ingredient${row.ingredientCount == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Food Cost',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        color: pillColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      foodCostPercent == null
                          ? '—'
                          : '${foodCostPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: pillColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statColumn(
                    context,
                    'Cost/Unit',
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(row.costPerUnit)}',
                    AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _statColumn(
                    context,
                    'Selling Price',
                    row.sellingPrice == null
                        ? 'Not priced'
                        : '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(row.sellingPrice!)}',
                    row.sellingPrice == null
                        ? AppColors.warning
                        : AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _statColumn(
                    context,
                    'Margin',
                    marginPercent == null
                        ? '—'
                        : '${marginPercent.toStringAsFixed(1)}%',
                    marginPercent == null
                        ? AppColors.textSecondary
                        : (marginPercent >= 0
                              ? AppColors.success
                              : AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared date-range chip selector for tabs 2 & 3
// ─────────────────────────────────────────────────────────────────────────

class _DateRangeSelector extends StatelessWidget {
  final String rangeLabel;
  final _QuickRange selectedRange;
  final ValueChanged<_QuickRange> onRangeSelected;

  const _DateRangeSelector({
    required this.rangeLabel,
    required this.selectedRange,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rangeLabel,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _QuickRange.values.map((r) {
              final selected = r == selectedRange;
              return InkWell(
                onTap: () => onRangeSelected(r),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r == _QuickRange.custom) ...[
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 13,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        r.label,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 2 — Ingredient Usage
// ─────────────────────────────────────────────────────────────────────────

class _IngredientUsageTab extends StatelessWidget {
  final String rangeLabel;
  final _QuickRange selectedRange;
  final ValueChanged<_QuickRange> onRangeSelected;
  final ({DateTime? from, DateTime? to}) range;

  const _IngredientUsageTab({
    required this.rangeLabel,
    required this.selectedRange,
    required this.onRangeSelected,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final rows = RecipeReportService.ingredientUsageReport(
      from: range.from,
      to: range.to,
    );
    final totalCost = rows.fold(0.0, (s, r) => s + r.estimatedCost);
    final totalMovements = rows.fold(0, (s, r) => s + r.movementCount);

    return ListView(
      padding: AppResponsive.padding(context),
      children: [
        _DateRangeSelector(
          rangeLabel: rangeLabel,
          selectedRange: selectedRange,
          onRangeSelected: onRangeSelected,
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.large),
        ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Ingredients Used',
              value: rows.length.toString(),
              icon: Icons.grass_rounded,
              color: AppColors.primary,
            ),
            ReportSummaryCard(
              title: 'Total Cost',
              value:
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalCost)}',
              icon: Icons.currency_exchange_rounded,
              color: AppColors.orange,
            ),
            ReportSummaryCard(
              title: 'Movements',
              value: totalMovements.toString(),
              icon: Icons.swap_horiz_rounded,
              color: AppColors.info,
            ),
          ],
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.large),
        if (rows.isEmpty)
          const AppEmptyState(
            icon: Icons.grass_rounded,
            title: 'No ingredient usage found',
            message:
                'No recipe-cascaded sales or production consumed raw materials in this range.',
          )
        else
          ...List.generate(rows.length, (i) {
            final row = rows[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UsageCard(
                rank: i + 1,
                name: row.itemName,
                qty: row.consumedQty,
                unit: row.unit,
                movementCount: row.movementCount,
                cost: row.estimatedCost,
                accent: AppColors.primary,
              ),
            );
          }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab 3 — Wastage
// ─────────────────────────────────────────────────────────────────────────

class _WastageTab extends StatelessWidget {
  final String rangeLabel;
  final _QuickRange selectedRange;
  final ValueChanged<_QuickRange> onRangeSelected;
  final ({DateTime? from, DateTime? to}) range;

  const _WastageTab({
    required this.rangeLabel,
    required this.selectedRange,
    required this.onRangeSelected,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final rows = RecipeReportService.wastageReport(
      from: range.from,
      to: range.to,
    );
    final totalCost = rows.fold(0.0, (s, r) => s + r.estimatedCost);
    final totalMovements = rows.fold(0, (s, r) => s + r.movementCount);

    return ListView(
      padding: AppResponsive.padding(context),
      children: [
        _DateRangeSelector(
          rangeLabel: rangeLabel,
          selectedRange: selectedRange,
          onRangeSelected: onRangeSelected,
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.large),
        ReportSummaryRow(
          cards: [
            ReportSummaryCard(
              title: 'Items Wasted',
              value: rows.length.toString(),
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
            ReportSummaryCard(
              title: 'Wastage Cost',
              value:
                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(totalCost)}',
              icon: Icons.currency_exchange_rounded,
              color: AppColors.danger,
            ),
            ReportSummaryCard(
              title: 'Movements',
              value: totalMovements.toString(),
              icon: Icons.swap_horiz_rounded,
              color: AppColors.info,
            ),
          ],
        ),
        AppResponsive.verticalSpace(context, size: SpacingSize.large),
        if (rows.isEmpty)
          const AppEmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'No wastage logged',
            message: 'No stock removed as "Wastage / Spoilage" in this range.',
          )
        else
          ...List.generate(rows.length, (i) {
            final row = rows[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UsageCard(
                rank: i + 1,
                name: row.itemName,
                qty: row.wastedQty,
                unit: row.unit,
                movementCount: row.movementCount,
                cost: row.estimatedCost,
                accent: AppColors.danger,
              ),
            );
          }),
      ],
    );
  }
}

/// Ranked row card shared by Ingredient Usage and Wastage tabs.
class _UsageCard extends StatelessWidget {
  final int rank;
  final String name;
  final double qty;
  final String unit;
  final int movementCount;
  final double cost;
  final Color accent;

  const _UsageCard({
    required this.rank,
    required this.name,
    required this.qty,
    required this.unit,
    required this.movementCount,
    required this.cost,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DecimalSettings.formatAmount(qty)} $unit  •  $movementCount movement${movementCount == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(cost)}',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
