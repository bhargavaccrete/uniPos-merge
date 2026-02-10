import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/stores/payment_method_store.dart';
import 'package:unipos/util/color.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_circle_rounded,
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),

            // Content
            Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Method Name',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  hintText: 'e.g., PhonePe, Google Pay',
                  hintStyle: GoogleFonts.poppins(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                NotificationService.instance.showSuccess('${_nameController.text} added successfully');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 24,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),

            // Content
            Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Method Name',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
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
                NotificationService.instance.showSuccess('Payment method updated successfully');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Update',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final width = size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Payment Methods',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Action Buttons Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Force re-initialization
                      await _paymentStore.init();
                      if (mounted) {
                        final count = _paymentStore.paymentMethods.length;
                        NotificationService.instance.showSuccess('Refreshed: Found $count payment methods');
                      }
                    },
                    icon: Icon(Icons.sync_rounded, size: isTablet ? 20 : 18),
                    label: Text(
                      'Sync',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 14 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: Icon(Icons.add_circle_rounded, size: isTablet ? 20 : 18),
                    label: Text(
                      'Add New',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 14 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Observer(
              builder: (_) {
                if (_paymentStore.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (_paymentStore.paymentMethods.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.payment_rounded,
                            size: isTablet ? 64 : 56,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No payment methods found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a payment method to get started',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Container(
                      width: width > 800 ? width : 800,
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.primary),
                            headingRowHeight: isTablet ? 56 : 50,
                            dataRowMinHeight: isTablet ? 60 : 56,
                            dataRowMaxHeight: isTablet ? 70 : 65,
                            columns: [
                              DataColumn(
                                label: Text(
                                  "Sr No",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Icon",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Method Name",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Status",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 15 : 14,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Actions",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 15 : 14,
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
                                color: WidgetStateProperty.all(
                                  index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      "${index + 1}",
                                      style: GoogleFonts.poppins(
                                        fontSize: isTablet ? 15 : 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: method.isEnabled
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getIcon(method.iconName),
                                        color: method.isEnabled ? Colors.green : Colors.grey,
                                        size: isTablet ? 24 : 22,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      method.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: isTablet ? 15 : 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Switch(
                                      value: method.isEnabled,
                                      onChanged: (value) async {
                                        await _paymentStore.togglePaymentMethod(method.id);
                                        if (mounted) {
                                          NotificationService.instance.showSuccess('${method.name} ${value ? 'enabled' : 'disabled'}');
                                        }
                                      },
                                      activeColor: Colors.green,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            onPressed: () => _showEditDialog(method.id, method.name),
                                            icon: Icon(
                                              Icons.edit_rounded,
                                              color: Colors.blue,
                                              size: isTablet ? 22 : 20,
                                            ),
                                            tooltip: 'Edit',
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            onPressed: () async {
                                              // Show confirmation dialog
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  contentPadding: EdgeInsets.zero,
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      // Header
                                                      Container(
                                                        padding: EdgeInsets.all(16),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              padding: EdgeInsets.all(10),
                                                              decoration: BoxDecoration(
                                                                color: Colors.red.withValues(alpha: 0.1),
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Icon(
                                                                Icons.delete_rounded,
                                                                size: 24,
                                                                color: Colors.red,
                                                              ),
                                                            ),
                                                            SizedBox(width: 12),
                                                            Expanded(
                                                              child: Text(
                                                                'Delete Payment Method',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Colors.black87,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Divider(height: 1, color: Colors.grey.shade200),

                                                      // Content
                                                      Padding(
                                                        padding: EdgeInsets.all(16),
                                                        child: Text(
                                                          'Are you sure you want to delete ${method.name}?',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: Text(
                                                        'Cancel',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.grey.shade600,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Delete',
                                                        style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                await _paymentStore.deletePaymentMethod(method.id);
                                                if (mounted) {
                                                  NotificationService.instance.showSuccess('${method.name} deleted');
                                                }
                                              }
                                            },
                                            icon: Icon(
                                              Icons.delete_rounded,
                                              color: Colors.red,
                                              size: isTablet ? 22 : 20,
                                            ),
                                            tooltip: 'Delete',
                                          ),
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
