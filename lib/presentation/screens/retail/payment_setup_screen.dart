import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/stores/payment_method_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class PaymentSetupScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const PaymentSetupScreen({Key? key, this.onComplete, this.onSkip})
    : super(key: key);

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  late PaymentMethodStore _store;

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
    _store.init();
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
                SizedBox(height: AppResponsive.largeSpacing(context)),
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
                SizedBox(height: AppResponsive.largeSpacing(context)),
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
                          Icon(
                            entry.value,
                            size: AppResponsive.iconSize(context),
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
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
                if (nameController.text.isNotEmpty &&
                    valueController.text.isNotEmpty) {
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
        content: const Text(
          'Are you sure you want to delete this payment method?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Methods Setup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxCardWidth(context),
        child: Observer(
          builder: (_) {
            if (_store.isLoading && _store.paymentMethods.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                // Header Section
                Container(
                  padding: AppResponsive.padding(context),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Text(
                          'Enable or disable payment methods to show during checkout',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Payment Methods List
                Expanded(
                  child: _store.paymentMethods.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payment,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(
                                height: AppResponsive.largeSpacing(context),
                              ),
                              Text(
                                'No payment methods configured',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: AppResponsive.cardPadding(context),
                          itemCount: _store.paymentMethods.length,
                          itemBuilder: (context, index) {
                            final method = _store.paymentMethods[index];
                            return Card(
                              margin: EdgeInsets.only(
                                bottom: AppResponsive.mediumSpacing(context),
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppResponsive.borderRadius(context),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: EdgeInsets.all(
                                    AppResponsive.mediumSpacing(context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: method.isEnabled
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getIcon(method.iconName),
                                    color: method.isEnabled
                                        ? AppColors.primary
                                        : Colors.grey[400],
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  method.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.subheadingFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: method.isEnabled
                                        ? AppColors.darkNeutral
                                        : Colors.grey[500],
                                  ),
                                ),
                                subtitle: Text(
                                  method.isEnabled ? 'Enabled' : 'Disabled',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.smallFontSize(
                                      context,
                                    ),
                                    color: method.isEnabled
                                        ? AppColors.success
                                        : Colors.grey[500],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: method.isEnabled,
                                      onChanged: (value) =>
                                          _store.togglePaymentMethod(method.id),
                                      activeColor: AppColors.primary,
                                    ),
                                    SizedBox(
                                      width: AppResponsive.smallSpacing(
                                        context,
                                      ),
                                    ),
                                    // Only show delete for custom methods (sortOrder > 6)
                                    if (method.sortOrder > 6)
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: AppColors.danger,
                                        ),
                                        onPressed: () =>
                                            _deleteMethod(method.id),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Action Button
                Container(
                  padding: AppResponsive.cardPadding(context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showAddMethodDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Custom Method'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        if (widget.onSkip != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onSkip,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(color: Colors.grey[400]!),
                                foregroundColor: Colors.grey[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Setup Later',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(width: AppResponsive.mediumSpacing(context)),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.onComplete != null) {
                                widget.onComplete!();
                              } else {
                                Navigator.pop(context);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Payment methods saved successfully',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              widget.onComplete != null ? 'Next' : 'Done',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
