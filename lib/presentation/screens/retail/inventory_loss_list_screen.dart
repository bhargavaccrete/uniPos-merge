import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/inventory_loss_model_178.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Goods written off at receipt — read-only by design.
///
/// A loss is a historical fact, so there is no edit, no delete and no status.
/// Correcting one would mean recording a different event, not rewriting this.
class InventoryLossListScreen extends StatefulWidget {
  final bool embedded;

  const InventoryLossListScreen({super.key, this.embedded = false});

  @override
  State<InventoryLossListScreen> createState() => _InventoryLossListScreenState();
}

class _InventoryLossListScreenState extends State<InventoryLossListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date == null ? iso : DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  List<InventoryLossModel> get _visibleLosses {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return damagedGoodsStore.inventoryLosses.toList();

    return damagedGoodsStore.inventoryLosses.where((loss) {
      return loss.lossNumber.toLowerCase().contains(query) ||
          (loss.productName?.toLowerCase().contains(query) ?? false) ||
          (loss.supplierName?.toLowerCase().contains(query) ?? false) ||
          (loss.grnNumber?.toLowerCase().contains(query) ?? false) ||
          loss.reason.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = MoneyScope(child: _buildBody(context));

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Inventory Losses'),
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
          child: AppTextField(
            controller: _searchController,
            hint: 'Search by product, supplier, GRN or reason...',
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
        ),
        _buildTotals(isTablet),
        Expanded(
          child: Observer(
            builder: (context) {
              if (damagedGoodsStore.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final losses = _visibleLosses;
              if (losses.isEmpty) {
                final searching = _searchController.text.trim().isNotEmpty;
                return AppEmptyState(
                  icon: searching
                      ? Icons.search_off_rounded
                      : Icons.report_gmailerrorred_outlined,
                  title: searching ? 'No losses match' : 'No inventory losses',
                  message: searching
                      ? 'Try a different search term.'
                      : 'Losses are recorded automatically when goods are marked "Write Off" while receiving a purchase order.',
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                itemCount: losses.length,
                itemBuilder: (context, index) => _buildCard(losses[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotals(bool isTablet) {
    return Observer(
      builder: (context) {
        if (damagedGoodsStore.inventoryLosses.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: AppColors.danger.withValues(alpha: 0.06),
          padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.trending_down_rounded,
                  size: 15, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${damagedGoodsStore.totalLossQty} units written off • ${formatMoney(damagedGoodsStore.totalLossValue)} total',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(InventoryLossModel loss) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
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
                      loss.productName ?? 'Unknown product',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (loss.variantInfo?.isNotEmpty ?? false)
                      Text(
                        loss.variantInfo!,
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
                    '${loss.quantity} pcs',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  Text(
                    formatMoney(loss.lossValue),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _meta(Icons.tag_rounded, loss.lossNumber),
              _meta(Icons.description_outlined, loss.reason),
              if (loss.supplierName?.isNotEmpty ?? false)
                _meta(Icons.storefront_outlined, loss.supplierName!),
              if (loss.grnNumber?.isNotEmpty ?? false)
                _meta(Icons.receipt_long_outlined, loss.grnNumber!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(loss.recordedAt),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
