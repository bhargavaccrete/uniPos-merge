import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/data/models/retail/hive_model/hold_sale_model_209.dart';
import '../../../core/di/service_locator.dart';

class ParkedSalesScreen extends StatefulWidget {
  const ParkedSalesScreen({super.key});

  @override
  State<ParkedSalesScreen> createState() => _ParkedSalesScreenState();
}

class _ParkedSalesScreenState extends State<ParkedSalesScreen> {
  @override
  void initState() {
    super.initState();
    holdSaleStore.loadHoldSales();
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _restoreHoldSale(HoldSaleModel holdSale) async {
    try {
      // Get hold sale items
      final items = await holdSaleStore.getItemsForHoldSale(holdSale.holdSaleId);

      if (items.isEmpty) {
        throw Exception('No items found in parked sale');
      }

      // Clear current cart
      await cartStore.clearCart();

      // Add each item to cart
      for (var holdItem in items) {
        final product = productStore.getProductById(holdItem.productId);
        final variant = await productStore.getVariantById(holdItem.variantId);

        if (product != null && variant != null) {
          // Add item with the exact quantity from hold sale
          await cartStore.addItem(product, variant);

          // Update quantity if needed
          if (holdItem.qty > 1) {
            for (int i = 1; i < holdItem.qty; i++) {
              await cartStore.incrementQuantity(holdItem.variantId);
            }
          }
        }
      }

      // Delete hold sale
      await holdSaleStore.deleteHoldSale(holdSale.holdSaleId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parked sale restored to cart!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteHoldSale(HoldSaleModel holdSale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parked Sale'),
        content: const Text('Are you sure you want to delete this parked sale? This action cannot be undone.'),
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

    if (confirmed == true) {
      try {
        await holdSaleStore.deleteHoldSale(holdSale.holdSaleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parked sale deleted'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting sale: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showHoldSaleDetails(HoldSaleModel holdSale) async {
    await holdSaleStore.selectHoldSale(holdSale);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Observer(
        builder: (context) {
          final items = holdSaleStore.currentHoldSaleItems;

          return AlertDialog(
            title: const Text('Parked Sale Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Parked At', _formatDate(holdSale.createdAt)),
                  if (holdSale.note != null)
                    _buildDetailRow('Note', holdSale.note!),
                  _buildDetailRow('Total Items', '${holdSale.totalItems}'),
                  _buildDetailRow('Subtotal', '₹${holdSale.subtotal.toStringAsFixed(2)}'),
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
                  ...items.map((item) => Container(
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
                            item.productName,
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
                                'Qty: ${item.qty}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Price: ₹${item.price.toStringAsFixed(2)}',
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
                    )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  holdSaleStore.clearSelection();
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteHoldSale(holdSale);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restoreHoldSale(holdSale);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restore'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
        title: const Text('Parked Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Observer(
        builder: (context) {
          if (holdSaleStore.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (holdSaleStore.holdSaleCount == 0) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildSummaryCard(),
              Expanded(child: _buildHoldSalesList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pause_circle_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No parked sales',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Parked sales will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB0B0B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Observer(
      builder: (context) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Parked Sales',
                  holdSaleStore.holdSaleCount.toString(),
                  Icons.pause_circle_outline,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Total Value',
                  '₹${holdSaleStore.totalHoldSalesValue.toStringAsFixed(2)}',
                  Icons.currency_rupee,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
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

  Widget _buildHoldSalesList() {
    return Observer(
      builder: (context) {
        final holdSales = holdSaleStore.holdSales;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: holdSales.length,
          itemBuilder: (context, index) {
            final holdSale = holdSales[index];
            return _buildHoldSaleCard(holdSale);
          },
        );
      },
    );
  }

  Widget _buildHoldSaleCard(HoldSaleModel holdSale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF3E0),
          child: Icon(
            Icons.pause_circle_outline,
            color: Colors.orange,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                holdSale.note ?? 'Parked Sale',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatDate(holdSale.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2, size: 14, color: Color(0xFF2196F3)),
                const SizedBox(width: 4),
                Text(
                  '${holdSale.totalItems} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF4CAF50)),
                Text(
                  holdSale.subtotal.toStringAsFixed(2),
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
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF6B6B6B)),
          onSelected: (value) {
            if (value == 'restore') {
              _restoreHoldSale(holdSale);
            } else if (value == 'delete') {
              _deleteHoldSale(holdSale);
            } else if (value == 'details') {
              _showHoldSaleDetails(holdSale);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline, color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 12),
                  Text('Restore to Cart'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 20),
                  SizedBox(width: 12),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showHoldSaleDetails(holdSale),
      ),
    );
  }
}