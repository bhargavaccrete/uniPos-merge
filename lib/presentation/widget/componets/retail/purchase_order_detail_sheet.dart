import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/quantity_format.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_item_model_212.dart';
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
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
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

/// Digits only — wa.me rejects spaces, dashes and a leading '+'.
String cleanRetailSupplierPhone(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9]'), '');
}

/// One PO line as "Name (Variant)".
///
/// Reads the line's denormalized [PurchaseOrderItemModel.productName] and
/// `variantInfo` instead of looking the product up, so a PO still reads
/// correctly after a product is renamed or deleted.
String _poLineLabel(PurchaseOrderItemModel item) {
  final variantInfo = item.variantInfo;
  final variantStr = (variantInfo == null || variantInfo.isEmpty)
      ? ''
      : ' ($variantInfo)';
  return '${item.productName ?? 'Unknown Product'}$variantStr';
}

/// Supplier-facing text for a purchase order.
///
/// The wording follows the order's status, because the same button is on the
/// sheet from "sent" all the way to "completed" and one text cannot serve all
/// three: asking a supplier to deliver goods they already delivered reads as a
/// duplicate order. [receipts] (keyed by `poItemId`, from
/// `purchaseOrderStore.getPOItemReceipts`) is what makes the received/pending
/// split possible; without it every line is treated as still outstanding.
///
/// [unitsByVariantId] is resolved by the caller because the unit lives on the
/// variant, not on the PO line.
String buildRetailWhatsAppPOMessage({
  required PurchaseOrderModel po,
  required List<PurchaseOrderItemModel> items,
  Map<String, String> unitsByVariantId = const {},
  Map<String, POItemReceipt> receipts = const {},
}) {
  String unitOf(PurchaseOrderItemModel item) =>
      unitsByVariantId[item.variantId] ?? '';

  switch (po.statusEnum) {
    case POStatus.fullyCompleted:
      return _completedPOMessage(po, items, unitOf, receipts);
    case POStatus.partiallyCompleted:
      return _partialPOMessage(po, items, unitOf, receipts);
    case POStatus.draft:
    case POStatus.sent:
    case POStatus.cancelled:
      return _openPOMessage(po, items, unitOf);
  }
}

/// Nothing received yet — the original "please supply this" order.
String _openPOMessage(
  PurchaseOrderModel po,
  List<PurchaseOrderItemModel> items,
  String Function(PurchaseOrderItemModel) unitOf,
) {
  final buffer = StringBuffer();
  buffer.writeln('Purchase Order: ${po.poNumber}');
  buffer.writeln('Supplier: ${po.supplierName ?? 'Unknown'}');
  buffer.writeln('Expected Delivery: ${poFormatDate(po.expectedDeliveryDate)}');
  if (po.notes?.isNotEmpty == true) {
    buffer.writeln('Notes: ${po.notes}');
  }
  buffer.writeln();
  buffer.writeln('Items:');
  for (final item in items) {
    buffer.writeln(
      '- ${_poLineLabel(item)}'
      ' — Qty: ${formatQtyWithUnit(item.orderedQty, unitOf(item))}',
    );
  }
  if (po.estimatedTotal > 0) {
    buffer.writeln();
    buffer.writeln('Estimated Total: ${formatMoney(po.estimatedTotal)}');
  }

  return buffer.toString().trim();
}

/// Part-delivered — a follow-up on what is still owed, with what already
/// arrived acknowledged so the supplier can reconcile against their own record.
String _partialPOMessage(
  PurchaseOrderModel po,
  List<PurchaseOrderItemModel> items,
  String Function(PurchaseOrderItemModel) unitOf,
  Map<String, POItemReceipt> receipts,
) {
  final buffer = StringBuffer();
  buffer.writeln('Purchase Order: ${po.poNumber}');
  buffer.writeln('Supplier: ${po.supplierName ?? 'Unknown'}');
  buffer.writeln('Status: Partially received');
  buffer.writeln('Expected Delivery: ${poFormatDate(po.expectedDeliveryDate)}');
  buffer.writeln();

  final pending = <String>[];
  final received = <String>[];
  for (final item in items) {
    final receipt = receipts[item.poItemId];
    // No receipt row means nothing was confirmed against the line, so the whole
    // ordered quantity is still outstanding.
    final got = receipt?.received ?? 0;
    final left = receipt?.remaining ?? item.orderedQty;
    if (left > 0) {
      pending.add(
        '- ${_poLineLabel(item)} — Pending:'
        ' ${formatQtyWithUnit(left, unitOf(item))}'
        ' (of ${formatQty(item.orderedQty)})',
      );
    }
    if (got > 0) {
      received.add(
        '- ${_poLineLabel(item)} — ${formatQtyWithUnit(got, unitOf(item))}',
      );
    }
  }

  if (pending.isNotEmpty) {
    buffer.writeln('Still pending:');
    pending.forEach(buffer.writeln);
    buffer.writeln();
  }
  if (received.isNotEmpty) {
    buffer.writeln('Already received:');
    received.forEach(buffer.writeln);
    buffer.writeln();
  }

  buffer.writeln(
    'Please confirm when the pending items will be delivered. Thank you.',
  );

  return buffer.toString().trim();
}

/// Everything delivered — an acknowledgement, not a request. Quantities are
/// what the supplier DELIVERED (received), not what passed inspection: damaged
/// units are settled through their own return or claim document.
String _completedPOMessage(
  PurchaseOrderModel po,
  List<PurchaseOrderItemModel> items,
  String Function(PurchaseOrderItemModel) unitOf,
  Map<String, POItemReceipt> receipts,
) {
  final buffer = StringBuffer();
  buffer.writeln('Purchase Order: ${po.poNumber}');
  buffer.writeln('Supplier: ${po.supplierName ?? 'Unknown'}');
  buffer.writeln('Status: Fully received');
  buffer.writeln();
  buffer.writeln('Received items:');
  for (final item in items) {
    final got = receipts[item.poItemId]?.received ?? item.orderedQty;
    buffer.writeln(
      '- ${_poLineLabel(item)} — ${formatQtyWithUnit(got, unitOf(item))}',
    );
  }
  if (po.estimatedTotal > 0) {
    buffer.writeln();
    buffer.writeln('Order Value: ${formatMoney(po.estimatedTotal)}');
  }
  buffer.writeln();
  buffer.writeln('This order is now complete. Thank you for the delivery.');

  return buffer.toString().trim();
}

/// Opens WhatsApp with the purchase order prefilled for [phone].
Future<void> shareRetailPOToWhatsApp({
  required PurchaseOrderModel po,
  required List<PurchaseOrderItemModel> items,
  required String phone,
  Map<String, POItemReceipt> receipts = const {},
}) async {
  final cleanPhone = cleanRetailSupplierPhone(phone);
  if (cleanPhone.isEmpty) {
    NotificationService.instance.showError(
      'Supplier mobile number is not available.',
    );
    return;
  }

  // Units are resolved here rather than in the builder: a bare "Qty: 2.5" is
  // ambiguous for anything sold by weight or volume, and the PO line doesn't
  // carry the unit. Cached per variant so a repeated product costs one read.
  final units = <String, String>{};
  for (final item in items) {
    if (units.containsKey(item.variantId)) continue;
    final variant = await productStore.getVariantById(item.variantId);
    if (variant != null) units[item.variantId] = variant.effectiveUnit;
  }

  final message = buildRetailWhatsAppPOMessage(
    po: po,
    items: items,
    unitsByVariantId: units,
    receipts: receipts,
  );
  final uri = Uri.parse(
    'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
  );

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      NotificationService.instance.showError('Could not launch WhatsApp.');
    }
  } catch (e) {
    NotificationService.instance.showError('Could not launch WhatsApp: $e');
  }
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

  /// Supplier phone for this PO, or null when there isn't a usable one.
  ///
  /// Reads [supplierStore] because the PO only denormalizes the supplier's
  /// name, not their number.
  String? get _supplierPhone {
    for (final s in supplierStore.suppliers) {
      if (s.supplierId != po.supplierId) continue;
      final phone = s.phone?.trim() ?? '';
      return phone.isEmpty ? null : phone;
    }
    return null;
  }

  /// A PO is shareable once it has left draft — there is nothing to send a
  /// supplier before that, and a cancelled order shouldn't be re-sent.
  bool get _canShare =>
      po.statusEnum != POStatus.draft && po.statusEnum != POStatus.cancelled;

  Future<void> _markSent(BuildContext context) async {
    final navigator = Navigator.of(context);
    // Captured before the write: `onChanged` can reload the store's selection,
    // and the share offered below still needs this order's lines.
    final items = purchaseOrderStore.currentPOItems.toList();
    final phone = _supplierPhone;

    await purchaseOrderStore.updatePOStatus(po.poId, POStatus.sent);

    // Guard the gap: if the sheet was dismissed while the store was writing,
    // popping now would take the route underneath it instead.
    if (!context.mounted) return;
    navigator.pop();
    NotificationService.instance.showSuccess('${po.poNumber} marked as sent');
    onChanged?.call();

    if (phone == null) return;

    // The navigator's context, not `context` — the sheet's element died with
    // the pop above, so the guard has to be on the context actually used.
    final navContext = navigator.context;
    if (!navContext.mounted) return;
    final wantShare = await showAppConfirmDialog(
      context: navContext,
      title: 'Purchase Order sent',
      message:
          'Would you like to share this Purchase Order with the supplier on WhatsApp?',
      confirmLabel: 'Share on WhatsApp',
      cancelLabel: 'Not Now',
      accent: AppColors.success,
      icon: Icons.share_rounded,
    );
    if (!wantShare) return;

    await shareRetailPOToWhatsApp(po: po, items: items, phone: phone);
  }

  Future<void> _shareToWhatsApp() async {
    final phone = _supplierPhone;
    if (phone == null) {
      NotificationService.instance.showError(
        'Supplier mobile number is not available.',
      );
      return;
    }
    await shareRetailPOToWhatsApp(
      po: po,
      items: purchaseOrderStore.currentPOItems.toList(),
      phone: phone,
      receipts: receipts,
    );
  }

  /// What the share button says, matched to what the message will actually be.
  String get _shareLabel {
    switch (po.statusEnum) {
      case POStatus.partiallyCompleted:
        return 'Follow Up';
      case POStatus.fullyCompleted:
        return 'Confirm Delivery';
      case POStatus.draft:
      case POStatus.sent:
      case POStatus.cancelled:
        return 'WhatsApp PO';
    }
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
      padding: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.divider),
          SizedBox(height: AppResponsive.smallSpacing(context)),
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
    double value,
    Color color,
  ) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          TextSpan(
            text: formatQty(value),
            style: GoogleFonts.poppins(
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
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppResponsive.largeBorderRadius(context)),
            ),
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
                            style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
                        borderRadius: BorderRadius.circular(
                          AppResponsive.largeBorderRadius(context),
                        ),
                      ),
                      child: Text(
                        poStatusLabel(po.statusEnum),
                        maxLines: 1,
                        style: GoogleFonts.poppins(
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
                            style: GoogleFonts.poppins(
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
                                              style: GoogleFonts.poppins(
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
                                                style: GoogleFonts.poppins(
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
                                      SizedBox(
                                        width: AppResponsive.smallSpacing(
                                          context,
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Qty: ${item.orderedQty}',
                                            maxLines: 1,
                                            style: GoogleFonts.poppins(
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
                                              style: GoogleFonts.poppins(
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
                              style: GoogleFonts.poppins(
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
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SizedBox(
                  height: AppResponsive.buttonHeight(context),
                  // Additive, not an if/else chain: sharing is orthogonal to
                  // receiving, so a sent PO has to be able to offer both. The
                  // old chain let exactly one branch render, which is why the
                  // WhatsApp action had nowhere to live.
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
                            label: Text('Edit'),
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
                            label: const Text(
                              'Mark Sent',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                      if (_canShare) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            // Stays tappable without a number so it can say
                            // why, rather than vanishing unexplained.
                            onPressed: _shareToWhatsApp,
                            icon: Icon(
                              Icons.share_rounded,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            label: Text(
                              _shareLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _supplierPhone == null
                                  ? AppColors.textSecondary
                                  : AppColors.success,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                        if (po.canReceive)
                          SizedBox(width: AppResponsive.mediumSpacing(context)),
                      ],
                      if (po.canReceive)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openReceiving(context),
                            icon: Icon(
                              Icons.local_shipping,
                              size: AppResponsive.smallIconSize(context),
                            ),
                            label: const Text(
                              'Receive Items',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ),
                      // Only when nothing else rendered — a cancelled order.
                      if (!po.canEdit && !_canShare && !po.canReceive)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
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
        final totalAccepted = grnItems.fold<double>(
          0.0,
          (sum, item) => sum + item.acceptedQty,
        );
        final totalDamaged = grnItems.fold<double>(
          0.0,
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
          margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GRN Header
              Container(
                padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: AppResponsive.smallIconSize(context),
                      color: AppColors.primary,
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    Expanded(
                      child: Text(
                        grn.grnNumber,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      poFormatDate(grn.receivedDate),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // GRN Summary
              Padding(
                padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
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
                        SizedBox(width: AppResponsive.largeSpacing(context)),
                        _buildGRNStat(
                          context,
                          'To Stock',
                          totalAccepted.toString(),
                          AppColors.info,
                        ),
                        if (totalDamaged > 0) ...[
                          SizedBox(width: AppResponsive.largeSpacing(context)),
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
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    // Damaged items breakdown
                    if (totalDamaged > 0) ...[
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      Container(
                        padding: EdgeInsets.all(
                          AppResponsive.smallSpacing(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  size: AppResponsive.smallIconSize(context),
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalDamaged damaged (${formatMoney(damagedAmount)})',
                                  style: GoogleFonts.poppins(
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
                                returnToSupplier.fold<double>(
                                  0.0,
                                  (s, i) => s + (i.damagedQty ?? 0),
                                ),
                                AppColors.warning,
                              ),
                            if (keepForClaim.isNotEmpty)
                              _buildDamagedRow(
                                context,
                                'Keep for Claim',
                                keepForClaim.fold<double>(
                                  0.0,
                                  (s, i) => s + (i.damagedQty ?? 0),
                                ),
                                AppColors.info,
                              ),
                            if (writeOff.isNotEmpty)
                              _buildDamagedRow(
                                context,
                                'Write Off',
                                writeOff.fold<double>(
                                  0.0,
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
          padding: EdgeInsets.only(top: AppResponsive.mediumSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.divider),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                'Linked Documents',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppResponsive.smallSpacing(context)),
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
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.smallSpacing(context),
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: AppResponsive.smallIconSize(context),
              color: color,
            ),
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
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
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
    double qty,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          SizedBox(width: 6),
          Text(
            '$qty x $label',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
