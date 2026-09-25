import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import '../../../presentation/widget/componets/common/app_text_field.dart';
import '../../../presentation/widget/componets/common/location_dropdown_field.dart';
import '../../../presentation/widget/componets/retail/retail_store_type_field.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/food_license_rule.dart';
import '../../../core/config/phone_rule.dart';
import '../../../core/config/postal_code_rule.dart';
import '../../../core/config/tax_id_rule.dart';
import '../../../domain/services/common/notification_service.dart';
import '../../../util/common/country_state_city_data.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';

/// Store Details Step
class StoreDetailsStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const StoreDetailsStep({
    Key? key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  }) : super(key: key);

  @override
  State<StoreDetailsStep> createState() => _StoreDetailsStepState();
}

class _StoreDetailsStepState extends State<StoreDetailsStep> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _storeNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _pincodeController;
  late TextEditingController _gstController;
  late TextEditingController _panController;
  late TextEditingController _foodLicenseController;

  // Focus nodes — chained so the keyboard "next" jumps to the following field.
  final _storeNameFocus = FocusNode();
  final _ownerNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _pincodeFocus = FocusNode();
  final _gstFocus = FocusNode();
  final _panFocus = FocusNode();
  final _foodLicenseFocus = FocusNode();

  // Cascading location options for the Country → State → City dropdowns.
  final _location = CountryStateCityData.instance;
  List<String> _countryOptions = [];
  List<String> _stateOptions = [];
  List<String> _cityOptions = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initLocationOptions();
  }

  /// Loads the country list, plus the state/city lists for any values already
  /// saved on the store (edit / returning to this step), so dropdowns pre-fill.
  Future<void> _initLocationOptions() async {
    final countries = await _location.countries();
    final country = _countryController.text.trim();
    final state = _stateController.text.trim();
    final states = country.isNotEmpty
        ? await _location.states(country)
        : <String>[];
    final cities = (country.isNotEmpty && state.isNotEmpty)
        ? await _location.cities(country, state)
        : <String>[];
    if (!mounted) return;
    setState(() {
      _countryOptions = countries;
      _stateOptions = states;
      _cityOptions = cities;
    });
  }

  Future<void> _onCountrySelected(String country) async {
    // Country changed → the old state/city no longer apply; reset both.
    _countryController.text = country;
    _stateController.clear();
    _cityController.clear();
    widget.store.setCountry(country);
    widget.store.setState('');
    widget.store.setCity('');
    // PAN only applies to India; if the user switches away after typing one,
    // drop it so the store never silently retains a now-hidden field's value.
    if (!_isIndia && _panController.text.isNotEmpty) {
      _panController.clear();
      widget.store.setPan('');
    }
    final states = await _location.states(country);
    if (!mounted) return;
    setState(() {
      _stateOptions = states;
      _cityOptions = [];
    });
  }

  Future<void> _onStateSelected(String state) async {
    _stateController.text = state;
    _cityController.clear();
    widget.store.setState(state);
    widget.store.setCity('');
    final cities = await _location.cities(
      _countryController.text.trim(),
      state,
    );
    if (!mounted) return;
    setState(() => _cityOptions = cities);
  }

  void _onCitySelected(String city) {
    setState(() => _cityController.text = city);
    widget.store.setCity(city);
  }

  String _val(String? v, String fallback) =>
      (v != null && v.isNotEmpty) ? v : fallback;

  /// True when the selected country is India — the single switch that drives
  /// the Tax & Legal section's fields/labels/validators.
  bool get _isIndia => _countryController.text.trim().toLowerCase() == 'india';

  /// Gates the registration-number field's visibility — a legal-status question,
  /// separate from `widget.store.taxEnabled` (behavioral; read by the Tax Setup
  /// step and billing logic). V1 onboarding always sets both together (see
  /// _onTaxRegistrationStatusChanged) but they're independently persisted.
  bool get _isRegisteredForTax => widget.store.isRegisteredForTax;

  // isRegisteredForTax and taxEnabled are distinct fields in the data model (see
  // SetupWizardStore), but V1 onboarding only ever sets them together via this one
  // Yes/No question — no separate control for taxEnabled exists in this wizard.
  void _onTaxRegistrationStatusChanged(bool registered) {
    setState(() {
      widget.store.setIsRegisteredForTax(registered);
      widget.store.setTaxEnabled(registered);
      // Hiding the GSTIN/PAN fields keeps what was typed, so switching back to
      // Registered restores it. Bills only print the number while tax is on.
    });
  }

  void _initializeControllers() {
    _storeNameController = TextEditingController(
      text: widget.store.storeName ?? '',
    );
    _ownerNameController = TextEditingController(
      text: widget.store.ownerName ?? '',
    );
    _phoneController = TextEditingController(text: widget.store.phone ?? '');
    _emailController = TextEditingController(text: widget.store.email ?? '');
    _addressController = TextEditingController(
      text: widget.store.address ?? '',
    );
    _cityController = TextEditingController(text: widget.store.city ?? '');
    _stateController = TextEditingController(text: widget.store.state ?? '');
    _countryController = TextEditingController(
      text: widget.store.country ?? '',
    );
    _pincodeController = TextEditingController(
      text: widget.store.pincode ?? '',
    );
    _gstController = TextEditingController(text: widget.store.gstin ?? '');
    _panController = TextEditingController(text: widget.store.pan ?? '');
    _foodLicenseController = TextEditingController(
      text: widget.store.foodLicenseNo,
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _foodLicenseController.dispose();
    _storeNameFocus.dispose();
    _ownerNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _pincodeFocus.dispose();
    _gstFocus.dispose();
    _panFocus.dispose();
    _foodLicenseFocus.dispose();
    super.dispose();
  }

  void _syncToStore() {
    widget.store.setStoreName(_storeNameController.text);
    widget.store.setOwnerName(_ownerNameController.text);
    widget.store.setPhone(_phoneController.text);
    widget.store.setEmail(_emailController.text);
    widget.store.setAddress(_addressController.text);
    widget.store.setCity(_cityController.text);
    widget.store.setState(_stateController.text);
    widget.store.setCountry(_countryController.text);
    widget.store.setPincode(_pincodeController.text);
    widget.store.setGstin(_gstController.text);
    widget.store.setPan(_panController.text);
    widget.store.setFoodLicenseNo(_foodLicenseController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isWide =
        AppResponsive.isTablet(context) || AppResponsive.isDesktop(context);
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

    return Column(
      children: [
        // ── Scrollable form content ──────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 0),
            child: Form(
              key: _formKey,
              child: isWide
                  ? _buildTabletLayout(context)
                  : _buildMobileLayout(context),
            ),
          ),
        ),

        // ── Buttons pinned at bottom ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, vPad),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
            ),
          ),
          child: _buildNavButtons(context),
        ),
      ],
    );
  }

  // ── Mobile: single column ────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, isTablet: false),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _buildBasicSection(context, isTablet: false),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _buildContactSection(context, isTablet: false),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _buildLegalSection(context),
        SizedBox(height: AppResponsive.largeSpacing(context)),
      ],
    );
  }

  // ── Tablet: centered max-width, two-column logo+fields ──────────────────────

  Widget _buildTabletLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Same cap the wizard applies (600 / 800) rather than a second,
          // wider ladder of its own. Kept rather than dropped: between 600 and
          // 850 the host renders its uncapped mobile tree, so this is the only
          // cap in effect there.
          maxWidth: AppResponsive.maxFormWidth(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isTablet: true),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            _buildBasicSection(context, isTablet: true),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildContactSection(context, isTablet: true),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildLegalSection(context),
            SizedBox(height: AppResponsive.largeSpacing(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, {required bool isTablet}) {
    if (isTablet) {
      return Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
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
                AppResponsive.largeBorderRadius(context),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: AppResponsive.largeIconSize(context),
            ),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Information',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue<double>(
                      context,
                      mobile: 22,
                      tablet: 26,
                      desktop: 30,
                    ),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Tell us about your store so we can personalize your experience',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Store Information',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue<double>(
              context,
              mobile: 20,
              tablet: 24,
              desktop: 28,
            ),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context) - 2),
        Text(
          'Basic details about your store',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Below this much MEASURED width a two-up row leaves each `AppTextField`
  /// too narrow for its label, which ellipsizes silently instead of overflowing.
  static const double _pairRowMinWidth = 340;

  /// Two fields side by side, stacked when the space can't hold both.
  /// Measured rather than breakpoint-based: this step renders inside the
  /// wizard's capped PageView, so screen width says nothing about space here.
  Widget _pairRow(BuildContext context, Widget first, Widget second) {
    final gap = AppResponsive.mediumSpacing(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _pairRowMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: gap),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: gap),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  // ── Section card wrapper ──────────────────────────────────────────────────────

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.mediumSpacing(context),
              vertical: AppResponsive.smallSpacing(context),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppResponsive.borderRadius(context)),
                topRight: Radius.circular(AppResponsive.borderRadius(context)),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.primary,
                ),
                SizedBox(width: AppResponsive.smallSpacing(context)),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.smallFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Section content
          Padding(
            padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── Basic info section (name + owner + logo) ──────────────────────────────────

  Widget _buildBasicSection(BuildContext context, {required bool isTablet}) {
    return _sectionCard(
      context,
      title: 'Basic Information',
      icon: Icons.business_rounded,
      child: Column(
        children: [
          if (isTablet)
            // Tablet: logo left, name+owner right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo upload
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Logo',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      _buildLogoUpload(context, height: 140),
                    ],
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                // Name + owner stacked
                Expanded(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _storeNameController,
                        autofocus: true,
                        focusNode: _storeNameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _ownerNameFocus.requestFocus(),
                        label: 'Store Name',
                        hint: 'e.g. Green Apple Cafe',
                        icon: Icons.store_rounded,
                        required: true,
                        maxLength: 50,
                        onChanged: (v) => widget.store.setStoreName(v),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Store name is required'
                            : null,
                      ),
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      AppTextField(
                        controller: _ownerNameController,
                        focusNode: _ownerNameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                        label: 'Owner Name',
                        hint: 'Enter owner name',
                        icon: Icons.person_rounded,
                        required: true,
                        maxLength: 50,
                        onChanged: (v) => widget.store.setOwnerName(v),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Owner name is required'
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            // Mobile: stacked
            AppTextField(
              controller: _storeNameController,
              autofocus: true,
              focusNode: _storeNameFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _ownerNameFocus.requestFocus(),
              label: 'Store Name',
              hint: 'e.g. Green Apple Cafe',
              icon: Icons.store_rounded,
              required: true,
              maxLength: 50,
              onChanged: (v) => widget.store.setStoreName(v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Store name is required' : null,
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _ownerNameController,
              focusNode: _ownerNameFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
              label: 'Owner Name',
              hint: 'Enter owner name',
              icon: Icons.person_rounded,
              required: true,
              maxLength: 50,
              onChanged: (v) => widget.store.setOwnerName(v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Owner name is required' : null,
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            Text(
              'Store Logo',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            _buildLogoUpload(context, height: 160),
          ],
          // Retail only: what this shop sells. Decides which product fields the
          // catalogue starts with, nothing else.
          if (AppConfig.isRetail) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _buildStoreTypeField(context),
          ],
        ],
      ),
    );
  }

  // ── Retail store type ─────────────────────────────────────────────────────────

  /// Moved here from the Business Type step: it belongs with the store's
  /// identity, and `saveBusinessDetails()` (called by Continue) is already what
  /// persists `retailStoreType`.
  Widget _buildStoreTypeField(BuildContext context) {
    return Observer(
      builder: (_) => RetailStoreTypeField(
        value: widget.store.selectedRetailStoreType,
        onChanged: widget.store.selectRetailStoreType,
      ),
    );
  }

  // ── Logo upload widget ────────────────────────────────────────────────────────

  Widget _buildLogoUpload(BuildContext context, {double height = 160}) {
    return Observer(
      builder: (_) {
        final hasImage = widget.store.logoByte != null;
        return InkWell(
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          onTap: () => widget.store.pickLogo(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
              color: hasImage ? Colors.black : AppColors.surfaceLight,
              border: Border.all(color: AppColors.divider),
              image: hasImage
                  ? DecorationImage(
                      image: MemoryImage(widget.store.logoByte!),
                      fit: BoxFit.contain,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (!hasImage)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            AppResponsive.mediumSpacing(context),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.primary,
                            size: height > 140 ? 32 : 24,
                          ),
                        ),
                        SizedBox(height: AppResponsive.smallSpacing(context)),
                        Text(
                          'Upload Logo',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.smallFontSize(context),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        if (height > 140)
                          Text(
                            'Tap to browse',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.captionFontSize(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (hasImage)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () => widget.store.deleteLogo(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: AppResponsive.smallIconSize(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Phone validation ──────────────────────────────────────────────────────────

  /// Validates the store phone number against the CURRENTLY selected country.
  ///
  /// Reads `_countryController` rather than `PhoneRule`'s saved-country
  /// getters: the country is chosen on this very screen and isn't persisted
  /// until the step completes, so the saved value is still blank here and
  /// would fall back to India.
  String? _validatePhone(String? v) =>
      PhoneRule.validateFor(_countryController.text, v);

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates the postal code against the CURRENTLY selected country — same
  /// reason as [_validatePhone]: the country is chosen on this screen and is
  /// not persisted until Continue, so the saved-country getters read blank.
  String? _validatePincode(String? v) =>
      PostalCodeRule.validateFor(_countryController.text, v);

  String? _validateGstin(String? v) =>
      TaxIdRule.validateFor(_countryController.text, v);

  String? _validatePan(String? v) => TaxIdRule.validatePan(v);

  /// First invalid required field, top-to-bottom → its focus node (null for the
  /// Country/State/City dropdowns, which have none) + the message to show. Used
  /// to notify + scroll-to-error when validation fails with an off-screen field.
  ({FocusNode? focus, String message})? _firstInvalidField() {
    if (_storeNameController.text.trim().isEmpty) {
      return (focus: _storeNameFocus, message: 'Store name is required');
    }
    if (_ownerNameController.text.trim().isEmpty) {
      return (focus: _ownerNameFocus, message: 'Owner name is required');
    }
    // Retail's store type sits in the Basic section, so it is checked here in
    // reading order. It is a dropdown, hence no focus node to scroll to.
    if (AppConfig.isRetail && !widget.store.hasRetailStoreType) {
      return (focus: null, message: 'Please choose what you sell');
    }
    // Country is checked BEFORE phone even though it sits lower on the form —
    // dependency order beats reading order here. The phone rule is derived
    // from the country, so demanding a country-shaped number before the
    // country is known produces a message the user cannot act on ("must be
    // exactly 10 digits" for a store that is not in India).
    if (_countryController.text.trim().isEmpty) {
      return (focus: null, message: 'Country is required');
    }
    final phoneErr = _validatePhone(_phoneController.text);
    if (phoneErr != null) return (focus: _phoneFocus, message: phoneErr);
    final emailErr = _validateEmail(_emailController.text);
    if (emailErr != null) return (focus: _emailFocus, message: emailErr);
    if (_addressController.text.trim().isEmpty) {
      return (focus: _addressFocus, message: 'Address is required');
    }
    if (_stateController.text.trim().isEmpty) {
      return (focus: null, message: 'State is required');
    }
    if (_cityController.text.trim().isEmpty) {
      return (focus: null, message: 'City is required');
    }
    final pinErr = _validatePincode(_pincodeController.text);
    if (pinErr != null) return (focus: _pincodeFocus, message: pinErr);
    final licErr = FoodLicenseRule.validateFor(
      _countryController.text,
      _foodLicenseController.text,
    );
    if (licErr != null) {
      return (focus: _foodLicenseFocus, message: licErr);
    }
    if (_isRegisteredForTax) {
      final gstErr = _validateGstin(_gstController.text);
      if (gstErr != null) return (focus: _gstFocus, message: gstErr);
      if (_isIndia) {
        final panErr = _validatePan(_panController.text);
        if (panErr != null) return (focus: _panFocus, message: panErr);
      }
    }
    return null;
  }

  // ── Contact section (phone + email + address) ─────────────────────────────────

  Widget _buildContactSection(BuildContext context, {required bool isTablet}) {
    return _sectionCard(
      context,
      title: 'Contact Details',
      icon: Icons.contact_phone_rounded,
      child: Column(
        children: [
          _pairRow(
            context,
            AppTextField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              label: 'Phone Number',
              icon: Icons.phone_rounded,
              required: true,
              keyboardType: TextInputType.phone,
              // All three follow the Country dropdown further down this form,
              // exactly as the GSTIN field below already follows it. While the
              // country is still unchosen these stay permissive (7–15) rather
              // than assuming India — the field is ABOVE the dropdown, so a
              // 10-digit demand would fire before the question was asked.
              hint: PhoneRule.hintFor(_countryController.text),
              maxLength: PhoneRule.maxLengthFor(_countryController.text),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => widget.store.setPhone(v),
              validator: _validatePhone,
            ),
            AppTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _addressFocus.requestFocus(),
              label: 'Email',
              hint: 'info@store.com',
              icon: Icons.email_rounded,
              required: true,
              maxLength: 60,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => widget.store.setEmail(v),
              validator: _validateEmail,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          AppTextField(
            controller: _addressController,
            focusNode: _addressFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            label: 'Store Address',
            hint: 'Street / Area',
            icon: Icons.location_on_rounded,
            required: true,
            maxLines: isTablet ? 2 : 3,
            maxLength: 150,
            onChanged: (v) => widget.store.setAddress(v),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Address is required' : null,
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          // Country → State → City cascading dropdowns (BA change: dropdowns for
          // data consistency; City also accepts a typed value if not listed).
          LocationDropdownField(
            label: 'Country',
            icon: Icons.public_rounded,
            value: _countryController.text.isEmpty
                ? null
                : _countryController.text,
            options: _countryOptions,
            onSelected: _onCountrySelected,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Country is required' : null,
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          _pairRow(
            context,
            LocationDropdownField(
              label: 'State',
              icon: Icons.map_rounded,
              value: _stateController.text.isEmpty
                  ? null
                  : _stateController.text,
              options: _stateOptions,
              ready: _countryController.text.trim().isNotEmpty,
              onBlocked: () => NotificationService.instance.showError(
                'Please select the country first',
              ),
              onSelected: _onStateSelected,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'State is required' : null,
            ),
            LocationDropdownField(
              label: 'City',
              icon: Icons.location_city_rounded,
              value: _cityController.text.isEmpty ? null : _cityController.text,
              options: _cityOptions,
              ready: _stateController.text.trim().isNotEmpty,
              allowCustom: true,
              onBlocked: () => NotificationService.instance.showError(
                'Please select the state first',
              ),
              onSelected: _onCitySelected,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'City is required' : null,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _pincodeController,
                  focusNode: _pincodeFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _foodLicenseFocus.requestFocus(),
                  // Label, cap, alphabet and even whether it is required all
                  // follow the Country dropdown — a UK postcode contains
                  // letters, and a few countries have none at all.
                  label: PostalCodeRule.labelFor(_countryController.text),
                  hint: PostalCodeRule.hintFor(_countryController.text),
                  icon: Icons.pin_drop_rounded,
                  required: PostalCodeRule.isRequiredFor(
                    _countryController.text,
                  ),
                  keyboardType:
                      PostalCodeRule.digitsOnlyFor(_countryController.text)
                      ? TextInputType.number
                      : TextInputType.text,
                  maxLength: PostalCodeRule.maxLengthFor(
                    _countryController.text,
                  ),
                  // Only applied where the code really is numeric: a
                  // digits-only filter silently swallows the letters in
                  // "SW1A 1AA" and reads as a broken keyboard.
                  inputFormatters:
                      PostalCodeRule.digitsOnlyFor(_countryController.text)
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  // Postcodes are conventionally uppercase; a keyboard hint
                  // only, it does not transform what is already typed.
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => widget.store.setPincode(v),
                  validator: _validatePincode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Legal section (registration status + GST/PAN) ──────────────────────────────

  Widget _buildLegalSection(BuildContext context) {
    final isIndia = _isIndia;
    return _sectionCard(
      context,
      title: 'Tax & Legal (Optional)',
      icon: Icons.receipt_long_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First in the section, and outside the _isRegisteredForTax gate: a
          // food licence is independent of tax registration, so a business that
          // answers "Not Registered" must still be able to enter one.
          _buildFoodLicenseField(context),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          _buildTaxRegistrationSelector(context, isIndia: isIndia),
          if (_isRegisteredForTax) ...[
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            isIndia
                ? _pairRow(
                    context,
                    AppTextField(
                      controller: _gstController,
                      focusNode: _gstFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _panFocus.requestFocus(),
                      label: TaxIdRule.labelFor(_countryController.text),
                      hint: TaxIdRule.hintFor(_countryController.text),
                      icon: Icons.receipt_long_rounded,
                      maxLength: TaxIdRule.maxLengthFor(
                        _countryController.text,
                      ),
                      onChanged: (v) => widget.store.setGstin(v),
                      validator: _validateGstin,
                    ),
                    AppTextField(
                      controller: _panController,
                      focusNode: _panFocus,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _panFocus.unfocus(),
                      label: 'PAN',
                      hint: 'Optional',
                      icon: Icons.credit_card_rounded,
                      maxLength: 10,
                      onChanged: (v) => widget.store.setPan(v),
                      validator: _validatePan,
                    ),
                  )
                : AppTextField(
                    controller: _gstController,
                    focusNode: _gstFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                    label: TaxIdRule.labelFor(_countryController.text),
                    hint: TaxIdRule.hintFor(_countryController.text),
                    icon: Icons.receipt_long_rounded,
                    maxLength: TaxIdRule.maxLengthFor(_countryController.text),
                    onChanged: (v) => widget.store.setGstin(v),
                    validator: _validateGstin,
                  ),
          ],
        ],
      ),
    );
  }

  /// Country-adaptive food-business licence (FSSAI in India). Always optional.
  /// Reads the LOCAL country controller, not the persisted record — nothing is
  /// saved yet while the user is still on this step.
  Widget _buildFoodLicenseField(BuildContext context) {
    final country = _countryController.text;
    final digitsOnly = FoodLicenseRule.digitsOnlyFor(country);

    return AppTextField(
      controller: _foodLicenseController,
      focusNode: _foodLicenseFocus,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      label: FoodLicenseRule.labelFor(country),
      hint: FoodLicenseRule.hintFor(country),
      icon: Icons.verified_user_outlined,
      maxLength: FoodLicenseRule.maxLengthFor(country),
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: (v) => widget.store.setFoodLicenseNo(v),
      validator: (v) => FoodLicenseRule.validateFor(country, v),
    );
  }

  Widget _buildTaxRegistrationSelector(
    BuildContext context, {
    required bool isIndia,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TaxIdRule.registrationTitleFor(_countryController.text),
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.darkNeutral,
          ),
        ),
        if (!isIndia) ...[
          const SizedBox(height: 2),
          Text(
            'Used for VAT, Sales Tax, GST and similar tax systems.',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: AppResponsive.smallSpacing(context)),
        _buildTaxRegistrationOption(
          context,
          label: 'Registered',
          selected: _isRegisteredForTax,
          onTap: () => _onTaxRegistrationStatusChanged(true),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        _buildTaxRegistrationOption(
          context,
          label: 'Not Registered',
          selected: !_isRegisteredForTax,
          onTap: () => _onTaxRegistrationStatusChanged(false),
        ),
      ],
    );
  }

  Widget _buildTaxRegistrationOption(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.mediumSpacing(context),
          vertical: AppResponsive.mediumSpacing(context),
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.darkNeutral,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav buttons ───────────────────────────────────────────────────────────────

  Widget _buildNavButtons(BuildContext context) {
    return Observer(
      builder: (_) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _syncToStore();
                widget.onPrevious();
              },
              icon: Icon(
                Icons.arrow_back,
                size: AppResponsive.smallIconSize(context),
              ),
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
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue<double>(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 16,
                  ),
                ),
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
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _syncToStore();
                  widget.store.saveBusinessDetails();
                  widget.onNext();
                  return;
                }
                // Validation failed — the invalid field may be scrolled off-screen,
                // so surface the reason and take the user straight to it.
                final first = _firstInvalidField();
                first?.focus
                    ?.requestFocus(); // focusing a field auto-scrolls it in
                NotificationService.instance.showError(
                  first?.message ?? 'Please fill all required fields correctly',
                );
              },
              icon: widget.store.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward,
                      size: AppResponsive.smallIconSize(context),
                      color: AppColors.white,
                    ),
              label: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue<double>(
                    context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 16,
                  ),
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
        ],
      ),
    );
  }
}
