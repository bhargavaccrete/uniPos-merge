import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import 'package:billberrylite/data/models/common/taxmodel_314.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:uuid/uuid.dart';
import '../../../util/color.dart';
import '../../widget/componets/common/app_dialog.dart';
import '../../../util/common/app_responsive.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import 'package:billberrylite/util/restaurant/staticswitch.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

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
  final _taxRateFocus = FocusNode();
  final _uuid = const Uuid();

  List<TaxItem> _taxes = [];

  // Country-adaptive quick-add preset rates. India gets its official GST slabs;
  // every other country gets none (VAT/Sales-Tax rates vary too much per country
  // to guess safely) — just the "Create Custom Tax" button.
  bool get _isIndia => widget.store.country.trim().toLowerCase() == 'india';

  List<Map<String, Object>> get _presets => _isIndia
      ? const [
          {'label': 'GST 5%', 'name': 'GST', 'rate': 5.0},
          {'label': 'GST 12%', 'name': 'GST', 'rate': 12.0},
          {'label': 'GST 18%', 'name': 'GST', 'rate': 18.0},
          {'label': 'GST 28%', 'name': 'GST', 'rate': 28.0},
        ]
      : const [];

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
      widget.store.setTaxInclusiveRestaurant(AppSettings.isTaxInclusive);
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      // Shared TaxStore — both modes may have pre-existing rates (e.g. a
      // re-run of onboarding after a backup restore).
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
    } catch (e) {
      debugPrint('Error loading taxes from database: $e');
    }
  }

  /// Returns false (after surfacing the error) on the first failed write.
  /// Safe to retry: the diff is by name+rate, so rates already written are
  /// skipped on the next attempt.
  Future<bool> _saveTaxesToDatabase() async {
    // Shared TaxStore — both modes persist every named rate entered here, not
    // just the one marked default (retail used to discard the rest).
    void fail() => NotificationService.instance.showError(
          taxStore.errorMessage ?? 'Failed to save taxes',
        );
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
          final ok = await taxStore.addTax(
            Tax(id: _uuid.v4(), taxname: item.name, taxperecentage: item.rate),
          );
          if (!ok) {
            fail();
            return false;
          }
        }
      }

      // Delete taxes the user removed (present in the DB, absent from the list).
      for (final tax in existingTaxes) {
        if (!desiredKeys.contains(
          keyOf(tax.taxname, tax.taxperecentage ?? 0.0),
        )) {
          if (!await taxStore.deleteTax(tax.id)) {
            fail();
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error saving taxes to database: $e');
      NotificationService.instance.showError('Failed to save taxes: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _taxNameController.dispose();
    _taxRateController.dispose();
    _taxRateFocus.dispose();
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
    // Same cap the wizard applies rather than a third set of numbers.
    final maxWidth = AppResponsive.maxFormWidth(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              hPad,
              AppResponsive.extraLargeSpacing(context),
              hPad,
              16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: AppResponsive.extraLargeSpacing(context)),
                    _buildTaxModeSelector(),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    _buildRecommendedRates(),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    _buildTaxList(),
                    SizedBox(height: AppResponsive.mediumSpacing(context)),
                    _buildFooterNote(),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
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
          padding: EdgeInsets.all(
            AppResponsive.getValue(
              context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.largeBorderRadius(context),
            ),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: AppColors.primary,
            size: AppResponsive.largeIconSize(context),
          ),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        // Expanded: without it the intrinsic width of the subtitle pushed this
        // Row ~13px past a 320px screen.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tax Configuration',
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
                'Set up tax rates for your business',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tax Mode Selector ────────────────────────────────────────────────────────

  Future<void> _setInclusive(bool value) async {
    if (AppConfig.isRestaurant) {
      widget.store.setTaxInclusiveRestaurant(value);
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
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        Observer(
          builder: (_) {
            final isInclusive = AppConfig.isRestaurant
                ? widget.store.taxInclusiveRestaurant
                : widget.store.taxInclusive;
            return Column(
              children: [
                _buildModeOption(
                  selected: isInclusive,
                  title: 'Tax Included in Price',
                  example: '${CurrencyHelper.currentSymbol}112 (GST included)',
                  onTap: () => _setInclusive(true),
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildModeOption(
                  selected: !isInclusive,
                  title: 'Tax Added at Billing',
                  example:
                      '${CurrencyHelper.currentSymbol}100 + GST = ${CurrencyHelper.currentSymbol}112',
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
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.largeSpacing(context),
          vertical: AppResponsive.mediumSpacing(context),
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
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
                  ? const Icon(Icons.check, size: 13, color: AppColors.white)
                  : null,
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.smallFontSize(context),
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
        if (_presets.isNotEmpty) ...[
          Text(
            'Recommended Tax Rates',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
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
                    : () =>
                          _addPreset(p['name'] as String, p['rate'] as double),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.mediumSpacing(context),
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: alreadyAdded
                        ? AppColors.surfaceMedium
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
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
                        size: AppResponsive.smallIconSize(context),
                        color: alreadyAdded
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
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
        ],
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCustomTaxDialog,
            icon: Icon(Icons.add, size: AppResponsive.smallIconSize(context)),
            label: Text(
              'Create Custom Tax',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.buttonFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.borderRadius(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomTaxDialog() async {
    _taxNameController.clear();
    _taxRateController.clear();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      // Nearest navigator — stays inside the wizard's pane, clear of the sidebar.
      useRootNavigator: false,
      builder: (ctx) {
        // Shared by the Rate field's done key and the Add button so pressing
        // enter on the keyboard commits the tax, exactly like tapping Add.
        void submit() {
          if (!(formKey.currentState?.validate() ?? false)) return;
          _addTax();
          Navigator.pop(ctx);
        }

        return AppDialogShell(
          title: 'Create Custom Tax',
          subtitle: 'Add a tax rate for your menu',
          accent: AppColors.primary,
          icon: Icons.receipt_long_rounded,
          body: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _taxNameController,
                  autofocus: true,
                  label: 'Tax Name',
                  hint: 'e.g. GST, VAT',
                  icon: Icons.label_outline,
                  required: true,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(ctx).requestFocus(_taxRateFocus),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Tax name is required'
                      : null,
                ),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                AppTextField(
                  controller: _taxRateController,
                  focusNode: _taxRateFocus,
                  label: 'Rate %',
                  hint: '18',
                  icon: Icons.percent,
                  required: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submit(),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Rate is required';
                    final r = double.tryParse(t);
                    if (r == null) return 'Enter a valid number';
                    if (r < 0) return 'Rate cannot be negative';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            appDialogCancelButton(ctx),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            appDialogPrimaryButton(label: 'Add', onPressed: submit),
          ],
        );
      },
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
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Container(
              // vertical 2 stays static — a sub-8 badge inset, not layout.
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.smallSpacing(context),
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Text(
                '${_taxes.length}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        ...List.generate(_taxes.length, (i) => _buildTaxRow(_taxes[i], i)),
      ],
    );
  }

  Widget _buildTaxRow(TaxItem tax, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
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
                ),
              ]
            : [],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: 4,
        ),
        leading: GestureDetector(
          onTap: () => _setDefault(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tax.isDefault ? AppColors.primary : AppColors.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: tax.isDefault ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Icon(
              tax.isDefault ? Icons.check : Icons.circle_outlined,
              size: AppResponsive.smallIconSize(context),
              color: tax.isDefault ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
        title: Text(
          tax.name,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: tax.isDefault
            ? Text(
                'Default tax',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.primary,
                ),
              )
            : Text(
                'Tap circle to set as default',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              // vertical 6 stays static — sub-8 pill inset.
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.mediumSpacing(context),
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                // Pill shape — ornamental.
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${tax.rate}%',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            GestureDetector(
              onTap: () => _removeAt(index),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: AppResponsive.getValue(
          context,
          mobile: 32.0,
          tablet: 36.0,
          desktop: 40.0,
        ),
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(
            Icons.percent_rounded,
            size: AppResponsive.getValue(
              context,
              mobile: 48.0,
              tablet: 56.0,
              desktop: 64.0,
            ),
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            'No taxes added yet',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use quick-add presets or enter manually above',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
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
        Icon(
          Icons.info_outline,
          size: 14,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Text(
          'You can modify taxes later from Settings.',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
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
            icon: Icon(
              Icons.arrow_back,
              size: AppResponsive.smallIconSize(context),
            ),
            // Styled explicitly: a bare Text() inherits the Material default,
            // which is Roboto — next to a Poppins 'Continue'.
            label: Text(
              'Back',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.buttonFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: AppResponsive.mediumSpacing(context),
              ),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
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
          child: Observer(
            builder: (_) => ElevatedButton.icon(
              onPressed: widget.store.isLoading
                  ? null
                  : () async {
                      if (!await widget.store.saveTaxDetails()) {
                        NotificationService.instance.showError(
                          widget.store.errorMessage ??
                              'Failed to save tax details',
                        );
                        return;
                      }
                      if (AppConfig.isRetail) {
                        // Through the store so its in-memory copy matches the
                        // preference — see CartStore.setTaxMode.
                        await retailCartStore.setTaxMode(
                          widget.store.taxInclusive,
                        );
                        if (_taxes.isNotEmpty) {
                          final defaultTax = _taxes.firstWhere(
                            (t) => t.isDefault,
                            orElse: () => _taxes.first,
                          );
                          await gstService.setDefaultGstRate(defaultTax.rate);
                        }
                      } else if (AppConfig.isRestaurant) {
                        await AppSettings.updateSetting(
                          'Tax Is Inclusive',
                          widget.store.taxInclusiveRestaurant,
                        );
                      }
                      if (!await _saveTaxesToDatabase()) return;
                      if (!mounted) return;
                      widget.onNext();
                    },
              icon: widget.store.isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward,
                      size: AppResponsive.smallIconSize(context),
                    ),
              label: Text(
                widget.store.isLoading ? 'Saving…' : 'Continue',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.buttonFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.mediumSpacing(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.borderRadius(context),
                  ),
                ),
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
