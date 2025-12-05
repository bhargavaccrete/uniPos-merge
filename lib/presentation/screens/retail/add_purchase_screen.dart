import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_model_207.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_Item_model_206.dart';
import 'package:unipos/data/models/retail/hive_model/supplier_model_205.dart';
import 'package:unipos/data/models/retail/hive_model/variante_model_201.dart';

class AddPurchaseScreen extends StatefulWidget {
  final PurchaseModel? purchase;

  const AddPurchaseScreen({super.key, this.purchase});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final TextEditingController _invoiceController = TextEditingController();
  SupplierModel? _selectedSupplier;
  final List<PurchaseItemData> _purchaseItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.purchase != null) {
      _loadPurchaseData();
    }
  }

  Future<void> _loadPurchaseData() async {
    if (widget.purchase == null) return;

    _invoiceController.text = widget.purchase!.invoiceNumber ?? '';
    _selectedSupplier = supplierStore.suppliers
        .firstWhere((s) => s.supplierId == widget.purchase!.supplierId);

    final items = await purchaseStore.getItemsByPurchaseId(widget.purchase!.purchaseId);
    final loadedItems = <PurchaseItemData>[];

    for (var item in items) {
      final variant = await productStore.getVariantById(item.variantId);
      if (variant != null) {
        loadedItems.add(PurchaseItemData(
          variant: variant,
          quantity: item.quantity,
          costPrice: item.costPrice,
          mrp: item.mrp,
        ));
      }
    }

    setState(() {
      _purchaseItems.clear();
      _purchaseItems.addAll(loadedItems);
    });
  }

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalAmount = _purchaseItems.fold(
        0.0, (sum, item) => sum + (item.quantity * item.costPrice));
    final totalItems = _purchaseItems.fold(0, (sum, item) => sum + item.quantity);

    final purchase = widget.purchase == null
        ? PurchaseModel.create(
            supplierId: _selectedSupplier!.supplierId,
            invoiceNumber: _invoiceController.text.isEmpty
                ? null
                : _invoiceController.text.trim(),
            totalItems: totalItems,
            totalAmount: totalAmount,
          )
        : PurchaseModel(
            purchaseId: widget.purchase!.purchaseId,
            supplierId: _selectedSupplier!.supplierId,
            invoiceNumber: _invoiceController.text.isEmpty
                ? null
                : _invoiceController.text.trim(),
            totalItems: totalItems,
            totalAmount: totalAmount,
            purchaseDate: widget.purchase!.purchaseDate,
            createdAt: widget.purchase!.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
          );

    final items = _purchaseItems
        .map((item) => PurchaseItemModel.create(
              purchaseId: purchase.purchaseId,
              variantId: item.variant.varianteId,
              productId: item.variant.productId,
              quantity: item.quantity,
              costPrice: item.costPrice,
              mrp: item.mrp,
            ))
        .toList();

    // Update stock quantities
    for (var item in _purchaseItems) {
      // Get the latest variant data to ensure we have current stock
      final variant = await productStore.getVariantById(item.variant.varianteId);
      final currentStock = variant?.stockQty ?? 0;
      await productStore.updateVariantStock(
          item.variant.varianteId, currentStock + item.quantity);
    }

    // Update supplier balance
    await supplierStore.updateSupplierBalance(
        _selectedSupplier!.supplierId, totalAmount);

    if (widget.purchase == null) {
      await purchaseStore.addPurchase(purchase, items);
    } else {
      await purchaseStore.updatePurchase(purchase, items);
    }

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.purchase == null
              ? 'Purchase added successfully'
              : 'Purchase updated successfully'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _showSupplierSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Select Supplier'),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAddSupplierDialog();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Observer(
            builder: (context) {
              final suppliers = supplierStore.suppliers;
              if (suppliers.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No suppliers found',
                      style: TextStyle(color: Color(0xFF6B6B6B)),
                    ),
                    const SizedBox(height: 8),
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
                      ),
                    ),
                  ],
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

  void _showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final gstController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Supplier'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter supplier name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: gstController,
                  decoration: const InputDecoration(
                    labelText: 'GST Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newSupplier = SupplierModel.create(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  address: addressController.text.trim().isEmpty
                      ? null
                      : addressController.text.trim(),
                  gstNumber: gstController.text.trim().isEmpty
                      ? null
                      : gstController.text.trim().toUpperCase(),
                );

                await supplierStore.addSupplier(newSupplier);

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _selectedSupplier = newSupplier;
                  });
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Supplier "${newSupplier.name}" added and selected'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPurchaseItemDialog(
        onAdd: (item) {
          setState(() {
            _purchaseItems.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _purchaseItems.fold(
        0.0, (sum, item) => sum + (item.quantity * item.costPrice));
    final totalItems = _purchaseItems.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(widget.purchase == null ? 'Add Purchase' : 'Edit Purchase'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePurchase,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                InkWell(
                  onTap: _showSupplierSelection,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Color(0xFF6B6B6B)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedSupplier?.name ?? 'Select Supplier',
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
                const SizedBox(height: 16),
                TextField(
                  controller: _invoiceController,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Number (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(20),
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
                      'Total Amount',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
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
          Expanded(
            child: _purchaseItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey[300]),
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _purchaseItems.length,
                    itemBuilder: (context, index) {
                      final item = _purchaseItems[index];
                      return _buildPurchaseItemCard(item, index);
                    },
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

  Widget _buildPurchaseItemCard(PurchaseItemData item, int index) {
    final product = productStore.getProductById(item.variant.productId);
    final subtotal = item.quantity * item.costPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Padding(
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
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailColumn('Quantity', '${item.quantity}'),
                _buildDetailColumn('Cost Price', '₹${item.costPrice.toStringAsFixed(2)}'),
                _buildDetailColumn('MRP', '₹${item.mrp.toStringAsFixed(2)}'),
                _buildDetailColumn('Subtotal', '₹${subtotal.toStringAsFixed(2)}',
                    isHighlighted: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value, {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
            color: isHighlighted ? const Color(0xFF4CAF50) : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  String _getVariantDescription(VarianteModel variant) {
    List<String> parts = [];
    if (variant.size != null) parts.add(variant.size!);
    if (variant.color != null) parts.add(variant.color!);
    if (variant.weight != null) parts.add(variant.weight!);
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }
}

class PurchaseItemData {
  final VarianteModel variant;
  int quantity;
  double costPrice;
  double mrp;

  PurchaseItemData({
    required this.variant,
    required this.quantity,
    required this.costPrice,
    required this.mrp,
  });
}

class _AddPurchaseItemDialog extends StatefulWidget {
  final Function(PurchaseItemData) onAdd;

  const _AddPurchaseItemDialog({required this.onAdd});

  @override
  State<_AddPurchaseItemDialog> createState() => _AddPurchaseItemDialogState();
}

class _AddPurchaseItemDialogState extends State<_AddPurchaseItemDialog> {
  VarianteModel? _selectedVariant;
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();

  void _showVariantSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Product Variant'),
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

                  child: Text('No variants found. Please add products first.'),
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
                    trailing: Text(
                      'Stock: ${variant.stockQty}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedVariant = variant;
                        _costPriceController.text =
                            variant.costPrice?.toString() ?? '0';
                        _mrpController.text = variant.mrp?.toString() ?? '0';
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
    if (variant.sku != null) parts.add('SKU: ${variant.sku}');
    return parts.isEmpty ? 'Default Variant' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Purchase Item'),
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
                            ? 'Select Product Variant'
                            : '${productStore.getProductById(_selectedVariant!.productId)?.productName ?? "Unknown"} - ${_getVariantDescription(_selectedVariant!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedVariant == null
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
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costPriceController,
              decoration: const InputDecoration(
                labelText: 'Cost Price',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mrpController,
              decoration: const InputDecoration(
                labelText: 'MRP (Selling Price)',
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
          onPressed: () {
            if (_selectedVariant == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a variant'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            final quantity = int.tryParse(_quantityController.text) ?? 0;
            final costPrice = double.tryParse(_costPriceController.text) ?? 0;
            final mrp = double.tryParse(_mrpController.text) ?? 0;

            if (quantity <= 0 || costPrice <= 0 || mrp <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter valid values'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            widget.onAdd(PurchaseItemData(
              variant: _selectedVariant!,
              quantity: quantity,
              costPrice: costPrice,
              mrp: mrp,
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