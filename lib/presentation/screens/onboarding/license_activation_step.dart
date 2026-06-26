import 'package:flutter/material.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/license_model.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

class LicenseActivationStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final SetupWizardStore? store;

  const LicenseActivationStep({
    super.key,
    required this.onNext,
    required this.onPrevious,
    this.store,
  });

  @override
  State<LicenseActivationStep> createState() => _LicenseActivationStepState();
}

class _LicenseActivationStepState extends State<LicenseActivationStep> {
  final LicenseStore _store = locator<LicenseStore>();
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _errorMsg;
  String? _pendingKey;

  @override
  void initState() {
    super.initState();
    _store.loadCachedLicense();
    _loadPendingKey();
  }

  Future<void> _loadPendingKey() async {
    final key = await _store.getPendingKey();
    if (mounted) setState(() => _pendingKey = key);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

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

    final businessName = widget.store?.storeName ?? '';
    final success = await _store.activateLicense(
      key,
      businessName: businessName,
    );
    setState(() => _loading = false);
    if (success) {
      widget.onNext();
    } else {
      setState(() => _errorMsg = _store.errorMessage ?? 'Activation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadyActivated = _store.licenseInfo?.isActive == true;
    final hasPendingKey =
        _pendingKey != null && _pendingKey!.trim().isNotEmpty;

    final iconSize = AppResponsive.getValue(
        context, mobile: 40.0, tablet: 48.0, desktop: 56.0);
    final containerSize = AppResponsive.getValue(
        context, mobile: 80.0, tablet: 96.0, desktop: 110.0);

    Color iconColor;
    IconData iconData;
    String title;
    String subtitle;

    if (alreadyActivated) {
      iconColor = AppColors.success;
      iconData = Icons.verified_rounded;
      title = 'License Already Active';
      subtitle = 'This device is licensed and ready to use.';
    } else if (hasPendingKey) {
      iconColor = AppColors.primary;
      iconData = Icons.schedule_rounded;
      title = 'Key Saved';
      subtitle =
          'Your license key will be activated automatically when setup completes.';
    } else {
      iconColor = AppColors.primary;
      iconData = Icons.key_rounded;
      title = 'Activate Your License';
      subtitle =
          'Enter the license key from your subscription to unlock all features.';
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: AppResponsive.screenPadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: containerSize,
                  height: containerSize,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: iconSize, color: iconColor),
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppResponsive.getValue(
                        context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppResponsive.smallSpacing(context)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),
                if (alreadyActivated) ...[
                  _activatedSummary(),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _continueButton(AppColors.success),
                ] else if (hasPendingKey) ...[
                  _pendingKeySummary(),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _continueButton(AppColors.primary),
                ] else ...[
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ],
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  SizedBox(
                    width: double.infinity,
                    height: AppResponsive.buttonHeight(context),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _activate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Activate & Continue',
                              style: TextStyle(
                                fontSize: AppResponsive.buttonFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  TextButton(
                    onPressed: widget.onNext,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: Colors.grey[500]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _continueButton(Color color) {
    return SizedBox(
      width: double.infinity,
      height: AppResponsive.buttonHeight(context),
      child: ElevatedButton(
        onPressed: widget.onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          'Continue',
          style: TextStyle(
            fontSize: AppResponsive.buttonFontSize(context),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _pendingKeySummary() {
    final key = _pendingKey!.trim();
    final segs = key.split('-');
    final masked = segs.length >= 4
        ? '${segs[0]}-••••-••••-${segs.last}'
        : key.length > 8
            ? '${key.substring(0, 4)}••••${key.substring(key.length - 4)}'
            : key;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _summaryRow(Icons.key_rounded, 'Key', masked, AppColors.primary),
          _summaryRow(Icons.schedule_rounded, 'Status',
              'Activates after setup', AppColors.info),
        ],
      ),
    );
  }

  Widget _activatedSummary() {
    final info = _store.licenseInfo!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _summaryRow(Icons.verified_rounded, 'Status', info.status.label,
              AppColors.success),
          if (info.planName.isNotEmpty)
            _summaryRow(Icons.workspace_premium_rounded, 'Plan', info.planName,
                AppColors.primary),
          _summaryRow(Icons.key_rounded, 'Key', info.maskedKey, Colors.grey),
        ],
      ),
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
}