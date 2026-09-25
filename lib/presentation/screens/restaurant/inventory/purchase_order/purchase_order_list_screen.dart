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
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/quantity_format.dart';

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
  final TextEditingController _searchController = TextEditingController();

  /// null = All.
  RestaurantPOStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    restaurantSupplierStore.loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the PO form — create when [po] is null, edit otherwise.
  Future<void> _navigateToPOForm({RestaurantPurchaseOrderModel? po}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddPurchaseOrderScreen(purchaseOrder: po)),
    );
    if (result == true) {
      restaurantPurchaseOrderStore.loadPurchaseOrders();
    }
  }

  Future<void> _deletePO(RestaurantPurchaseOrderModel po) async {
    if (!restaurantPurchaseOrderStore.canDeletePurchaseOrder(po.poId)) {
      await showAppErrorDialog(
        context: context,
        title: "Can't delete ${po.poNumber}",
        message: 'Only draft orders with no goods received can be deleted.',
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete ${po.poNumber}?',
      message:
          'The order and its items are removed permanently. This cannot be undone.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;

    final deleted = await restaurantPurchaseOrderStore.deletePurchaseOrder(
      po.poId,
    );
    if (!mounted) return;
    if (deleted) {
      NotificationService.instance.showSuccess('${po.poNumber} deleted');
    } else {
      NotificationService.instance.showError(
        '${po.poNumber} could not be deleted',
      );
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

            // One pass feeds both the hero stats and the filter pills.
            // statusEnum is a firstWhere over the enum values on every call,
            // so a single switch beats five chained .where()s.
            var draftCount = 0;
            var sentCount = 0;
            var partialCount = 0;
            var completedCount = 0;
            for (final p in pos) {
              switch (p.statusEnum) {
                case RestaurantPOStatus.draft:
                  draftCount++;
                case RestaurantPOStatus.sent:
                  sentCount++;
                case RestaurantPOStatus.partiallyReceived:
                  partialCount++;
                case RestaurantPOStatus.completed:
                  completedCount++;
                case RestaurantPOStatus.cancelled:
                  // Nothing in restaurant code ever writes this status, so it
                  // gets no pill. A legacy record still shows under "All",
                  // which is why the four counts may not sum to pos.length.
                  break;
              }
            }
            final openCount = sentCount + partialCount;

            // Status + text in one pass over the already-materialized list —
            // no repository round-trip, so an edit or delete shows up
            // immediately. Same rule the return / claim registers use.
            final query = _searchController.text.trim().toLowerCase();
            final visible = (_statusFilter == null && query.isEmpty)
                ? pos
                : pos.where((p) {
                    if (_statusFilter != null && p.statusEnum != _statusFilter) {
                      return false;
                    }
                    if (query.isEmpty) return true;
                    return p.poNumber.toLowerCase().contains(query) ||
                        (p.supplierName?.toLowerCase().contains(query) ??
                            false);
                  }).toList();

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
                // Search + pills, in the white band the return / claim
                // registers use. Only rendered once there is something to
                // filter — an empty search box over "No purchase orders yet"
                // is noise, as are five zero-count pills.
                if (pos.isNotEmpty)
                  Container(
                    color: AppColors.white,
                    padding: EdgeInsets.fromLTRB(
                      AppResponsive.padding(context).left,
                      AppResponsive.mediumSpacing(context),
                      AppResponsive.padding(context).right,
                      AppResponsive.mediumSpacing(context),
                    ),
                    child: AppResponsive.constrainedContent(
                      context: context,
                      maxWidth: AppResponsive.maxContentWidth(context),
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _searchController,
                            hint: 'Search by PO number or supplier...',
                            icon: Icons.search_rounded,
                            onChanged: (_) => setState(() {}),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      size: AppResponsive.smallIconSize(context),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          SizedBox(height: AppResponsive.mediumSpacing(context)),
                          _buildStatusFilter(
                            all: pos.length,
                            draft: draftCount,
                            sent: sentCount,
                            partial: partialCount,
                            completed: completedCount,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Hero stays full-bleed; only the card list narrows.
                Expanded(
                  child: AppResponsive.constrainedContent(
                    context: context,
                    maxWidth: AppResponsive.maxContentWidth(context),
                    alignment: Alignment.topCenter,
                    child: visible.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: AppResponsive.padding(context),
                            itemCount: visible.length,
                            itemBuilder: (context, index) =>
                                _buildPOCard(visible[index]),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToPOForm(),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  /// Status pills. Copied from the purchase-return / supplier-claim list
  /// screens so the three registers filter identically: equal-width on
  /// tablet and desktop, horizontally scrollable on mobile.
  Widget _buildStatusFilter({
    required int all,
    required int draft,
    required int sent,
    required int partial,
    required int completed,
  }) {
    // Not const, unlike the reference — the counts are runtime values. They
    // are baked into the label so _statusChip's child stays a single Text and
    // keeps working inside FittedBox; a separate count badge would need a Row,
    // which scales badly under scaleDown.
    final options = <(String, RestaurantPOStatus?)>[
      ('All ($all)', null),
      ('Draft ($draft)', RestaurantPOStatus.draft),
      ('Sent ($sent)', RestaurantPOStatus.sent),
      ('Partial ($partial)', RestaurantPOStatus.partiallyReceived),
      ('Completed ($completed)', RestaurantPOStatus.completed),
    ];

    final height = AppResponsive.getValue(
      context,
      mobile: 34.0,
      tablet: 40.0,
      desktop: 44.0,
    );
    final gap = AppResponsive.smallSpacing(context);

    if (!AppResponsive.isMobile(context)) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: _statusChip(options[i].$1, options[i].$2)),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, index) =>
            _statusChip(options[index].$1, options[index].$2),
      ),
    );
  }

  Widget _statusChip(String label, RestaurantPOStatus? status) {
    final selected = _statusFilter == status;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = status),
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.smallBorderRadius(context),
          ),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchController.text.trim().isNotEmpty;
    final filtering = _statusFilter != null || searching;

    return AppEmptyState(
      icon: filtering
          ? (searching ? Icons.search_off_rounded : Icons.filter_alt_off_rounded)
          : Icons.assignment_outlined,
      title: filtering ? 'No purchase orders match' : 'No purchase orders yet',
      message: filtering
          ? 'Try a different search or status filter.'
          : 'Create your first PO using the + button',
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
                  // Draft-only, using the model's own guard. Visible buttons
                  // rather than an overflow menu, matching RowActionButton's
                  // stated convention for full-width rows. Non-draft cards
                  // reserve no placeholder width — dead space on most cards
                  // costs more than the title-width difference.
                  if (po.canEdit) ...[
                    SizedBox(width: AppResponsive.smallSpacing(context)),
                    RowActionButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.info,
                      tooltip: 'Edit PO',
                      onTap: () => _navigateToPOForm(po: po),
                    ),
                    const SizedBox(width: 6),
                    RowActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.danger,
                      tooltip: 'Delete PO',
                      onTap: () => _deletePO(po),
                    ),
                  ],
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
                  // "Qty", not "items": totalItems stores the summed ordered
                  // QUANTITY across lines, so 10kg cheese + 10 buns is 20 —
                  // a size indicator, never a line count. formatQty kills the
                  // trailing .0 that a whole double would otherwise print.
                  _metaItem(
                    Icons.inventory_2,
                    'Qty ${formatQty(po.totalItems)}',
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
                                      'Qty: ${formatQty(item.orderedQty)}'
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
    buffer.writeln(
      '- ${item.itemName} — Qty: ${formatQty(item.orderedQty)}$unitStr',
    );
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
