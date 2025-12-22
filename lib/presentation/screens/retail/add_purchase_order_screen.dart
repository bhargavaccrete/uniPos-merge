import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_model_211.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_order_item_model_212.dart';
import 'package:unipos/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';

class AddPurchaseOrderScreen extends StatefulWidget {
  final PurchaseOrderModel? purchaseOrder;

  const AddPurchaseOrderScreen({super.key, this.purchaseOrder});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  SupplierModel? _selectedSupplier;
  DateTime _expectedDeliveryDate = DateTime.now().add(const Duration(days: 7));
  final TextEditingController _notesController = TextEditingController();
  final List<POItemData> _orderItems = [];
  late String _poNumber;

  bool get isEditing => widget.purchaseOrder != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadPOData();
    } else {
      _poNumber = purchaseOrderStore.generatePONumber();
    }
  }

  Future<void> _loadPOData() async {
    if (widget.purchaseOrder == null) return;

    final po = widget.purchaseOrder!;
    _poNumber = po.poNumber;
    _expectedDeliveryDate = DateTime.parse(po.expectedDeliveryDate);
    _notesController.text = po.notes ?? '';

    // Find supplier
    _selectedSupplier = supplierStore.suppliers
        .where((s) => s.supplierId == po.supplierId)
        .firstOrNull;

    // Load items
    await purchaseOrderStore.loadPOItems(po.poId);
    final items = purchaseOrderStore.currentPOItems;

    final loadedItems = <POItemData>[];
    for (var item in items) {
      final variant = await productStore.getVariantById(item.variantId);
      if (variant != null) {
        loadedItems.add(POItemData(
          variant: variant,
          orderedQty: item.orderedQty,
          estimatedPrice: item.estimatedPrice,
          poItemId: item.poItemId,
        ));
      }
    }

    setState(() {
      _orderItems.clear();
      _orderItems.addAll(loadedItems);
    });
  }

  Future<void> _selectDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _expectedDeliveryDate = picked;
      });
    }
  }

  Future<void> _savePO() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final po = isEditing
        ? widget.purchaseOrder!.copyWith(
            supplierId: _selectedSupplier!.supplierId,
            supplierName: _selectedSupplier!.name,
            expectedDeliveryDate: _expectedDeliveryDate.toIso8601String(),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          )
        : PurchaseOrderModel.create(
            poNumber: _poNumber,
            supplierId: _selectedSupplier!.supplierId,
            supplierName: _selectedSupplier!.name,
            expectedDeliveryDate: _expectedDeliveryDate.toIso8601String(),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );

    final items = _orderItems
        .map((item) => PurchaseOrderItemModel.create(
              poId: po.poId,
              variantId: item.variant.varianteId,
              productId: item.variant.productId,
              productName: productStore.getProductById(item.variant.productId)?.productName,
              variantInfo: _getVariantDescription(item.variant),
              orderedQty: item.orderedQty,
              estimatedPrice: item.estimatedPrice,
            ))
        .toList();

    if (isEditing) {
      await purchaseOrderStore.updatePurchaseOrder(po, items);
    } else {
      await purchaseOrderStore.addPurchaseOrder(po, items);
    }

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Purchase Order updated' : 'Purchase Order created'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _showSupplierSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Supplier'),
        content: SizedBox(
          width: double.maxFinite,
          child: Observer(
            builder: (context) {
              final suppliers = supplierStore.suppliers;
              if (suppliers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No suppliers found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a supplier to create purchase orders',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B6B6B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddSupplierDialog();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Supplier'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
                      child: Text(
                        supplier.name[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFF2196F3)),
                      ),
                    ),
                    title: Text(supplier.name),
                    subtitle: supplier.phone != null ? Text(supplier.phone!) : null,
                    onTap: () {
                      setState(() {
                        _selectedSupplier = supplier;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAddSupplierDialog();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final gstController = TextEditingController();
    final openingBalanceController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstController,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: openingBalanceController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Supplier name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final openingBalance = double.tryParse(openingBalanceController.text) ?? 0;

              final newSupplier = SupplierModel.create(
                name: nameController.text.trim(),
                phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                gstNumber: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                openingBalance: openingBalance,
                currentBalance: openingBalance,
              );

              await supplierStore.addSupplier(newSupplier);

              if (mounted) {
                // Auto-select the newly added supplier
                setState(() {
                  _selectedSupplier = newSupplier;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Supplier "${newSupplier.name}" added and selected'),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Supplier'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPOItemDialog(
        onAdd: (item) {
          setState(() {
            _orderItems.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  void _editItemQty(int index) {
    final item = _orderItems[index];
    final controller = TextEditingController(text: item.orderedQty.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(controller.text) ?? 0;
              if (newQty > 0) {
                setState(() {
                  _orderItems[index] = item.copyWith(orderedQty: newQty);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getVariantDescription(VarianteModel variant) {
    return variant.variantDescription;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _orderItems.fold<int>(0, (sum, item) => sum + item.orderedQty);
    final estimatedTotal = _orderItems.fold<double>(
        0.0, (sum, item) => sum + (item.orderedQty * (item.estimatedPrice ?? 0)));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Purchase Order' : 'Create Purchase Order'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _savePO,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // PO Header Info
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PO Number
                  Row(
                    children: [
                      const Icon(Icons.tag, color: Color(0xFF6B6B6B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _poNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Supplier Selection
                  InkWell(
                    onTap: isEditing && widget.purchaseOrder!.statusEnum != POStatus.draft
                        ? null
                        : _showSupplierSelection,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront, color: Color(0xFF6B6B6B), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedSupplier?.name ?? 'Select Supplier *',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedSupplier == null
                                    ? const Color(0xFFB0B0B0)
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF6B6B6B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Expected Delivery Date
                  InkWell(
                    onTap: _selectDeliveryDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF6B6B6B), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Expected: ${_formatDate(_expectedDeliveryDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit, color: Color(0xFF6B6B6B), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes (single line)
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),

          // Summary
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Items',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                      ),
                      Text(
                        totalItems.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Estimated Total',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                      ),
                      Text(
                        estimatedTotal > 0 ? '₹${estimatedTotal.toStringAsFixed(2)}' : '--',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Items List Header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_orderItems.length} products',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items List
          _orderItems.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No items added',
                          style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap + button to add items',
                          style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _orderItems[index];
                        return _buildItemCard(item, index);
                      },
                      childCount: _orderItems.length,
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildItemCard(POItemData item, int index) {
    final product = productStore.getProductById(item.variant.productId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?.productName ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getVariantDescription(item.variant),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _editItemQty(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: ${item.orderedQty}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ),
                      ),
                      if (item.estimatedPrice != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '@ ₹${item.estimatedPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (item.estimatedPrice != null)
                  Text(
                    '₹${(item.orderedQty * item.estimatedPrice!).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Data class for PO items during editing
class POItemData {
  final VarianteModel variant;
  final int orderedQty;
  final double? estimatedPrice;
  final String? poItemId;

  POItemData({
    required this.variant,
    required this.orderedQty,
    this.estimatedPrice,
    this.poItemId,
  });

  POItemData copyWith({
    VarianteModel? variant,
    int? orderedQty,
    double? estimatedPrice,
    String? poItemId,
  }) {
    return POItemData(
      variant: variant ?? this.variant,
      orderedQty: orderedQty ?? this.orderedQty,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      poItemId: poItemId ?? this.poItemId,
    );
  }
}

// Dialog for adding items to PO
class _AddPOItemDialog extends StatefulWidget {
  final Function(POItemData) onAdd;

  const _AddPOItemDialog({required this.onAdd});

  @override
  State<_AddPOItemDialog> createState() => _AddPOItemDialogState();
}

class _AddPOItemDialogState extends State<_AddPOItemDialog> {
  VarianteModel? _selectedVariant;
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();

  void _showVariantSelection() async {
    // Show product search dialog
    final selectedVariants = await showDialog<List<VarianteModel>>(
      context: context,
      builder: (context) => const _ProductSearchDialog(),
    );

    if (selectedVariants != null && selectedVariants.isNotEmpty && mounted) {
      // Show quantity confirmation dialog
      final quantityData = await showDialog<Map<VarianteModel, _QuantityPriceData>>(
        context: context,
        builder: (context) => _QuantityConfirmationDialog(
          variants: selectedVariants,
          onConfirm: (data) {
            Navigator.pop(context, data);
          },
        ),
      );

      if (quantityData != null && quantityData.isNotEmpty) {
        // Add all selected products to the order
        for (var entry in quantityData.entries) {
          widget.onAdd(POItemData(
            variant: entry.key,
            orderedQty: entry.value.quantity,
            estimatedPrice: entry.value.price,
          ));
        }

        // Check if widget is still mounted before popping
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    if (variant.size != null) parts.add(variant.size!);
    if (variant.color != null) parts.add(variant.color!);
    if (variant.weight != null) parts.add(variant.weight!);
    // Add custom attributes
    if (variant.customAttributes != null && variant.customAttributes!.isNotEmpty) {
      for (var entry in variant.customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item to Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _showVariantSelection,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Color(0xFF6B6B6B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedVariant == null
                            ? 'Select Product *'
                            : '${productStore.getProductById(_selectedVariant!.productId)?.productName ?? "Unknown"}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedVariant == null
                              ? const Color(0xFFB0B0B0)
                              : const Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF6B6B6B)),
                  ],
                ),
              ),
            ),
            if (_selectedVariant != null) ...[
              const SizedBox(height: 8),
              Text(
                _getVariantDescription(_selectedVariant!),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Estimated Price (Optional)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
                helperText: 'Leave empty if unknown',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            if (_selectedVariant == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a product'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            final quantity = int.tryParse(_quantityController.text) ?? 0;
            if (quantity <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid quantity'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            final price = _priceController.text.isNotEmpty
                ? double.tryParse(_priceController.text)
                : null;

            widget.onAdd(POItemData(
              variant: _selectedVariant!,
              orderedQty: quantity,
              estimatedPrice: price,
            ));

            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Helper class to hold quantity and price data
class _QuantityPriceData {
  final int quantity;
  final double? price;

  _QuantityPriceData({required this.quantity, this.price});
}

// Product Search Dialog with search functionality and multiple selection
class _ProductSearchDialog extends StatefulWidget {
  final Function(Map<VarianteModel, _QuantityPriceData>)? onMultipleSelect;

  const _ProductSearchDialog({this.onMultipleSelect});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<VarianteModel> _allVariants = [];
  List<VarianteModel> _filteredVariants = [];
  final Set<String> _selectedVariantIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
    _searchController.addListener(_filterVariants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVariants() async {
    final variants = await productStore.getAllVariants();
    setState(() {
      _allVariants = variants;
      _filteredVariants = variants;
      _isLoading = false;
    });
  }

  void _filterVariants() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredVariants = _allVariants;
      });
      return;
    }

    setState(() {
      _filteredVariants = _allVariants.where((variant) {
        final product = productStore.getProductById(variant.productId);
        final productName = product?.productName?.toLowerCase() ?? '';
        final variantDesc = _getVariantDescription(variant).toLowerCase();
        final sku = variant.sku?.toLowerCase() ?? '';
        final barcode = variant.barcode?.toLowerCase() ?? '';

        return productName.contains(query) ||
               variantDesc.contains(query) ||
               sku.contains(query) ||
               barcode.contains(query);
      }).toList();
    });
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    if (variant.size != null) parts.add(variant.size!);
    if (variant.color != null) parts.add(variant.color!);
    if (variant.weight != null) parts.add(variant.weight!);
    if (variant.customAttributes != null && variant.customAttributes!.isNotEmpty) {
      for (var entry in variant.customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Product'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products, SKU, barcode...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Selection controls and results count
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedVariantIds.isEmpty
                        ? (_searchController.text.isNotEmpty
                            ? '${_filteredVariants.length} result${_filteredVariants.length != 1 ? 's' : ''} found'
                            : '${_filteredVariants.length} product${_filteredVariants.length != 1 ? 's' : ''}')
                        : '${_selectedVariantIds.length} selected',
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedVariantIds.isEmpty ? const Color(0xFF6B6B6B) : const Color(0xFF4CAF50),
                      fontWeight: _selectedVariantIds.isEmpty ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                if (_filteredVariants.isNotEmpty) ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedVariantIds.length == _filteredVariants.length) {
                          _selectedVariantIds.clear();
                        } else {
                          _selectedVariantIds.clear();
                          _selectedVariantIds.addAll(_filteredVariants.map((v) => v.varianteId));
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _selectedVariantIds.length == _filteredVariants.length ? 'Clear All' : 'Select All',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Product List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredVariants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchController.text.isEmpty
                                    ? Icons.inventory_2_outlined
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'No products found.\nPlease add products first.'
                                    : 'No products match your search',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B6B6B),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredVariants.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final variant = _filteredVariants[index];
                            final product = productStore.getProductById(variant.productId);
                            final isSelected = _selectedVariantIds.contains(variant.varianteId);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedVariantIds.add(variant.varianteId);
                                    } else {
                                      _selectedVariantIds.remove(variant.varianteId);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF4CAF50),
                              ),
                              title: Text(
                                product?.productName ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getVariantDescription(variant),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: variant.stockQty > 0
                                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Stock: ${variant.stockQty}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: variant.stockQty > 0
                                                ? const Color(0xFF4CAF50)
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                      if (variant.costPrice != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${variant.costPrice!.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedVariantIds.remove(variant.varianteId);
                                  } else {
                                    _selectedVariantIds.add(variant.varianteId);
                                  }
                                });
                              },
                            );
                          },
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
        if (_selectedVariantIds.isNotEmpty)
          ElevatedButton(
            onPressed: () {
              final selectedVariants = _allVariants
                  .where((v) => _selectedVariantIds.contains(v.varianteId))
                  .toList();

              // Pop this dialog and pass the selected variants
              Navigator.pop(context, selectedVariants);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: Text('Add Selected (${_selectedVariantIds.length})'),
          ),
      ],
    );
  }
}

// Dialog to set quantities for multiple selected products
class _QuantityConfirmationDialog extends StatefulWidget {
  final List<VarianteModel> variants;
  final Function(Map<VarianteModel, _QuantityPriceData>) onConfirm;

  const _QuantityConfirmationDialog({
    required this.variants,
    required this.onConfirm,
  });

  @override
  State<_QuantityConfirmationDialog> createState() => _QuantityConfirmationDialogState();
}

class _QuantityConfirmationDialogState extends State<_QuantityConfirmationDialog> {
  late Map<String, TextEditingController> _quantityControllers;
  late Map<String, TextEditingController> _priceControllers;

  @override
  void initState() {
    super.initState();
    _quantityControllers = {};
    _priceControllers = {};

    for (var variant in widget.variants) {
      _quantityControllers[variant.varianteId] = TextEditingController(text: '1');
      _priceControllers[variant.varianteId] = TextEditingController(
        text: variant.costPrice?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    if (variant.size != null) parts.add(variant.size!);
    if (variant.color != null) parts.add(variant.color!);
    if (variant.weight != null) parts.add(variant.weight!);
    if (variant.customAttributes != null && variant.customAttributes!.isNotEmpty) {
      for (var entry in variant.customAttributes!.entries) {
        parts.add('${entry.key}: ${entry.value}');
      }
    }
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set Quantities (${widget.variants.length} items)'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListView.separated(
          itemCount: widget.variants.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final variant = widget.variants[index];
            final product = productStore.getProductById(variant.productId);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name and variant
                  Text(
                    product?.productName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getVariantDescription(variant),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quantity and Price inputs
                  Row(
                    children: [
                      // Quantity input
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _quantityControllers[variant.varianteId],
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Price input
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _priceControllers[variant.varianteId],
                          decoration: const InputDecoration(
                            labelText: 'Price (Optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            prefixText: '₹ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Build map of variants with their quantities and prices
            final result = <VarianteModel, _QuantityPriceData>{};

            for (var variant in widget.variants) {
              final qty = int.tryParse(_quantityControllers[variant.varianteId]!.text) ?? 0;
              if (qty > 0) {
                final price = _priceControllers[variant.varianteId]!.text.isNotEmpty
                    ? double.tryParse(_priceControllers[variant.varianteId]!.text)
                    : null;

                result[variant] = _QuantityPriceData(
                  quantity: qty,
                  price: price,
                );
              }
            }

            if (result.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter valid quantities'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // Pop with the result data
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add to Order'),
        ),
      ],
    );
  }
}