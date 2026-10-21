import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Change PIN — same mechanism as restaurant's admin PIN (see
/// `AuthService.changePin`). Kept the class/file name to avoid touching the
/// home_screen.dart call site.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await authService.changePin(
        oldPin: _currentPinController.text.trim(),
        newPin: _newPinController.text.trim(),
        confirmPin: _confirmPinController.text.trim(),
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PIN changed successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Change PIN', centerTitle: true),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxCardWidth(context),
        child: SingleChildScrollView(
          padding: AppResponsive.padding(context),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Container(
                  padding: AppResponsive.cardPadding(context),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppResponsive.borderRadius(context),
                    ),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PIN Requirements',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: AppColors.info,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'PIN must be 4–6 digits',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.smallFontSize(context),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppResponsive.extraLargeSpacing(context)),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(
                      AppResponsive.mediumSpacing(context),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppResponsive.smallBorderRadius(context),
                      ),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: AppResponsive.iconSize(context),
                        ),
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              color: AppColors.danger,
                              fontSize: AppResponsive.bodyFontSize(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.extraLargeSpacing(context)),
                ],

                // Current PIN
                _buildPinField(
                  controller: _currentPinController,
                  label: 'Current PIN',
                  hint: 'Enter your current PIN',
                  obscure: _obscureCurrentPin,
                  onToggleVisibility: () =>
                      setState(() => _obscureCurrentPin = !_obscureCurrentPin),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Current PIN is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // New PIN
                _buildPinField(
                  controller: _newPinController,
                  label: 'New PIN',
                  hint: 'Enter your new PIN',
                  obscure: _obscureNewPin,
                  onToggleVisibility: () =>
                      setState(() => _obscureNewPin = !_obscureNewPin),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'New PIN is required';
                    }
                    if (!RegExp(r'^\d{4,6}$').hasMatch(value.trim())) {
                      return 'PIN must be 4–6 digits';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppResponsive.largeSpacing(context)),

                // Confirm New PIN
                _buildPinField(
                  controller: _confirmPinController,
                  label: 'Confirm New PIN',
                  hint: 'Confirm your new PIN',
                  obscure: _obscureConfirmPin,
                  onToggleVisibility: () =>
                      setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm your new PIN';
                    }
                    if (value.trim() != _newPinController.text.trim()) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppResponsive.extraLargeSpacing(context)),

                // Change PIN Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangePin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.divider,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Change PIN',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.subheadingFontSize(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return AppTextField(
      controller: controller,
      enabled: !_isLoading,
      label: label,
      hint: hint,
      icon: Icons.lock_outline_rounded,
      required: true,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: AppResponsive.iconSize(context),
          color: AppColors.textSecondary,
        ),
        onPressed: onToggleVisibility,
      ),
      validator: validator,
    );
  }
}
