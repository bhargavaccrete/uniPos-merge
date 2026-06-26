import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import '../../../util/common/app_responsive.dart';
import '../../../util/common/upi_qr_helper.dart';
import 'package:billberrylite/models/payment_method.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/stores/payment_method_store.dart';
import '../../../util/color.dart';
import '../../widget/componets/common/app_dialog.dart';
import '../../../util/common/currency_helper.dart';

/// Payment Setup Step — Setup Wizard
/// Modern UI matching TaxSetupStep style.
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

  final StoreSettingsService _storeSettings = StoreSettingsService();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiPayeeController = TextEditingController();

  /// Drives the QR preview. Updated off the keystroke frame (debounced) so the
  /// CustomPaint subtree never rebuilds during text-input processing.
  final ValueNotifier<String> _upiQrData = ValueNotifier<String>('');
  Timer? _qrDebounce;

  /// Values that belong to the 6 built-in default methods.
  /// Custom-added methods will have different values, making them deletable.
  static const Set<String> _defaultValues = {
    'cash', 'card', 'upi', 'wallet', 'credit', 'other',
  };

  static const Map<String, IconData> _availableIcons = {
    'payment': Icons.payment,
    'money': Icons.money,
    'credit_card': Icons.credit_card,
    'qr_code_2': Icons.qr_code_2,
    'account_balance_wallet': Icons.account_balance_wallet,
    'receipt_long': Icons.receipt_long,
    'more_horiz': Icons.more_horiz,
    'account_balance': Icons.account_balance,
    'attach_money': Icons.attach_money,
    'phone_android': Icons.phone_android,
  };

  static const Map<String, String> _iconLabels = {
    'payment': 'Generic Payment',
    'money': 'Cash / Money',
    'credit_card': 'Card',
    'qr_code_2': 'QR / UPI',
    'account_balance_wallet': 'Wallet',
    'receipt_long': 'Receipt / Credit',
    'more_horiz': 'Other',
    'account_balance': 'Bank',
    'attach_money': 'Dollar',
    'phone_android': 'Mobile',
  };

  @override
  void initState() {
    super.initState();
    _store = locator<PaymentMethodStore>();
    _initializeStore();
    _loadUpiSettings();
  }

  @override
  void dispose() {
    _qrDebounce?.cancel();
    _upiQrData.dispose();
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


  void _showEditDialog(PaymentMethod method) async {
    final nameController = TextEditingController(text: method.name);
    if (method.value == 'upi') {
      final upiId = await _storeSettings.getUpiId();
      final upiPayee = await _storeSettings.getUpiPayeeName();
      _upiIdController.text = upiId ?? '';
      _upiPayeeController.text = upiPayee ?? '';
      _refreshUpiPreview();
    }

    if (!mounted) return;
    
    final isUpi = method.value == 'upi';
    await showDialog(
      context: context,
      builder: (context) => AppDialogShell(
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
              controller: nameController,
              label: 'Method Name',
              hint: 'Enter method name',
              icon: Icons.payment_rounded,
              required: true,
            ),
            if (isUpi) ...[
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
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final updatedMethod = method.copyWith(
                  name: nameController.text,
                  value: nameController.text.toLowerCase().replaceAll(' ', '_'),
                );
                await _store.updatePaymentMethod(updatedMethod);
                if (isUpi) {
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
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
    nameController.dispose();
  }

  Future<void> _initializeStore() async {
    try {
      await _store.init();
    } catch (e) {
      debugPrint('PaymentSetupStep: Error during init: $e');
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  bool _isDefault(String value) => _defaultValues.contains(value);

  IconData _getIcon(String iconName) =>
      _availableIcons[iconName] ?? Icons.payment;

  // ── Currency picker ─────────────────────────────────────────────────────────

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text('Select Currency',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: CurrencyHelper.currencies.entries.map((e) {
                  final info = e.value;
                  final isSelected = CurrencyHelper.currentCurrencyCode == info.code;
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(info.symbol,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            )),
                      ),
                    ),
                    title: Text(info.name,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: AppColors.textPrimary)),
                    subtitle: Text(info.code,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      await CurrencyHelper.setCurrency(info.code);
                      if (mounted) Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add dialog ──────────────────────────────────────────────────────────────

  Future<void> _showAddMethodDialog() async {
    final nameController = TextEditingController();
    String selectedIcon = 'payment';
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialogShell(
          title: 'Add Payment Method',
          subtitle: 'Create a custom payment option',
          accent: AppColors.primary,
          icon: Icons.add_card,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name field ──
              Text('Display Name',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textPrimary),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'e.g., PayTM, GPay, Sodexo',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary),
                  errorText: errorText,
                  errorStyle: GoogleFonts.poppins(fontSize: 11),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Icon picker ──
              Text('Icon',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.entries.map((e) {
                  final selected = selectedIcon == e.key;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedIcon = e.key),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.divider,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(e.value,
                              size: 16,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _iconLabels[e.key] ?? e.key,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Add',
              onPressed: () async {
                final name = nameController.text.trim();

                // Validation: empty name
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Name is required');
                  return;
                }

                // Validation: duplicate name
                final exists = _store.paymentMethods.any(
                    (m) => m.name.toLowerCase() == name.toLowerCase());
                if (exists) {
                  setDialogState(() => errorText = '"$name" already exists');
                  return;
                }

                await _store.addPaymentMethod(
                  name: name,
                  value: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
                  iconName: selectedIcon,
                );
                if (mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  // ── Delete confirm ──────────────────────────────────────────────────────────

  Future<void> _deleteMethod(String id, String name) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete "$name"?',
      message: 'This payment method will be permanently removed.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      await _store.deletePaymentMethod(id);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Loading payment methods…',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final hPad = AppResponsive.getValue<double>(
        context, mobile: 20, tablet: 32, desktop: 40);
    final vPad = AppResponsive.getValue<double>(
        context, mobile: 16, tablet: 20, desktop: 24);
    final maxWidth = AppResponsive.getValue<double>(
        context, mobile: double.infinity, tablet: 680, desktop: 760);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.payment_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Methods',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Enable methods your customers can pay with',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Currency selector ──
          Text('Currency',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(
            valueListenable: CurrencyHelper.currencyNotifier,
            builder: (_, code, __) {
              final info = CurrencyHelper.currencies[code] ?? CurrencyHelper.currencies['INR']!;
              return GestureDetector(
                onTap: _showCurrencyPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(info.symbol,
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.name,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(info.code,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Methods list ──
          Observer(builder: (_) {
            if (_store.isLoading && _store.paymentMethods.isEmpty) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child:
                          CircularProgressIndicator(color: AppColors.primary)));
            }

            if (_store.paymentMethods.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                ..._store.paymentMethods.map((method) =>
                    _buildMethodCard(method)),
                const SizedBox(height: 12),
                _buildAddButton(),
              ],
            );
          }),

                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, vPad),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _buildNavSection(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavSection() {
    return Observer(builder: (_) {
      final hasEnabled = _store.enabledCount > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enable at least one payment method to continue.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onPrevious,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text('Back',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: hasEnabled ? widget.onNext : null,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text('Continue',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  // ── Method card ─────────────────────────────────────────────────────────────

  Widget _buildMethodCard(method) {
    final isDefault = _isDefault(method.value as String);
    final enabled = method.isEnabled as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
     ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIcon(method.iconName as String),
                color: enabled ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name as String,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: enabled
                              ? AppColors.success
                              : AppColors.textSecondary
                                  .withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        enabled ? 'Enabled' : 'Disabled',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: enabled
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Default',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            Switch(
              value: enabled,
              onChanged: (_) =>
                  _store.togglePaymentMethod(method.id as String),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (enabled) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _showEditDialog(method),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  tooltip: 'Edit Method',
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],

            // Delete (custom methods only)
            if (!isDefault) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: AppColors.danger.withValues(alpha: 0.8),
                    size: 20),
                onPressed: () => _deleteMethod(
                    method.id as String, method.name as String),
                tooltip: 'Delete',
                splashRadius: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddMethodDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Add Custom Method',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No payment methods configured',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap below to add your first method',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          _buildAddButton(),
        ],
      ),
    );
  }

}
