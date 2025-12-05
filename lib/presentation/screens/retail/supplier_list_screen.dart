import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/supplier_model_205.dart';


class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    supplierStore.searchSuppliers(query);
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
                    content: Text('Name is required'),
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Supplier added successfully'),
                    backgroundColor: Color(0xFF4CAF50),
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

  void _showSupplierDetails(SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (supplier.phone != null) _buildDetailRow('Phone', supplier.phone!),
              if (supplier.address != null) _buildDetailRow('Address', supplier.address!),
              if (supplier.gstNumber != null) _buildDetailRow('GST Number', supplier.gstNumber!),
              const Divider(height: 24),
              _buildDetailRow('Opening Balance', '₹${supplier.openingBalance.toStringAsFixed(2)}'),
              _buildDetailRow('Current Balance', '₹${supplier.currentBalance.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildDetailRow('Created', _formatDate(supplier.createdAt)),
              _buildDetailRow('Last Updated', _formatDate(supplier.updatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showUpdateBalanceDialog(supplier);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Balance'),
          ),
        ],
      ),
    );
  }

  void _showUpdateBalanceDialog(SupplierModel supplier) {
    final amountController = TextEditingController();
    bool isDebit = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Balance: ₹${supplier.currentBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Purchase (Debit)'),
                      value: true,
                      groupValue: isDebit,
                      onChanged: (value) {
                        setState(() {
                          isDebit = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Payment (Credit)'),
                      value: false,
                      groupValue: isDebit,
                      onChanged: (value) {
                        setState(() {
                          isDebit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final finalAmount = isDebit ? amount : -amount;
                await supplierStore.updateSupplierBalance(supplier.supplierId, finalAmount);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Balance updated successfully'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Suppliers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSummaryCard(),
          Expanded(
            child: Observer(
              builder: (context) {
                if (_searchController.text.isEmpty) {
                  if (supplierStore.supplierCount == 0) {
                    return _buildEmptyState();
                  }
                  return _buildAllSuppliersList();
                }

                if (supplierStore.searchResults.isEmpty) {
                  return _buildNoResultsState();
                }

                return _buildSearchResults();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSupplierDialog,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, phone, or GST...',
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Suppliers',
                  supplierStore.supplierCount.toString(),
                  Icons.people_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Total Outstanding',
                  '₹${supplierStore.totalOutstanding.toStringAsFixed(2)}',
                  Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6B6B6B)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No suppliers yet',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first supplier using the + button',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No suppliers found',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No results for "${_searchController.text}"',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSuppliersList() {
    return Observer(
      builder: (context) {
        final suppliers = supplierStore.suppliers;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
            return _buildSupplierCard(supplier);
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Observer(
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: supplierStore.searchResults.length,
          itemBuilder: (context, index) {
            final supplier = supplierStore.searchResults[index];
            return _buildSupplierCard(supplier);
          },
        );
      },
    );
  }

  Widget _buildSupplierCard(SupplierModel supplier) {
    final hasBalance = supplier.currentBalance != 0;
    final isNegative = supplier.currentBalance < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
          child: Text(
            supplier.name[0].toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          supplier.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (supplier.phone != null)
              Text(
                supplier.phone!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
              ),
            if (hasBalance) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isNegative ? Icons.check_circle_outline : Icons.error_outline,
                    size: 14,
                    color: isNegative ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '₹${supplier.currentBalance.abs().toStringAsFixed(2)} ${isNegative ? "Advance" : "Outstanding"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isNegative ? const Color(0xFF4CAF50) : const Color(0xFFFF5722),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB0B0B0)),
        onTap: () => _showSupplierDetails(supplier),
      ),
    );
  }
}