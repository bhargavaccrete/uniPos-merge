import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_return_model_174.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Colour for a return status — shared with the detail screen so both agree.
Color purchaseReturnStatusColor(PurchaseReturnStatus status) {
  switch (status) {
    case PurchaseReturnStatus.pending:
      return AppColors.warning;
    case PurchaseReturnStatus.creditReceived:
      return AppColors.success;
    case PurchaseReturnStatus.cancelled:
      return AppColors.textSecondary;
  }
}

/// Goods sent back to suppliers because they arrived damaged.
///
/// Hosted standalone or inside the Damaged Goods hub with [embedded] — the hub
/// owns the AppBar in that case, exactly like the product catalog hub.
class PurchaseReturnListScreen extends StatefulWidget {
  final bool embedded;

  const PurchaseReturnListScreen({super.key, this.embedded = false});

  @override
  State<PurchaseReturnListScreen> createState() =>
      _PurchaseReturnListScreenState();
}

class _PurchaseReturnListScreenState extends State<PurchaseReturnListScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// null = All.
  PurchaseReturnStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy').format(date);
  }

  /// Filtering is a plain list operation over the store's observable — no
  /// repository round-trip, so an update shows up immediately.
  List<PurchaseReturnModel> get _visibleReturns {
    final query = _searchController.text.trim().toLowerCase();

    return damagedGoodsStore.purchaseReturns.where((item) {
      if (_statusFilter != null && item.statusEnum != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.returnNumber.toLowerCase().contains(query) ||
          item.grnNumber.toLowerCase().contains(query) ||
          item.poNumber.toLowerCase().contains(query) ||
          (item.supplierName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _openDetail(PurchaseReturnModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseReturnDetailScreen(purchaseReturn: model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = MoneyScope(child: _buildBody(context));

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Purchase Returns'),
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
                hint: 'Search by PR, GRN, PO or supplier...',
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
        Expanded(
          child: Observer(
            builder: (context) {
              if (damagedGoodsStore.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final returns = _visibleReturns;
              if (returns.isEmpty) return _buildEmptyState();

              return ListView.builder(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                itemCount: returns.length,
                itemBuilder: (context, index) => _buildCard(returns[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    const options = <(String, PurchaseReturnStatus?)>[
      ('All', null),
      ('Pending', PurchaseReturnStatus.pending),
      ('Credit Received', PurchaseReturnStatus.creditReceived),
      ('Cancelled', PurchaseReturnStatus.cancelled),
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
      icon: filtering
          ? Icons.search_off_rounded
          : Icons.assignment_return_outlined,
      title: filtering ? 'No returns match' : 'No purchase returns yet',
      message: filtering
          ? 'Try a different search or status filter.'
          : 'Returns are raised automatically when goods are marked "Return to Supplier" while receiving a purchase order.',
    );
  }

  Widget _buildCard(PurchaseReturnModel model) {
    final color = purchaseReturnStatusColor(model.statusEnum);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => _openDetail(model),
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
                      model.returnNumber,
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
                _formatDate(model.returnDate),
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
