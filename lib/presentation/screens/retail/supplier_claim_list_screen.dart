import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_claim_model_176.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Colour for a claim status — shared with the detail screen.
Color supplierClaimStatusColor(SupplierClaimStatus status) {
  switch (status) {
    case SupplierClaimStatus.pending:
      return AppColors.warning;
    case SupplierClaimStatus.approved:
      return AppColors.info;
    case SupplierClaimStatus.rejected:
      return AppColors.danger;
    case SupplierClaimStatus.settled:
      return AppColors.success;
  }
}

/// Damaged goods kept on site while compensation is pursued with the supplier.
class SupplierClaimListScreen extends StatefulWidget {
  final bool embedded;

  const SupplierClaimListScreen({super.key, this.embedded = false});

  @override
  State<SupplierClaimListScreen> createState() => _SupplierClaimListScreenState();
}

class _SupplierClaimListScreenState extends State<SupplierClaimListScreen> {
  final TextEditingController _searchController = TextEditingController();
  SupplierClaimStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  List<SupplierClaimModel> get _visibleClaims {
    final query = _searchController.text.trim().toLowerCase();

    return damagedGoodsStore.supplierClaims.where((item) {
      if (_statusFilter != null && item.statusEnum != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.claimNumber.toLowerCase().contains(query) ||
          item.grnNumber.toLowerCase().contains(query) ||
          item.poNumber.toLowerCase().contains(query) ||
          (item.supplierName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = MoneyScope(child: _buildBody(context));

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Supplier Claims'),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: EdgeInsets.fromLTRB(
              isTablet ? 20 : 16, isTablet ? 16 : 12, isTablet ? 20 : 16, 12),
          child: Column(
            children: [
              AppTextField(
                controller: _searchController,
                hint: 'Search by claim, GRN, PO or supplier...',
                icon: Icons.search_rounded,
                onChanged: (_) => setState(() {}),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _buildStatusFilter(),
            ],
          ),
        ),
        _buildOpenSummary(isTablet),
        Expanded(
          child: Observer(
            builder: (context) {
              if (damagedGoodsStore.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final claims = _visibleClaims;
              if (claims.isEmpty) return _buildEmptyState();

              return ListView.builder(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                itemCount: claims.length,
                itemBuilder: (context, index) => _buildCard(claims[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Open claims are money still in dispute — worth surfacing above the list.
  Widget _buildOpenSummary(bool isTablet) {
    return Observer(
      builder: (context) {
        final count = damagedGoodsStore.openClaimCount;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: AppColors.warning.withValues(alpha: 0.08),
          padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  size: 15, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count open claim${count == 1 ? '' : 's'} • ${formatMoney(damagedGoodsStore.openClaimValue)} awaiting supplier decision',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusFilter() {
    const options = <(String, SupplierClaimStatus?)>[
      ('All', null),
      ('Pending', SupplierClaimStatus.pending),
      ('Approved', SupplierClaimStatus.approved),
      ('Settled', SupplierClaimStatus.settled),
      ('Rejected', SupplierClaimStatus.rejected),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, status) = options[index];
          final selected = _statusFilter == status;
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = status),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final filtering =
        _statusFilter != null || _searchController.text.trim().isNotEmpty;

    return AppEmptyState(
      icon: filtering ? Icons.search_off_rounded : Icons.gavel_rounded,
      title: filtering ? 'No claims match' : 'No supplier claims yet',
      message: filtering
          ? 'Try a different search or status filter.'
          : 'Claims are raised automatically when goods are marked "Keep for Claim" while receiving a purchase order.',
    );
  }

  Widget _buildCard(SupplierClaimModel model) {
    final color = supplierClaimStatusColor(model.statusEnum);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: model.isOpen
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupplierClaimDetailScreen(claim: model),
            ),
          );
          if (mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model.claimNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AppStatusPill(label: model.statusDisplay, color: color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                model.supplierName ?? 'Unknown supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${model.grnNumber}  •  ${model.poNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${model.totalQty} pcs  •  ${formatMoney(model.totalAmount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(model.claimDate),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
