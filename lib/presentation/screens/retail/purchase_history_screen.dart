import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../../core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/purchase_model_207.dart';
import 'package:unipos/presentation/screens/retail/add_purchase_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    purchaseStore.searchPurchases(query);
  }

  Future<void> _navigateToAddPurchase({PurchaseModel? purchase}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPurchaseScreen(purchase: purchase),
      ),
    );

    if (result == true) {
      purchaseStore.loadPurchases();
    }
  }

  void _showPurchaseDetails(PurchaseModel purchase) async {
    await purchaseStore.selectPurchase(purchase);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Observer(
        builder: (context) {
          final supplier = supplierStore.suppliers
              .where((s) => s.supplierId == purchase.supplierId)
              .firstOrNull;
          final items = purchaseStore.currentPurchaseItems;

          return AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Purchase Details',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToAddPurchase(purchase: purchase);
                  },
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Purchase ID', '#${purchase.purchaseId.substring(purchase.purchaseId.length - 8)}'),
                  _buildDetailRow('Supplier', supplier?.name ?? 'Unknown Supplier'),
                  if (purchase.invoiceNumber != null)
                    _buildDetailRow('Invoice Number', purchase.invoiceNumber!),
                  _buildDetailRow('Date', _formatDate(purchase.purchaseDate)),
                  const Divider(height: 24),
                  _buildDetailRow('Total Items', '${purchase.totalItems}'),
                  _buildDetailRow('Total Amount', '₹${purchase.totalAmount.toStringAsFixed(2)}'),
                  const Divider(height: 24),
                  const Text(
                    'Items:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    final product = productStore.getProductById(item.productId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?.productName ?? 'Unknown Product',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Qty: ${item.quantity}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Cost: ₹${item.costPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Total: ₹${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  purchaseStore.clearSelection();
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Purchase'),
                      content: const Text('Are you sure you want to delete this purchase?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await purchaseStore.deletePurchase(purchase.purchaseId);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase deleted successfully'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
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
        title: const Text('Purchase History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
                  if (purchaseStore.purchaseCount == 0) {
                    return _buildEmptyState();
                  }
                  return _buildAllPurchasesList();
                }

                if (purchaseStore.searchResults.isEmpty) {
                  return _buildNoResultsState();
                }

                return _buildSearchResults();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPurchase(),
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
          hintText: 'Search by invoice number...',
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
                  'Total Purchases',
                  purchaseStore.purchaseCount.toString(),
                  Icons.shopping_cart_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Total Amount',
                  '₹${purchaseStore.totalPurchaseAmount.toStringAsFixed(2)}',
                  Icons.currency_rupee,
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
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No purchases yet',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first purchase using the + button',
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
            'No purchases found',
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

  Widget _buildAllPurchasesList() {
    return Observer(
      builder: (context) {
        final purchases = purchaseStore.purchases;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final purchase = purchases[index];
            return _buildPurchaseCard(purchase);
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
          itemCount: purchaseStore.searchResults.length,
          itemBuilder: (context, index) {
            final purchase = purchaseStore.searchResults[index];
            return _buildPurchaseCard(purchase);
          },
        );
      },
    );
  }

  Widget _buildPurchaseCard(PurchaseModel purchase) {
    // Safely get supplier, handle case where supplier might be deleted
    final supplier = supplierStore.suppliers
        .where((s) => s.supplierId == purchase.supplierId)
        .firstOrNull;

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
          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
          child: const Icon(
            Icons.shopping_cart,
            color: Color(0xFF4CAF50),
            size: 20,
          ),
        ),
        title: Text(
          supplier?.name ?? 'Unknown Supplier',
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
            if (purchase.invoiceNumber != null)
              Text(
                'Invoice: ${purchase.invoiceNumber}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(purchase.purchaseDate),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2, size: 14, color: Color(0xFF2196F3)),
                const SizedBox(width: 4),
                Text(
                  '${purchase.totalItems} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF4CAF50)),
                Text(
                  '${purchase.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB0B0B0)),
        onTap: () => _showPurchaseDetails(purchase),
      ),
    );
  }
}