import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Self-signup step: verify email via OTP, then enter the emailed license key.
///   email → otp (verify) → enter key → onNext
/// The verified key is saved as the pending key and activated at Review.
enum _Phase { email, otp, enterKey }

class EmailVerificationStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const EmailVerificationStep({
    super.key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<EmailVerificationStep> createState() => _EmailVerificationStepState();
}

class _EmailVerificationStepState extends State<EmailVerificationStep> {
  final LicenseStore _license = locator<LicenseStore>();

  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _keyController = TextEditingController();

  _Phase _phase = _Phase.email;
  bool _loading = false;
  String? _errorMsg;
  String _submittedEmail = '';
  Timer? _ticker;

  DateTime? _lastResendTime;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.store.email);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return '${email[0]}••••${email.substring(at)}';
  }

  // ── Countdown driven by the server's expiresat ─────────────────────────────
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Duration get _remaining {
    final exp = _license.otpExpiresAt;
    if (exp == null) return Duration.zero;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get _remainingLabel {
    final d = _remaining;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _resendCooldownSeconds {
    if (_lastResendTime == null) return 0;
    final diff = DateTime.now().difference(_lastResendTime!);
    final remaining = 60 - diff.inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  void _setLoading(bool val) {
    if (!mounted) return;
    setState(() {
      _loading = val;
    });
    widget.store.isLoading = val;
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address');
      return;
    }
    widget.store.setEmail(email);
    _setLoading(true);
    setState(() {
      _errorMsg = null;
    });
    final ok = await _license.requestSignupOtp(widget.store.buildSignupBody());
    if (!mounted) return;
    _setLoading(false);
    setState(() {
      if (ok) {
        _submittedEmail = email;
        _phase = _Phase.otp;
        _lastResendTime = DateTime.now();
        _startTicker();
      } else {
        _errorMsg = _license.signupError;
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMsg = 'Please enter the code from your email');
      return;
    }
    _setLoading(true);
    setState(() {
      _isResending = false;
      _errorMsg = null;
    });
    final ok = await _license.verifyOtp(_submittedEmail, otp);
    if (!mounted) return;
    // Drop the numeric OTP keyboard before showing the (alphanumeric) key field,
    // so the soft keyboard re-queries the type instead of staying digits-only.
    FocusScope.of(context).unfocus();
    _setLoading(false);
    setState(() {
      if (ok) {
        _ticker?.cancel();
        _phase = _Phase.enterKey;
      } else {
        _errorMsg = _license.signupError;
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCooldownSeconds > 0) return;
    _setLoading(true);
    setState(() {
      _isResending = true;
      _errorMsg = null;
    });
    final ok = await _license.resendOtp(_submittedEmail);
    if (!mounted) return;
    _setLoading(false);
    setState(() {
      _isResending = false;
      if (ok) {
        _lastResendTime = DateTime.now();
        _startTicker();
      } else {
        _errorMsg = _license.signupError;
      }
    });
  }

  Future<void> _submitKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMsg = 'Please enter the license key from your email');
      return;
    }
    _setLoading(true);
    setState(() {
      _errorMsg = null;
    });
    final valid = await _license.validateKey(key);
    if (!mounted) {
      _setLoading(false);
      return;
    }
    if (!valid) {
      _setLoading(false);
      setState(() {
        _errorMsg = _license.errorMessage;
      });
      return;
    }

    // Activate NOW (not at the Review step) so the signed entitlements manifest
    // is loaded BEFORE Product/Staff setup — only then can those steps enforce
    // the plan's item/user limits. A successful activation clears the pending
    // key, so the Review step skips re-activation and goes straight to home.
    await _license.savePendingKey(key);
    final activated = await _license.activateWithPendingKey(
      businessName: widget.store.storeName,
    );
    if (!mounted) {
      _setLoading(false);
      return;
    }
    _setLoading(false);
    if (activated) {
      widget.onNext();
    } else {
      setState(() {
        _errorMsg =
            _license.errorMessage ?? 'Activation failed. Please try again.';
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: AppResponsive.screenPadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_phaseContent(context)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phaseContent(BuildContext context) {
    // Once the license is already activated (came back to this step, or the app
    // resumed setup after a restart), NEVER re-show email/OTP/key entry — the key
    // is consumed and the OTP expired. Show a completed state with Continue.
    if (_license.isLicensed) {
      return _activatedView(context);
    }
    switch (_phase) {
      case _Phase.email:
        return _emailView(context);
      case _Phase.otp:
        return _otpView(context);
      case _Phase.enterKey:
        return _enterKeyView(context);
    }
  }

  Widget _activatedView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.verified_rounded, AppColors.success,
            'License Activated',
            'Your license is active. Continue setting up your store.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _primaryButton(context, label: 'Continue', onPressed: widget.onNext),
      ],
    );
  }

  Widget _emailView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.mark_email_unread_rounded, AppColors.primary,
            'Verify Your Email',
            "We'll send a verification code to confirm your email and create your account."),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        AppTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'you@business.com',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          required: true,
          enableSuggestions: false,
          autocorrect: false,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(context,
            label: 'Send Verification Code', onPressed: _sendOtp),
        _backButton(context, onPressed: widget.onPrevious),
      ],
    );
  }

  Widget _otpView(BuildContext context) {
    final expired = _remaining == Duration.zero;
    return Column(
      children: [
        _hero(context, Icons.mark_email_read_rounded, AppColors.success,
            'Enter Verification Code',
            'We sent a 6-digit code to ${_maskEmail(_submittedEmail)}.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        AppTextField(
          controller: _otpController,
          label: 'Verification Code',
          hint: '6-digit code',
          icon: Icons.lock_clock_rounded,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enableSuggestions: false,
          autocorrect: false,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text(
          expired ? 'Code expired' : 'Code expires in $_remainingLabel',
          style: TextStyle(
            fontSize: AppResponsive.smallFontSize(context),
            color: expired ? AppColors.danger : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(context, label: 'Verify', onPressed: _verifyOtp),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        TextButton(
          onPressed: (_loading || _resendCooldownSeconds > 0) ? null : _resendOtp,
          child: Text(
            _resendCooldownSeconds > 0
                ? "Resend code in ${_resendCooldownSeconds}s"
                : "Didn't get it? Resend code",
            style: TextStyle(
              fontSize: AppResponsive.smallFontSize(context),
              color: (_loading || _resendCooldownSeconds > 0)
                  ? AppColors.textSecondary
                  : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _backButton(context,
            onPressed: () => setState(() {
                  _ticker?.cancel();
                  _errorMsg = null;
                  _phase = _Phase.email;
                })),
      ],
    );
  }

  Widget _enterKeyView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.vpn_key_rounded, AppColors.primary,
            'Enter Your License Key',
            'Email verified. We emailed your license key to ${_maskEmail(_submittedEmail)} — paste it below to continue.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        AppTextField(
          controller: _keyController,
          label: 'License Key',
          hint: 'Paste your license key',
          icon: Icons.vpn_key_rounded,
          required: true,
          // Keys are alphanumeric (e.g. UNIPOS-12345678901234) — force the full
          // text keyboard so it never falls back to digits-only.
          keyboardType: TextInputType.text,
          enableSuggestions: false,
          autocorrect: false,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(context, label: 'Continue', onPressed: _submitKey),
        _backButton(context,
            onPressed: () => setState(() {
                  _errorMsg = null;
                  _phase = _Phase.otp;
                  _startTicker();
                })),
      ],
    );
  }

  // ── Shared UI ──────────────────────────────────────────────────────────────
  Widget _hero(BuildContext context, IconData icon, Color color, String title,
      String subtitle) {
    final iconSize = AppResponsive.getValue(context,
        mobile: 40.0, tablet: 48.0, desktop: 56.0);
    final containerSize = AppResponsive.getValue(context,
        mobile: 80.0, tablet: 96.0, desktop: 110.0);
    return Column(
      children: [
        Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppResponsive.getValue(context,
                  mobile: 20.0, tablet: 24.0, desktop: 28.0),
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            )),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppResponsive.bodyFontSize(context),
                color: Colors.grey[600])),
      ],
    );
  }

  Widget _primaryButton(BuildContext context,
      {required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: AppResponsive.buttonHeight(context),
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppResponsive.buttonFontSize(context),
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }

  Widget _backButton(BuildContext context, {required VoidCallback onPressed}) {
    return Padding(
      padding: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
      child: TextButton(
        onPressed: _loading ? null : onPressed,
        child: Text('Back',
            style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: Colors.grey[600])),
      ),
    );
  }

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(msg,
            style: const TextStyle(fontSize: 12, color: AppColors.danger)),
      ),
    );
  }
}
