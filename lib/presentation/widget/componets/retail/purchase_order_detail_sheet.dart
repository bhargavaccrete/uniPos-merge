import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/presentation/screens/retail/add_purchase_order_screen.dart';
import 'package:billberrylite/presentation/screens/retail/material_receiving_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_detail_screen.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_loss_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_detail_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// The purchase-order detail sheet, shared by every screen that lists orders.
///
/// Lifted out of `purchase_order_list_screen.dart`, which owned it as ~900
/// lines of private State methods — which is why the supplier detail screen
/// could not tap through to it. The sheet's markup moved unchanged; only the
/// three action buttons were rewritten, because they used to call the list
/// screen's own navigation helpers.

/// Status colour for a purchase order, shared so an order reads the same
/// wherever it appears.
Color poStatusColor(POStatus status) {
  switch (status) {
    case POStatus.draft:
      return AppColors.textSecondary;
    case POStatus.sent:
      return AppColors.info;
    case POStatus.partiallyCompleted:
      return AppColors.warning;
    case POStatus.fullyCompleted:
      return AppColors.success;
    case POStatus.cancelled:
      return AppColors.danger;
  }
}

String poStatusLabel(POStatus status) {
  switch (status) {
    case POStatus.draft:
      return 'Draft';
    case POStatus.sent:
      return 'Sent';
    case POStatus.partiallyCompleted:
      return 'Partial';
    case POStatus.fullyCompleted:
      return 'Completed';
    case POStatus.cancelled:
      return 'Cancelled';
  }
}

String poFormatDate(String isoDate) {
  final date = DateTime.parse(isoDate);
  return '${date.day}/${date.month}/${date.year}';
}

/// Open the detail sheet for [po].
///
/// Resolves the per-line receiving breakdown before opening, so each row
/// renders its own ordered/received/accepted split without a FutureBuilder per
/// row.
///
/// [onChanged] fires when the sheet did something the caller's list should
/// reflect — edited, marked sent, or received. The sheet reloads the PO store
/// itself; the callback exists for callers holding their own derived state.
Future<void> showPurchaseOrderDetailSheet({
  required BuildContext context,
  required PurchaseOrderModel po,
  VoidCallback? onChanged,
}) async {
  await purchaseOrderStore.selectPO(po);
  final receipts = await purchaseOrderStore.getPOItemReceipts(po.poId);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PurchaseOrderDetailSheet(
      po: po,
      receipts: receipts,
      onChanged: onChanged,
    ),
  );
}

class PurchaseOrderDetailSheet extends StatelessWidget {
  final PurchaseOrderModel po;
  final Map<String, POItemReceipt> receipts;
  final VoidCallback? onChanged;

  const PurchaseOrderDetailSheet({
    super.key,
    required this.po,
    required this.receipts,
    this.onChanged,
  });

  // ==================== ACTIONS ====================
  //
  // Each grabs the NavigatorState BEFORE popping. Popping tears down the
  // sheet's own context, so reaching for `Navigator.of(context)` afterwards
  // would be reading a dead element — the trap that bit the parked-sales sheet.

  Future<void> _openEditor(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();

    final result = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPurchaseOrderScreen(purchaseOrder: po),
      ),
    );
    if (result == true) {
      await purchaseOrderStore.loadPurchaseOrders();
      onChanged?.call();
    }
  }

  Future<void> _openReceiving(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();

    final result = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialReceivingScreen(purchaseOrder: po),
      ),
    );
    if (result == true) {
      await purchaseOrderStore.loadPurchaseOrders();
      onChanged?.call();
    }
  }

  Future<void> _markSent(BuildContext context) async {
    final navigator = Navigator.of(context);
    await purchaseOrderStore.updatePOStatus(po.poId, POStatus.sent);

    // Guard the gap: if the sheet was dismissed while the store was writing,
    // popping now would take the route underneath it instead.
    if (!context.mounted) return;
    navigator.pop();
    NotificationService.instance.showSuccess('${po.poNumber} marked as sent');
    onChanged?.call();
  }

  /// Ordered / Received / Accepted / Damaged / Remaining for one PO line.
  ///
  /// Reporting only — the completion rule is untouched. Note Remaining tracks
  /// *received*, not *accepted*, which is why a line can read
  /// "Received 50, Accepted 48, Remaining 0": the supplier delivered
  /// everything, but two units never made it into stock.
  Widget _buildItemReceiptBreakdown(
    BuildContext context,
    POItemReceipt? receipt,
  ) {
    if (receipt == null || receipt.received == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _receiptChip(
                context,
                'Ordered',
                receipt.ordered,
                AppColors.textSecondary,
              ),
              _receiptChip(
                context,
                'Received',
                receipt.received,
                AppColors.info,
              ),
              _receiptChip(
                context,
                'Accepted',
                receipt.accepted,
                AppColors.success,
              ),
              if (receipt.damaged > 0)
                _receiptChip(
                  context,
                  'Damaged',
                  receipt.damaged,
                  AppColors.danger,
                ),
              _receiptChip(
                context,
                'Remaining',
                receipt.remaining,
                receipt.remaining == 0 ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptChip(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppResponsive.padding(context);

    // Anchored bottom but width-capped — unconstrained, this sheet stretched
    // across a full laptop window. heightFactor keeps it sized to the sheet,
    // otherwise Align fills the screen and kills tap-to-dismiss above it.
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppResponsive.maxCardWidth(context),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: pad,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            po.poNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            po.supplierName ?? 'Unknown Supplier',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppResponsive.bodyFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: poStatusColor(
                          po.statusEnum,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        poStatusLabel(po.statusEnum),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w600,
                          color: poStatusColor(po.statusEnum),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Observer(
                  builder: (context) {
                    final items = purchaseOrderStore.currentPOItems;
                    final grns = purchaseOrderStore.currentPOGRNs;

                    return SingleChildScrollView(
                      padding: pad,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            context,
                            'Expected Delivery',
                            poFormatDate(po.expectedDeliveryDate),
                          ),
                          _buildInfoRow(
                            context,
                            'Created',
                            poFormatDate(po.createdAt),
                          ),
                          _buildInfoRow(
                            context,
                            'Total Items',
                            '${po.totalItems}',
                          ),
                          if (po.estimatedTotal > 0)
                            _buildInfoRow(
                              context,
                              'Estimated Total',
                              formatMoney(po.estimatedTotal),
                            ),
                          if (po.notes != null && po.notes!.isNotEmpty)
                            _buildInfoRow(context, 'Notes', po.notes!),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                          Text(
                            'Order Items',
                            style: TextStyle(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(
                            height: AppResponsive.mediumSpacing(context),
                          ),
                          ...items.map(
                            (item) => Container(
                              margin: EdgeInsets.only(
                                bottom: AppResponsive.smallSpacing(context),
                              ),
                              padding: EdgeInsets.all(
                                AppResponsive.mediumSpacing(context),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMedium,
                                borderRadius: BorderRadius.circular(
                                  AppResponsive.smallBorderRadius(context),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName ??
                                                  'Unknown Product',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize:
                                                    AppResponsive.bodyFontSize(
                                                      context,
                                                    ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (item.variantInfo != null)
                                              Text(
                                                item.variantInfo!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      AppResponsive.smallFontSize(
                                                        context,
                                                      ),
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Qty: ${item.orderedQty}',
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize:
                                                  AppResponsive.bodyFontSize(
                                                    context,
                                                  ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (item.estimatedPrice != null)
                                            Text(
                                              formatMoney(
                                                item.estimatedTotal ?? 0,
                                              ),
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize:
                                                    AppResponsive.smallFontSize(
                                                      context,
                                                    ),
                                                color: AppColors.success,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  _buildItemReceiptBreakdown(
                                    context,
                                    receipts[item.poItemId],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // GRN History Section
                          if (grns.isNotEmpty) ...[
                            SizedBox(
                              height: AppResponsive.extraLargeSpacing(context),
                            ),
                            Text(
                              'Receiving History',
                              style: TextStyle(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(
                              height: AppResponsive.mediumSpacing(context),
                            ),
                            ...grns.map(
                              (grn) => _buildGRNSummaryCard(context, grn),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: pad,
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SizedBox(
                  height: AppResponsive.buttonHeight(context),
                  child: Row(
                    children: [
                      if (po.canEdit) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openEditor(context),
                            icon: Icon(
                              Icons.edit,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            label: const Text('Edit'),
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _markSent(context),
                            icon: Icon(
                              Icons.send,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            label: const Text('Mark Sent'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                      ] else if (po.canReceive) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openReceiving(context),
                            icon: Icon(
                              Icons.local_shipping,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            label: const Text('Receive Items'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
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
              style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGRNSummaryCard(BuildContext context, GRNModel grn) {
    return FutureBuilder<List<GRNItemModel>>(
      future: purchaseOrderStore.getGRNItemsForGRN(grn.grnId),
      builder: (context, snapshot) {
        final grnItems = snapshot.data ?? [];
        final totalAccepted = grnItems.fold<int>(
          0,
          (sum, item) => sum + item.acceptedQty,
        );
        final totalDamaged = grnItems.fold<int>(
          0,
          (sum, item) => sum + (item.damagedQty ?? 0),
        );
        final damagedAmount = grnItems.fold<double>(
          0.0,
          (sum, item) => sum + (item.damagedAmount ?? 0),
        );

        // Group damaged items by handling method
        final returnToSupplier = grnItems
            .where(
              (i) => i.damagedHandlingEnum == DamagedHandling.returnToSupplier,
            )
            .toList();
        final keepForClaim = grnItems
            .where((i) => i.damagedHandlingEnum == DamagedHandling.keepForClaim)
            .toList();
        final writeOff = grnItems
            .where((i) => i.damagedHandlingEnum == DamagedHandling.writeOff)
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GRN Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        grn.grnNumber,
                        style: TextStyle(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      poFormatDate(grn.receivedDate),
                      style: TextStyle(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // GRN Summary
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildGRNStat(
                          context,
                          'Received',
                          grn.totalReceivedQty.toString(),
                          AppColors.success,
                        ),
                        const SizedBox(width: 16),
                        _buildGRNStat(
                          context,
                          'To Stock',
                          totalAccepted.toString(),
                          AppColors.info,
                        ),
                        if (totalDamaged > 0) ...[
                          const SizedBox(width: 16),
                          _buildGRNStat(
                            context,
                            'Damaged',
                            totalDamaged.toString(),
                            AppColors.danger,
                          ),
                        ],
                        const Spacer(),
                        Text(
                          formatMoney(grn.totalAmount ?? 0),
                          style: TextStyle(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    // Damaged items breakdown
                    if (totalDamaged > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  size: 14,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalDamaged damaged (${formatMoney(damagedAmount)})',
                                  style: TextStyle(
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (returnToSupplier.isNotEmpty)
                              _buildDamagedRow(
                                context,
                                'Return to Supplier',
                                returnToSupplier.fold<int>(
                                  0,
                                  (s, i) => s + (i.damagedQty ?? 0),
                                ),
                                AppColors.warning,
                              ),
                            if (keepForClaim.isNotEmpty)
                              _buildDamagedRow(
                                context,
                                'Keep for Claim',
                                keepForClaim.fold<int>(
                                  0,
                                  (s, i) => s + (i.damagedQty ?? 0),
                                ),
                                AppColors.info,
                              ),
                            if (writeOff.isNotEmpty)
                              _buildDamagedRow(
                                context,
                                'Write Off',
                                writeOff.fold<int>(
                                  0,
                                  (s, i) => s + (i.damagedQty ?? 0),
                                ),
                                AppColors.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ],
                    _buildLinkedDocuments(context, grn),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Documents this GRN's damaged lines produced, each a shortcut into the
  /// record itself. Loaded per GRN because the paper trail lives in a different
  /// store from the receiving history.
  Widget _buildLinkedDocuments(BuildContext context, GRNModel grn) {
    return FutureBuilder<GRNDamagedDocuments>(
      future: damagedGoodsStore.documentsForGRN(grn.grnId),
      builder: (context, snapshot) {
        final docs = snapshot.data;
        if (docs == null || docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Text(
                'Linked Documents',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in docs.returns)
                    _documentLink(
                      context: context,
                      label: r.returnNumber,
                      icon: Icons.assignment_return_outlined,
                      color: purchaseReturnStatusColor(r.statusEnum),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PurchaseReturnDetailScreen(purchaseReturn: r),
                        ),
                      ),
                    ),
                  for (final c in docs.claims)
                    _documentLink(
                      context: context,
                      label: c.claimNumber,
                      icon: Icons.gavel_rounded,
                      color: supplierClaimStatusColor(c.statusEnum),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierClaimDetailScreen(claim: c),
                        ),
                      ),
                    ),
                  // Losses are read-only, so they open the list rather than a
                  // detail screen that would have no actions on it.
                  if (docs.losses.isNotEmpty)
                    _documentLink(
                      context: context,
                      label: docs.losses.length == 1
                          ? docs.losses.first.lossNumber
                          : '${docs.losses.length} write-offs',
                      icon: Icons.report_gmailerrorred_outlined,
                      color: AppColors.danger,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventoryLossListScreen(),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _documentLink({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildGRNStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDamagedRow(
    BuildContext context,
    String label,
    int qty,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Text(
            '$qty x $label',
            style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
