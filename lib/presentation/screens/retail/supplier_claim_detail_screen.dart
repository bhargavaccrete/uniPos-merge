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
                  fontSize: 13,
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
                          'That change is not allowed');
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

    NotificationService.instance
        .showSuccess('Claim ${_model.statusDisplay.toLowerCase()}');
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
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildLifecycleCard(),
                    const SizedBox(height: 16),
                    _buildSourceCard(),
                    const SizedBox(height: 16),
                    _buildItemsCard(),
                    const SizedBox(height: 20),
                    _buildActions(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final color = supplierClaimStatusColor(_model.statusEnum);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _model.statusDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _headerStat('Quantity', '${_model.totalQty}'),
              const SizedBox(width: 24),
              _headerStat('Claimed', formatMoney(_model.totalAmount)),
              const SizedBox(width: 24),
              _headerStat('Raised', _formatDate(_model.claimDate)),
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
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
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
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final stage in stages)
              Text(
                _statusLabel(stage),
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: stage == current ? FontWeight.w700 : FontWeight.w400,
                  color: stage == current
                      ? supplierClaimStatusColor(stage)
                      : AppColors.textSecondary,
                ),
              ),
          ],
        ),
        if (_model.resolutionNote?.isNotEmpty ?? false) ...[
          const SizedBox(height: 14),
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
    final color =
        reached ? supplierClaimStatusColor(stage) : AppColors.divider;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: reached ? color.withValues(alpha: 0.15) : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: reached
          ? Icon(Icons.check, size: 12, color: color)
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
                fontSize: 13, color: AppColors.textSecondary),
          ),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Unknown product',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.variantInfo?.isNotEmpty ?? false)
                        Text(
                          item.variantInfo!,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.claimedQty} pcs',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.totalAmount != null)
                      Text(
                        formatMoney(item.totalAmount!),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMedium,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'This claim is ${_model.statusDisplay.toLowerCase()} and closed — no further action available.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 12.5, color: AppColors.textSecondary),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < transitions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _applyTransition(transitions[i]),
              icon: Icon(_transitionIcon(transitions[i]), size: 18),
              label: Text(
                _transitionLabel(transitions[i]),
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: supplierClaimStatusColor(transitions[i]),
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, size: 19, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
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
