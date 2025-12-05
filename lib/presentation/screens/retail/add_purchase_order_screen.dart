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
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No suppliers found. Please add a supplier first.'),
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

  void _showVariantSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Product'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<VarianteModel>>(
            future: productStore.getAllVariants(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No products found. Please add products first.'),
                  ),
                );
              }

              final variants = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: variants.length,
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  final product = productStore.getProductById(variant.productId);
                  return ListTile(
                    title: Text(product?.productName ?? 'Unknown'),
                    subtitle: Text(_getVariantDescription(variant)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Stock: ${variant.stockQty}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (variant.costPrice != null)
                          Text(
                            '₹${variant.costPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedVariant = variant;
                        _priceController.text = variant.costPrice?.toString() ?? '';
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
        ],
      ),
    );
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