import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/core/config/food_license_rule.dart';
import 'package:billberrylite/core/config/tax_id_rule.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:flutter/services.dart';
import 'package:billberrylite/util/color.dart';

class StoreInfoSettingsScreen extends StatefulWidget {
  const StoreInfoSettingsScreen({super.key});

  @override
  State<StoreInfoSettingsScreen> createState() =>
      _StoreInfoSettingsScreenState();
}

class _StoreInfoSettingsScreenState extends State<StoreInfoSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeSettingsService = StoreSettingsService();

  // Controllers
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _foodLicenseController = TextEditingController();
  final _panController = TextEditingController();

  // Logo
  Uint8List? _logoBytes;
  bool _logoChanged = false;

  // Tax registration as saved, and as currently chosen on screen. Written only
  // on Save, and only while no day is open.
  bool _savedRegistered = true;
  bool _isRegistered = true;

  static const _dayOpenMessage =
      'Close the day with End of Day before changing tax registration.';

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    _storeNameController.text =
        await _storeSettingsService.getStoreName() ?? '';
    _ownerNameController.text =
        await _storeSettingsService.getOwnerName() ?? '';
    _addressController.text =
        await _storeSettingsService.getStoreAddress() ?? '';
    _cityController.text = await _storeSettingsService.getStoreCity() ?? '';
    _stateController.text = await _storeSettingsService.getStoreState() ?? '';
    _pincodeController.text =
        await _storeSettingsService.getStorePincode() ?? '';
    _phoneController.text = await _storeSettingsService.getStorePhone() ?? '';
    _emailController.text = await _storeSettingsService.getStoreEmail() ?? '';
    _gstNumberController.text =
        await _storeSettingsService.getGSTNumber() ?? '';
    // Food licence is stored in Hive only — StoreSettingsService has no key
    // for it, and the receipt builders read it straight off BusinessDetails.
    _foodLicenseController.text =
        businessDetailsRepository.get()?.foodLicenseNo ?? '';
    _isRegistered = _savedRegistered = TaxIdRule.isRegistered;
    // PAN, like the food licence, lives only on BusinessDetails.
    _panController.text = businessDetailsRepository.get()?.pan ?? '';
    _logoBytes = await _storeSettingsService.getStoreLogo();

    setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        // Validate image size (max 2MB)
        if (bytes.length > 2 * 1024 * 1024) {
          if (mounted) {
            NotificationService.instance.showError(
              'Image is too large. Please select an image under 2MB.',
            );
          }
          return;
        }

        setState(() {
          _logoBytes = bytes;
          _logoChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error picking image: $e');
      }
    }
  }

  Future<void> _deleteLogo() async {
    setState(() {
      _logoBytes = null;
      _logoChanged = true;
    });
  }

  /// Carts and the retail bill do not re-read the tax flag mid-sale, so the
  /// switch is only allowed with no session open and no End of Day pending.
  Future<bool> _dayIsOpen() async =>
      await DayManagementService.isDayStarted() ||
      await DayManagementService.hasPendingEOD();

  Future<void> _onRegistrationToggled(bool registered) async {
    if (await _dayIsOpen()) {
      NotificationService.instance.showError(_dayOpenMessage);
      return;
    }
    if (!mounted) return;
    final number = TaxIdRule.label;
    final confirm = await showAppConfirmDialog(
      context: context,
      title: registered ? 'Turn on tax?' : 'Turn off tax?',
      message: registered
          ? 'After you save, new bills will charge tax at each item\'s tax '
                'rate and your $number will print on bills. Saved bills keep '
                'their amounts.'
          : 'After you save, new bills will charge no tax and your $number '
                'will stop printing. Item tax rates and your $number are kept, '
                'so you can turn tax back on later. Saved bills keep their '
                'amounts.',
      confirmLabel: registered ? 'Turn On' : 'Turn Off',
      accent: registered ? AppColors.primary : AppColors.warning,
      icon: Icons.receipt_long_rounded,
    );
    if (!confirm || !mounted) return;
    setState(() => _isRegistered = registered);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    // Re-checked here: a day could have been started after the switch moved.
    final registrationChanged = _isRegistered != _savedRegistered;
    if (registrationChanged && await _dayIsOpen()) {
      NotificationService.instance.showError(_dayOpenMessage);
      return;
    }

    setState(() => _isSaving = true);

    bool registrationSuccess = true;
    if (registrationChanged) {
      try {
        await businessDetailsRepository.saveTaxRegistration(_isRegistered);
        _savedRegistered = _isRegistered;
      } catch (e) {
        registrationSuccess = false;
        debugPrint('StoreInfoSettings: failed to save tax registration: $e');
      }
    }

    // Save text settings
    final success = await _storeSettingsService.saveAllSettings(
      storeName: _storeNameController.text,
      // Optional fields are always passed: null means "leave unchanged", so an
      // emptied field used to keep its old value on bills. A blank value now
      // removes it (StoreSettingsService._setOrRemove).
      ownerName: _ownerNameController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      gstNumber: _gstNumberController.text.trim(),
    );

    // Food licence has no prefs key — persist it to the Hive record the
    // receipt builders and FoodLicenseRule read.
    bool licenseSuccess = true;
    try {
      final details = businessDetailsRepository.get();
      if (details != null) {
        await businessDetailsRepository.save(
          details.copyWith(
            foodLicenseNo: _foodLicenseController.text.trim(),
            pan: _panController.text.trim(),
          ),
        );
      }
    } catch (e) {
      licenseSuccess = false;
      debugPrint('StoreInfoSettings: failed to save food licence: $e');
    }

    // Save logo if it was changed
    bool logoSuccess = true;
    if (_logoChanged) {
      if (_logoBytes != null) {
        logoSuccess = await _storeSettingsService.setStoreLogo(_logoBytes!);
      } else {
        logoSuccess = await _storeSettingsService.deleteStoreLogo();
      }
    }

    setState(() => _isSaving = false);

    if (mounted) {
      final bool allSuccess =
          success && logoSuccess && licenseSuccess && registrationSuccess;
      if (allSuccess) {
        NotificationService.instance.showSuccess(
          registrationChanged && _isRegistered
              ? 'Saved. Tax is on — set up rates in Tax Settings and apply them to your products.'
              : 'Store information saved successfully',
        );
      } else {
        NotificationService.instance.showError('Failed to save some settings');
      }

      if (allSuccess) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstNumberController.dispose();
    _foodLicenseController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Store Information'),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxCardWidth(context),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: AppResponsive.padding(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
                      Container(
                        padding: AppResponsive.cardPadding(context),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppResponsive.borderRadius(context),
                          ),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.info),
                            SizedBox(
                              width: AppResponsive.mediumSpacing(context),
                            ),
                            Expanded(
                              child: Text(
                                'This information will appear on all receipts and invoices',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.bodyFontSize(context),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Logo Section
                      _buildSectionHeader('Store Logo'),
                      SizedBox(height: AppResponsive.smallSpacing(context)),
                      Text(
                        'Your logo will appear on receipts and invoices',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildLogoSection(),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Business Details Section
                      _buildSectionHeader('Business Details'),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Store Name',
                        icon: Icons.store,
                        hint: 'e.g., ABC Store',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Store name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _ownerNameController,
                        label: 'Owner Name',
                        icon: Icons.person,
                        hint: 'e.g., John Doe',
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTaxRegistrationCard(),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      // Hidden while "Not Registered", as on Store Details. The
                      // controller keeps the value and saves it back unchanged,
                      // so turning registration off never clears the number.
                      if (_isRegistered) ...[
                        _buildTextField(
                          controller: _gstNumberController,
                          label: TaxIdRule.label,
                          icon: Icons.account_balance_wallet,
                          hint: TaxIdRule.hint,
                          maxLength: TaxIdRule.maxLength,
                          textCapitalization: TextCapitalization.characters,
                          validator: TaxIdRule.validate,
                        ),
                        SizedBox(height: AppResponsive.largeSpacing(context)),
                        // PAN is India-only, as on Store Details.
                        if (TaxIdRule.isIndia) ...[
                          _buildTextField(
                            controller: _panController,
                            label: 'PAN',
                            icon: Icons.credit_card_rounded,
                            hint: 'e.g. ABCDE1234F',
                            maxLength: 10,
                            textCapitalization: TextCapitalization.characters,
                            validator: TaxIdRule.validatePan,
                          ),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                        ],
                      ],
                      _buildTextField(
                        controller: _foodLicenseController,
                        label: FoodLicenseRule.label,
                        icon: Icons.verified_user_outlined,
                        hint: FoodLicenseRule.hint,
                        maxLength: FoodLicenseRule.maxLength,
                        keyboardType: FoodLicenseRule.digitsOnly
                            ? TextInputType.number
                            : TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: FoodLicenseRule.digitsOnly
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null,
                        validator: FoodLicenseRule.validate,
                      ),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Address Section
                      _buildSectionHeader('Address'),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Street Address',
                        icon: Icons.location_on,
                        hint: 'e.g., 123 Main Street',
                        maxLines: 2,
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              icon: Icons.location_city,
                              hint: 'e.g., Mumbai',
                            ),
                          ),
                          SizedBox(width: AppResponsive.largeSpacing(context)),
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: 'Pincode',
                              icon: Icons.pin_drop,
                              hint: '400001',
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        icon: Icons.map,
                        hint: 'e.g., Maharashtra',
                      ),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Contact Information Section
                      _buildSectionHeader('Contact Information'),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        hint: '+91 1234567890',
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email,
                        hint: 'store@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(
                        height: AppResponsive.extraLargeSpacing(context),
                      ),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Save Information',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.white,
                                    fontSize: AppResponsive.subheadingFontSize(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTaxRegistrationCard() {
    final radius = BorderRadius.circular(AppResponsive.borderRadius(context));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: radius,
        border: Border.all(color: AppColors.divider),
      ),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: radius),
        value: _isRegistered,
        onChanged: _isSaving ? null : _onRegistrationToggled,
        activeThumbColor: AppColors.primary,
        secondary: Icon(
          Icons.receipt_long_rounded,
          color: AppColors.primary,
          size: AppResponsive.iconSize(context),
        ),
        title: Text(
          TaxIdRule.registrationTitle,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          _isRegistered
              ? 'Registered — tax is charged on bills'
              : 'Not registered — no tax is charged',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.subheadingFontSize(context),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Delegates to [AppTextField] — this screen had eleven raw `TextFormField`s,
  /// each rebuilding the same decoration by hand. The shared field owns the
  /// house border, fill, label and error treatment, so a change to input styling
  /// lands here for free instead of needing eleven edits.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      icon: icon,
      keyboardType: keyboardType ?? TextInputType.text,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildLogoSection() {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Logo Display
          Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _logoBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                    child: Image.memory(_logoBytes!, fit: BoxFit.contain),
                  )
                : Icon(Icons.image_outlined, size: 60, color: Colors.grey[400]),
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: Icon(
                  _logoBytes != null ? Icons.edit : Icons.upload,
                  size: AppResponsive.smallIconSize(context),
                ),
                label: Text(_logoBytes != null ? 'Change Logo' : 'Upload Logo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppResponsive.smallBorderRadius(context),
                    ),
                  ),
                ),
              ),
              if (_logoBytes != null) ...[
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                OutlinedButton.icon(
                  onPressed: _deleteLogo,
                  icon: Icon(
                    Icons.delete_outline,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  label: Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
