import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/stores/payment_method_store.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late PaymentMethodStore _paymentStore;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paymentStore = locator<PaymentMethodStore>();
    _paymentStore.loadPaymentMethods();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Icon mapping for payment methods
  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'money':
        return Icons.money;
      case 'credit_card':
        return Icons.credit_card;
      case 'qr_code_2':
        return Icons.qr_code_2;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'receipt_long':
        return Icons.receipt_long;
      default:
        return Icons.payment;
    }
  }

  void _showAddDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Add Payment Method',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Method Name',
                hintText: 'e.g., PhonePe, Google Pay',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
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
              if (_nameController.text.isNotEmpty) {
                await _paymentStore.addPaymentMethod(
                  name: _nameController.text,
                  value: _nameController.text.toLowerCase().replaceAll(' ', '_'),
                  iconName: 'payment',
                );
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_nameController.text} added successfully'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String id, String currentName) {
    _nameController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Payment Method',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Method Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
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
              if (_nameController.text.isNotEmpty) {
                final method = _paymentStore.paymentMethods.firstWhere((m) => m.id == id);
                final updatedMethod = method.copyWith(
                  name: _nameController.text,
                  value: _nameController.text.toLowerCase().replaceAll(' ', '_'),
                );
                await _paymentStore.updatePaymentMethod(updatedMethod);
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment method updated successfully'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Payment Methods",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () async {
              await _paymentStore.init();
              if (mounted) {
                final count = _paymentStore.paymentMethods.length;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Refreshed: Found $count payment methods'),
                    backgroundColor: count > 0 ? const Color(0xFF4CAF50) : Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Payment Method',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (_paymentStore.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_paymentStore.paymentMethods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No payment methods found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Payment Method'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _paymentStore.paymentMethods.length,
            itemBuilder: (context, index) {
              final method = _paymentStore.paymentMethods[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: method.isEnabled
                        ? const Color(0xFF4CAF50).withOpacity(0.3)
                        : const Color(0xFFE8E8E8),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: method.isEnabled
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIcon(method.iconName),
                      color: method.isEnabled ? const Color(0xFF4CAF50) : Colors.grey,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    method.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    method.isEnabled ? 'Active' : 'Disabled',
                    style: TextStyle(
                      fontSize: 13,
                      color: method.isEnabled ? const Color(0xFF4CAF50) : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enable/Disable Switch
                      Switch(
                        value: method.isEnabled,
                        onChanged: (value) async {
                          await _paymentStore.togglePaymentMethod(method.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${method.name} ${value ? 'enabled' : 'disabled'}',
                                ),
                                backgroundColor: const Color(0xFF4CAF50),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        activeColor: const Color(0xFF4CAF50),
                      ),
                      // Edit Button
                      IconButton(
                        onPressed: () => _showEditDialog(method.id, method.name),
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF2196F3)),
                        tooltip: 'Edit',
                      ),
                      // Delete Button
                      IconButton(
                        onPressed: () async {
                          // Show confirmation dialog
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text(
                                'Delete Payment Method',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              content: Text(
                                'Are you sure you want to delete "${method.name}"?',
                              ),
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

                          if (confirm == true) {
                            await _paymentStore.deletePaymentMethod(method.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${method.name} deleted'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
