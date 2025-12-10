import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/stores/payment_method_store.dart';
import '../util/color.dart';

/// Payment Setup Step - Setup Wizard Version
/// Matches the design pattern of BusinessTypeStep and TaxSetupStep
class PaymentSetupStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const PaymentSetupStep({
    Key? key,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<PaymentSetupStep> createState() => _PaymentSetupStepState();
}

class _PaymentSetupStepState extends State<PaymentSetupStep> {
  late PaymentMethodStore _store;
  bool _isInitialized = false;

  // Available icon options
  static const Map<String, IconData> _availableIcons = {
    'money': Icons.money,
    'credit_card': Icons.credit_card,
    'qr_code_2': Icons.qr_code_2,
    'account_balance_wallet': Icons.account_balance_wallet,
    'receipt_long': Icons.receipt_long,
    'more_horiz': Icons.more_horiz,
    'payment': Icons.payment,
    'account_balance': Icons.account_balance,
    'attach_money': Icons.attach_money,
    'phone_android': Icons.phone_android,
  };

  @override
  void initState() {
    super.initState();
    _store = locator<PaymentMethodStore>();
    _initializeStore();
  }

  Future<void> _initializeStore() async {
    print('🔧 PaymentSetupStep: Starting initialization...');
    try {
      await _store.init();
      print('🔧 PaymentSetupStep: Store initialized');
      print('🔧 PaymentSetupStep: Payment methods count: ${_store.paymentMethods.length}');
      if (_store.paymentMethods.isNotEmpty) {
        print('🔧 PaymentSetupStep: First method: ${_store.paymentMethods.first.name}');
      }
    } catch (e) {
      print('❌ PaymentSetupStep: Error during init: $e');
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      print('🔧 PaymentSetupStep: Initialization complete, rebuilding UI');
    }
  }

  Future<void> _showAddMethodDialog() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    String selectedIcon = 'payment';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'e.g., PayTM, GPay',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: 'Internal Value',
                    hintText: 'e.g., paytm, gpay',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  decoration: InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: _availableIcons.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Row(
                        children: [
                          Icon(entry.value, size: 20),
                          const SizedBox(width: 8),
                          Text(entry.key),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedIcon = value!;
                    });
                  },
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
                if (nameController.text.isNotEmpty && valueController.text.isNotEmpty) {
                  await _store.addPaymentMethod(
                    name: nameController.text,
                    value: valueController.text,
                    iconName: selectedIcon,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMethod(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: const Text('Are you sure you want to delete this payment method?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _store.deletePaymentMethod(id);
    }
  }

  IconData _getIcon(String iconName) {
    return _availableIcons[iconName] ?? Icons.payment;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Loading payment methods...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enable or disable payment methods for checkout',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.info.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Default payment methods are pre-configured. You can add custom methods below.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Payment Methods List
          Observer(
            builder: (_) {
              if (_store.isLoading && _store.paymentMethods.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_store.paymentMethods.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No payment methods configured',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payment, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Available Payment Methods',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkNeutral,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Payment Methods
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _store.paymentMethods.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final method = _store.paymentMethods[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: method.isEnabled
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: method.isEnabled
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getIcon(method.iconName),
                                  color: method.isEnabled
                                      ? AppColors.primary
                                      : Colors.grey[400],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      method.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: method.isEnabled
                                            ? AppColors.darkNeutral
                                            : Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      method.isEnabled ? 'Enabled' : 'Disabled',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: method.isEnabled
                                            ? AppColors.success
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: method.isEnabled,
                                onChanged: (value) => _store.togglePaymentMethod(method.id),
                                activeColor: AppColors.primary,
                              ),
                              // Only show delete for custom methods (sortOrder > 6)
                              if (method.sortOrder > 6) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete, color: AppColors.danger, size: 20),
                                  onPressed: () => _deleteMethod(method.id),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    // Add Custom Method Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton.icon(
                        onPressed: _showAddMethodDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Custom Method'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}