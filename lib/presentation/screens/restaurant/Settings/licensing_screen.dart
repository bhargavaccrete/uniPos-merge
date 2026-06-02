import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/license_model.dart';
import 'package:unipos/domain/store/restaurant/company_store.dart';
import 'package:unipos/domain/store/restaurant/license_store.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';

class LicensingScreen extends StatefulWidget {
  const LicensingScreen({super.key});

  @override
  State<LicensingScreen> createState() => _LicensingScreenState();
}

class _LicensingScreenState extends State<LicensingScreen> {
  final LicenseStore _store = locator<LicenseStore>();
  final _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _store.loadCachedLicense();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _showActivateSheet({bool isReactivate = false}) {
    _keyController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivateSheet(
        controller: _keyController,
        store: _store,
        isReactivate: isReactivate,
        onSuccess: () {
          Navigator.pop(context);
          _showSnack('License activated successfully', isError: false);
        },
        onError: (msg) => _showSnack(msg, isError: true),
      ),
    );
  }

  void _confirmDeactivate() {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                    AppResponsive.dialogWidth(context)) /
                2)
            .clamp(40.0, 200.0)
        : 24.0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding:
            EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate License'),
        content: const Text(
          'This will remove the license from this device. A new license key will be required to reactivate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              _showSnack('License removed from this device', isError: false);
              await _store.deactivateLicense();
            },
            child: const Text('Deactivate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final pad = isTablet ? 24.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'License & Subscription',
        titleFontSize: isTablet ? 22 : 20,
      ),
      body: SafeArea(
        child: Observer(
          builder: (_) => SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _licenseStatusCard(isTablet),
                const SizedBox(height: 16),
                if (_store.licenseInfo?.deviceInfo != null) ...[
                  _deviceInfoCard(_store.licenseInfo!.deviceInfo!, isTablet),
                  const SizedBox(height: 16),
                ],
                _actionsCard(isTablet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _licenseStatusCard(bool isTablet) {
    final info = _store.licenseInfo;
    final status = _store.status;

    return _card(
      isTablet: isTablet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.verified_rounded, 'License Status', isTablet),
          const SizedBox(height: 16),
          Row(
            children: [
              _statusBadge(status),
              const Spacer(),
              if (info != null && info.planName.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    info.planName,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (info != null) ...[
            const SizedBox(height: 14),
            _infoRow('License Key', info.maskedKey),
            if (info.expiryDate != null)
              _infoRow(
                  'Expires', DateFormat('dd MMM yyyy').format(info.expiryDate!)),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'No license activated on this device.',
              style: TextStyle(
                  fontSize: isTablet ? 14 : 13,
                  color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deviceInfoCard(DeviceInfo device, bool isTablet) {
    return _card(
      isTablet: isTablet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.devices_rounded, 'Device Information', isTablet),
          const SizedBox(height: 16),
          _infoRow('Device ID', device.deviceId, copyable: true),
          _infoRow('Device Name', device.deviceName),
          _infoRow('Model', device.deviceModel),
          _infoRow('OS', '${device.osName} ${device.osVersion}'),
          _infoRow('App Version', device.appVersion),
        ],
      ),
    );
  }

  Widget _actionsCard(bool isTablet) {
    final hasLicense = _store.licenseInfo != null;

    return _card(
      isTablet: isTablet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.settings_outlined, 'Actions', isTablet),
          const SizedBox(height: 16),
          if (!hasLicense)
            _actionButton(
              label: 'Activate License',
              icon: Icons.key_rounded,
              color: AppColors.primary,
              onTap: () => _showActivateSheet(),
            ),
          if (kDebugMode) ...[
            _actionButton(
              label: '[DEV] Inject Valid License (30 days)',
              icon: Icons.science_rounded,
              color: Colors.teal,
              onTap: () async {
                await _store.injectMockLicense(validityDays: 30);
                _showSnack('Mock license injected', isError: false);
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            _actionButton(
              label: '[DEV] Inject Expired License',
              icon: Icons.science_rounded,
              color: Colors.orange,
              onTap: () async {
                await _store.injectExpiredLicense();
                _showSnack('Expired license injected — restart to see lock', isError: false);
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
          ],
          if (hasLicense) ...[
            _actionButton(
              label: 'Re-activate / Change Key',
              icon: Icons.refresh_rounded,
              color: AppColors.primary,
              onTap: () => _showActivateSheet(isReactivate: true),
            ),
            const SizedBox(height: 10),
            _actionButton(
              label: 'Refresh from Server',
              icon: Icons.sync_rounded,
              color: AppColors.info,
              onTap: _store.isLoading
                  ? null
                  : () async {
                      await _store.refreshLicense();
                      if (_store.errorMessage != null) {
                        _showSnack(_store.errorMessage!, isError: true);
                      } else {
                        _showSnack('License refreshed', isError: false);
                      }
                    },
            ),
            const SizedBox(height: 10),
            _actionButton(
              label: 'Deactivate on This Device',
              icon: Icons.remove_circle_outline_rounded,
              color: AppColors.danger,
              onTap: _confirmDeactivate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(LicenseStatus status) {
    Color color;
    IconData icon;
    switch (status) {
      case LicenseStatus.active:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case LicenseStatus.expired:
        color = AppColors.warning;
        icon = Icons.schedule_rounded;
        break;
      case LicenseStatus.suspended:
        color = AppColors.danger;
        icon = Icons.block_rounded;
        break;
      case LicenseStatus.notActivated:
        color = Colors.grey;
        icon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSnack('Copied to clipboard', isError: false);
              },
              child: Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader(IconData icon, String title, bool isTablet) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: isTablet ? 22 : 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: isTablet ? 15 : 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _card({required Widget child, required bool isTablet}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class _ActivateSheet extends StatefulWidget {
  final TextEditingController controller;
  final LicenseStore store;
  final bool isReactivate;
  final VoidCallback onSuccess;
  final void Function(String) onError;

  const _ActivateSheet({
    required this.controller,
    required this.store,
    required this.isReactivate,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ActivateSheet> createState() => _ActivateSheetState();
}

class _ActivateSheetState extends State<_ActivateSheet> {
  bool _loading = false;

  Future<void> _activate() async {
    final key = widget.controller.text.trim();
    if (key.isEmpty) {
      widget.onError('Please enter a license key');
      return;
    }
    setState(() => _loading = true);

    final businessName =
        locator<CompanyStore>().company?.comapanyName ?? '';
    final success = await widget.store.activateLicense(
      key,
      businessName: businessName,
    );
    setState(() => _loading = false);
    if (success) {
      widget.onSuccess();
    } else {
      widget.onError(widget.store.errorMessage ?? 'Activation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final isTablet = !AppResponsive.isMobile(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isReactivate
                ? 'Re-activate License'
                : 'Activate License',
            style: GoogleFonts.poppins(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the license key provided with your subscription.',
            style: TextStyle(
                fontSize: isTablet ? 14 : 13,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: widget.controller,
            label: 'License Key',
            hint: 'e.g. XXXX-XXXX-XXXX-XXXX',
            icon: Icons.key_rounded,
            enableSuggestions: false,
            autocorrect: false,
          ),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Activate',
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
}