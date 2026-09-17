import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_item_model.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_purchase_order_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/purchase_order/add_purchase_order_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/purchase_order/goods_receiving_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Restaurant Purchase Orders list — status badges, tap for a detail sheet,
/// "Mark Sent" / "Receive" actions. See docs/inventory_recipe_system_plan.md §6.2.
class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

Color poStatusColor(RestaurantPOStatus status) {
  switch (status) {
    case RestaurantPOStatus.draft:
      return AppColors.textSecondary;
    case RestaurantPOStatus.sent:
      return AppColors.info;
    case RestaurantPOStatus.partiallyReceived:
      return AppColors.orange;
    case RestaurantPOStatus.completed:
      return AppColors.success;
    case RestaurantPOStatus.cancelled:
      return AppColors.danger;
  }
}

String poStatusLabel(RestaurantPOStatus status) {
  switch (status) {
    case RestaurantPOStatus.draft:
      return 'Draft';
    case RestaurantPOStatus.sent:
      return 'Sent';
    case RestaurantPOStatus.partiallyReceived:
      return 'Partial';
    case RestaurantPOStatus.completed:
      return 'Completed';
    case RestaurantPOStatus.cancelled:
      return 'Cancelled';
  }
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  @override
  void initState() {
    super.initState();
    restaurantSupplierStore.loadSuppliers();
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddPurchaseOrderScreen()),
    );
    if (result == true) {
      restaurantPurchaseOrderStore.loadPurchaseOrders();
    }
  }

  Future<void> _navigateToReceiving(RestaurantPurchaseOrderModel po) async {
    // No reload on return: confirmGRN reloads purchase orders and GRNs itself.
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GoodsReceivingScreen(purchaseOrder: po),
      ),
    );
  }

  Future<void> _markSent(RestaurantPurchaseOrderModel po) async {
    await restaurantPurchaseOrderStore.markPOSent(po.poId);
    if (!mounted) return;
    NotificationService.instance.showSuccess('${po.poNumber} marked as Sent');

    final supplier = restaurantSupplierStore.suppliers
        .where((s) => s.supplierId == po.supplierId)
        .firstOrNull;
    final phone = supplier?.phone;

    if (phone != null && phone.trim().isNotEmpty) {
      final wantShare = await showAppConfirmDialog(
        context: context,
        title: 'Purchase Order sent',
        message:
            'Would you like to share this Purchase Order with the supplier on WhatsApp?',
        confirmLabel: 'Share on WhatsApp',
        cancelLabel: 'Not Now',
        accent: AppColors.success,
        icon: Icons.share_rounded,
      );
      if (wantShare && mounted) {
        final items = restaurantPurchaseOrderItemRepository.getItemsByPOId(
          po.poId,
        );
        await sharePurchaseOrderToWhatsApp(
          context: context,
          po: po,
          items: items,
          phone: phone,
        );
      }
    }
  }

  void _showDetail(RestaurantPurchaseOrderModel po) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PODetailSheet(
        po: po,
        onMarkSent: () async {
          Navigator.pop(context);
          await _markSent(po);
        },
        onReceive: () {
          Navigator.pop(context);
          _navigateToReceiving(po);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(title: 'Purchase Orders'),
        body: Observer(
          builder: (context) {
            final pos = restaurantPurchaseOrderStore.purchaseOrders.toList();

            final openCount = pos
                .where(
                  (p) =>
                      p.statusEnum == RestaurantPOStatus.sent ||
                      p.statusEnum == RestaurantPOStatus.partiallyReceived,
                )
                .length;
            final draftCount = pos
                .where((p) => p.statusEnum == RestaurantPOStatus.draft)
                .length;

            return Column(
              children: [
                GradientHeroHeader(
                  title: 'Purchase Orders',
                  subtitle:
                      'Order raw materials from suppliers and receive them in',
                  icon: Icons.local_shipping_rounded,
                  accent: AppColors.info,
                  stats: [
                    HeroStat(
                      icon: Icons.receipt_long_rounded,
                      value: '${pos.length}',
                      label: 'Total POs',
                    ),
                    HeroStat(
                      icon: Icons.pending_actions_rounded,
                      value: '$openCount',
                      label: 'Awaiting Receipt',
                    ),
                    HeroStat(
                      icon: Icons.edit_note_rounded,
                      value: '$draftCount',
                      label: 'Drafts',
                    ),
                  ],
                ),
                // Hero stays full-bleed; only the card list narrows.
                Expanded(
                  child: AppResponsive.constrainedContent(
                    context: context,
                    maxWidth: AppResponsive.maxContentWidth(context),
                    alignment: Alignment.topCenter,
                    child: pos.isEmpty
                        ? AppEmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'No purchase orders yet',
                            message: 'Create your first PO using the + button',
                            action: appEmptyStateAction(
                              label: 'Create Purchase Order',
                              onPressed: _navigateToAdd,
                            ),
                          )
                        : ListView.builder(
                            padding: AppResponsive.padding(context),
                            itemCount: pos.length,
                            itemBuilder: (context, index) =>
                                _buildPOCard(pos[index]),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToAdd,
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPOCard(RestaurantPurchaseOrderModel po) {
    final radius = 16.0;
    final status = po.statusEnum;
    final statusColor = poStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: statusColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showDetail(po),
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: AppResponsive.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      po.poNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      poStatusLabel(status),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                po.supplierName ?? 'Unknown Supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Wrap(
                spacing: AppResponsive.mediumSpacing(context),
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _metaItem(
                    Icons.calendar_today,
                    'Delivery: ${_formatDate(po.expectedDeliveryDate)}',
                    AppColors.textSecondary,
                  ),
                  _metaItem(
                    Icons.inventory_2,
                    '${po.totalItems} items',
                    AppColors.info,
                  ),
                  if (po.estimatedTotal > 0)
                    Text(
                      formatMoney(po.estimatedTotal),
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (status == RestaurantPOStatus.draft) ...[
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.buttonHeight(context),
                  child: OutlinedButton.icon(
                    onPressed: () => _markSent(po),
                    icon: Icon(
                      Icons.send,
                      size: AppResponsive.smallIconSize(context),
                    ),
                    label: const Text('Mark Sent'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ] else if (po.canReceive) ...[
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.buttonHeight(context),
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToReceiving(po),
                    icon: Icon(
                      Icons.local_shipping,
                      size: AppResponsive.smallIconSize(context),
                    ),
                    label: const Text('Receive'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: color,
          ),
        ),
      ],
    );
  }

  static String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// PO detail bottom sheet: line items + Mark Sent / Receive actions.
class _PODetailSheet extends StatefulWidget {
  final RestaurantPurchaseOrderModel po;
  final VoidCallback onMarkSent;
  final VoidCallback onReceive;

  const _PODetailSheet({
    required this.po,
    required this.onMarkSent,
    required this.onReceive,
  });

  @override
  State<_PODetailSheet> createState() => _PODetailSheetState();
}

class _PODetailSheetState extends State<_PODetailSheet> {
  List<RestaurantPurchaseOrderItemModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _items = restaurantPurchaseOrderItemRepository.getItemsByPOId(
        widget.po.poId,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final po = widget.po;
    final status = po.statusEnum;
    final supplier = restaurantSupplierStore.suppliers
        .where((s) => s.supplierId == po.supplierId)
        .firstOrNull;
    final phone = supplier?.phone;

    return MoneyScope(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            po.poNumber,
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: poStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            poStatusLabel(status),
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: poStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      po.supplierName ?? 'Unknown Supplier',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (po.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        po.notes!,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? const AppEmptyState(
                        dense: true,
                        icon: Icons.inventory_2_outlined,
                        title: 'No line items',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 20),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName ?? 'Unknown Item',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: AppResponsive.bodyFontSize(
                                          context,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Qty: ${item.orderedQty}'
                                      '${item.estimatedPrice != null ? ' @ ${formatMoney(item.estimatedPrice!)}' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.smallFontSize(
                                          context,
                                        ),
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.estimatedTotal != null)
                                Text(
                                  formatMoney(item.estimatedTotal!),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (status == RestaurantPOStatus.draft ||
                  po.canReceive ||
                  status == RestaurantPOStatus.completed)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      if (status == RestaurantPOStatus.draft)
                        appDialogPrimaryButton(
                          label: 'Mark Sent',
                          onPressed: widget.onMarkSent,
                        ),
                      if (status != RestaurantPOStatus.draft &&
                          status != RestaurantPOStatus.cancelled) ...[
                        appDialogPrimaryButton(
                          label: 'WhatsApp PO',
                          onPressed: (phone == null || phone.trim().isEmpty)
                              ? () {
                                  NotificationService.instance.showError(
                                    'Supplier mobile number is not available.',
                                  );
                                }
                              : () => sharePurchaseOrderToWhatsApp(
                                  context: context,
                                  po: po,
                                  items: _items,
                                  phone: phone,
                                ),
                          color: (phone == null || phone.trim().isEmpty)
                              ? AppColors.textSecondary
                              : AppColors.success,
                        ),
                        if (po.canReceive) const SizedBox(width: 12),
                      ],
                      if (po.canReceive)
                        appDialogPrimaryButton(
                          label: 'Receive Items',
                          onPressed: widget.onReceive,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String cleanSupplierPhone(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9]'), '');
}

String buildWhatsAppPOMessage({
  required RestaurantPurchaseOrderModel po,
  required List<RestaurantPurchaseOrderItemModel> items,
  required List<Items> allItems,
}) {
  final buffer = StringBuffer();
  buffer.writeln('Purchase Order: ${po.poNumber}');
  buffer.writeln('Supplier: ${po.supplierName ?? 'Unknown'}');

  String localFormatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  buffer.writeln(
    'Expected Delivery: ${localFormatDate(po.expectedDeliveryDate)}',
  );
  if (po.notes?.isNotEmpty == true) {
    buffer.writeln('Notes: ${po.notes}');
  }
  buffer.writeln();
  buffer.writeln('Items:');
  for (final item in items) {
    final itemDetail = allItems.where((i) => i.id == item.itemId).firstOrNull;
    final unit = itemDetail?.unit ?? '';
    final unitStr = unit.isNotEmpty ? ' $unit' : '';
    final qty = item.orderedQty;
    final cleanQty = qty == qty.toInt()
        ? qty.toInt().toString()
        : qty.toString();
    buffer.writeln('- ${item.itemName} — Qty: $cleanQty$unitStr');
  }
  buffer.writeln();
  buffer.writeln('Estimated Total: ${formatMoney(po.estimatedTotal)}');

  return buffer.toString().trim();
}

Future<void> sharePurchaseOrderToWhatsApp({
  required BuildContext context,
  required RestaurantPurchaseOrderModel po,
  required List<RestaurantPurchaseOrderItemModel> items,
  required String phone,
}) async {
  final cleanPhone = cleanSupplierPhone(phone);
  if (cleanPhone.isEmpty) {
    NotificationService.instance.showError(
      'Supplier mobile number is not available.',
    );
    return;
  }

  final message = buildWhatsAppPOMessage(
    po: po,
    items: items,
    allItems: itemStore.items,
  );
  final whatsappUrl =
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
  final uri = Uri.parse(whatsappUrl);

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      NotificationService.instance.showError('Could not launch WhatsApp.');
    }
  } catch (e) {
    NotificationService.instance.showError('Could not launch WhatsApp: $e');
  }
}
