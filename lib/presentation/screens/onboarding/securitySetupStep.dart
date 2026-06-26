import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/staff_model_222.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/restaurant_auth_helper.dart';
import 'package:billberrylite/domain/services/common/backup_encryption_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';

/// Onboarding "Security" step — sets the admin login PIN and the backup
/// password up-front so backups are always encrypted and admin login is never
/// left on the default PIN. Both are changeable later in Settings.
class SecuritySetupStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const SecuritySetupStep({
    super.key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<SecuritySetupStep> createState() => _SecuritySetupStepState();
}

class _SecuritySetupStepState extends State<SecuritySetupStep> {
  // Admin login PIN (key matches admin_login.dart / changePassword.dart).
  static const String _adminPasswordKey = 'restaurant_admin_password';

  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  final _pwdController = TextEditingController();
  final _pwdConfirmController = TextEditingController();

  bool _obscurePin = true;
  bool _obscurePwd = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _pinConfirmController.dispose();
    _pwdController.dispose();
    _pwdConfirmController.dispose();
    super.dispose();
  }

  /// Validates the inputs, returning an error to show or null when all valid.
  String? _validate() {
    final pin = _pinController.text.trim();
    final pwd = _pwdController.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      return 'Admin PIN must be 4–6 digits';
    }
    if (pin != _pinConfirmController.text.trim()) {
      return 'Admin PINs do not match';
    }
    // Shared backup-password policy (same rules in Settings + export gate).
    return BackupEncryptionService.validatePassword(
        pwd, _pwdConfirmController.text.trim());
  }

  /// True when [pin] is already assigned to a staff member, so the admin PIN
  /// can't reuse it (keeps PIN-only login unambiguous). Staff are persisted by
  /// the previous Staff step, so we read them straight from storage. Restaurant
  /// staff store a hashed PIN (verify); retail staff store it in plaintext.
  Future<bool> _pinUsedByStaff(String pin) async {
    if (AppConfig.isRetail) {
      if (!Hive.isBoxOpen('retail_staff')) return false;
      final box = Hive.box<RetailStaffModel>('retail_staff');
      return box.values.any((s) => s.pin == pin);
    }
    await staffStore.loadStaff();
    return staffStore.staff
        .any((s) => RestaurantAuthHelper.verifyPassword(pin, s.pinNo));
  }

  Future<void> _onContinue() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // Reject an admin PIN already in use by a staff member (mirrors the staff
    // screen, which rejects a staff PIN matching the admin's).
    if (await _pinUsedByStaff(_pinController.text.trim())) {
      setState(() => _error =
          'This PIN is already assigned to a staff member. Choose a different admin PIN.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    // Save admin PIN (hashed) + backup password. Saved immediately (same pattern
    // as the payment-setup step) so they persist even before wizard completion.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _adminPasswordKey, RestaurantAuthHelper.hashPassword(_pinController.text.trim()));
    await BackupEncryptionService.setPassword(_pwdController.text.trim());

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppResponsive.largeSpacing(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _buildHeader(context),
            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── Admin login PIN ──
            _sectionLabel(context, 'Admin Login PIN', Icons.admin_panel_settings_rounded),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            AppTextField(
              controller: _pinController,
              label: 'Admin PIN (4–6 digits)',
              hint: 'Used to log in as admin',
              icon: Icons.pin_rounded,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffixIcon: IconButton(
                icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _pinConfirmController,
              label: 'Confirm Admin PIN',
              icon: Icons.pin_rounded,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),

            SizedBox(height: AppResponsive.largeSpacing(context)),

            // ── Backup password ──
            _sectionLabel(context, 'Backup Password', Icons.lock_rounded),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            AppTextField(
              controller: _pwdController,
              label: 'Backup Password (6 digits)',
              hint: 'Used to encrypt your backups',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePwd,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffixIcon: IconButton(
                icon: Icon(_obscurePwd ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
              ),
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            AppTextField(
              controller: _pwdConfirmController,
              label: 'Confirm Backup Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePwd,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Backups cannot be recovered without this password. Keep it safe.',
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              SizedBox(height: AppResponsive.mediumSpacing(context)),
              Text(_error!,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 12.5)),
            ],

                ],
              ),
            ),
          ),
          // Pinned footer — Back / Continue stay at the bottom like other steps.
          Container(
            padding: EdgeInsets.fromLTRB(
                AppResponsive.largeSpacing(context),
                12,
                AppResponsive.largeSpacing(context),
                AppResponsive.largeSpacing(context)),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
              ),
            ),
            child: _buildNavButtons(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: AppResponsive.smallIconSize(context), color: AppColors.primary),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue<double>(context, mobile: 20, tablet: 24, desktop: 28),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Set an admin login PIN and a password that encrypts your backups.',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.smallFontSize(context),
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildNavButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : widget.onPrevious,
            icon: Icon(Icons.arrow_back, size: AppResponsive.smallIconSize(context)),
            label: Text('Back',
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 16)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context))),
            ),
          ),
        ),
        SizedBox(width: AppResponsive.mediumSpacing(context)),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _onContinue,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.arrow_forward,
                    size: AppResponsive.smallIconSize(context), color: AppColors.white),
            label: Text('Continue',
                style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                  vertical: AppResponsive.getValue<double>(context, mobile: 14, tablet: 16, desktop: 16)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context))),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
