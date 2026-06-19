import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:unipos/models/payment_method.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/stores/payment_method_store.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/common/upi_qr_helper.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';

class Paymentsmethods extends StatefulWidget {
  @override
  _paymentsmethodsState createState() => _paymentsmethodsState();
}

class _paymentsmethodsState extends State<Paymentsmethods> {
  late PaymentMethodStore _paymentStore;
  final _nameController = TextEditingController();

  final StoreSettingsService _storeSettings = StoreSettingsService();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiPayeeController = TextEditingController();

  /// Drives the QR preview. Updated off the keystroke frame (debounced) so the
  /// CustomPaint subtree never rebuilds during text-input processing.
  final ValueNotifier<String> _upiQrData = ValueNotifier<String>('');
  Timer? _qrDebounce;

  @override
  void initState() {
    super.initState();
    _paymentStore = locator<PaymentMethodStore>();
    _paymentStore.loadPaymentMethods();
    _loadUpiSettings();
  }

  @override
  void dispose() {
    _qrDebounce?.cancel();
    _upiQrData.dispose();
    _nameController.dispose();
    _upiIdController.dispose();
    _upiPayeeController.dispose();
    super.dispose();
  }

  Future<void> _loadUpiSettings() async {
    final upiId = await _storeSettings.getUpiId();
    final upiPayee = await _storeSettings.getUpiPayeeName();
    if (!mounted) return;
    setState(() {
      _upiIdController.text = upiId ?? '';
      _upiPayeeController.text = upiPayee ?? '';
    });
    _refreshUpiPreview();
  }

  /// Immediately recompute the UPI string driving the QR preview.
  void _refreshUpiPreview() {
    _upiQrData.value = _upiIdController.text.trim().isEmpty
        ? ''
        : UpiQrHelper.buildUpiUri(_upiIdController.text,
            payee: _upiPayeeController.text);
  }

  /// Debounced preview update fired from field onChanged callbacks.
  void _scheduleUpiPreview() {
    _qrDebounce?.cancel();
    _qrDebounce =
        Timer(const Duration(milliseconds: 350), _refreshUpiPreview);
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
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
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
            Divider(height: 1, color: AppColors.divider),

            // Content
            Padding(
              padding: EdgeInsets.all(16),
              child: AppTextField(
                controller: _nameController,
                label: 'Method Name',
                hint: 'e.g., PhonePe, Google Pay',
                icon: Icons.payment_rounded,
                required: true,
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
                color: AppColors.textSecondary,
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

  void _showEditDialog(PaymentMethod method) async {
    _nameController.text = method.name;
    if (method.value == 'upi') {
      final upiId = await _storeSettings.getUpiId();
      final upiPayee = await _storeSettings.getUpiPayeeName();
      _upiIdController.text = upiId ?? '';
      _upiPayeeController.text = upiPayee ?? '';
      _refreshUpiPreview();
    }

    if (!mounted) return;
    
    final editHInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
        : 24.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: editHInset, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 24,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                const Divider(height: 1, color: AppColors.divider),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: 'Method Name',
                        hint: 'Enter method name',
                        icon: Icons.payment_rounded,
                        required: true,
                      ),
                      if (method.value == 'upi') ...[
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _upiIdController,
                          label: 'Merchant UPI ID (VPA)',
                          hint: 'e.g., merchant@okhdfc',
                          icon: Icons.alternate_email_rounded,
                          onChanged: (_) => _scheduleUpiPreview(),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _upiPayeeController,
                          label: 'Payee Name (Optional)',
                          hint: 'Falls back to Store Name',
                          icon: Icons.person_outline_rounded,
                          onChanged: (_) => _scheduleUpiPreview(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Payment QR Preview',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String>(
                          valueListenable: _upiQrData,
                          builder: (context, qrData, _) => Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: qrData.isEmpty
                                ? Column(
                                    children: [
                                      Icon(Icons.qr_code_2,
                                          size: 48,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.5)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Enter a UPI ID to generate the QR code',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppColors.divider),
                                        ),
                                        child: SizedBox(
                                          width: 160,
                                          height: 160,
                                          child: QrImageView(
                                            data: qrData,
                                            version: QrVersions.auto,
                                            size: 160,
                                            gapless: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Auto-generated from the UPI ID above',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  final updatedMethod = method.copyWith(
                    name: _nameController.text,
                    value: _nameController.text.toLowerCase().replaceAll(' ', '_'),
                  );
                  await _paymentStore.updatePaymentMethod(updatedMethod);
                  if (method.value == 'upi') {
                    await _storeSettings.setUpiId(_upiIdController.text);
                    await _storeSettings.setUpiPayeeName(_upiPayeeController.text);
                    // Generate the QR from the UPI ID and store it so receipts
                    // keep printing the same merchant QR.
                    final qrBytes = await UpiQrHelper.generateQrBytes(
                      _upiIdController.text,
                      payee: _upiPayeeController.text,
                    );
                    await _storeSettings.setUpiQrImage(qrBytes);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    NotificationService.instance.showSuccess('Payment method updated successfully');
                  }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Payment Methods',
        titleFontSize: isTablet ? 22 : 20,
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
                      color: Colors.white,
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
            color: AppColors.white,
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
                            color: AppColors.surfaceMedium,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.payment_rounded,
                            size: isTablet ? 64 : 56,
                            color: AppColors.textSecondary,
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.primary),
                            headingRowHeight: isTablet ? 56 : 50,
                            dataRowMinHeight: isTablet ? 60 : 56,
                            dataRowMaxHeight: isTablet ? 70 : 65,
                            columnSpacing: isTablet ? 20 : 10,
                            horizontalMargin: isTablet ? 16 : 10,
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
                                  index % 2 == 0 ? AppColors.white : AppColors.surfaceLight,
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
                                            : AppColors.textSecondary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getIcon(method.iconName),
                                        color: method.isEnabled ? Colors.green : AppColors.textSecondary,
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
                                            onPressed: () => _showEditDialog(method),
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
                                              final deleteHInset = !AppResponsive.isMobile(context)
                                                  ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
                                                  : 24.0;
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  insetPadding: EdgeInsets.symmetric(horizontal: deleteHInset, vertical: 24),
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
                                                      Divider(height: 1, color: AppColors.divider),

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
                                                          color: AppColors.textSecondary,
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
                      );
                    },
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
