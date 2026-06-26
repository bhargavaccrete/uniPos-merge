import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import 'package:billberrylite/data/models/restaurant/db/taxmodel_314.dart';
import 'package:billberrylite/data/models/restaurant/db/database/hive_tax.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/models/tax_details.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../util/color.dart';
import '../../widget/componets/common/app_dialog.dart';
import '../../../util/common/app_responsive.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';

class TaxSetupStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const TaxSetupStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<TaxSetupStep> createState() => _TaxSetupStepState();
}

class _TaxSetupStepState extends State<TaxSetupStep> {
  final _taxNameController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _uuid = const Uuid();

  List<TaxItem> _taxes = [];

  // Quick-add preset rates
  static const _presets = [
    {'label': 'GST 5%', 'name': 'GST', 'rate': 5.0},
    {'label': 'GST 12%', 'name': 'GST', 'rate': 12.0},
    {'label': 'GST 18%', 'name': 'GST', 'rate': 18.0},
    {'label': 'VAT 10%', 'name': 'VAT', 'rate': 10.0},
  ];

  @override
  void initState() {
    super.initState();
    _loadFromStore();
    _loadFromDatabase();
    _loadRestaurantSettings();
  }

  void _loadFromStore() {
    // Restore the FULL list the user built (synced via setTaxRates) — not just
    // the single default — so returning to this step shows every tax added,
    // not only the default one.
    final rates = widget.store.taxRates;
    if (rates != null && rates.isNotEmpty) {
      _taxes = rates.map((r) => r as TaxItem).toList();
      // Guarantee exactly one default.
      if (!_taxes.any((t) => t.isDefault)) {
        _taxes[0] = TaxItem(_taxes[0].name, _taxes[0].rate, true);
      }
      return;
    }
    if (widget.store.taxName.isNotEmpty && widget.store.taxRate > 0) {
      _taxes = [TaxItem(widget.store.taxName, widget.store.taxRate, true)];
    }
  }

  Future<void> _loadRestaurantSettings() async {
    if (AppConfig.isRestaurant) {
      await AppSettings.load();
      widget.store.setTaxEnabled(AppSettings.isTaxInclusive);
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      if (AppConfig.isRestaurant) {
        final existingTaxes = await taxStore.taxes.toList();
        if (existingTaxes.isNotEmpty && _taxes.isEmpty) {
          setState(() {
            _taxes = existingTaxes.map((tax) {
              return TaxItem(tax.taxname, tax.taxperecentage ?? 0, false);
            }).toList();
            if (_taxes.isNotEmpty) {
              _taxes[0] = TaxItem(_taxes[0].name, _taxes[0].rate, true);
            }
          });
          _syncToStore();
        }
      }
    } catch (e) {
      debugPrint('Error loading taxes from database: $e');
    }
  }

  Future<void> _saveTaxesToDatabase() async {
    if (!AppConfig.isRestaurant) return;
    try {
      final existingTaxes = taxStore.taxes.toList();

      // Identify a tax by name + rate, so multiple same-named rates
      // (GST 5/12/18) stay distinct instead of collapsing onto one name.
      String keyOf(String name, double rate) =>
          '${name.trim().toLowerCase()}|$rate';

      final existingByKey = <String, Tax>{
        for (final tax in existingTaxes)
          keyOf(tax.taxname, tax.taxperecentage ?? 0.0): tax,
      };

      // Add every tax in the list that isn't already in the DB.
      final desiredKeys = <String>{};
      for (final item in _taxes) {
        final key = keyOf(item.name, item.rate);
        desiredKeys.add(key);
        if (!existingByKey.containsKey(key)) {
          await taxStore.addTax(Tax(
            id: _uuid.v4(),
            taxname: item.name,
            taxperecentage: item.rate,
          ));
        }
      }

      // Delete taxes the user removed (present in the DB, absent from the list).
      for (final tax in existingTaxes) {
        if (!desiredKeys.contains(keyOf(tax.taxname, tax.taxperecentage ?? 0.0))) {
          await taxStore.deleteTax(tax.id);
        }
      }
    } catch (e) {
      debugPrint('Error saving taxes to database: $e');
      if (mounted) NotificationService.instance.showError('Failed to save taxes: $e');
    }
  }

  @override
  void dispose() {
    _taxNameController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  void _addTax() {
    final name = _taxNameController.text.trim();
    final rateText = _taxRateController.text.trim();
    if (name.isEmpty || rateText.isEmpty) return;
    final rate = double.tryParse(rateText);
    if (rate == null) return;
    setState(() {
      _taxes.add(TaxItem(name, rate, _taxes.isEmpty));
      _taxNameController.clear();
      _taxRateController.clear();
    });
    _syncToStore();
  }

  void _addPreset(String name, double rate) {
    setState(() {
      _taxes.add(TaxItem(name, rate, _taxes.isEmpty));
    });
    _syncToStore();
  }

  void _removeAt(int index) {
    setState(() {
      _taxes.removeAt(index);
      if (_taxes.isNotEmpty) {
        _taxes[0] = TaxItem(_taxes[0].name, _taxes[0].rate, true);
      }
    });
    _syncToStore();
  }

  void _setDefault(int index) {
    setState(() {
      _taxes = _taxes.asMap().entries.map((e) {
        return TaxItem(e.value.name, e.value.rate, e.key == index);
      }).toList();
    });
    _syncToStore();
  }

  void _syncToStore() {
    final defaultTax = _taxes.firstWhere(
      (t) => t.isDefault,
      orElse: () => _taxes.isNotEmpty ? _taxes.first : TaxItem('GST', 0, true),
    );
    widget.store.setTaxName(defaultTax.name);
    widget.store.setTaxRate(defaultTax.rate);
    widget.store.setTaxRates(_taxes);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildTaxModeSelector(),
                    const SizedBox(height: 20),
                    _buildRecommendedRates(),
                    const SizedBox(height: 20),
                    _buildTaxList(),
                    const SizedBox(height: 16),
                    _buildFooterNote(),
                    const SizedBox(height: 8),
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
              child: _buildNavButtons(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tax Configuration',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Set up tax rates for your business',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tax Mode Selector ────────────────────────────────────────────────────────

  Future<void> _setInclusive(bool value) async {
    if (AppConfig.isRestaurant) {
      widget.store.setTaxEnabled(value);
      await AppSettings.updateSetting('Tax Is Inclusive', value);
    } else {
      widget.store.setTaxInclusive(value);
    }
  }

  Widget _buildTaxModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose how tax is calculated',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Observer(
          builder: (_) {
            final isInclusive = AppConfig.isRestaurant
                ? widget.store.taxEnabled
                : widget.store.taxInclusive;
            return Column(
              children: [
                _buildModeOption(
                  selected: isInclusive,
                  title: 'Tax Included in Price',
                  example: '₹112 (GST included)',
                  onTap: () => _setInclusive(true),
                ),
                const SizedBox(height: 12),
                _buildModeOption(
                  selected: !isInclusive,
                  title: 'Tax Added at Billing',
                  example: '₹100 + GST = ₹112',
                  onTap: () => _setInclusive(false),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required bool selected,
    required String title,
    required String example,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.04) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recommended Rates ────────────────────────────────────────────────────────

  Widget _buildRecommendedRates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Tax Rates',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            final alreadyAdded = _taxes.any(
              (t) => t.name == p['name'] && t.rate == (p['rate'] as double),
            );
            return GestureDetector(
              onTap: alreadyAdded
                  ? null
                  : () => _addPreset(p['name'] as String, p['rate'] as double),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: alreadyAdded
                      ? AppColors.surfaceMedium
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: alreadyAdded
                        ? AppColors.divider
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      alreadyAdded ? Icons.check : Icons.add,
                      size: 15,
                      color: alreadyAdded
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      p['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: alreadyAdded
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCustomTaxDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Create Custom Tax',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomTaxDialog() async {
    _taxNameController.clear();
    _taxRateController.clear();
    await showDialog(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: 'Create Custom Tax',
        subtitle: 'Add a tax rate for your menu',
        accent: AppColors.primary,
        icon: Icons.receipt_long_rounded,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _taxNameController,
              label: 'Tax Name',
              hint: 'e.g. GST, VAT',
              icon: Icons.label_outline,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _taxRateController,
              label: 'Rate %',
              hint: '18',
              icon: Icons.percent,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          appDialogCancelButton(ctx),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: 'Add',
            onPressed: () {
              final name = _taxNameController.text.trim();
              final rate = double.tryParse(_taxRateController.text.trim());
              if (name.isEmpty || rate == null) return;
              _addTax();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // ── Tax List ─────────────────────────────────────────────────────────────────

  Widget _buildTaxList() {
    if (_taxes.isEmpty) return _buildEmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Default Tax',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_taxes.length}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_taxes.length, (i) => _buildTaxRow(_taxes[i], i)),
      ],
    );
  }

  Widget _buildTaxRow(TaxItem tax, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tax.isDefault
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.divider,
          width: tax.isDefault ? 1.5 : 1,
        ),
        boxShadow: tax.isDefault
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: GestureDetector(
          onTap: () => _setDefault(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tax.isDefault
                  ? AppColors.primary
                  : AppColors.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: tax.isDefault
                    ? AppColors.primary
                    : AppColors.divider,
              ),
            ),
            child: Icon(
              tax.isDefault ? Icons.check : Icons.circle_outlined,
              size: 16,
              color: tax.isDefault
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
          ),
        ),
        title: Text(
          tax.name,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: tax.isDefault
            ? Text(
                'Default tax',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.primary),
              )
            : Text(
                'Tap circle to set as default',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${tax.rate}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeAt(index),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.divider, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.percent_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No taxes added yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use quick-add presets or enter manually above',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Footer note ──────────────────────────────────────────────────────────────

  Widget _buildFooterNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline,
            size: 14, color: AppColors.textSecondary.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          'You can modify taxes later from Settings.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  Widget _buildNavButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onPrevious,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: Observer(
            builder: (_) => ElevatedButton.icon(
              onPressed: widget.store.isLoading
                  ? null
                  : () async {
                      widget.store.saveTaxDetails();
                      if (AppConfig.isRetail) {
                        await gstService
                            .setTaxInclusiveMode(widget.store.taxInclusive);
                        if (_taxes.isNotEmpty) {
                          final defaultTax = _taxes.firstWhere(
                            (t) => t.isDefault,
                            orElse: () => _taxes.first,
                          );
                          await gstService
                              .setDefaultGstRate(defaultTax.rate);
                        }
                      } else if (AppConfig.isRestaurant) {
                        await AppSettings.updateSetting(
                            'Tax Is Inclusive', widget.store.taxEnabled);
                      }
                      await _saveTaxesToDatabase();
                      widget.onNext();
                    },
              icon: widget.store.isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_forward, size: 18),
              label: Text(
                widget.store.isLoading ? 'Saving…' : 'Continue',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class TaxItem {
  final String name;
  final double rate;
  final bool isDefault;

  TaxItem(this.name, this.rate, this.isDefault);
}
