import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/store/retail/damaged_goods_store.dart';
import 'package:billberrylite/domain/store/retail/purchase_order_store.dart';
import 'package:billberrylite/presentation/screens/retail/inventory_loss_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_detail_screen.dart';
import 'package:billberrylite/presentation/screens/retail/purchase_return_list_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_detail_screen.dart';
import 'package:billberrylite/presentation/screens/retail/supplier_claim_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_model_213.dart';
import 'package:billberrylite/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:billberrylite/presentation/screens/retail/add_purchase_order_screen.dart';
import 'package:billberrylite/presentation/screens/retail/material_receiving_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
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

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(POStatus status) {
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

  String _getStatusLabel(POStatus status) {
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

  void _showPODetails(PurchaseOrderModel po) async {
    await purchaseOrderStore.selectPO(po);
    // Resolved before the sheet opens so each line can render its own
    // ordered/received/accepted breakdown without a per-row FutureBuilder.
    final receipts = await purchaseOrderStore.getPOItemReceipts(po.poId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPODetailsSheet(po, receipts),
    );
  }

  /// Ordered / Received / Accepted / Damaged / Remaining for one PO line.
  ///
  /// Reporting only — the completion rule is untouched. Note Remaining tracks
  /// *received*, not *accepted*, which is why a line can read
  /// "Received 50, Accepted 48, Remaining 0": the supplier delivered
  /// everything, but two units never made it into stock.
  Widget _buildItemReceiptBreakdown(POItemReceipt? receipt) {
    if (receipt == null || receipt.received == 0) return const SizedBox.shrink();

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
              _receiptChip('Ordered', receipt.ordered, AppColors.textSecondary),
              _receiptChip('Received', receipt.received, AppColors.info),
              _receiptChip('Accepted', receipt.accepted, AppColors.success),
              if (receipt.damaged > 0)
                _receiptChip('Damaged', receipt.damaged, AppColors.danger),
              _receiptChip(
                'Remaining',
                receipt.remaining,
                receipt.remaining == 0
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptChip(String label, int value, Color color) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPODetailsSheet(
      PurchaseOrderModel po, Map<String, POItemReceipt> receipts) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        po.supplierName ?? 'Unknown Supplier',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(po.statusEnum).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusLabel(po.statusEnum),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(po.statusEnum),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Expected Delivery', _formatDate(po.expectedDeliveryDate)),
                      _buildInfoRow('Created', _formatDate(po.createdAt)),
                      _buildInfoRow('Total Items', '${po.totalItems}'),
                      if (po.estimatedTotal > 0)
                        _buildInfoRow('Estimated Total', formatMoney(po.estimatedTotal)),
                      if (po.notes != null && po.notes!.isNotEmpty)
                        _buildInfoRow('Notes', po.notes!),
                      const SizedBox(height: 16),
                      const Text(
                        'Order Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...items.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(8),
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
                                        item.productName ?? 'Unknown Product',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (item.variantInfo != null)
                                        Text(
                                          item.variantInfo!,
                                          style: const TextStyle(
                                            fontSize: 12,
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
                                      'Qty: ${item.orderedQty}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (item.estimatedPrice != null)
                                      Text(
                                        formatMoney(item.estimatedTotal ?? 0),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.success,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                                _buildItemReceiptBreakdown(
                                    receipts[item.poItemId]),
                              ],
                            ),
                          )),
                      // GRN History Section
                      if (grns.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Receiving History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...grns.map((grn) => _buildGRNSummaryCard(grn)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                if (po.canEdit) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToAddPO(po: po);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await purchaseOrderStore.updatePOStatus(
                            po.poId, POStatus.sent);
                        // `context` here is the State's, so `mounted` is the
                        // matching guard — the sheet is popped off it.
                        if (!mounted) return;
                        Navigator.pop(context);
                        NotificationService.instance
                            .showSuccess('${po.poNumber} marked as sent');
                      },
                      icon: const Icon(Icons.send),
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
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToReceiving(po);
                      },
                      icon: const Icon(Icons.local_shipping),
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Status tab + supplier + date, applied together. Each status now has its
  /// own tab — previously "Done" merged fullyCompleted with cancelled, which
  /// hid cancellations among genuinely completed orders.
  List<PurchaseOrderModel> _applyFilters(
      List<PurchaseOrderModel> pos, int tabIndex) {
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
        final start = DateTime(_dateFilter!.start.year,
            _dateFilter!.start.month, _dateFilter!.start.day);
        final end = DateTime(
            _dateFilter!.end.year, _dateFilter!.end.month, _dateFilter!.end.day);
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

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.clear_all_rounded),
              title: const Text('All suppliers'),
              selected: _supplierFilter == null,
              onTap: () => Navigator.pop(sheetContext, allSuppliers),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: supplierStore.suppliers
                    .map((s) => ListTile(
                          leading: const Icon(Icons.storefront_outlined),
                          title: Text(s.name),
                          selected:
                              _supplierFilter?.supplierId == s.supplierId,
                          onTap: () => Navigator.pop(sheetContext, s.supplierId),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
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
            icon: Icon(_supplierFilter != null
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            tooltip: 'Filter by supplier',
            onPressed: _pickSupplierFilter,
          ),
          IconButton(
            icon: Icon(_dateFilter != null
                ? Icons.event_available
                : Icons.date_range_outlined),
            tooltip: 'Filter by date',
            onPressed: _pickDateFilter,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [for (final label in _tabLabels) Tab(text: label)],
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
    final isTablet = !AppResponsive.isMobile(context);

    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
          isTablet ? 20 : 16, isTablet ? 16 : 12, isTablet ? 20 : 16, 12),
      child: AppTextField(
        controller: _searchController,
        hint: 'Search by PO number or supplier...',
        icon: Icons.search_rounded,
        onChanged: (value) {
          _onSearchChanged(value);
          setState(() {});
        },
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  setState(() {});
                },
              )
            : null,
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Observer(
      builder: (context) {
        return Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Draft',
                  purchaseOrderStore.draftPOCount.toString(),
                  Icons.edit_note,
                  AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Pending',
                  purchaseOrderStore.pendingReceivingCount.toString(),
                  Icons.local_shipping,
                  AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
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
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPOs.length,
          itemBuilder: (context, index) {
            return _buildPOCard(filteredPOs[index]);
          },
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
        '${_formatDate(_dateFilter!.start.toIso8601String())} – ${_formatDate(_dateFilter!.end.toIso8601String())}',
    ];

    return Container(
      width: double.infinity,
      color: AppColors.info.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 14, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ),
          InkWell(
            onTap: _clearExtraFilters,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ),
          ),
        ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: AppColors.divider,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          if (tabIndex == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Create your first PO using the + button',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPOCard(PurchaseOrderModel po) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: InkWell(
        onTap: () => _showPODetails(po),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      po.poNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(po.statusEnum).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusLabel(po.statusEnum),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(po.statusEnum),
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
                        icon: const Icon(Icons.more_vert,
                            size: 18, color: AppColors.textSecondary),
                        onSelected: (value) {
                          if (value == 'cancel') _cancelPO(po);
                          if (value == 'delete') _deletePO(po);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                Icon(Icons.block, size: 18, color: AppColors.warning),
                                SizedBox(width: 10),
                                Text('Cancel PO', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                SizedBox(width: 10),
                                Text('Delete',
                                    style: TextStyle(fontSize: 13, color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                po.supplierName ?? 'Unknown Supplier',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              _buildCardProgress(po),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Delivery: ${_formatDate(po.expectedDeliveryDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.inventory_2, size: 14, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    '${po.totalItems} items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (po.estimatedTotal > 0) ...[
                    const Spacer(),
                    Text(
                      formatMoney(po.estimatedTotal),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (po.canReceive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToReceiving(po),
                    icon: const Icon(Icons.local_shipping, size: 18),
                    label: const Text('Receive Items'),
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

  /// "12/50 received · 4,800 accepted" — reads the store's synchronous
  /// progress helper so every card can render without its own FutureBuilder.
  Widget _buildCardProgress(PurchaseOrderModel po) {
    return Observer(
      builder: (context) {
        final progress = purchaseOrderStore.progressFor(po);
        if (!progress.hasReceipts) return const SizedBox.shrink();

        final complete = progress.remaining == 0;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.local_shipping_outlined,
                size: 14,
                color: complete
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                '${progress.received}/${progress.ordered} received',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: complete
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${formatMoney(progress.acceptedAmount)} accepted',
                style: const TextStyle(
                  fontSize: 12,
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
      NotificationService.instance
          .showError('Only draft purchase orders can be cancelled');
    }
  }

  Future<void> _deletePO(PurchaseOrderModel po) async {
    // Draft-only AND nothing received — a GRN stores poId and would be
    // orphaned along with the stock it already moved.
    final canDelete =
        await purchaseOrderStore.canDeletePurchaseOrder(po.poId);
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

  Widget _buildGRNSummaryCard(GRNModel grn) {
    return FutureBuilder<List<GRNItemModel>>(
      future: purchaseOrderStore.getGRNItemsForGRN(grn.grnId),
      builder: (context, snapshot) {
        final grnItems = snapshot.data ?? [];
        final totalAccepted = grnItems.fold<int>(0, (sum, item) => sum + item.acceptedQty);
        final totalDamaged = grnItems.fold<int>(0, (sum, item) => sum + (item.damagedQty ?? 0));
        final damagedAmount = grnItems.fold<double>(0.0, (sum, item) => sum + (item.damagedAmount ?? 0));

        // Group damaged items by handling method
        final returnToSupplier = grnItems.where((i) => i.damagedHandlingEnum == DamagedHandling.returnToSupplier).toList();
        final keepForClaim = grnItems.where((i) => i.damagedHandlingEnum == DamagedHandling.keepForClaim).toList();
        final writeOff = grnItems.where((i) => i.damagedHandlingEnum == DamagedHandling.writeOff).toList();

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
                    const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        grn.grnNumber,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      _formatDate(grn.receivedDate),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                        _buildGRNStat('Received', grn.totalReceivedQty.toString(), AppColors.success),
                        const SizedBox(width: 16),
                        _buildGRNStat('To Stock', totalAccepted.toString(), AppColors.info),
                        if (totalDamaged > 0) ...[
                          const SizedBox(width: 16),
                          _buildGRNStat('Damaged', totalDamaged.toString(), AppColors.danger),
                        ],
                        const Spacer(),
                        Text(
                          formatMoney(grn.totalAmount ?? 0),
                          style: const TextStyle(
                            fontSize: 14,
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
                                const Icon(Icons.warning_amber, size: 14, color: AppColors.warning),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalDamaged damaged (${formatMoney(damagedAmount)})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (returnToSupplier.isNotEmpty)
                              _buildDamagedRow(
                                'Return to Supplier',
                                returnToSupplier.fold<int>(0, (s, i) => s + (i.damagedQty ?? 0)),
                                AppColors.warning,
                              ),
                            if (keepForClaim.isNotEmpty)
                              _buildDamagedRow(
                                'Keep for Claim',
                                keepForClaim.fold<int>(0, (s, i) => s + (i.damagedQty ?? 0)),
                                AppColors.info,
                              ),
                            if (writeOff.isNotEmpty)
                              _buildDamagedRow(
                                'Write Off',
                                writeOff.fold<int>(0, (s, i) => s + (i.damagedQty ?? 0)),
                                AppColors.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ],
                    _buildLinkedDocuments(grn),
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
  Widget _buildLinkedDocuments(GRNModel grn) {
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
                  fontSize: 12,
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
                fontSize: 11.5,
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

  Widget _buildGRNStat(String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildDamagedRow(String label, int qty, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 6),
          Text('$qty x $label', style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}