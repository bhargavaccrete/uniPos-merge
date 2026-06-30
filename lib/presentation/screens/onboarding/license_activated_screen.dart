import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/screens/restaurant/welcome_Admin.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Handles the activate API call and shows the result before the user
/// proceeds to the dashboard.
class LicenseActivatedScreen extends StatefulWidget {
  final String businessName;
  const LicenseActivatedScreen({super.key, required this.businessName});

  @override
  State<LicenseActivatedScreen> createState() =>
      _LicenseActivatedScreenState();
}

class _LicenseActivatedScreenState extends State<LicenseActivatedScreen> {
  final LicenseStore _store = locator<LicenseStore>();
  bool _loading = true;
  bool _activated = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _activate();
  }

  Future<void> _activate() async {
    final success = await _store.activateWithPendingKey(
      businessName: widget.businessName,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _activated = success;
        _errorMsg = success ? null : (_store.errorMessage ?? 'Activation failed');
      });
    }
  }

  void _goToDashboard() {
    LicenseStore.navigateToNextScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);
    final pad = isTablet ? 48.0 : 28.0;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: isTablet ? 460 : double.infinity),
              child: _loading ? _buildLoading() : _buildResult(isTablet),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Activating your license...',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildResult(bool isTablet) {
    final info = _store.licenseInfo;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: _activated
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.danger.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _activated
                ? Icons.verified_rounded
                : Icons.error_outline_rounded,
            size: 52,
            color: _activated ? AppColors.success : AppColors.danger,
          ),
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        Text(
          _activated ? 'License Activated!' : 'Activation Failed',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        Text(
          _activated
              ? 'Your store is fully set up and ready to go.'
              : (_errorMsg ?? 'Please activate from Settings later.'),
          style: TextStyle(
            fontSize: isTablet ? 15 : 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        if (_activated && info != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                if (info.planName.isNotEmpty) ...[
                  _row(Icons.workspace_premium_rounded, 'Plan',
                      info.planName, AppColors.primary),
                  const Divider(height: 20),
                ],
                _row(
                  Icons.calendar_today_rounded,
                  'Valid for',
                  info.daysRemaining < 9999
                      ? '${info.daysRemaining} days'
                      : 'Perpetual',
                  AppColors.textPrimary,
                ),
                const Divider(height: 20),
                _row(Icons.key_rounded, 'Key', info.maskedKey,
                    AppColors.textSecondary),
              ],
            ),
          ),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),
        ],
        if (_activated) ...[
          SizedBox(
            width: double.infinity,
            height: isTablet ? 54 : 50,
            child: ElevatedButton(
              onPressed: _goToDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Start Using Bill Berry Lite',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: isTablet ? 54 : 50,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMsg = null;
                });
                _activate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor)),
      ],
    );
  }
}
