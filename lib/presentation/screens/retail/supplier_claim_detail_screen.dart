import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_item_model_177.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// A single supplier claim and its lifecycle.
///
/// The screen only ever offers the transitions the store permits — pending →
/// approved/rejected and approved → settled. The store re-checks anyway, so an
/// invalid move can't slip through even if this UI is wrong.
class SupplierClaimDetailScreen extends StatefulWidget {
  final SupplierClaimModel claim;

  const SupplierClaimDetailScreen({super.key, required this.claim});

  @override
  State<SupplierClaimDetailScreen> createState() =>
      _SupplierClaimDetailScreenState();
}

class _SupplierClaimDetailScreenState extends State<SupplierClaimDetailScreen> {
  late SupplierClaimModel _model;
  List<SupplierClaimItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _model = widget.claim;
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await damagedGoodsStore.getClaimItems(_model.claimId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  /// Transitions offered for the current status — the single place the UI
  /// decides what's legal, mirroring the store's own guard.
  List<SupplierClaimStatus> get _availableTransitions {
    switch (_model.statusEnum) {
      case SupplierClaimStatus.pending:
        return [SupplierClaimStatus.approved, SupplierClaimStatus.rejected];
      case SupplierClaimStatus.approved:
        return [SupplierClaimStatus.settled];
      case SupplierClaimStatus.rejected:
      case SupplierClaimStatus.settled:
        return const [];
    }
  }

  String _transitionLabel(SupplierClaimStatus status) {
    switch (status) {
      case SupplierClaimStatus.approved:
        return 'Approve';
      case SupplierClaimStatus.rejected:
        return 'Reject';
      case SupplierClaimStatus.settled:
        return 'Mark Settled';
      case SupplierClaimStatus.pending:
        return 'Pending';
    }
  }

  IconData _transitionIcon(SupplierClaimStatus status) {
    switch (status) {
      case SupplierClaimStatus.approved:
        return Icons.check_circle_outline;
      case SupplierClaimStatus.rejected:
        return Icons.cancel_outlined;
      case SupplierClaimStatus.settled:
        return Icons.task_alt_rounded;
      case SupplierClaimStatus.pending:
        return Icons.hourglass_top_rounded;
    }
  }

  Future<void> _applyTransition(SupplierClaimStatus target) async {
    final noteController = TextEditingController();
    final accent = supplierClaimStatusColor(target);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [noteController],
        child: AppDialogShell(
          title: '${_transitionLabel(target)} claim?',
          subtitle: _model.claimNumber,
          accent: accent,
          icon: _transitionIcon(target),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _transitionExplanation(target),
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: noteController,
                label: 'Resolution note',
                hint: 'Optional — what the supplier said',
                icon: Icons.sticky_note_2_outlined,
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: _transitionLabel(target),
              color: accent,
              onPressed: () async {
                final note = noteController.text.trim();
                final ok = await damagedGoodsStore.updateClaimStatus(
                  claimId: _model.claimId,
                  status: target,
                  resolutionNote: note.isEmpty ? null : note,
                );

                if (!dialogContext.mounted) return;
                if (!ok) {
                  NotificationService.instance.showError(
                    damagedGoodsStore.errorMessage ??
                        'That change is not allowed',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final updated = damagedGoodsStore.supplierClaims
        .where((c) => c.claimId == _model.claimId)
        .firstOrNull;
    if (updated != null) setState(() => _model = updated);

    NotificationService.instance.showSuccess(
      'Claim ${_model.statusDisplay.toLowerCase()}',
    );
  }

  String _transitionExplanation(SupplierClaimStatus target) {
    switch (target) {
      case SupplierClaimStatus.approved:
        return 'The supplier accepted the claim. Settlement is still outstanding — '
            'mark it Settled once compensation is agreed.';
      case SupplierClaimStatus.rejected:
        return 'The supplier refused the claim, so the damaged goods stay a loss '
            'for the business. This closes the claim.';
      case SupplierClaimStatus.settled:
        return 'Compensation has been received or written down. This closes the claim.';
      case SupplierClaimStatus.pending:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: _model.claimNumber),
      body: MoneyScope(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppResponsive.padding(context).left,
                  AppResponsive.mediumSpacing(context),
                  AppResponsive.padding(context).left,
                  AppResponsive.largeSpacing(context),
                ),
                child: _capped(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildLifecycleCard(),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildSourceCard(),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildItemsCard(),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Caps content width on large screens so a stack of detail cards doesn't
  /// stretch across a laptop.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxCardWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter, not Center: Center aligns on BOTH axes, so a
      // shrink-wrapping child floats in the vertical middle.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildHeaderCard() {
    final color = supplierClaimStatusColor(_model.statusEnum);

    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _model.supplierName ?? 'Unknown supplier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _model.statusDisplay,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          // Expanded thirds, not fixed 24px gaps — "Claimed ₹12,345.00" plus a
          // date needed more than a 320px phone had, and the Row overflowed.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _headerStat('Quantity', '${_model.totalQty}')),
              Expanded(
                child: _headerStat('Claimed', formatMoney(_model.totalAmount)),
              ),
              Expanded(
                child: _headerStat('Raised', _formatDate(_model.claimDate)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Visual pipeline so it's obvious where the claim sits and what's next.
  Widget _buildLifecycleCard() {
    final current = _model.statusEnum;
    final rejected = current == SupplierClaimStatus.rejected;

    final stages = rejected
        ? [SupplierClaimStatus.pending, SupplierClaimStatus.rejected]
        : [
            SupplierClaimStatus.pending,
            SupplierClaimStatus.approved,
            SupplierClaimStatus.settled,
          ];

    final currentIndex = stages.indexOf(current);

    return _card(
      title: 'Progress',
      icon: Icons.timeline_rounded,
      children: [
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= currentIndex
                        ? supplierClaimStatusColor(stages[i])
                        : AppColors.divider,
                  ),
                ),
              _stageDot(stages[i], reached: i <= currentIndex),
            ],
          ],
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final stage in stages)
              Text(
                _statusLabel(stage),
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  fontWeight: stage == current
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: stage == current
                      ? supplierClaimStatusColor(stage)
                      : AppColors.textSecondary,
                ),
              ),
          ],
        ),
        if (_model.resolutionNote?.isNotEmpty ?? false) ...[
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          _row('Resolution', _model.resolutionNote!),
        ],
        if (_model.resolvedAt != null)
          _row('Closed on', _formatDate(_model.resolvedAt)),
      ],
    );
  }

  String _statusLabel(SupplierClaimStatus status) {
    switch (status) {
      case SupplierClaimStatus.pending:
        return 'Pending';
      case SupplierClaimStatus.approved:
        return 'Approved';
      case SupplierClaimStatus.rejected:
        return 'Rejected';
      case SupplierClaimStatus.settled:
        return 'Settled';
    }
  }

  Widget _stageDot(SupplierClaimStatus stage, {required bool reached}) {
    final color = reached ? supplierClaimStatusColor(stage) : AppColors.divider;
    final dot = AppResponsive.getValue(
      context,
      mobile: 22.0,
      tablet: 26.0,
      desktop: 30.0,
    );
    return Container(
      width: dot,
      height: dot,
      decoration: BoxDecoration(
        color: reached ? color.withValues(alpha: 0.15) : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: reached
          ? Icon(Icons.check, size: dot * 0.55, color: color)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSourceCard() {
    return _card(
      title: 'Source Documents',
      icon: Icons.link_rounded,
      children: [
        _row('Purchase Order', _model.poNumber),
        _row('GRN', _model.grnNumber),
        _row('Supplier', _model.supplierName ?? '—'),
        if (_model.notes?.isNotEmpty ?? false) _row('Notes', _model.notes!),
      ],
    );
  }

  Widget _buildItemsCard() {
    return _card(
      title: 'Claimed Items',
      icon: Icons.inventory_2_outlined,
      children: [
        if (_items.isEmpty)
          Text(
            'No line items recorded.',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        for (final item in _items)
          Padding(
            padding: EdgeInsets.only(
              bottom: AppResponsive.smallSpacing(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Unknown product',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.variantInfo?.isNotEmpty ?? false)
                        Text(
                          item.variantInfo!,
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
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.claimedQty} pcs',
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.totalAmount != null)
                      Text(
                        formatMoney(item.totalAmount!),
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    final transitions = _availableTransitions;

    if (transitions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
        decoration: BoxDecoration(
          color: AppColors.surfaceMedium,
          borderRadius: BorderRadius.circular(
            AppResponsive.smallBorderRadius(context),
          ),
        ),
        child: Text(
          'This claim is ${_model.statusDisplay.toLowerCase()} and closed — no further action available.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < transitions.length; i++) ...[
          if (i > 0) SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _applyTransition(transitions[i]),
              icon: Icon(
                _transitionIcon(transitions[i]),
                size: AppResponsive.smallIconSize(context),
              ),
              label: Text(
                _transitionLabel(transitions[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: supplierClaimStatusColor(transitions[i]),
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue(
                    context,
                    mobile: 13.0,
                    tablet: 15.0,
                    desktop: 17.0,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==================== SHARED BITS ====================

  Widget _card({
    required String title,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    final side = AppResponsive.padding(context).left;
    final vGap = AppResponsive.mediumSpacing(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, vGap, side, vGap),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppResponsive.iconSize(context),
                  color: iconColor ?? AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: EdgeInsets.fromLTRB(side, vGap, side, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capped label column: wide enough for the longest label, but it stops
          // growing on a laptop so every extra pixel goes to the value.
          SizedBox(
            width: AppResponsive.getValue(
              context,
              mobile: 110.0,
              tablet: 130.0,
              desktop: 150.0,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
