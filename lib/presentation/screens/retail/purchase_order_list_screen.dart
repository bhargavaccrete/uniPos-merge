import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:unipos/data/models/retail/hive_model/grn_model_213.dart';
import 'package:unipos/data/models/retail/hive_model/grn_item_model_214.dart';
import 'package:unipos/presentation/screens/retail/add_purchase_order_screen.dart';
import 'package:unipos/presentation/screens/retail/material_receiving_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    purchaseOrderStore.loadPurchaseOrders();
  }

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
        return const Color(0xFF9E9E9E);
      case POStatus.sent:
        return const Color(0xFF2196F3);
      case POStatus.partiallyCompleted:
        return const Color(0xFFFF9800);
      case POStatus.fullyCompleted:
        return const Color(0xFF4CAF50);
      case POStatus.cancelled:
        return const Color(0xFFF44336);
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

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPODetailsSheet(po),
    );
  }

  Widget _buildPODetailsSheet(PurchaseOrderModel po) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
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
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(po.statusEnum).withOpacity(0.1),
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
                        _buildInfoRow('Estimated Total', '₹${po.estimatedTotal.toStringAsFixed(2)}'),
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
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
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
                                            color: Color(0xFF6B6B6B),
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
                                        '₹${item.estimatedTotal?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                  ],
                                ),
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
              border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
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
                        await purchaseOrderStore.updatePOStatus(po.poId, POStatus.sent);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PO marked as sent'),
                            backgroundColor: Color(0xFF4CAF50),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Mark Sent'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
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
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
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
                color: Color(0xFF6B6B6B),
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

  List<PurchaseOrderModel> _filterPOsByTab(List<PurchaseOrderModel> pos, int tabIndex) {
    switch (tabIndex) {
      case 0: // All
        return pos;
      case 1: // Draft
        return pos.where((po) => po.statusEnum == POStatus.draft).toList();
      case 2: // Sent/Pending
        return pos.where((po) => po.canReceive).toList();
      case 3: // Completed
        return pos.where((po) => po.isCompleted).toList();
      default:
        return pos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Purchase Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A1A1A),
          unselectedLabelColor: const Color(0xFF6B6B6B),
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Draft'),
            Tab(text: 'Pending'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSummaryCard(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPOList(0),
                _buildPOList(1),
                _buildPOList(2),
                _buildPOList(3),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPO(),
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by PO number or supplier...',
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF6B6B6B)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          _onSearchChanged(value);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Observer(
      builder: (context) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Draft',
                  purchaseOrderStore.draftPOCount.toString(),
                  Icons.edit_note,
                  const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Pending',
                  purchaseOrderStore.pendingReceivingCount.toString(),
                  Icons.local_shipping,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Total',
                  purchaseOrderStore.poCount.toString(),
                  Icons.list_alt,
                  const Color(0xFF4CAF50),
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
        color: color.withOpacity(0.1),
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
              color: Color(0xFF6B6B6B),
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

        final filteredPOs = _filterPOsByTab(allPOs, tabIndex);

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

  Widget _buildEmptyState(int tabIndex) {
    String message;
    switch (tabIndex) {
      case 1:
        message = 'No draft purchase orders';
        break;
      case 2:
        message = 'No pending orders to receive';
        break;
      case 3:
        message = 'No completed orders';
        break;
      default:
        message = 'No purchase orders yet';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          if (tabIndex == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Create your first PO using the + button',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB0B0B0),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
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
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(po.statusEnum).withOpacity(0.1),
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                po.supplierName ?? 'Unknown Supplier',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6B6B6B)),
                  const SizedBox(width: 4),
                  Text(
                    'Delivery: ${_formatDate(po.expectedDeliveryDate)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.inventory_2, size: 14, color: Color(0xFF2196F3)),
                  const SizedBox(width: 4),
                  Text(
                    '${po.totalItems} items',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (po.estimatedTotal > 0) ...[
                    const Spacer(),
                    Text(
                      '₹${po.estimatedTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
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
                      foregroundColor: const Color(0xFF4CAF50),
                      side: const BorderSide(color: Color(0xFF4CAF50)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GRN Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 16, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        grn.grnNumber,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      _formatDate(grn.receivedDate),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
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
                        _buildGRNStat('Received', grn.totalReceivedQty.toString(), const Color(0xFF4CAF50)),
                        const SizedBox(width: 16),
                        _buildGRNStat('To Stock', totalAccepted.toString(), const Color(0xFF2196F3)),
                        if (totalDamaged > 0) ...[
                          const SizedBox(width: 16),
                          _buildGRNStat('Damaged', totalDamaged.toString(), const Color(0xFFF44336)),
                        ],
                        const Spacer(),
                        Text(
                          '₹${grn.totalAmount?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
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
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber, size: 14, color: Color(0xFFFF9800)),
                                const SizedBox(width: 6),
                                Text(
                                  '$totalDamaged damaged (₹${damagedAmount.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (returnToSupplier.isNotEmpty)
                              _buildDamagedRow(
                                'Return to Supplier',
                                returnToSupplier.fold<int>(0, (s, i) => s + (i.damagedQty ?? 0)),
                                const Color(0xFFFF9800),
                              ),
                            if (keepForClaim.isNotEmpty)
                              _buildDamagedRow(
                                'Keep for Claim',
                                keepForClaim.fold<int>(0, (s, i) => s + (i.damagedQty ?? 0)),
                                const Color(0xFF2196F3),
                              ),
                            if (writeOff.isNotEmpty)
                              _buildDamagedRow(
                                'Write Off',
                                writeOff.fold<int>(0, (s, i) => s + (i.damagedQty ?? 0)),
                                const Color(0xFF6B6B6B),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGRNStat(String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
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