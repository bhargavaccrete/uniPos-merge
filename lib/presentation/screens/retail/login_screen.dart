import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/images.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import 'home_screen.dart';

/// PIN-only login — same UI structure and layout as restaurant's login (see
/// `restaurant_login.dart`): entered PIN identifies whoever it is, admin first,
/// then staff (see `AuthService.login`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;
  String? _errorMessage;
  bool _showDefaultPinHint = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultCredentials();
  }

  Future<void> _checkDefaultCredentials() async {
    final isDefault = await authService.isUsingDefaultCredentials();
    if (mounted) setState(() => _showDefaultPinHint = isDefault);
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await authService.login(_pinController.text);

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
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
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: width,
            height: height * 0.95,
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.width(context, 0.05),
              vertical: AppResponsive.height(context, 0.02),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    alignment: Alignment.center,
                    width: AppResponsive.width(context, 0.5),
                    height: AppResponsive.height(context, 0.20),
                    child: Image.asset(AppImages.logo),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.02)),

                  // Title
                  Text(
                    'Bill Berry Lite',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(
                        context,
                        mobile: 24.0,
                        tablet: 26.4,
                        desktop: 28.8,
                      ),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.01)),

                  Text(
                    'Login to Continue',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(
                        context,
                        mobile: 16.0,
                        tablet: 17.6,
                        desktop: 19.2,
                      ),
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.05)),

                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.red.shade700,
                                fontSize: AppResponsive.getValue(
                                  context,
                                  mobile: 14.0,
                                  tablet: 15.4,
                                  desktop: 16.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppResponsive.height(context, 0.02)),
                  ],

                  // PIN Field — the only credential needed
                  AppTextField(
                    controller: _pinController,
                    autofocus: true,
                    enabled: !_isLoading,
                    label: 'PIN',
                    hint: 'Enter your PIN',
                    icon: Icons.lock_outline_rounded,
                    required: true,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _handleLogin();
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'PIN is required';
                      }
                      if (!RegExp(r'^\d{4,6}$').hasMatch(value.trim())) {
                        return 'PIN must be 4–6 digits';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.04)),

                  // Login Button
                  CommonButton(
                    width: width,
                    height: AppResponsive.height(context, 0.065),
                    onTap: _isLoading ? () {} : _handleLogin,
                    bgcolor: _isLoading ? Colors.grey : AppColors.primary,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Center(
                            child: Text(
                              'Login',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: AppResponsive.getValue(
                                  context,
                                  mobile: 18.0,
                                  tablet: 19.8,
                                  desktop: 21.6,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),

                  // Help Text — default PIN hint
                  if (_showDefaultPinHint) ...[
                    SizedBox(height: AppResponsive.height(context, 0.03)),
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Default PIN: 123456',
                              style: GoogleFonts.poppins(
                                color: AppColors.info,
                                fontSize: AppResponsive.smallFontSize(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: AppResponsive.height(context, 0.03)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
