import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:unipos/data/models/retail/hive_model/grn_model_213.dart';
import 'package:unipos/data/models/retail/hive_model/grn_item_model_214.dart';

class MaterialReceivingScreen extends StatefulWidget {
  final PurchaseOrderModel purchaseOrder;

  const MaterialReceivingScreen({super.key, required this.purchaseOrder});

  @override
  State<MaterialReceivingScreen> createState() => _MaterialReceivingScreenState();
}

class _MaterialReceivingScreenState extends State<MaterialReceivingScreen> {
  late String _grnNumber;
  DateTime _receivedDate = DateTime.now();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<ReceivingItemData> _receivingItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _grnNumber = purchaseOrderStore.generateGRNNumber();
    _loadPOItems();
  }

  Future<void> _loadPOItems() async {
    await purchaseOrderStore.loadPOItems(widget.purchaseOrder.poId);

    // Prepare receiving items from PO items, accounting for already received qty
    final items = <ReceivingItemData>[];
    for (var poItem in purchaseOrderStore.currentPOItems) {
      final variant = await productStore.getVariantById(poItem.variantId);

      // Get already received quantity for this PO item
      final alreadyReceived = await purchaseOrderStore.getReceivedQtyForPOItem(poItem.poItemId);
      final remainingQty = poItem.orderedQty - alreadyReceived;

      // Only add items that still have remaining quantity to receive
      if (remainingQty > 0) {
        items.add(ReceivingItemData(
          poItemId: poItem.poItemId,
          variantId: poItem.variantId,
          productId: poItem.productId,
          productName: poItem.productName ?? 'Unknown Product',
          variantInfo: poItem.variantInfo,
          orderedQty: remainingQty, // Show only remaining quantity
          receivedQty: remainingQty, // Default to full receipt of remaining
          damagedQty: 0,
          costPrice: poItem.estimatedPrice ?? variant?.costPrice ?? 0,
        ));
      }
    }

    setState(() {
      _receivingItems.addAll(items);
      _isLoading = false;
    });
  }

  Future<void> _selectReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _receivedDate = picked;
      });
    }
  }

  void _updateReceivedQty(int index, int qty) {
    setState(() {
      _receivingItems[index] = _receivingItems[index].copyWith(receivedQty: qty);
    });
  }

  void _updateDamagedQty(int index, int qty) {
    setState(() {
      _receivingItems[index] = _receivingItems[index].copyWith(damagedQty: qty);
    });
  }

  void _updateCostPrice(int index, double price) {
    setState(() {
      _receivingItems[index] = _receivingItems[index].copyWith(costPrice: price);
    });
  }

  void _showEditItemDialog(int index) {
    final item = _receivingItems[index];
    final receivedController = TextEditingController(text: item.receivedQty.toString());
    final damagedController = TextEditingController(text: item.damagedQty.toString());
    final priceController = TextEditingController(text: item.costPrice.toStringAsFixed(2));
    DamagedHandling selectedHandling = item.damagedHandling;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final damaged = int.tryParse(damagedController.text) ?? 0;
          final received = int.tryParse(receivedController.text) ?? 0;
          final accepted = received - damaged;
          final price = double.tryParse(priceController.text) ?? 0;

          return AlertDialog(
            title: Text(item.productName),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ordered: ${item.orderedQty}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: receivedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Received Quantity',
                      border: OutlineInputBorder(),
                      helperText: 'Total items physically received',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: damagedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Damaged Quantity',
                      border: OutlineInputBorder(),
                      helperText: 'Items received but damaged',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (damaged > 0) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DamagedHandling>(
                      value: selectedHandling == DamagedHandling.none ? DamagedHandling.keepForClaim : selectedHandling,
                      decoration: const InputDecoration(
                        labelText: 'Damaged Item Handling',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DamagedHandling.keepForClaim,
                          child: Text('Keep for Claim'),
                        ),
                        DropdownMenuItem(
                          value: DamagedHandling.returnToSupplier,
                          child: Text('Return to Supplier'),
                        ),
                        DropdownMenuItem(
                          value: DamagedHandling.writeOff,
                          child: Text('Write Off as Loss'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedHandling = value ?? DamagedHandling.keepForClaim;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cost Price per Unit',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Accepted (to stock):', style: TextStyle(fontSize: 13)),
                            Text(
                              '$accepted items',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ],
                        ),
                        if (damaged > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Damaged:', style: TextStyle(fontSize: 13)),
                              Text(
                                '$damaged items (₹${(damaged * price).toStringAsFixed(2)})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF44336),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stock Value:', style: TextStyle(fontSize: 13)),
                            Text(
                              '₹${(accepted * price).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final received = int.tryParse(receivedController.text) ?? 0;
                  final damaged = int.tryParse(damagedController.text) ?? 0;
                  final price = double.tryParse(priceController.text) ?? 0;

                  // Validate damaged <= received
                  if (damaged > received) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Damaged quantity cannot exceed received quantity'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _receivingItems[index] = item.copyWith(
                      receivedQty: received,
                      damagedQty: damaged,
                      damagedHandling: damaged > 0 ? selectedHandling : DamagedHandling.none,
                      costPrice: price,
                    );
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAndConfirmGRN() async {
    // Validation
    final hasReceivedItems = _receivingItems.any((item) => item.receivedQty > 0);
    if (!hasReceivedItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter received quantities for at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if damaged handling is selected for items with damage
    final itemsWithUnhandledDamage = _receivingItems.where(
      (item) => item.damagedQty > 0 && item.damagedHandling == DamagedHandling.none,
    ).toList();

    if (itemsWithUnhandledDamage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select handling method for damaged items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate totals
    final totalOrdered = _receivingItems.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final totalReceived = _receivingItems.fold<int>(0, (sum, item) => sum + item.receivedQty);
    final totalAccepted = _receivingItems.fold<int>(0, (sum, item) => sum + item.acceptedQty);
    final totalDamaged = _receivingItems.fold<int>(0, (sum, item) => sum + item.damagedQty);
    final totalAcceptedAmount = _receivingItems.fold<double>(0.0, (sum, item) => sum + item.acceptedAmount);
    final totalDamagedAmount = _receivingItems.fold<double>(0.0, (sum, item) => sum + item.damagedAmount);

    // Count items by handling method
    final returnToSupplierItems = _receivingItems.where(
      (item) => item.damagedHandling == DamagedHandling.returnToSupplier
    ).toList();
    final keepForClaimItems = _receivingItems.where(
      (item) => item.damagedHandling == DamagedHandling.keepForClaim
    ).toList();
    final writeOffItems = _receivingItems.where(
      (item) => item.damagedHandling == DamagedHandling.writeOff
    ).toList();

    // Create GRN
    final grn = GRNModel.create(
      grnNumber: _grnNumber,
      poId: widget.purchaseOrder.poId,
      poNumber: widget.purchaseOrder.poNumber,
      supplierId: widget.purchaseOrder.supplierId,
      supplierName: widget.purchaseOrder.supplierName,
      receivedDate: _receivedDate.toIso8601String(),
      totalOrderedQty: totalOrdered,
      totalReceivedQty: totalReceived,
      totalAmount: totalAcceptedAmount, // Only accepted amount goes to stock value
      invoiceNumber: _invoiceController.text.isEmpty ? null : _invoiceController.text.trim(),
      notes: _notesController.text.isEmpty ? null : _notesController.text.trim(),
    );

    // Create GRN Items with acceptedQty and damagedHandling
    final grnItems = _receivingItems
        .where((item) => item.receivedQty > 0)
        .map((item) => GRNItemModel.create(
              grnId: grn.grnId,
              poItemId: item.poItemId,
              variantId: item.variantId,
              productId: item.productId,
              productName: item.productName,
              variantInfo: item.variantInfo,
              orderedQty: item.orderedQty,
              receivedQty: item.receivedQty,
              acceptedQty: item.acceptedQty, // Only good items
              damagedQty: item.damagedQty > 0 ? item.damagedQty : null,
              damagedHandling: item.damagedQty > 0 ? item.damagedHandling : null,
              costPrice: item.costPrice,
            ))
        .toList();

    // Show confirmation dialog with detailed breakdown
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Receipt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stock Update:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildConfirmItem('Add $totalAccepted items to inventory'),
              _buildConfirmItem('Stock value: ₹${totalAcceptedAmount.toStringAsFixed(2)}'),
              if (totalDamaged > 0) ...[
                const SizedBox(height: 12),
                const Text('Damaged Items:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF44336))),
                const SizedBox(height: 8),
                _buildConfirmItem(
                  '$totalDamaged damaged (₹${totalDamagedAmount.toStringAsFixed(2)})',
                  color: const Color(0xFFF44336),
                ),
                if (returnToSupplierItems.isNotEmpty)
                  _buildConfirmItem(
                    '${returnToSupplierItems.fold<int>(0, (s, i) => s + i.damagedQty)} to return to supplier',
                    color: const Color(0xFFFF9800),
                  ),
                if (keepForClaimItems.isNotEmpty)
                  _buildConfirmItem(
                    '${keepForClaimItems.fold<int>(0, (s, i) => s + i.damagedQty)} kept for claim',
                    color: const Color(0xFF2196F3),
                  ),
                if (writeOffItems.isNotEmpty)
                  _buildConfirmItem(
                    '${writeOffItems.fold<int>(0, (s, i) => s + i.damagedQty)} written off as loss',
                    color: const Color(0xFF6B6B6B),
                  ),
              ],
              if (totalReceived < totalOrdered) ...[
                const SizedBox(height: 12),
                _buildConfirmItem(
                  'Shortage: ${totalOrdered - totalReceived} items not received',
                  color: Colors.orange,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB0B0B0),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Update Stock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Save GRN
    await purchaseOrderStore.createGRN(grn, grnItems);

    // Confirm GRN (this updates PO status)
    final confirmedItems = await purchaseOrderStore.confirmGRN(grn.grnId);

    // Update stock for each item - ONLY acceptedQty goes to stock
    // Use goodQty as fallback for backward compatibility with old data
    for (var item in confirmedItems) {
      final qtyToAdd = item.acceptedQty > 0 ? item.acceptedQty : item.goodQty;
      if (qtyToAdd > 0) {
        final variant = await productStore.getVariantById(item.variantId);
        if (variant != null) {
          final newStock = variant.stockQty + qtyToAdd;
          await productStore.updateVariantStock(item.variantId, newStock);

          // Also update cost price if provided
          if (item.costPrice != null && item.costPrice! > 0) {
            await productStore.updateVariantCostPrice(item.variantId, item.costPrice!);
          }
        }
      }
    }

    // Update supplier balance - only for accepted items value
    await supplierStore.updateSupplierBalance(
      widget.purchaseOrder.supplierId,
      totalAcceptedAmount,
    );

    if (mounted) {
      Navigator.pop(context, true);

      String message = 'Added $totalAccepted items to stock';
      if (totalDamaged > 0) {
        message += ' ($totalDamaged damaged)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  Widget _buildConfirmItem(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: color ?? const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color ?? const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalOrdered = _receivingItems.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final totalReceived = _receivingItems.fold<int>(0, (sum, item) => sum + item.receivedQty);
    final totalAccepted = _receivingItems.fold<int>(0, (sum, item) => sum + item.acceptedQty);
    final totalDamaged = _receivingItems.fold<int>(0, (sum, item) => sum + item.damagedQty);
    final totalAcceptedAmount = _receivingItems.fold<double>(0.0, (sum, item) => sum + item.acceptedAmount);
    final shortage = totalOrdered - totalReceived;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Material Receiving'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _receivingItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'All items received!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No pending items to receive for this PO',
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                // Header Info
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
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
                                  _grnNumber,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PO: ${widget.purchaseOrder.poNumber}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B6B6B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _selectReceivedDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE8E8E8)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B6B6B)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(_receivedDate),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.storefront, size: 16, color: Color(0xFF6B6B6B)),
                          const SizedBox(width: 8),
                          Text(
                            widget.purchaseOrder.supplierName ?? 'Unknown Supplier',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invoiceController,
                        decoration: const InputDecoration(
                          labelText: 'Supplier Invoice Number (Optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // Summary
                Container(
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem('Ordered', totalOrdered.toString(), const Color(0xFF6B6B6B)),
                          ),
                          Expanded(
                            child: _buildSummaryItem('Received', totalReceived.toString(), const Color(0xFF4CAF50)),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'To Stock',
                              totalAccepted.toString(),
                              const Color(0xFF2196F3),
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              'Damaged',
                              totalDamaged.toString(),
                              totalDamaged > 0 ? const Color(0xFFF44336) : const Color(0xFF6B6B6B),
                            ),
                          ),
                        ],
                      ),
                      if (totalDamaged > 0 || shortage > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFFFF9800)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  totalDamaged > 0 && shortage > 0
                                      ? '$totalDamaged damaged, ${shortage} not received'
                                      : totalDamaged > 0
                                          ? '$totalDamaged items damaged'
                                          : '${shortage} items not received',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ),
                              Text(
                                '₹${totalAcceptedAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (totalDamaged == 0 && shortage == 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Stock Value: ₹${totalAcceptedAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Items Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap item to edit',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),

                // Items List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _receivingItems.length,
                    itemBuilder: (context, index) {
                      return _buildReceivingItemCard(index);
                    },
                  ),
                ),

                // Notes
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'e.g., 5 shirts damaged during shipping',
                    ),
                    maxLines: 2,
                  ),
                ),

                // Action Button
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveAndConfirmGRN,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirm Receipt & Update Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
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
    );
  }

  Widget _buildReceivingItemCard(int index) {
    final item = _receivingItems[index];
    final isShortage = item.receivedQty < item.orderedQty;
    final hasDamage = item.damagedQty > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isShortage || hasDamage ? const Color(0xFFFF9800) : const Color(0xFFE8E8E8),
          width: isShortage || hasDamage ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => _showEditItemDialog(index),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                          item.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                  const Icon(Icons.edit, size: 18, color: Color(0xFFB0B0B0)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildQtyChip('Ordered', item.orderedQty, const Color(0xFF6B6B6B)),
                  const SizedBox(width: 8),
                  _buildQtyChip('Received', item.receivedQty, const Color(0xFF4CAF50)),
                  if (hasDamage) ...[
                    const SizedBox(width: 8),
                    _buildQtyChip('Damaged', item.damagedQty, const Color(0xFFF44336)),
                  ],
                  const Spacer(),
                  Text(
                    '₹${(item.receivedQty * item.costPrice).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              if (isShortage || hasDamage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (isShortage)
                        Text(
                          'Shortage: ${item.orderedQty - item.receivedQty}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF9800),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (hasDamage && item.damagedHandling != DamagedHandling.none)
                        Text(
                          _getDamagedHandlingText(item.damagedHandling),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getDamagedHandlingColor(item.damagedHandling),
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildQtyChip(String label, int qty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $qty',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _getDamagedHandlingText(DamagedHandling handling) {
    switch (handling) {
      case DamagedHandling.keepForClaim:
        return 'Keep for Claim';
      case DamagedHandling.returnToSupplier:
        return 'Return to Supplier';
      case DamagedHandling.writeOff:
        return 'Write Off';
      default:
        return '';
    }
  }

  Color _getDamagedHandlingColor(DamagedHandling handling) {
    switch (handling) {
      case DamagedHandling.keepForClaim:
        return const Color(0xFF2196F3);
      case DamagedHandling.returnToSupplier:
        return const Color(0xFFFF9800);
      case DamagedHandling.writeOff:
        return const Color(0xFF6B6B6B);
      default:
        return const Color(0xFF6B6B6B);
    }
  }
}

// Data class for receiving items
class ReceivingItemData {
  final String poItemId;
  final String variantId;
  final String productId;
  final String productName;
  final String? variantInfo;
  final int orderedQty;
  final int receivedQty;
  final int damagedQty;
  final DamagedHandling damagedHandling;
  final double costPrice;

  ReceivingItemData({
    required this.poItemId,
    required this.variantId,
    required this.productId,
    required this.productName,
    this.variantInfo,
    required this.orderedQty,
    required this.receivedQty,
    required this.damagedQty,
    this.damagedHandling = DamagedHandling.none,
    required this.costPrice,
  });

  /// Accepted quantity = received - damaged (only good items go to stock)
  int get acceptedQty => receivedQty - damagedQty;

  /// Amount for accepted items only
  double get acceptedAmount => acceptedQty * costPrice;

  /// Amount for damaged items (for claims/returns)
  double get damagedAmount => damagedQty * costPrice;

  ReceivingItemData copyWith({
    String? poItemId,
    String? variantId,
    String? productId,
    String? productName,
    String? variantInfo,
    int? orderedQty,
    int? receivedQty,
    int? damagedQty,
    DamagedHandling? damagedHandling,
    double? costPrice,
  }) {
    return ReceivingItemData(
      poItemId: poItemId ?? this.poItemId,
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantInfo: variantInfo ?? this.variantInfo,
      orderedQty: orderedQty ?? this.orderedQty,
      receivedQty: receivedQty ?? this.receivedQty,
      damagedQty: damagedQty ?? this.damagedQty,
      damagedHandling: damagedHandling ?? this.damagedHandling,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}