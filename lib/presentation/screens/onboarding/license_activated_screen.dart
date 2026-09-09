import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Handles the activate API call and shows the result before the user
/// proceeds to the dashboard.
class LicenseActivatedScreen extends StatefulWidget {
  final String businessName;
  const LicenseActivatedScreen({super.key, required this.businessName});

  @override
  State<LicenseActivatedScreen> createState() => _LicenseActivatedScreenState();
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
        _errorMsg = success
            ? null
            : (_store.errorMessage ?? 'Activation failed');
      });
    }
  }

  void _goToDashboard() {
    LicenseStore.navigateToNextScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppResponsive.getValue(
      context,
      mobile: 28.0,
      tablet: 40.0,
      desktop: 48.0,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        // Scrollable: the result card runs ~470px, which overflows in landscape,
        // in a short window, and at large text scale. minHeight comes from the
        // measured box, not MediaQuery, so SafeArea insets are already excluded.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppResponsive.getValue(
                        context,
                        mobile: double.infinity,
                        tablet: 460.0,
                        desktop: 520.0,
                      ),
                    ),
                    child: _loading
                        ? _buildLoading(context)
                        : _buildResult(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        SizedBox(height: AppResponsive.extraLargeSpacing(context)),
        Text(
          'Activating your license...',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final info = _store.licenseInfo;
    final badge = AppResponsive.getValue(
      context,
      mobile: 88.0,
      tablet: 96.0,
      desktop: 108.0,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: badge,
          height: badge,
          decoration: BoxDecoration(
            color: _activated
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.danger.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _activated ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: badge * 0.54,
            color: _activated ? AppColors.success : AppColors.danger,
          ),
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        Text(
          _activated ? 'License Activated!' : 'Activation Failed',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue(
              context,
              mobile: 24.0,
              tablet: 28.0,
              desktop: 32.0,
            ),
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
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.getValue(
              context,
              mobile: 13.0,
              tablet: 15.0,
              desktop: 16.0,
            ),
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppResponsive.largeSpacing(context)),
        if (_activated && info != null) ...[
          Container(
            padding: AppResponsive.cardPadding(context),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(
                AppResponsive.borderRadius(context),
              ),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                if (info.planName.isNotEmpty) ...[
                  _row(
                    Icons.workspace_premium_rounded,
                    'Plan',
                    info.planName,
                    AppColors.primary,
                  ),
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
                _row(
                  Icons.key_rounded,
                  'Key',
                  info.maskedKey,
                  AppColors.textSecondary,
                ),
              ],
            ),
          ),
          SizedBox(height: AppResponsive.extraLargeSpacing(context)),
        ],
        if (_activated) ...[
          SizedBox(
            width: double.infinity,
            height: AppResponsive.getValue(
              context,
              mobile: 50.0,
              tablet: 54.0,
              desktop: 58.0,
            ),
            child: ElevatedButton(
              onPressed: _goToDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Using Bill Berry Lite',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.buttonFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: AppResponsive.getValue(
              context,
              mobile: 50.0,
              tablet: 54.0,
              desktop: 58.0,
            ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.buttonFontSize(context),
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
        Icon(
          icon,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ),
        // Flexible + ellipsis: a long plan name or key must shrink rather than
        // push the row past its bounds on a narrow phone.
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
