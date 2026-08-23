import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/presentation/screens/retail/add_purchase_order_screen.dart';
import 'package:billberrylite/presentation/screens/retail/material_receiving_screen.dart';
import 'package:billberrylite/presentation/widget/componets/retail/purchase_order_detail_sheet.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  /// Opens with the supplier filter already applied — used when arriving from
  /// a supplier's Purchases tab, where landing on every supplier's orders
  /// would throw away the context the user came from. The filter chip still
  /// shows, so it can be cleared to see everything.
  final SupplierModel? initialSupplier;

  const PurchaseOrderListScreen({super.key, this.initialSupplier});

  @override
  State<PurchaseOrderListScreen> createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  /// Tab order — index maps straight onto this list, so a null entry means
  /// "All" rather than a status.
  static const List<POStatus?> _tabStatuses = [
    null, // All
    POStatus.draft,
    POStatus.sent,
    POStatus.partiallyCompleted,
    POStatus.fullyCompleted,
    POStatus.cancelled,
  ];

  static const List<String> _tabLabels = [
    'All',
    'Draft',
    'Sent',
    'Partial',
    'Completed',
    'Cancelled',
  ];

  SupplierModel? _supplierFilter;
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabStatuses.length, vsync: this);
    _supplierFilter = widget.initialSupplier;
    purchaseOrderStore.loadPurchaseOrders();
  }

  bool get _hasExtraFilters => _supplierFilter != null || _dateFilter != null;

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    purchaseOrderStore.searchPurchaseOrders(query);
  }

  Future<void> _navigateToAddPO({PurchaseOrderModel? po}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPurchaseOrderScreen(purchaseOrder: po),
      ),
    );

    if (result == true) {
      purchaseOrderStore.loadPurchaseOrders();
    }
  }

  Future<void> _navigateToReceiving(PurchaseOrderModel po) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialReceivingScreen(purchaseOrder: po),
      ),
    );

    if (result == true) {
      purchaseOrderStore.loadPurchaseOrders();
    }
  }

  /// Status tab + supplier + date, applied together. Each status now has its
  /// own tab — previously "Done" merged fullyCompleted with cancelled, which
  /// hid cancellations among genuinely completed orders.
  List<PurchaseOrderModel> _applyFilters(
    List<PurchaseOrderModel> pos,
    int tabIndex,
  ) {
    final status = _tabStatuses[tabIndex];

    return pos.where((po) {
      if (status != null && po.statusEnum != status) return false;

      if (_supplierFilter != null &&
          po.supplierId != _supplierFilter!.supplierId) {
        return false;
      }

      if (_dateFilter != null) {
        final created = DateTime.tryParse(po.createdAt);
        if (created == null) return false;
        // Compare on calendar days so an order created late in the day still
        // falls inside a range that ends that day.
        final day = DateTime(created.year, created.month, created.day);
        final start = DateTime(
          _dateFilter!.start.year,
          _dateFilter!.start.month,
          _dateFilter!.start.day,
        );
        final end = DateTime(
          _dateFilter!.end.year,
          _dateFilter!.end.month,
          _dateFilter!.end.day,
        );
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _pickSupplierFilter() async {
    // Returns a supplierId; '' means "All suppliers". Popping a SupplierModel?
    // directly would make "All" and a swipe-dismiss indistinguishable, so a
    // dismissed sheet (null) leaves the current filter alone.
    const allSuppliers = '';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Filter by Supplier',
        subtitle: 'Show purchase orders from one supplier',
        accent: AppColors.primary,
        icon: Icons.filter_alt_outlined,
        // Plain Column, not a ListView — AppDialogShell already wraps the body
        // in a SingleChildScrollView, and nesting two scrollables makes them
        // fight over the drag.
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _supplierFilterTile(
              dialogContext,
              icon: Icons.clear_all_rounded,
              label: 'All suppliers',
              selected: _supplierFilter == null,
              value: allSuppliers,
            ),
            if (supplierStore.suppliers.isNotEmpty)
              const Divider(height: 1, color: AppColors.divider),
            for (final s in supplierStore.suppliers)
              _supplierFilterTile(
                dialogContext,
                icon: Icons.storefront_outlined,
                label: s.name,
                selected: _supplierFilter?.supplierId == s.supplierId,
                value: s.supplierId,
              ),
          ],
        ),
        actions: [appDialogCancelButton(dialogContext, label: 'Close')],
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _supplierFilter = result == allSuppliers
          ? null
          : supplierStore.suppliers
                .where((s) => s.supplierId == result)
                .firstOrNull;
    });
  }

  /// One row of the supplier-filter dialog. Pops the supplier id so the caller
  /// can tell "All" (empty string) apart from a dismiss (null).
  Widget _supplierFilterTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: AppResponsive.isMobile(context),
      leading: Icon(
        icon,
        size: AppResponsive.iconSize(context),
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              size: AppResponsive.smallIconSize(context),
              color: AppColors.primary,
            )
          : null,
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _pickDateFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
    );
    if (range != null && mounted) {
      setState(() => _dateFilter = range);
    }
  }

  void _clearExtraFilters() {
    setState(() {
      _supplierFilter = null;
      _dateFilter = null;
    });
  }

  /// Caps content width on large screens. Backgrounds still span edge to edge —
  /// only what you read is constrained, so a laptop doesn't stretch a PO card
  /// across the whole window.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxContentWidth(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Purchase Orders',
        actions: [
          // A tinted icon would vanish against the primary AppBar, so an active
          // filter is flagged with a filled icon instead of a colour change.
          IconButton(
            icon: Icon(
              _supplierFilter != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter by supplier',
            onPressed: _pickSupplierFilter,
          ),
          IconButton(
            icon: Icon(
              _dateFilter != null
                  ? Icons.event_available
                  : Icons.date_range_outlined,
            ),
            tooltip: 'Filter by date',
            onPressed: _pickDateFilter,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          // Phones can't fit six labels, so they scroll. From tablet up there
          // is room to divide the width evenly, which also kills the dead space
          // that left-packed scrollable tabs leave on a wide screen.
          isScrollable: AppResponsive.isMobile(context),
          tabAlignment: AppResponsive.isMobile(context)
              ? TabAlignment.start
              : TabAlignment.fill,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          // Underline hugs the word rather than the whole tab cell — with
          // scrollable tabs the cell is wider than its label, so a full-width
          // indicator reads as misaligned.
          indicatorSize: TabBarIndicatorSize.label,
          // Scrolling: a wide gutter so six labels aren't packed together.
          // Filling: a narrow one, because each tab is already an equal slice
          // and a big gutter would squeeze "Completed" into an ellipsis on the
          // smallest tablet.
          labelPadding: EdgeInsets.symmetric(
            horizontal: AppResponsive.isMobile(context)
                ? AppResponsive.largeSpacing(context)
                : AppResponsive.smallSpacing(context),
          ),
          labelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            for (final label in _tabLabels)
              Tab(
                height: AppResponsive.getValue(
                  context,
                  mobile: 44.0,
                  tablet: 48.0,
                  desktop: 52.0,
                ),
                text: label,
              ),
          ],
        ),
      ),
      body: MoneyScope(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildActiveFilterBar(),
            _buildSummaryCard(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (var i = 0; i < _tabStatuses.length; i++) _buildPOList(i),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPO(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    final side = AppResponsive.padding(context).left;

    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        side,
        AppResponsive.mediumSpacing(context),
        side,
        12,
      ),
      child: _capped(
        context,
        AppTextField(
          controller: _searchController,
          hint: 'Search by PO number or supplier...',
          icon: Icons.search_rounded,
          onChanged: (value) {
            _onSearchChanged(value);
            setState(() {});
          },
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Observer(
      builder: (context) {
        final side = AppResponsive.padding(context).left;
        final gap = AppResponsive.mediumSpacing(context);

        return Container(
          color: AppColors.white,
          padding: EdgeInsets.fromLTRB(
            side,
            AppResponsive.smallSpacing(context),
            side,
            gap,
          ),
          child: _capped(
            context,
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Draft',
                    purchaseOrderStore.draftPOCount.toString(),
                    Icons.edit_note,
                    AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _buildStatItem(
                    'Pending',
                    purchaseOrderStore.pendingReceivingCount.toString(),
                    Icons.local_shipping,
                    AppColors.info,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    purchaseOrderStore.poCount.toString(),
                    Icons.list_alt,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: AppResponsive.iconSize(context), color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOList(int tabIndex) {
    return Observer(
      builder: (context) {
        final allPOs = _searchController.text.isEmpty
            ? purchaseOrderStore.purchaseOrders.toList()
            : purchaseOrderStore.searchResults.toList();

        final filteredPOs = _applyFilters(allPOs, tabIndex);

        if (filteredPOs.isEmpty) {
          return _buildEmptyState(tabIndex);
        }

        return _capped(
          context,
          ListView.builder(
            padding: AppResponsive.padding(context),
            itemCount: filteredPOs.length,
            itemBuilder: (context, index) {
              return _buildPOCard(filteredPOs[index]);
            },
          ),
        );
      },
    );
  }

  /// Shows which non-status filters are narrowing the list, with a one-tap
  /// clear — otherwise an empty tab looks like missing data rather than an
  /// active filter.
  Widget _buildActiveFilterBar() {
    if (!_hasExtraFilters) return const SizedBox.shrink();

    final parts = <String>[
      if (_supplierFilter != null) _supplierFilter!.name,
      if (_dateFilter != null)
        '${poFormatDate(_dateFilter!.start.toIso8601String())} – ${poFormatDate(_dateFilter!.end.toIso8601String())}',
    ];

    return Container(
      width: double.infinity,
      color: AppColors.info.withValues(alpha: 0.08),
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.padding(context).left,
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: _capped(
        context,
        Row(
          children: [
            Icon(
              Icons.filter_alt,
              size: AppResponsive.smallIconSize(context),
              color: AppColors.info,
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(
              child: Text(
                parts.join('  •  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.info,
                ),
              ),
            ),
            InkWell(
              onTap: _clearExtraFilters,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final status = _tabStatuses[tabIndex];
    String message;
    if (_hasExtraFilters) {
      message = 'No orders match these filters';
    } else if (status == null) {
      message = 'No purchase orders yet';
    } else {
      message = 'No ${_tabLabels[tabIndex].toLowerCase()} purchase orders';
    }

    return Center(
      child: Padding(
        padding: AppResponsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: AppResponsive.getValue(
                context,
                mobile: 80.0,
                tablet: 92.0,
                desktop: 104.0,
              ),
              color: AppColors.divider,
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppResponsive.subheadingFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            if (tabIndex == 0) ...[
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                'Create your first PO using the + button',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPOCard(PurchaseOrderModel po) {
    final radius = AppResponsive.smallBorderRadius(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: InkWell(
        onTap: () => showPurchaseOrderDetailSheet(
          context: context,
          po: po,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
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
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
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
                      color: poStatusColor(
                        po.statusEnum,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      poStatusLabel(po.statusEnum),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: AppResponsive.captionFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: poStatusColor(po.statusEnum),
                      ),
                    ),
                  ),
                  // Cancel/Delete are draft-only, so the menu only exists then.
                  if (po.statusEnum == POStatus.draft)
                    SizedBox(
                      height: 28,
                      width: 32,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        onSelected: (value) {
                          if (value == 'cancel') _cancelPO(po);
                          if (value == 'delete') _deletePO(po);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 18,
                                  color: AppColors.warning,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Cancel PO',
                                  style: TextStyle(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.danger,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: AppResponsive.bodyFontSize(
                                      context,
                                    ),
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppResponsive.smallSpacing(context)),
              Text(
                po.supplierName ?? 'Unknown Supplier',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              _buildCardProgress(po),
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              // Wrap, not Row: date + item count + amount need ~265px of fixed
              // content, which overflows a 320px phone once the card and list
              // padding are taken out. A Spacer can't shrink below zero.
              Wrap(
                spacing: AppResponsive.mediumSpacing(context),
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _poMetaItem(
                    Icons.calendar_today,
                    'Delivery: ${poFormatDate(po.expectedDeliveryDate)}',
                    AppColors.textSecondary,
                  ),
                  _poMetaItem(
                    Icons.inventory_2,
                    '${po.totalItems} items',
                    AppColors.info,
                    bold: true,
                  ),
                  if (po.estimatedTotal > 0)
                    Text(
                      formatMoney(po.estimatedTotal),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (po.canReceive) ...[
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
                    label: Text(
                      'Receive Items',
                      style: TextStyle(
                        fontSize: AppResponsive.bodyFontSize(context),
                      ),
                    ),
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

  /// One icon+label pair of the PO card's meta line. Sized to its content so it
  /// can sit in a Wrap and drop to the next row instead of overflowing.
  Widget _poMetaItem(
    IconData icon,
    String label,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context), color: color),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            color: color,
            fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// "12/50 received · 4,800 accepted" — reads the store's synchronous
  /// progress helper so every card can render without its own FutureBuilder.
  Widget _buildCardProgress(PurchaseOrderModel po) {
    return Observer(
      builder: (context) {
        final progress = purchaseOrderStore.progressFor(po);
        if (!progress.hasReceipts) return const SizedBox.shrink();

        final complete = progress.remaining == 0;
        return Padding(
          padding: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
          child: Wrap(
            spacing: AppResponsive.mediumSpacing(context),
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _poMetaItem(
                complete ? Icons.check_circle : Icons.local_shipping_outlined,
                '${progress.received}/${progress.ordered} received',
                complete ? AppColors.success : AppColors.warning,
                bold: true,
              ),
              Text(
                '${formatMoney(progress.billedAmount)} billed',
                maxLines: 1,
                style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== CANCEL / DELETE ====================

  Future<void> _cancelPO(PurchaseOrderModel po) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Cancel ${po.poNumber}?',
      message:
          'The order stays on record as Cancelled. Only draft orders can be cancelled.',
      confirmLabel: 'Cancel PO',
      cancelLabel: 'Keep',
      accent: AppColors.warning,
      icon: Icons.block,
    );
    if (!confirmed || !mounted) return;

    final ok = await purchaseOrderStore.cancelPurchaseOrder(po.poId);
    if (!mounted) return;

    if (ok) {
      NotificationService.instance.showSuccess('${po.poNumber} cancelled');
    } else {
      NotificationService.instance.showError(
        'Only draft purchase orders can be cancelled',
      );
    }
  }

  Future<void> _deletePO(PurchaseOrderModel po) async {
    // Draft-only AND nothing received — a GRN stores poId and would be
    // orphaned along with the stock it already moved.
    final canDelete = await purchaseOrderStore.canDeletePurchaseOrder(po.poId);
    if (!mounted) return;

    if (!canDelete) {
      await showAppErrorDialog(
        context: context,
        title: 'Can\'t delete ${po.poNumber}',
        message:
            'Only draft orders with no goods received can be deleted. Cancel it instead to keep the record.',
      );
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete ${po.poNumber}?',
      message: 'The order and its items are removed permanently.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;

    await purchaseOrderStore.deletePurchaseOrder(po.poId);
    if (!mounted) return;
    NotificationService.instance.showSuccess('${po.poNumber} deleted');
  }
}
