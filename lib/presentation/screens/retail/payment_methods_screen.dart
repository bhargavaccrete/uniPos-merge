import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/models/payment_method.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/row_action_button.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/stores/payment_method_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/upi_qr_helper.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late PaymentMethodStore _paymentStore;
  final StoreSettingsService _storeSettings = StoreSettingsService();

  final _nameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _upiPayeeController = TextEditingController();

  // Focus chain for the UPI dialog (name → UPI ID → payee).
  final FocusNode _upiIdFocus = FocusNode();
  final FocusNode _upiPayeeFocus = FocusNode();

  /// Drives the QR preview. Updated off the keystroke frame (debounced) so the
  /// CustomPaint subtree never rebuilds during text-input processing.
  final ValueNotifier<String> _upiQrData = ValueNotifier<String>('');
  Timer? _qrDebounce;

  /// The six seeded methods (`payment_method_repository.dart`).
  ///
  /// Their `value` is a bucket key hardcoded across the app —
  /// `sale_repository.dart` payment splits, `cash_drawer_screen.dart` expected
  /// cash, `eod_service.dart` collections. Deriving it from a renamed label
  /// would silently move every later sale into a bucket nothing reads, so
  /// built-ins keep their value and can't be deleted. Same rule the setup
  /// wizard applies (`paymentSetupStep.dart`).
  static const Set<String> _builtInValues = {
    'cash',
    'card',
    'upi',
    'wallet',
    'credit',
    'other',
  };

  bool _isBuiltIn(PaymentMethod m) => _builtInValues.contains(m.value);

  @override
  void initState() {
    super.initState();
    _paymentStore = locator<PaymentMethodStore>();
    _paymentStore.loadPaymentMethods();
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

  /// Immediately recompute the UPI string driving the QR preview.
  void _refreshUpiPreview() {
    _upiQrData.value = _upiIdController.text.trim().isEmpty
        ? ''
        : UpiQrHelper.buildUpiUri(
            _upiIdController.text,
            payee: _upiPayeeController.text,
          );
  }

  /// Debounced preview update fired from field onChanged callbacks.
  void _scheduleUpiPreview() {
    _qrDebounce?.cancel();
    _qrDebounce = Timer(const Duration(milliseconds: 350), _refreshUpiPreview);
  }

  // ── Add ────────────────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    _nameController.clear();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Add Payment Method',
        subtitle: 'Create a custom payment option',
        icon: Icons.add_circle_rounded,
        accent: AppColors.primary,
        body: AppTextField(
          controller: _nameController,
          autofocus: true,
          label: 'Method Name',
          hint: 'e.g. PhonePe, Google Pay',
          icon: Icons.payment_rounded,
          required: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Add',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await _paymentStore.addPaymentMethod(
      name: name,
      value: name.toLowerCase().replaceAll(' ', '_'),
      iconName: 'payment',
    );
    if (mounted) {
      NotificationService.instance.showSuccess('$name added successfully');
    }
  }

  // ── Edit / UPI setup ───────────────────────────────────────────────────────

  /// Edit a method. For UPI this is also where the merchant VPA and printed
  /// QR are configured — retail's receipt builder already prints them
  /// (`retail/print_service.dart`), but before this the wizard was the only
  /// place they could be set.
  Future<void> _showEditDialog(PaymentMethod method) async {
    _nameController.text = method.name;
    final isUpi = method.value == 'upi';

    if (isUpi) {
      _upiIdController.text = await _storeSettings.getUpiId() ?? '';
      _upiPayeeController.text = await _storeSettings.getUpiPayeeName() ?? '';
      _refreshUpiPreview();
    }
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: isUpi ? 'UPI Setup' : 'Edit Payment Method',
        subtitle: isUpi
            ? 'Set your merchant UPI ID & QR'
            : 'Update payment details',
        icon: isUpi ? Icons.qr_code_2_rounded : Icons.edit_rounded,
        accent: AppColors.primary,
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
              textInputAction: isUpi
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (isUpi) {
                  _upiIdFocus.requestFocus();
                } else {
                  Navigator.pop(dialogContext, true);
                }
              },
            ),
            if (isUpi) ...[
              const SizedBox(height: 16),
              AppTextField(
                controller: _upiIdController,
                focusNode: _upiIdFocus,
                label: 'Merchant UPI ID (VPA)',
                hint: 'e.g. merchant@okhdfc',
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
                onFieldSubmitted: (_) => Navigator.pop(dialogContext, true),
                onChanged: (_) => _scheduleUpiPreview(),
              ),
              const SizedBox(height: 16),
              _buildQrPreview(dialogContext),
            ],
          ],
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Update',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await _paymentStore.updatePaymentMethod(
      method.copyWith(
        name: name,
        // Built-ins keep their bucket key; only custom methods re-derive it.
        value: _isBuiltIn(method)
            ? method.value
            : name.toLowerCase().replaceAll(' ', '_'),
      ),
    );

    if (isUpi) {
      await _storeSettings.setUpiId(_upiIdController.text);
      await _storeSettings.setUpiPayeeName(_upiPayeeController.text);
      // Render the QR once here and store the image, so every receipt prints
      // the same bytes instead of regenerating per bill.
      await _storeSettings.setUpiQrImage(
        await UpiQrHelper.generateQrBytes(
          _upiIdController.text,
          payee: _upiPayeeController.text,
        ),
      );
    }

    if (mounted) {
      NotificationService.instance.showSuccess(
        isUpi ? 'UPI details saved' : 'Payment method updated successfully',
      );
    }
  }

  Widget _buildQrPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment QR Preview',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
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
                      Icon(
                        Icons.qr_code_2,
                        size: 48,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter a UPI ID to generate the QR code',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
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
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(PaymentMethod method) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'Delete Payment Method?',
      message:
          'Delete "${method.name}"? It will no longer be offered at '
          'checkout.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirm) return;

    await _paymentStore.deletePaymentMethod(method.id);
    if (mounted) {
      NotificationService.instance.showSuccess('${method.name} deleted');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Payment Methods',
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        child: Observer(
          builder: (_) {
            if (_paymentStore.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (_paymentStore.paymentMethods.isEmpty) {
              return const AppEmptyState(
                icon: Icons.payment_outlined,
                title: 'No payment methods',
                message: 'Add the ways your customers can pay.',
              );
            }

            return ListView.builder(
              padding: AppResponsive.padding(context).copyWith(bottom: 88),
              itemCount: _paymentStore.paymentMethods.length,
              itemBuilder: (context, index) => _buildMethodCard(
                context,
                _paymentStore.paymentMethods[index],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// One payment method as a card: tinted icon, name + status, enable switch
  /// and a ⋮ menu. Edit/Delete sit in the menu rather than as visible icon
  /// buttons so the switch stays the one obvious tap target.
  Widget _buildMethodCard(BuildContext context, PaymentMethod method) {
    final enabled = method.isEnabled;
    final statusColor = enabled ? AppColors.success : AppColors.textSecondary;
    final isBuiltIn = _isBuiltIn(method);
    final isUpi = method.value == 'upi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIcon(method.iconName),
                color: statusColor,
                size: AppResponsive.iconSize(context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          method.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isBuiltIn) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              fontWeight: FontWeight.w500,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
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
                      const SizedBox(width: 6),
                      Text(
                        enabled ? 'Enabled' : 'Disabled',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (isUpi) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.qr_code_2,
                          size: AppResponsive.captionFontSize(context) + 3,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'QR on receipt',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              activeThumbColor: AppColors.success,
              onChanged: (value) async {
                await _paymentStore.togglePaymentMethod(method.id);
                if (mounted) {
                  NotificationService.instance.showSuccess(
                    '${method.name} ${value ? 'enabled' : 'disabled'}',
                  );
                }
              },
            ),
            const SizedBox(width: 4),
            RowActionButton(
              icon: isUpi ? Icons.qr_code_2_rounded : Icons.edit_outlined,
              color: AppColors.primary,
              tooltip: isUpi ? 'UPI Setup' : 'Edit',
              onTap: () => _showEditDialog(method),
            ),
            // A built-in's value is a reporting bucket key — deleting Cash
            // would leave the drawer and EOD reading a method that no longer
            // exists. Omitted rather than disabled: the row keeps the same
            // shape the menu gave it, one action instead of two.
            if (!isBuiltIn) ...[
              const SizedBox(width: 6),
              RowActionButton(
                icon: Icons.delete_outline_rounded,
                color: AppColors.danger,
                tooltip: 'Delete',
                onTap: () => _confirmDelete(method),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
