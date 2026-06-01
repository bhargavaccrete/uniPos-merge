import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/domain/store/restaurant/license_store.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

/// Shown after "I'm a New User" — validates the key upfront and saves it as
/// pending. Activation (requiring businessname) fires automatically after
/// the setup wizard fills in the store name.
class LicenseKeyEntryScreen extends StatefulWidget {
  const LicenseKeyEntryScreen({super.key});

  @override
  State<LicenseKeyEntryScreen> createState() => _LicenseKeyEntryScreenState();
}

class _LicenseKeyEntryScreenState extends State<LicenseKeyEntryScreen> {
  final LicenseStore _store = locator<LicenseStore>();
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMsg = 'Please enter your license key');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final valid = await _store.validateKey(key);
    setState(() => _loading = false);

    if (!valid) {
      setState(() => _errorMsg = _store.errorMessage ?? 'Invalid license key');
      return;
    }
    await _store.savePendingKey(key);
    _goToSetup();
  }

  void _skip() => _goToSetup();

  void _goToSetup() =>
      Navigator.pushReplacementNamed(context, RouteNames.setupWizard);

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final pad = isTablet ? 40.0 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 480 : double.infinity,
                minHeight: MediaQuery.of(context).size.height - pad * 2,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.key_rounded,
                        size: 44, color: AppColors.primary),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  Text(
                    'Enter Your License Key',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 26 : 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Text(
                    'Your key will be validated now and activated\nautomatically after store setup is complete.',
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 22 : 18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _keyController,
                          label: 'License Key',
                          hint: 'e.g. XXXX-XXXX-XXXX-XXXX',
                          icon: Icons.vpn_key_rounded,
                          enableSuggestions: false,
                          autocorrect: false,
                        ),
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 14, color: AppColors.danger),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: isTablet ? 54 : 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _validate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'Validate & Continue',
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 16 : 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Activation requires your store name. '
                            'We\'ll activate automatically after setup.',
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 12,
                              color: AppColors.info,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip for now — activate in Settings later',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
