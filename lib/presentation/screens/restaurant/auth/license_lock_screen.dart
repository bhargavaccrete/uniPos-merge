import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/data/models/restaurant/license_model.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Full-screen license gate. Shown when:
///   • No license has been activated on this device, OR
///   • The local expiry date has passed.
///
/// The app cannot proceed past this screen without a valid activation.
/// [onActivated] is called by the parent guard to re-check and unlock.
class LicenseLockScreen extends StatefulWidget {
  final VoidCallback onActivated;

  const LicenseLockScreen({super.key, required this.onActivated});

  @override
  State<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends State<LicenseLockScreen> {
  final LicenseStore _store = locator<LicenseStore>();
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  // Three mutually-exclusive lock reasons. Everything on this screen keys off
  // these instead of a single boolean, so `suspended` (deactivated by Bill
  // Berry) no longer masquerades as `expired`.
  LicenseStatus get _status =>
      _store.licenseInfo?.status ?? LicenseStatus.notActivated;

  bool get _isNotActivated => _status == LicenseStatus.notActivated;
  bool get _isExpired => _status == LicenseStatus.expired;
  bool get _isDeactivated => _status == LicenseStatus.suspended;

  // Skip is only ever allowed on a fresh device. An expired or deactivated
  // license must be renewed or resolved with support — it cannot be bypassed.
  bool get _canSkip => _isNotActivated;

  void _contactSupport() =>
      Navigator.pushNamed(context, RouteNames.restaurantNeedHelp);

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMsg = 'Please enter your license key');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final success = await _store.activateLicense(key);
    setState(() => _loading = false);
    if (success) {
      widget.onActivated();
    } else {
      setState(
          () => _errorMsg = _store.errorMessage ?? 'Activation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final pad = isTablet ? 40.0 : 24.0;

    return PopScope(
      canPop: false, // cannot back out of the lock screen
      child: Scaffold(
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
                    _lockIcon(),
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    _headline(isTablet),
                    SizedBox(height: AppResponsive.smallSpacing(context)),
                    _subtext(isTablet),
                    if (_isDeactivated) ...[
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      _deactivatedBanner(isTablet),
                    ],
                    if (_isExpired) ...[
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      _expiredInfoCard(isTablet),
                    ],
                    // For expired / deactivated licenses, contacting support is
                    // the primary path — surface it above the key field.
                    if (!_isNotActivated) ...[
                      SizedBox(height: AppResponsive.largeSpacing(context)),
                      _contactButton(isTablet),
                    ],
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    _keyInputCard(isTablet),
                    if (_canSkip) ...[
                      SizedBox(height: AppResponsive.mediumSpacing(context)),
                      _skipButton(isTablet),
                    ],
                    SizedBox(height: AppResponsive.largeSpacing(context)),
                    _supportNote(isTablet),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockIcon() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _isDeactivated
            ? Icons.gpp_bad_rounded
            : _isExpired
                ? Icons.lock_clock_rounded
                : Icons.lock_outline_rounded,
        size: 48,
        color: AppColors.danger,
      ),
    );
  }

  Widget _headline(bool isTablet) {
    return Text(
      _isDeactivated
          ? 'License Deactivated'
          : _isExpired
              ? 'License Expired'
              : 'License Required',
      style: GoogleFonts.poppins(
        fontSize: isTablet ? 26 : 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _subtext(bool isTablet) {
    final String msg;
    if (_isDeactivated) {
      msg =
          'This device\'s license has been deactivated. Please contact Bill Berry to restore access or get a new license key.';
    } else if (_isExpired) {
      msg =
          'Your license has expired. Contact Bill Berry for a new key to continue using Bill Berry Lite.';
    } else {
      msg =
          'This device is not licensed. Enter your license key to unlock the app.';
    }
    return Text(
      msg,
      style: TextStyle(
          fontSize: isTablet ? 15 : 13, color: AppColors.textSecondary),
      textAlign: TextAlign.center,
    );
  }

  Widget _expiredInfoCard(bool isTablet) {
    final info = _store.licenseInfo!;
    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _infoRow(Icons.workspace_premium_rounded, 'Plan',
              info.planName.isNotEmpty ? info.planName : '—', AppColors.warning),
          if (info.expiryDate != null)
            _infoRow(
              Icons.event_rounded,
              'Expired on',
              DateFormat('dd MMM yyyy').format(info.expiryDate!),
              AppColors.danger,
            ),
          _infoRow(Icons.key_rounded, 'Key', info.maskedKey, Colors.grey),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text('$label: ',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deactivatedBanner(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_gmailerrorred_rounded,
              size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your license was deactivated by Bill Berry. Please reach out to '
              'reactivate this device or purchase a new license key.',
              style: TextStyle(
                fontSize: isTablet ? 13 : 12,
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton(bool isTablet) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 54 : 50,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _contactSupport,
        icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
        label: Text(
          'Contact Bill Berry',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _keyInputCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.key_rounded,
                    size: isTablet ? 22 : 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Enter New License Key',
                style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: isTablet ? 54 : 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _activate,
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
                      'Activate & Unlock',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _skip() async {
    await _store.skipLicense();
    widget.onActivated();
  }

  Widget _skipButton(bool isTablet) {
    return TextButton.icon(
      onPressed: _loading ? null : _skip,
      icon: Icon(Icons.skip_next_rounded,
          size: isTablet ? 20 : 18, color: AppColors.textSecondary),
      label: Text(
        'Skip for now',
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 14 : 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _supportNote(bool isTablet) {
    return Text(
      'Each license key is valid for one device only.\nContact your administrator for a new key.',
      style: TextStyle(
          fontSize: isTablet ? 13 : 11, color: AppColors.textSecondary),
      textAlign: TextAlign.center,
    );
  }
}