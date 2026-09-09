import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final TextEditingController _methodNameController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiPayeeController = TextEditingController();

  // Focus chain for the UPI edit dialog (name → UPI ID → payee).
  final FocusNode _upiIdFocus = FocusNode();
  final FocusNode _upiPayeeFocus = FocusNode();

  /// Drives the QR preview. Updated off the keystroke frame (debounced) so the
  /// CustomPaint subtree never rebuilds during text-input processing.
  final ValueNotifier<String> _upiQrData = ValueNotifier<String>('');
  Timer? _qrDebounce;

  /// Values that belong to the 6 built-in default methods.
  /// Custom-added methods will have different values, making them deletable.
  static const Set<String> _defaultValues = {
    'cash',
    'card',
    'upi',
    'wallet',
    'credit',
    'other',
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
    _methodNameController.dispose();
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

  void _showEditDialog(PaymentMethod method) async {
    _methodNameController.text = method.name;
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
      builder: (context) {
        // Shared by the last field's done key and the Update button so pressing
        // enter on the keyboard commits the edit exactly like tapping Update.
        Future<void> submit() async {
          if (_methodNameController.text.isEmpty) return;
          final updatedMethod = method.copyWith(
            name: _methodNameController.text,
            value: _methodNameController.text.toLowerCase().replaceAll(
              ' ',
              '_',
            ),
          );
          await _store.updatePaymentMethod(updatedMethod);
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
          if (mounted) Navigator.pop(context);
        }

        return AppDialogShell(
          title: isUpi ? 'UPI Setup' : 'Edit Payment Method',
          subtitle: isUpi
              ? 'Set your merchant UPI ID & QR'
              : 'Update payment details',
          accent: AppColors.primary,
          icon: isUpi ? Icons.qr_code_2_rounded : Icons.edit_rounded,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _methodNameController,
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
                    FocusScope.of(context).requestFocus(_upiIdFocus);
                  } else {
                    submit();
                  }
                },
              ),
              if (isUpi) ...[
                SizedBox(height: AppResponsive.largeSpacing(context)),
                AppTextField(
                  controller: _upiIdController,
                  focusNode: _upiIdFocus,
                  label: 'Merchant UPI ID (VPA)',
                  hint: 'e.g., merchant@okhdfc',
                  icon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_upiPayeeFocus),
                  onChanged: (_) => _scheduleUpiPreview(),
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
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
                SizedBox(height: AppResponsive.largeSpacing(context)),
                Text(
                  'Payment QR Preview',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                ValueListenableBuilder<String>(
                  valueListenable: _upiQrData,
                  builder: (context, qrData, _) => Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      AppResponsive.largeSpacing(context),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context),
                      ),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: qrData.isEmpty
                        ? Column(
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 48,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              SizedBox(
                                height: AppResponsive.smallSpacing(context),
                              ),
                              Text(
                                'Enter a UPI ID to generate the QR code',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  AppResponsive.smallSpacing(context),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppResponsive.smallBorderRadius(context),
                                  ),
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
                              SizedBox(
                                height: AppResponsive.smallSpacing(context),
                              ),
                              Text(
                                'Auto-generated from the UPI ID above',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.captionFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
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
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(label: 'Update', onPressed: submit),
          ],
        );
      },
    );
  }

  Future<void> _initializeStore() async {
    try {
      await _store.init();
      await _applyCountryDefaultsOnce();
    } catch (e) {
      debugPrint('PaymentSetupStep: Error during init: $e');
    }
    if (mounted) setState(() => _isInitialized = true);
  }

  /// Key marking that the country-derived defaults below have already run.
  static const String _countryDefaultsKey = 'payment_country_defaults_applied';

  /// Adapts the seeded defaults to the country chosen back on Store Details.
  ///
  /// The six built-in methods are seeded by `PaymentMethodRepository` at app
  /// STARTUP, long before a country exists, so they cannot be seeded per
  /// country — they can only be adjusted here, once the answer is known.
  ///
  /// Runs at most once per install, and never for India (whose seeded defaults
  /// are already correct). Guarded so a user who deliberately switches UPI on
  /// in the UK does not have it switched off again on every revisit.
  Future<void> _applyCountryDefaultsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_countryDefaultsKey) ?? false) return;

    final country = businessDetailsRepository.get()?.country;
    // No country yet (the step was reached out of order) — leave everything
    // alone AND do not burn the flag, so this can still apply later.
    if (country == null || country.trim().isEmpty) return;

    await prefs.setBool(_countryDefaultsKey, true);

    final isIndia = country.trim().toLowerCase() == 'india';

    // UPI is an India-only rail. Switched OFF rather than removed: the value
    // 'upi' is a reporting bucket key, so the row must keep existing, and the
    // user can turn it back on from this very screen.
    if (!isIndia) {
      // Resolve the id BEFORE toggling: togglePaymentMethod reloads the store,
      // which clears and refills `paymentMethods` mid-iteration.
      String? upiId;
      for (final m in _store.paymentMethods) {
        if (m.value == 'upi' && m.isEnabled) {
          upiId = m.id;
          break;
        }
      }
      if (upiId != null) await _store.togglePaymentMethod(upiId);
    }

    // Currency defaults to INR app-wide; preselect the country's own so a
    // non-India business is not billing in rupees by accident. Unknown
    // countries keep whatever is already selected — never a guess.
    final code = CurrencyHelper.currencyCodeForCountry(country);
    if (code != null && code != CurrencyHelper.currentCurrencyCode) {
      await CurrencyHelper.setCurrency(code);
    }
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
              width: 40,
              height: 4,
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
                  SizedBox(width: AppResponsive.smallSpacing(context)),
                  Text(
                    'Select Currency',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: CurrencyHelper.currencies.entries.map((e) {
                  final info = e.value;
                  final isSelected =
                      CurrencyHelper.currentCurrencyCode == info.code;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.smallBorderRadius(context),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          info.symbol,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.subheadingFontSize(context),
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      info.name,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      info.code,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                          )
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
    _methodNameController.clear();
    String selectedIcon = 'payment';
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Shared by the name field's done key and the Add button so pressing
          // enter commits the new method exactly like tapping Add.
          Future<void> submitAdd() async {
            final name = _methodNameController.text.trim();
            if (name.isEmpty) {
              setDialogState(() => errorText = 'Name is required');
              return;
            }
            final exists = _store.paymentMethods.any(
              (m) => m.name.toLowerCase() == name.toLowerCase(),
            );
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
          }

          return AppDialogShell(
            title: 'Add Payment Method',
            subtitle: 'Create a custom payment option',
            accent: AppColors.primary,
            icon: Icons.add_card,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name field ──
                AppTextField(
                  controller: _methodNameController,
                  autofocus: true,
                  label: 'Display Name',
                  hint: 'e.g., PayTM, GPay, Sodexo',
                  icon: Icons.payment_rounded,
                  required: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submitAdd(),
                  onChanged: (_) {
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                  validator: (_) => errorText,
                  autovalidateMode: AutovalidateMode.always,
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // ── Icon picker ──
                Text(
                  'Icon',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.entries.map((e) {
                    final selected = selectedIcon == e.key;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = e.key),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.divider,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              e.value,
                              size: AppResponsive.smallIconSize(context),
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _iconLabels[e.key] ?? e.key,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
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
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              appDialogPrimaryButton(label: 'Add', onPressed: submitAdd),
            ],
          );
        },
      ),
    );
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
            SizedBox(height: AppResponsive.largeSpacing(context)),
            Text(
              'Loading payment methods…',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final hPad = AppResponsive.getValue<double>(
      context,
      mobile: 20,
      tablet: 32,
      desktop: 40,
    );
    final vPad = AppResponsive.getValue<double>(
      context,
      mobile: 16,
      tablet: 20,
      desktop: 24,
    );
    final maxWidth = AppResponsive.getValue<double>(
      context,
      mobile: double.infinity,
      tablet: 680,
      desktop: 760,
    );
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
                          padding: EdgeInsets.all(
                            AppResponsive.mediumSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.75),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppResponsive.borderRadius(context),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.payment_rounded,
                            color: Colors.white,
                            size: AppResponsive.largeIconSize(context),
                          ),
                        ),
                        SizedBox(width: AppResponsive.largeSpacing(context)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Methods',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.getValue(
                                    context,
                                    mobile: 22.0,
                                    tablet: 26.0,
                                    desktop: 30.0,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Enable methods your customers can pay with',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.smallFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppResponsive.largeSpacing(context)),

                    // ── Currency selector ──
                    Text(
                      'Currency',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    ValueListenableBuilder<String>(
                      valueListenable: CurrencyHelper.currencyNotifier,
                      builder: (_, code, __) {
                        final info =
                            CurrencyHelper.currencies[code] ??
                            CurrencyHelper.currencies['INR']!;
                        return GestureDetector(
                          onTap: _showCurrencyPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppResponsive.borderRadius(context),
                              ),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      info.symbol,
                                      style: GoogleFonts.poppins(
                                        fontSize:
                                            AppResponsive.subheadingFontSize(
                                              context,
                                            ),
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: AppResponsive.mediumSpacing(context),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        info.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.bodyFontSize(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        info.code,
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.smallFontSize(
                                            context,
                                          ),
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: AppResponsive.extraLargeSpacing(context)),

                    // ── Methods list ──
                    Observer(
                      builder: (_) {
                        if (_store.isLoading && _store.paymentMethods.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }

                        if (_store.paymentMethods.isEmpty) {
                          return _buildEmptyState();
                        }

                        return Column(
                          children: [
                            ..._store.paymentMethods.map(
                              (method) => _buildMethodCard(method),
                            ),
                            SizedBox(
                              height: AppResponsive.mediumSpacing(context),
                            ),
                            _buildAddButton(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, vPad),
          decoration: BoxDecoration(
            color: AppColors.white,
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
    return Observer(
      builder: (_) {
        final hasEnabled = _store.enabledCount > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: AppResponsive.smallIconSize(context),
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context)),
                      Expanded(
                        child: Text(
                          'Enable at least one payment method to continue.',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            color: AppColors.danger,
                          ),
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
                    label: Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: hasEnabled ? widget.onNext : null,
                    icon: Icon(
                      Icons.arrow_forward,
                      size: AppResponsive.smallIconSize(context),
                      color: AppColors.white,
                    ),
                    label: Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Method card ─────────────────────────────────────────────────────────────

  Widget _buildMethodCard(method) {
    final isDefault = _isDefault(method.value as String);
    final enabled = method.isEnabled as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon badge
            Container(
              padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIcon(method.iconName as String),
                color: enabled ? AppColors.primary : AppColors.textSecondary,
                size: AppResponsive.iconSize(context),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name as String,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(
                        context,
                        mobile: 15.0,
                        tablet: 16.0,
                        desktop: 18.0,
                      ),
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
                              : AppColors.textSecondary.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Flexible: the trailing Switch + edit + delete cluster is
                      // ~152px of fixed chrome, leaving this row under 40px on a
                      // 320 screen.
                      Flexible(
                        child: Text(
                          enabled ? 'Enabled' : 'Disabled',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: enabled
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
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
              onChanged: (_) => _store.togglePaymentMethod(method.id as String),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (enabled) ...[
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
                child: IconButton(
                  onPressed: () => _showEditDialog(method),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: AppColors.primary,
                    size: AppResponsive.iconSize(context),
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
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.danger.withValues(alpha: 0.8),
                  size: AppResponsive.iconSize(context),
                ),
                onPressed: () =>
                    _deleteMethod(method.id as String, method.name as String),
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
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
              size: AppResponsive.iconSize(context),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Text(
              'Add Custom Method',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
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
          Icon(
            Icons.payment_outlined,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          Text(
            'No payment methods configured',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.getValue(
                context,
                mobile: 15.0,
                tablet: 16.0,
                desktop: 18.0,
              ),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            'Tap below to add your first method',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),
          _buildAddButton(),
        ],
      ),
    );
  }
}
