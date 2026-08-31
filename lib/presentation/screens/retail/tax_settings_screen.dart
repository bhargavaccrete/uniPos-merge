import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:uuid/uuid.dart';
import 'package:billberrylite/domain/services/retail/gst_service.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/config/tax_feature.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  bool _taxInclusiveMode = false;
  double _defaultGstRate = 0;
  bool _isLoading = true;
  final GstService _gstService = GstService();

  @override
  void initState() {
    super.initState();
    taxStore.loadTaxes();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _taxInclusiveMode = await _gstService.isTaxInclusiveMode();
      _defaultGstRate = await _gstService.getDefaultGstRate();
    } catch (e) {
      debugPrint('Error loading GST settings: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleTaxInclusiveMode(bool value) async {
    await _gstService.setTaxInclusiveMode(value);
    setState(() => _taxInclusiveMode = value);
  }

  Future<void> _updateDefaultGstRate(double rate) async {
    await _gstService.setDefaultGstRate(rate);
    setState(() => _defaultGstRate = rate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tax Settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Rates and defaults applied at billing',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: AppResponsive.smallFontSize(context),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : AppResponsive.constrainedContent(
              context: context,
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: AppResponsive.padding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('General Settings'),
                    const SizedBox(height: 12),
                    _buildGeneralSettingsCard(),
                    const SizedBox(height: 24),

                    // Note: GST/HSN is set per product (and can be overridden per
                    // variant) — not per category, since one category can hold
                    // items with different tax classes.
                    _buildSectionTitle('Tax Rates'),
                    const SizedBox(height: 12),
                    _buildTaxRatesCard(),
                    const SizedBox(height: 24),

                    // India-only reference: these are Indian GST slabs and the
                    // thresholds are stated in rupees, so the card is meaningless
                    // (and misleading) for any other country. The setup wizard's
                    // tax step gates its presets the same way.
                    if (_isIndia) ...[
                      _buildSectionTitle('Common GST Rates (India)'),
                      const SizedBox(height: 12),
                      _buildGstRateReferenceCard(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  /// Accent bar + title, the section header used across the settings screens.
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxDisabledNotice(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
    final enabled = TaxFeature.enabled;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          if (!enabled)
            _buildTaxDisabledNotice(
              'Tax is currently disabled. This business is marked as not registered for tax during setup.',
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tax Inclusive Mode Toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tax Inclusive Pricing',
                            style: TextStyle(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Product prices include tax',
                            style: TextStyle(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _taxInclusiveMode,
                      onChanged: enabled ? _toggleTaxInclusiveMode : null,
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Default GST Rate
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Default Tax Rate',
                            style: TextStyle(
                              fontSize: AppResponsive.bodyFontSize(context),
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Applied when no product/variant tax is set',
                            style: TextStyle(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: enabled
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: enabled ? _showDefaultGstRateDialog : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_defaultGstRate.toInt()}%',
                                style: TextStyle(
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  color: enabled
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.expand_more_rounded,
                                size: AppResponsive.smallIconSize(context),
                                color: enabled
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRatesCard() {
    if (!TaxFeature.enabled) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: _buildTaxDisabledNotice(
          'Tax rate management is unavailable while tax is disabled for this business.',
        ),
      );
    }
    return Observer(
      builder: (_) {
        final taxes = taxStore.taxes;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            children: [
              if (taxes.isEmpty)
                Padding(
                  padding: AppResponsive.cardPadding(context),
                  child: Text(
                    'No named tax rates yet. Add one to pick it on products/variants.',
                    style: TextStyle(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ...taxes.map(
                  (tax) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tax.taxname,
                                style: TextStyle(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${tax.taxperecentage ?? 0}%',
                                style: TextStyle(
                                  fontSize: AppResponsive.captionFontSize(
                                    context,
                                  ),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showTaxDialog(existingTax: tax),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: AppColors.success,
                        ),
                        IconButton(
                          onPressed: () => _confirmDeleteTax(tax),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showTaxDialog(),
                    icon: const Icon(Icons.add, color: AppColors.success),
                    label: Text(
                      'Add Tax Rate',
                      style: TextStyle(color: AppColors.success),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteTax(Tax tax) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Tax Rate?',
      message:
          'Delete "${tax.taxname}" (${tax.taxperecentage ?? 0}%)? '
          'Products already using it keep their stored rate.',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      await taxStore.deleteTax(tax.id);
    }
  }

  Future<void> _showTaxDialog({Tax? existingTax}) async {
    final isEdit = existingTax != null;
    final nameController = TextEditingController(
      text: existingTax?.taxname ?? '',
    );
    final rateController = TextEditingController(
      text: existingTax?.taxperecentage != null
          ? existingTax!.taxperecentage.toString()
          : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DialogDisposeScope(
        disposables: [nameController, rateController],
        child: AppDialogShell(
          title: isEdit ? 'Edit Tax Rate' : 'Add Tax Rate',
          subtitle: 'Selectable on products and variants',
          icon: Icons.percent_rounded,
          accent: AppColors.primary,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                autofocus: true,
                label: 'Tax Name',
                hint: 'e.g. GST',
                icon: Icons.label_outline_rounded,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: rateController,
                label: 'Rate %',
                hint: 'e.g. 18',
                icon: Icons.percent_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(dialogContext),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: isEdit ? 'Update' : 'Add',
              color: AppColors.primary,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final name = nameController.text.trim();
    final rate = double.tryParse(rateController.text.trim());
    if (name.isEmpty || rate == null || rate < 0 || rate > 100) {
      NotificationService.instance.showError(
        'Enter a valid name and rate (0-100)',
      );
      return;
    }

    if (isEdit) {
      await taxStore.updateTax(
        existingTax.copyWith(taxname: name, taxperecentage: rate),
      );
    } else {
      await taxStore.addTax(
        Tax(id: const Uuid().v4(), taxname: name, taxperecentage: rate),
      );
    }
  }

  /// True when the business is registered in India. Reads the saved
  /// BusinessDetails — unlike the wizard, this screen runs after setup.
  bool get _isIndia =>
      (businessDetailsRepository.get()?.country ?? '').trim().toLowerCase() ==
      'india';

  Widget _buildGstRateReferenceCard() {
    final rates = [
      {'rate': '0%', 'items': 'Essential goods, milk, vegetables, fruits'},
      {'rate': '5%', 'items': 'Clothing under Rs.1000, footwear under Rs.500'},
      {'rate': '12%', 'items': 'Clothing Rs.1000+, footwear Rs.500-1000'},
      {'rate': '18%', 'items': 'Electronics, appliances, services'},
      {'rate': '28%', 'items': 'Luxury goods, automobiles, cosmetics'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: rates.map((rate) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rate['rate']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppResponsive.smallFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rate['items']!,
                    style: TextStyle(
                      fontSize: AppResponsive.smallFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showDefaultGstRateDialog() async {
    final taxes = taxStore.taxes;
    final rates = taxes.isNotEmpty
        ? taxes.map((t) => t.taxperecentage ?? 0).toSet().toList()
        : GstService.commonGstRates;

    final picked = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Default Tax Rate',
        subtitle: 'Applied to a product that has no rate of its own',
        icon: Icons.percent_rounded,
        accent: AppColors.primary,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: rates.map((rate) {
            final selected = rate == _defaultGstRate;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(dialogContext, rate),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: AppResponsive.smallIconSize(dialogContext),
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${rate.toInt()}%',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(dialogContext),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [appDialogCancelButton(dialogContext)],
      ),
    );

    if (picked == null || picked == _defaultGstRate) return;
    await _updateDefaultGstRate(picked);
  }
}
