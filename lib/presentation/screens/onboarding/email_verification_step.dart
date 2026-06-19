import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/store/restaurant/license_store.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

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

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address');
      return;
    }
    widget.store.setEmail(email);
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final ok = await _license.requestSignupOtp(widget.store.buildSignupBody());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) {
        _submittedEmail = email;
        _phase = _Phase.otp;
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
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final ok = await _license.verifyOtp(_submittedEmail, otp);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) {
        _ticker?.cancel();
        _phase = _Phase.enterKey;
      } else {
        _errorMsg = _license.signupError;
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final ok = await _license.resendOtp(_submittedEmail);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) {
        _startTicker();
      } else {
        _errorMsg = _license.signupError;
      }
    });
  }

  // Temporary bypass: skip OTP send/verify and go straight to key entry.
  void _skipToKey() {
    _ticker?.cancel();
    setState(() {
      _submittedEmail = _emailController.text.trim();
      _errorMsg = null;
      _phase = _Phase.enterKey;
    });
  }

  // Temporary bypass: skip license validation/activation and continue setup.
  // Sets the persisted bypass flag so the license guard won't lock the app.
  Future<void> _skip() async {
    setState(() => _loading = true);
    await _license.skipLicense();
    if (!mounted) return;
    widget.onNext();
  }

  Future<void> _submitKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMsg = 'Please enter the license key from your email');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final valid = await _license.validateKey(key);
    if (!mounted) return;
    if (valid) {
      await _license.savePendingKey(key);
      if (!mounted) return;
      widget.onNext();
    } else {
      setState(() {
        _loading = false;
        _errorMsg = _license.errorMessage;
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
    switch (_phase) {
      case _Phase.email:
        return _emailView(context);
      case _Phase.otp:
        return _otpView(context);
      case _Phase.enterKey:
        return _enterKeyView(context);
    }
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
        SizedBox(height: AppResponsive.smallSpacing(context)),
        TextButton(
          onPressed: _loading ? null : _skipToKey,
          child: Text('Skip for now',
              style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: Colors.grey[500])),
        ),
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
          onPressed: _loading ? null : _resendOtp,
          child: Text("Didn't get it? Resend code",
              style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
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
          hint: 'e.g. UNIPOS-XXXXXXXXXXXX',
          icon: Icons.vpn_key_rounded,
          required: true,
          enableSuggestions: false,
          autocorrect: false,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(context, label: 'Continue', onPressed: _submitKey),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        TextButton(
          onPressed: _loading ? null : _skip,
          child: Text('Skip for now',
              style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: Colors.grey[500])),
        ),
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
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
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
