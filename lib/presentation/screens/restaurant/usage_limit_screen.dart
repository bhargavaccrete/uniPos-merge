import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/plan/plan_gate.dart';
import '../../../core/plan/plan_enforcement.dart';
import '../../../core/plan/entitlement_keys.dart';

/// Usage & Limits — a read-only overview of how much of each plan-capped
/// resource the outlet has consumed against its plan allowance.
///
/// The plan (Free/Premium/Trial) and every resource count are MobX observables,
/// so the whole body is wrapped in a single [Observer]: a server-pushed plan
/// change or a newly added item/table/etc. re-renders the bars automatically.
/// No gradients — the design leans on a flat, tinted palette from [AppColors].
class UsageLimitScreen extends StatefulWidget {
  const UsageLimitScreen({super.key});

  @override
  State<UsageLimitScreen> createState() => _UsageLimitScreenState();
}

class _UsageLimitScreenState extends State<UsageLimitScreen> {
  @override
  void initState() {
    super.initState();
    // The dashboard is a pre-login screen, so these stores may not be loaded
    // yet. Fire the loaders once; each is idempotent and updates its observable
    // list, which the Observer below picks up. Failures are non-fatal here.
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([
      itemStore.loadItems(),
      categoryStore.loadCategories(),
      tableStore.loadTables(),
      staffStore.loadStaff(),
      customerStore.loadCustomers(),
      printerStore.loadSavedPrinters(),
    ].map((f) => f.catchError((_) {})));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0.5,
        shadowColor: AppColors.cardShadow,
        iconTheme: const IconThemeData(color: AppColors.primary),
        centerTitle: false,
        title: Text(
          'Usage & Limits',
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: Center(
            child: ConstrainedBox(
              // Keep the column comfortable on tablet / desktop / web.
              constraints: const BoxConstraints(maxWidth: 640),
              child: Observer(
                builder: (_) {
                  final isPremium = PlanGate.isPremium;
                  final metrics = _buildMetrics();

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _PlanBanner(
                        planLabel: PlanGate.planLabel,
                        isPremium: isPremium,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Resources',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final m in metrics) ...[
                        _UsageCard(metric: m),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 4),
                      _FootNote(isPremium: isPremium),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The plan-capped resources, each paired with its live count and the plan
  /// cap resolved straight from the server-driven entitlement manifest.
  ///
  /// The cap comes from [PlanEnforce.limit] using the SAME [EntKeys] the stores
  /// enforce on add (see e.g. `item_store` → [EntKeys.manageMenuItemsMax]), so
  /// what this screen shows and what the app actually blocks can never diverge.
  /// Semantics mirror [PlanEnforce.withinLimit]: a cap of 0/absent — or a
  /// resource with no cap key at all (`entKey == null`, e.g. Categories &
  /// Printers, which the plan does not count-limit) — means unlimited.
  List<_UsageMetric> _buildMetrics() {
    int? capFor(String? entKey) {
      if (entKey == null) return null; // resource has no count cap in the plan
      final max = PlanEnforce.limit(entKey); // null when license is bypassed
      if (max == null || max <= 0) return null; // 0/absent ⇒ unlimited
      return max;
    }

    _UsageMetric make(
      String label,
      IconData icon,
      Color accent,
      int count,
      String? entKey,
    ) {
      return _UsageMetric(
        label: label,
        icon: icon,
        accent: accent,
        count: count,
        limit: capFor(entKey),
      );
    }

    return [
      make('Menu Items', Icons.restaurant_menu, AppColors.menuTab,
          itemStore.itemCount, EntKeys.manageMenuItemsMax),
      make('Categories', Icons.category_outlined, AppColors.secondary,
          categoryStore.categoryCount, null),
      make('Tables', Icons.table_restaurant_outlined, AppColors.tablesTab,
          tableStore.totalTables, EntKeys.billingTablesMax),
      make('Staff', Icons.badge_outlined, AppColors.info,
          staffStore.totalStaff, EntKeys.usersMax),
      make('Customers', Icons.people_alt_outlined, AppColors.orange,
          customerStore.totalCustomers, EntKeys.customersMax),
      make('Printers', Icons.print_outlined, AppColors.accent,
          printerStore.savedPrinters.length, null),
    ];
  }
}

/// Immutable view-model for one resource row.
class _UsageMetric {
  const _UsageMetric({
    required this.label,
    required this.icon,
    required this.accent,
    required this.count,
    required this.limit,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final int count;

  /// null = unlimited on the active plan.
  final int? limit;

  bool get isUnlimited => limit == null;

  /// 0..1 fill fraction (0 when unlimited or when the cap is 0).
  double get ratio {
    if (isUnlimited || limit == 0) return isUnlimited ? 0 : 1;
    return (count / limit!).clamp(0.0, 1.0);
  }

  bool get atLimit => !isUnlimited && count >= limit!;
  int get remaining => isUnlimited ? 0 : (limit! - count).clamp(0, limit!);

  /// The status colour that drives the bar + trailing pill.
  Color get statusColor {
    if (isUnlimited) return AppColors.info;
    if (atLimit) return AppColors.danger;
    if (ratio >= 0.8) return AppColors.warning;
    return AppColors.success;
  }
}

/// Top card summarising the active plan.
class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.planLabel, required this.isPremium});

  final String planLabel;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final accent = isPremium ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium_outlined : Icons.speed_outlined,
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Current Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        planLabel.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isPremium
                      ? 'All resources are unlimited on your plan.'
                      : 'Track how much of each free limit you have used.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One resource card: icon, label, used/limit, a flat progress bar and a pill.
class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.metric});

  final _UsageMetric metric;

  @override
  Widget build(BuildContext context) {
    final color = metric.statusColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: metric.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(metric.icon, color: metric.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.isUnlimited
                          ? '${metric.count} in use'
                          : '${metric.count} of ${metric.limit} used',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _TrailingPill(metric: metric, color: color),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: metric.isUnlimited ? 1.0 : metric.ratio,
              minHeight: 8,
              backgroundColor: metric.isUnlimited
                  ? AppColors.info.withValues(alpha: 0.14)
                  : color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(
                metric.isUnlimited ? AppColors.info.withValues(alpha: 0.35) : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-aligned status pill: "∞ Unlimited", "N left", or "Limit reached".
class _TrailingPill extends StatelessWidget {
  const _TrailingPill({required this.metric, required this.color});

  final _UsageMetric metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData? icon;
    if (metric.isUnlimited) {
      label = 'Unlimited';
      icon = Icons.all_inclusive;
    } else if (metric.atLimit) {
      label = 'Limit reached';
      icon = Icons.lock_outline;
    } else {
      label = '${metric.remaining} left';
      icon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small explanatory line under the list.
class _FootNote extends StatelessWidget {
  const _FootNote({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isPremium
                ? 'You can add resources without limits. Pull down to refresh.'
                : 'Reaching a limit blocks new additions until you upgrade or remove existing entries. Pull down to refresh.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
