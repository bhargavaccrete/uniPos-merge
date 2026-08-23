import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/stock_take_model_180.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../domain/services/retail/stock_adjustment_reason.dart';
import '../../../domain/services/retail/stock_adjustment_service.dart';
import 'stock_take_screen.dart';

/// Every physical count, newest first.
///
/// Drafts are resumable — a shop counting a large floor will not finish in one
/// sitting, and forcing a single session would push them to guess rather than
/// count.
class StockTakeListScreen extends StatefulWidget {
  const StockTakeListScreen({super.key});

  @override
  State<StockTakeListScreen> createState() => _StockTakeListScreenState();
}

class _StockTakeListScreenState extends State<StockTakeListScreen> {
  @override
  void initState() {
    super.initState();
    stockTakeStore.loadTakes();
  }

  Future<void> _startTake() async {
    if (!PlanGuard.allowedOr(
      context,
      RetailEntKeys.inventoryStockTake,
      featureName: 'Stock Take',
    )) {
      return;
    }

    if (!StockAdjustmentService.canAdjust) {
      NotificationService.instance
          .showError('Only the admin can run a stock take.');
      return;
    }

    final scope = await showDialog<String?>(
      context: context,
      builder: (_) => const _ScopeDialog(),
    );
    // A null result means the dialog was dismissed; an empty string is a
    // deliberate "no label", which is allowed.
    if (scope == null || !mounted) return;

    final take = await stockTakeStore.startTake(
      scopeNote: scope.isEmpty ? null : scope,
    );

    if (!mounted) return;
    if (take == null) {
      NotificationService.instance.showError(
        stockTakeStore.errorMessage ?? 'Stock take could not be started.',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockTakeScreen(takeId: take.takeId),
      ),
    );
    if (mounted) await stockTakeStore.loadTakes();
  }

  Future<void> _openTake(StockTakeModel take) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockTakeScreen(takeId: take.takeId),
      ),
    );
    if (mounted) await stockTakeStore.loadTakes();
  }

  Future<void> _cancelTake(StockTakeModel take) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Discard ${take.takeNumber}?',
      message: 'The count and all its lines will be deleted. Stock is not '
          'affected — nothing was applied.',
      confirmLabel: 'Discard',
      accent: AppColors.danger,
    );
    if (!confirmed) return;

    final ok = await stockTakeStore.cancelTake(take.takeId);
    if (!mounted) return;
    if (ok) {
      NotificationService.instance.showSuccess('Stock take discarded');
    } else {
      NotificationService.instance.showError(
        stockTakeStore.errorMessage ?? 'Could not discard stock take.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Stock Takes'),
      body: SafeArea(
        child: Observer(
          builder: (context) {
            if (stockTakeStore.isLoading && stockTakeStore.takes.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final takes = stockTakeStore.takes;
            if (takes.isEmpty) {
              return AppEmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No stock takes yet',
                message: 'Count your shelves and apply the variances in one '
                    'go, instead of correcting products one at a time.',
                action: ElevatedButton.icon(
                  onPressed: _startTake,
                  icon: const Icon(Icons.add),
                  label: const Text('Start Stock Take'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              );
            }

            return AppResponsive.constrainedContent(
              context: context,
              alignment: Alignment.topCenter,
              child: ListView.builder(
                padding: AppResponsive.padding(context),
                itemCount: takes.length,
                itemBuilder: (context, i) => _buildCard(context, takes[i]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Observer(
        builder: (context) => stockTakeStore.takes.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _startTake,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                icon: const Icon(Icons.add),
                label: Text(
                  'New Count',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, StockTakeModel take) {
    final net = take.committedNetQty;
    final color = take.isCompleted ? AppColors.success : AppColors.warning;

    return InkWell(
      onTap: () => _openTake(take),
      borderRadius:
          BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
      child: Container(
        margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius:
              BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        take.takeNumber,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        take.scopeNote?.isNotEmpty ?? false
                            ? take.scopeNote!
                            : 'Full count',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    take.statusDisplay,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                // Discard stays behind the overflow menu, and only for drafts —
                // a completed take is the evidence for adjustments that
                // already happened.
                if (take.isDraft)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: AppColors.textSecondary),
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'discard') _cancelTake(take);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'discard',
                        child: Text('Discard'),
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            const Divider(height: 1, color: AppColors.divider),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Wrap(
              spacing: AppResponsive.mediumSpacing(context),
              runSpacing: 4,
              children: [
                _meta(context, Icons.person_outline_rounded, take.countedBy),
                _meta(
                  context,
                  Icons.event_outlined,
                  _formatDate(take.completedAt ?? take.createdAt),
                ),
                if (take.isCompleted && take.committedLineCount != null)
                  _meta(
                    context,
                    Icons.playlist_add_check_rounded,
                    '${take.committedLineCount} applied',
                  ),
                if (take.isCompleted && net != null && net != 0)
                  _meta(
                    context,
                    net > 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    '${net > 0 ? '+' : ''}$net units',
                  ),
                if (take.isCompleted && take.varianceReason != null)
                  _meta(
                    context,
                    Icons.description_outlined,
                    StockAdjustmentReason.labelFor(take.varianceReason!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
}

/// Optional label for what is being counted. Skippable — demanding a label
/// before a shop can start counting would just produce "asdf".
class _ScopeDialog extends StatefulWidget {
  const _ScopeDialog();

  @override
  State<_ScopeDialog> createState() => _ScopeDialogState();
}

class _ScopeDialogState extends State<_ScopeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      title: 'Start Stock Take',
      subtitle: 'Counting does not change stock until you apply it',
      accent: AppColors.primary,
      icon: Icons.fact_check_outlined,
      body: AppTextField(
        controller: _controller,
        label: 'What are you counting? (Optional)',
        hint: 'e.g. Aisle 3, Shirts, Full store',
        icon: Icons.label_outline_rounded,
        autofocus: true,
        onFieldSubmitted: (_) =>
            Navigator.pop(context, _controller.text.trim()),
      ),
      actions: [
        appDialogCancelButton(context),
        const SizedBox(width: 12),
        appDialogPrimaryButton(
          label: 'Start',
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
        ),
      ],
    );
  }
}
