import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../core/di/service_locator.dart';


class CartPanel extends StatefulWidget {
  const CartPanel({super.key});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final _discountController = TextEditingController();
  double _discount = 0.0;

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'shoes':
        return Icons.shopping_bag_outlined;
      case 'jeans':
      case 'clothing':
        return Icons.checkroom_outlined;
      case 'bags':
        return Icons.work_outline;
      case 'electronics':
        return Icons.devices_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _discountController.addListener(() {
      setState(() {
        _discount = double.tryParse(_discountController.text) ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final subtotal = cartStore.totalPrice;
        final total = subtotal - _discount;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cart',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      '${cartStore.itemCount} items',
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE8E8E8), thickness: 0.5),
              // Cart items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: cartStore.itemCount,
                  itemBuilder: (context, index) {
                    // Wrap each item in Observer to react to individual item changes
                    return Observer(
                      builder: (context) {
                        // Access item directly from store to ensure reactivity
                        if (index >= cartStore.items.length) {
                          return const SizedBox.shrink();
                        }
                        final item = cartStore.items[index];

                        return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Product image
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFE8E8E8),
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _getCategoryIcon(item.productName),
                                size: 28,
                                color: const Color(0xFFD0D0D0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Product details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cartStore.getDisplayName(item),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6B6B6B),
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quantity controls
                          Flexible(
                            flex: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE8E8E8),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 16),
                                    color: const Color(0xFF6B6B6B),
                                    onPressed: () {
                                      cartStore.decrementQuantity(item.variantId);
                                    },
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 20),
                                    child: Text(
                                      item.qty.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 16),
                                    color: const Color(0xFF1A1A1A),
                                    onPressed: () async {
                                      final result = await cartStore.incrementQuantity(item.variantId);
                                      if (!result.success && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result.errorMessage ?? 'Cannot add more items'),
                                            backgroundColor: Colors.orange,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE8E8E8), thickness: 0.5),
              // Price summary and payment
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildPriceSummary(subtotal, _discount, total),
                    const SizedBox(height: 20),
                    _buildPaymentButtons(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceSummary(double subtotal, double discount, double total) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Subtotal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0,
              ),
            ),
            Text(
              '₹${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Discount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: Color(0xFF6B6B6B),
                letterSpacing: 0,
              ),
            ),
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFE8E8E8),
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontWeight: FontWeight.w300,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE8E8E8), thickness: 0.5),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0,
              ),
            ),
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildPaymentButton(
            label: 'Cash',
            icon: Icons.payments_outlined,
            isPrimary: false,
            onPressed: () {
              // TODO: Implement cash payment
              Navigator.pop(context);
              cartStore.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment successful'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPaymentButton(
            label: 'Card',
            icon: Icons.credit_card_rounded,
            isPrimary: false,
            onPressed: () {
              // TODO: Implement card payment
              Navigator.pop(context);
              cartStore.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment successful'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPaymentButton(
            label: 'UPI',
            icon: Icons.qr_code_scanner,
            isPrimary: true,
            onPressed: () {
              // TODO: Implement UPI payment
              Navigator.pop(context);
              cartStore.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment successful'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF1A1A1A),
        side: BorderSide(
          color: isPrimary ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
          width: 0.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}