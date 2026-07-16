import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:billberrylite/models/payment_method.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/stores/payment_method_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/upi_qr_helper.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';

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

  // Focus chain for the UPI edit dialog (name → UPI ID → payee).
  final FocusNode _upiIdFocus = FocusNode();
  final FocusNode _upiPayeeFocus = FocusNode();

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
    _upiIdFocus.dispose();
    _upiPayeeFocus.dispose();
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
    showDialog(
      context: context,
      builder: (context) {
        // Shared by the name field's done key and the Add button.
        Future<void> submitAdd() async {
          if (_nameController.text.trim().isEmpty) return;
          await _paymentStore.addPaymentMethod(
            name: _nameController.text,
            value: _nameController.text.toLowerCase().replaceAll(' ', '_'),
            iconName: 'payment',
          );
          if (mounted) Navigator.pop(context);
          NotificationService.instance
              .showSuccess('${_nameController.text} added successfully');
        }

        return AppDialogShell(
          title: 'Add Payment Method',
          subtitle: 'Create a custom payment option',
          accent: AppColors.primary,
          icon: Icons.add_circle_rounded,
          body: AppTextField(
            controller: _nameController,
            autofocus: true,
            label: 'Method Name',
            hint: 'e.g., PhonePe, Google Pay',
            icon: Icons.payment_rounded,
            required: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => submitAdd(),
          ),
          actions: [
            appDialogCancelButton(context),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add',
              onPressed: submitAdd,
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(PaymentMethod method) async {
    _nameController.text = method.name;
    final isUpi = method.value == 'upi';
    if (isUpi) {
      final upiId = await _storeSettings.getUpiId();
      final upiPayee = await _storeSettings.getUpiPayeeName();
      _upiIdController.text = upiId ?? '';
      _upiPayeeController.text = upiPayee ?? '';
      _refreshUpiPreview();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        // Shared by the last field's done key and the Update button.
        Future<void> submit() async {
          if (_nameController.text.trim().isEmpty) return;
          final updatedMethod = method.copyWith(
            name: _nameController.text,
            value: _nameController.text.toLowerCase().replaceAll(' ', '_'),
          );
          await _paymentStore.updatePaymentMethod(updatedMethod);
          if (isUpi) {
            await _storeSettings.setUpiId(_upiIdController.text);
            await _storeSettings.setUpiPayeeName(_upiPayeeController.text);
            // Generate the QR from the UPI ID and store it so receipts keep
            // printing the same merchant QR.
            final qrBytes = await UpiQrHelper.generateQrBytes(
              _upiIdController.text,
              payee: _upiPayeeController.text,
            );
            await _storeSettings.setUpiQrImage(qrBytes);
          }
          if (mounted) {
            Navigator.pop(context);
            NotificationService.instance
                .showSuccess('Payment method updated successfully');
          }
        }

        return AppDialogShell(
        title: isUpi ? 'UPI Setup' : 'Edit Payment Method',
        subtitle:
            isUpi ? 'Set your merchant UPI ID & QR' : 'Update payment details',
        accent: AppColors.primary,
        icon: isUpi ? Icons.qr_code_2_rounded : Icons.edit_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _nameController,
              autofocus: true,
              label: 'Method Name',
              hint: 'Enter method name',
              icon: Icons.payment_rounded,
              required: true,
              textInputAction:
                  isUpi ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (isUpi) {
                  _upiIdFocus.requestFocus();
                } else {
                  submit();
                }
              },
            ),
            if (isUpi) ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _upiIdController,
                focusNode: _upiIdFocus,
                label: 'Merchant UPI ID (VPA)',
                hint: 'e.g., merchant@okhdfc',
                icon: Icons.alternate_email_rounded,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _upiPayeeFocus.requestFocus(),
                onChanged: (_) => _scheduleUpiPreview(),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _upiPayeeController,
                focusNode: _upiPayeeFocus,
                label: 'Payee Name (Optional)',
                hint: 'Falls back to Store Name',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                onChanged: (_) => _scheduleUpiPreview(),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment QR Preview',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppColors.divider),
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
        actions: [
          appDialogCancelButton(context),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Update',
            onPressed: submit,
          ),
        ],
        );
      },
    );
  }

  /// Confirm + delete a payment method (shared by the card overflow menu).
  Future<void> _confirmDelete(PaymentMethod method) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Delete Payment Method',
      message: 'Are you sure you want to delete ${method.name}?',
      confirmLabel: 'Delete',
      accent: Colors.red,
      icon: Icons.delete_rounded,
    );
    if (confirm) {
      await _paymentStore.deletePaymentMethod(method.id);
      if (mounted) {
        NotificationService.instance.showSuccess('${method.name} deleted');
      }
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Payment Method',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
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

                // Card list — mobile-friendly replacement for the old DataTable.
                // Each method is a card: colored icon, name + status, an enable
                // switch, and a ⋮ overflow menu (Edit / Delete).
                return ListView.builder(
                  // Extra bottom padding so the FAB never covers the last card.
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 20 : 16,
                    isTablet ? 20 : 16,
                    isTablet ? 20 : 16,
                    88,
                  ),
                  itemCount: _paymentStore.paymentMethods.length,
                  itemBuilder: (context, index) {
                    return _buildMethodCard(
                      context,
                      _paymentStore.paymentMethods[index],
                      isTablet,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// A styled row for the card overflow menu: tinted icon chip + colored label.
  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color == Colors.red ? Colors.red : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// One payment method rendered as a card row.
  Widget _buildMethodCard(
    BuildContext context,
    PaymentMethod method,
    bool isTablet,
  ) {
    final enabled = method.isEnabled;
    final statusColor = enabled ? Colors.green : AppColors.textSecondary;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 16 : 14),
        child: Row(
          children: [
            // Colored icon tile
            Container(
              padding: EdgeInsets.all(isTablet ? 12 : 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIcon(method.iconName),
                color: statusColor,
                size: isTablet ? 26 : 24,
              ),
            ),
            SizedBox(width: isTablet ? 16 : 14),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        enabled ? 'Enabled' : 'Disabled',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Enable switch
            Switch(
              value: enabled,
              activeColor: Colors.green,
              onChanged: (value) async {
                await _paymentStore.togglePaymentMethod(method.id);
                if (mounted) {
                  NotificationService.instance.showSuccess(
                      '${method.name} ${value ? 'enabled' : 'disabled'}');
                }
              },
            ),

            // Overflow menu — Edit / Delete
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: isTablet ? 24 : 22),
              // White sheet — kill the Material 3 elevation tint (the purple wash).
              color: AppColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.divider),
              ),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(method);
                } else if (value == 'delete') {
                  _confirmDelete(method);
                }
              },
              itemBuilder: (_) => [
                _menuItem(
                  value: 'edit',
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: AppColors.primary,
                ),
                _menuItem(
                  value: 'delete',
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
