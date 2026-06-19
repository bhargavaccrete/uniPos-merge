import 'package:flutter/material.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// DEMO / MOCK — License step for the email-flow setup wizard (Model A).
///
/// This is the wizard-embedded version of the standalone
/// LicenseEmailFlowDemoScreen: same four-phase flow, but rendered as a setup
/// step (no Scaffold) with onNext/onPrevious callbacks. It prefills the email
/// captured in the Store Details step from [SetupWizardStore].
///
/// Nothing here calls the server — every step is simulated. When the backend
/// "request key" endpoint exists, swap the two Future.delayed calls for real
/// LicenseStore calls (validateKey → activateLicense already exist).
/// ─────────────────────────────────────────────────────────────────────────

enum _Phase { requestForm, emailSent, enterKey, activated }

class LicenseEmailStep extends StatefulWidget {
  final SetupWizardStore store;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const LicenseEmailStep({
    super.key,
    required this.store,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<LicenseEmailStep> createState() => _LicenseEmailStepState();
}

class _LicenseEmailStepState extends State<LicenseEmailStep> {
  late final TextEditingController _emailController;
  final _keyController = TextEditingController();

  _Phase _phase = _Phase.requestForm;
  bool _loading = false;
  String? _errorMsg;
  String _submittedEmail = '';

  @override
  void initState() {
    super.initState();
    // Prefill from the email captured in the Store Details step — automation.
    _emailController = TextEditingController(text: widget.store.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  // Mask the local part of an email for display, e.g. office@store.com → o••••@store.com.
  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    return '${email[0]}••••${email.substring(at)}';
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  Future<void> _requestKey() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _errorMsg = 'Please enter a valid email address');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    // SIMULATED server round-trip — real backend generates + emails the key.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submittedEmail = email;
      _phase = _Phase.emailSent;
    });
  }

  Future<void> _activateKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMsg = 'Please enter the license key from your email');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    // SIMULATED. Live version reuses LicenseStore: validateKey → activateLicense.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _phase = _Phase.activated;
    });
  }

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
              children: [
                _phaseContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phaseContent(BuildContext context) {
    switch (_phase) {
      case _Phase.requestForm:
        return _requestFormView(context);
      case _Phase.emailSent:
        return _emailSentView(context);
      case _Phase.enterKey:
        return _enterKeyView(context);
      case _Phase.activated:
        return _activatedView(context);
    }
  }

  Widget _requestFormView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.mark_email_unread_rounded, AppColors.primary,
            'Get Your License Key',
            'We\'ll email a license key to the address below. No key needed up front.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        AppTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'you@business.com',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          enableSuggestions: false,
          autocorrect: false,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(context, label: 'Email Me My Key', onPressed: _requestKey),
        _skipButton(context),
      ],
    );
  }

  Widget _emailSentView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.mark_email_read_rounded, AppColors.success,
            'Check Your Inbox',
            'We\'ve emailed your license key. Open the email, then enter the key here.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _infoCard(context, color: AppColors.success, rows: [
          _summaryRow(Icons.email_rounded, 'Sent to',
              _maskEmail(_submittedEmail), AppColors.success),
          _summaryRow(
              Icons.schedule_rounded, 'Status', 'Key on its way', AppColors.info),
        ]),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _primaryButton(context,
            label: 'I\'ve Got My Key  →',
            onPressed: () => setState(() {
                  _errorMsg = null;
                  _phase = _Phase.enterKey;
                })),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        TextButton(
          onPressed: _loading ? null : _requestKey,
          child: Text('Didn\'t get it? Resend',
              style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _enterKeyView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.vpn_key_rounded, AppColors.primary,
            'Enter Your License Key',
            'Paste the key from the email we sent to ${_maskEmail(_submittedEmail)}.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        AppTextField(
          controller: _keyController,
          label: 'License Key',
          hint: 'e.g. XXXX-XXXX-XXXX-XXXX',
          icon: Icons.vpn_key_rounded,
          enableSuggestions: false,
          autocorrect: false,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(context, label: 'Activate', onPressed: _activateKey),
      ],
    );
  }

  Widget _activatedView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.verified_rounded, AppColors.success,
            'License Activated',
            'This device is licensed and ready. Continue setting up your store.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _infoCard(context, color: AppColors.success, rows: [
          _summaryRow(
              Icons.verified_rounded, 'Status', 'Active', AppColors.success),
          _summaryRow(Icons.vpn_key_rounded, 'Key',
              _keyController.text.trim(), Colors.grey),
        ]),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _primaryButton(context, label: 'Continue', onPressed: widget.onNext),
      ],
    );
  }

  // ── Shared building blocks (match license_activation_step.dart styling) ────
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

  // Lets the user move past licensing during setup (mirrors the real wizard's
  // "Skip for now" — the day/license can be handled later).
  Widget _skipButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppResponsive.smallSpacing(context)),
      child: TextButton(
        onPressed: _loading ? null : widget.onNext,
        child: Text('Skip for now',
            style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: Colors.grey[500])),
      ),
    );
  }

  Widget _infoCard(BuildContext context,
      {required Color color, required List<Widget> rows}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNeutral)),
          ),
        ],
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
