import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// DEMO / MOCK SCREEN — "License via Email" (Model A)
///
/// Purpose: visually walk through the email-based license-key flow so it can
/// be shown to the backend team. NOTHING here calls the server — every step
/// is driven by local state with a simulated delay. The real onboarding/
/// licensing flow (license_activation_step.dart, setup wizard) is untouched.
///
/// Flow (Model A — "email then enter"):
///   1. requestForm → user enters email, taps "Email Me My Key"
///   2. emailSent   → server (one day) generates a key and emails it
///   3. enterKey    → user types the key they received by email
///   4. activated   → key validated/activated, app unlocked
///
/// When the backend endpoint exists, going live is a small, separate change:
/// replace the simulated delays with LicenseStore calls (validateKey/activate
/// already exist; only the new "request" endpoint must be added server-side).
/// See the "For backend — proposed API" panel at the bottom of the screen.
/// ─────────────────────────────────────────────────────────────────────────

enum _Phase { requestForm, emailSent, enterKey, activated }

class LicenseEmailFlowDemoScreen extends StatefulWidget {
  const LicenseEmailFlowDemoScreen({super.key});

  @override
  State<LicenseEmailFlowDemoScreen> createState() =>
      _LicenseEmailFlowDemoScreenState();
}

class _LicenseEmailFlowDemoScreenState
    extends State<LicenseEmailFlowDemoScreen> {
  final _emailController = TextEditingController();
  final _businessController = TextEditingController();
  final _keyController = TextEditingController();

  _Phase _phase = _Phase.requestForm;
  bool _loading = false;
  String? _errorMsg;
  String _submittedEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _businessController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  // ── Email masking helper ──────────────────────────────────────────────────
  // Masks the local part of an email for display so the full address isn't
  // echoed back, e.g. "office@store.com" → "o••••@store.com". Keeps the first
  // character + the domain visible; degrades gracefully on edge cases.
  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email; // no "@" or empty local part → nothing to mask
    final local = email.substring(0, at);
    final domain = email.substring(at); // includes the "@"
    return '${local[0]}••••$domain';
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  // ── Phase 1: simulate "request key by email" ──────────────────────────────
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

    // SIMULATED server round-trip (no network call). The real backend would
    // generate a unique key, store it bound to this email, and email it.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _submittedEmail = email;
      _phase = _Phase.emailSent;
    });
  }

  // ── Phase 3: simulate activating the emailed key ──────────────────────────
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

    // SIMULATED. Live version reuses the EXISTING LicenseStore flow:
    //   validateKey(key) → activateLicense(key, businessName: ...)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _phase = _Phase.activated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'License via Email — Demo'),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: AppResponsive.screenPadding(context),
              child: Column(
                children: [
                  // A small "DEMO" banner so it's never mistaken for the real flow.
                  _demoBanner(context),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _phaseContent(context),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _backendSpecPanel(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Per-phase content ─────────────────────────────────────────────────────
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
            'Enter your email and we\'ll send your license key to your inbox.'),
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
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        AppTextField(
          controller: _businessController,
          label: 'Business Name (optional)',
          hint: 'My Restaurant',
          icon: Icons.storefront_rounded,
        ),
        if (_errorMsg != null) _errorText(_errorMsg!),
        SizedBox(height: AppResponsive.mediumSpacing(context)),
        _primaryButton(
          context,
          label: 'Email Me My Key',
          onPressed: _requestKey,
        ),
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
        _infoCard(
          context,
          color: AppColors.success,
          rows: [
            _summaryRow(Icons.email_rounded, 'Sent to',
                _maskEmail(_submittedEmail), AppColors.success),
            _summaryRow(Icons.schedule_rounded, 'Status',
                'Key on its way', AppColors.info),
          ],
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _primaryButton(
          context,
          label: 'I\'ve Got My Key  →',
          onPressed: () => setState(() {
            _errorMsg = null;
            _phase = _Phase.enterKey;
          }),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        TextButton(
          onPressed: _loading ? null : _requestKey,
          child: Text(
            'Didn\'t get it? Resend',
            style: TextStyle(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        _primaryButton(
          context,
          label: 'Activate',
          onPressed: _activateKey,
        ),
      ],
    );
  }

  Widget _activatedView(BuildContext context) {
    return Column(
      children: [
        _hero(context, Icons.verified_rounded, AppColors.success,
            'License Activated',
            'This device is licensed and ready to use.'),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _infoCard(
          context,
          color: AppColors.success,
          rows: [
            _summaryRow(Icons.verified_rounded, 'Status', 'Active',
                AppColors.success),
            _summaryRow(Icons.vpn_key_rounded, 'Key',
                _keyController.text.trim(), Colors.grey),
          ],
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        _primaryButton(
          context,
          label: 'Done',
          color: AppColors.success,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ── Shared building blocks (styled to match license_activation_step.dart) ──
  Widget _hero(BuildContext context, IconData icon, Color color, String title,
      String subtitle) {
    final iconSize =
        AppResponsive.getValue(context, mobile: 40.0, tablet: 48.0, desktop: 56.0);
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
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppResponsive.getValue(context,
                mobile: 20.0, tablet: 24.0, desktop: 28.0),
            fontWeight: FontWeight.bold,
            color: AppColors.darkNeutral,
          ),
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppResponsive.bodyFontSize(context),
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(BuildContext context,
      {required String label, required VoidCallback onPressed, Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: AppResponsive.buttonHeight(context),
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: AppResponsive.buttonFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
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
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkNeutral),
            ),
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

  Widget _demoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'UI demo only — no real key is generated or sent.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Collapsible spec panel for the backend team ───────────────────────────
  Widget _backendSpecPanel(BuildContext context) {
    const spec = '''
POST /api/v1/mobile/license/request
Headers:
  Content-Type: application/json
  X-Device-Key: <device key>   // same as other endpoints

Request body:
{
  "email":        "owner@store.com",
  "businessname": "My Restaurant",
  "ownername":    "Jane Doe",     // optional
  "phone":        "9876543210",   // optional
  "device":       { ...DevicePayloadService.build()... }
}

Success response:
{
  "success": 1,
  "message": "License key has been emailed to you.",
  "data": { "email": "o••••@store.com", "expiresInDays": 14 }
}

Server responsibilities:
  • generate a unique key
  • store it (status = unactivated) bound to the email + trial expiry
  • email the key to the user
  • rate-limit / dedupe (1 per email + per deviceid)
  • do NOT return the key in the response — email only (Model A)

After the user enters the emailed key, the EXISTING flow finishes it:
  validateKey(key) → activateLicense(key, businessName)''';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.code_rounded, color: AppColors.primary, size: 20),
          title: Text(
            'For backend — proposed API',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkNeutral,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                spec,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.45,
                  color: Color(0xFFD4D4E0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
