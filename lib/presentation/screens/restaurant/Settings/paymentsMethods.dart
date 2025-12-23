import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/stores/payment_method_store.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';

class Paymentsmethods extends StatefulWidget {
  @override
  _paymentsmethodsState createState() => _paymentsmethodsState();
}

class _paymentsmethodsState extends State<Paymentsmethods> {
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
        return Icons.more_horiz;
    }
  }

  void _showAddDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Method Name',
                hintText: 'e.g., PhonePe, Google Pay',
                border: OutlineInputBorder(),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_nameController.text} added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
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
        title: const Text('Edit Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Method Name',
                border: OutlineInputBorder(),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment method updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: const Text(
          "Payment Methods",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person),
                SizedBox(width: 5),
                Text('Admin'),
              ],
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
CommonButton(
                  onTap: () async {
                    // Force re-initialization
                    await _paymentStore.init();
                    if (mounted) {
                      final count = _paymentStore.paymentMethods.length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Refreshed: Found $count payment methods'),
                          backgroundColor: count > 0 ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  },
                  bordercircular: 10,
                  height: 50,
                  width: 120,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        "Sync",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CommonButton(
                  onTap: _showAddDialog,
                  bordercircular: 10,
                  height: 50,
                  width: 120,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        "Add",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Observer(
              builder: (_) {
                if (_paymentStore.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_paymentStore.paymentMethods.isEmpty) {
                  return const Center(
                    child: Text('No payment methods found'),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Container(
                      width: width > 800 ? width : 800,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue),
                        columns: const [
                          DataColumn(
                            label: Text(
                              "Sr No",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Icon",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Method Name",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Status",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Actions",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        rows: _paymentStore.paymentMethods
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final method = entry.value;

                          return DataRow(
                            cells: [
                              DataCell(Text("${index + 1}")),
                              DataCell(Icon(
                                _getIcon(method.iconName),
                                color: method.isEnabled ? Colors.green : Colors.grey,
                              )),
                              DataCell(Text(method.name)),
                              DataCell(
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
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  activeColor: Colors.green,
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _showEditDialog(method.id, method.name),
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        // Show confirmation dialog
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Payment Method'),
                                            content: Text(
                                              'Are you sure you want to delete ${method.name}?',
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
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
