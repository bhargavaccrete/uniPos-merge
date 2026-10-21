import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_stock_take_model.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'stock_take_screen.dart';

/// Every physical count, newest first. Mirrors retail's `StockTakeListScreen`.
///
/// Drafts are resumable — a kitchen counting a large storeroom will not
/// finish in one sitting, and forcing a single session would push staff to
/// guess rather than count.
class RestaurantStockTakeListScreen extends StatefulWidget {
  const RestaurantStockTakeListScreen({super.key});

  @override
  State<RestaurantStockTakeListScreen> createState() =>
      _RestaurantStockTakeListScreenState();
}

class _RestaurantStockTakeListScreenState
    extends State<RestaurantStockTakeListScreen> {
  @override
  void initState() {
    super.initState();
    restaurantStockTakeStore.loadTakes();
  }

  Future<void> _startTake() async {
    final scope = await showDialog<String?>(
      context: context,
      builder: (_) => const _ScopeDialog(),
    );
    // A null result means the dialog was dismissed; an empty string is a
    // deliberate "no label", which is allowed.
    if (scope == null || !mounted) return;

    final take = await restaurantStockTakeStore.startTake(
      scopeNote: scope.isEmpty ? null : scope,
    );

    if (!mounted) return;
    if (take == null) {
      NotificationService.instance.showError(
        restaurantStockTakeStore.errorMessage ??
            'Stock take could not be started.',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantStockTakeScreen(takeId: take.takeId),
      ),
    );
  }

  Future<void> _openTake(RestaurantStockTakeModel take) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantStockTakeScreen(takeId: take.takeId),
      ),
    );
  }

  Future<void> _cancelTake(RestaurantStockTakeModel take) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Discard ${take.takeNumber}?',
      message:
          'The count and all its lines will be deleted. Stock is not '
          'affected — nothing was applied.',
      confirmLabel: 'Discard',
      accent: AppColors.danger,
    );
    if (!confirmed) return;

    final ok = await restaurantStockTakeStore.cancelTake(take.takeId);
    if (!mounted) return;
    if (ok) {
      NotificationService.instance.showSuccess('Stock take discarded');
    } else {
      NotificationService.instance.showError(
        restaurantStockTakeStore.errorMessage ??
            'Could not discard stock take.',
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
            final takes = restaurantStockTakeStore.takes;
            final draftCount = takes.where((t) => t.isDraft).length;
            final completedCount = takes.where((t) => t.isCompleted).length;

            final Widget content;
            if (restaurantStockTakeStore.isLoading && takes.isEmpty) {
              content = const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            } else if (takes.isEmpty) {
              content = const AppEmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No stock takes yet',
                message:
                    'Count your raw materials and apply the variances '
                    'in one go, instead of correcting items one at a time. '
                    'Start one with the New Count button.',
              );
            } else {
              content = ListView.builder(
                padding: AppResponsive.padding(context),
                itemCount: takes.length,
                itemBuilder: (context, i) => _buildCard(context, takes[i]),
              );
            }

            return Column(
              children: [
                GradientHeroHeader(
                  title: 'Stock Takes',
                  subtitle:
                      'Physically count raw materials and apply variances in one go',
                  icon: Icons.fact_check_rounded,
                  accent: AppColors.warning,
                  stats: [
                    HeroStat(
                      icon: Icons.list_alt_rounded,
                      value: '${takes.length}',
                      label: 'Total Counts',
                    ),
                    HeroStat(
                      icon: Icons.edit_note_rounded,
                      value: '$draftCount',
                      label: 'In Progress',
                    ),
                    HeroStat(
                      icon: Icons.task_alt_rounded,
                      value: '$completedCount',
                      label: 'Completed',
                    ),
                  ],
                ),
                Expanded(
                  child: AppResponsive.constrainedContent(
                    context: context,
                    maxWidth: AppResponsive.maxContentWidth(context),
                    alignment: Alignment.topCenter,
                    child: content,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Always visible — it is the only way to start a count now that the
      // empty state no longer carries its own button.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startTake,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New Count',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, RestaurantStockTakeModel take) {
    final net = take.committedNetQty;
    final color = take.isCompleted
        ? AppColors.success
        : (take.isCancelled ? AppColors.textSecondary : AppColors.warning);

    return InkWell(
      onTap: () => _openTake(take),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
                // Discard stays behind the overflow menu, and only for
                // drafts — a completed take is the evidence for adjustments
                // that already happened.
                if (take.isDraft)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    take.varianceReason!,
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
/// before staff can start counting would just produce "asdf".
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
        hint: 'e.g. Walk-in fridge, Dry store, Full count',
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
