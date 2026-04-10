import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/dashboard.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/common/app_responsive.dart';
import '../../../../util/restaurant/restaurant_auth_helper.dart';
import '../../../../util/restaurant/restaurant_session.dart';
import '../../../../core/di/service_locator.dart';
import '../welcome_Admin.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _failedAttempts = 0;

  static const String _passwordKey = 'restaurant_admin_password';
  static const String _defaultPassword = '123456';
  static const String _isLoggedInKey = 'restaurant_is_logged_in';
  static const int _maxAttempts = 5;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_failedAttempts >= _maxAttempts) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_passwordKey)
          ?? RestaurantAuthHelper.hashPassword(_defaultPassword);
      final entered = _passwordController.text.trim();

      if (RestaurantAuthHelper.verifyPassword(entered, storedHash)) {
        _failedAttempts = 0;
        await prefs.setBool(_isLoggedInKey, true);
        await RestaurantSession.saveAdminSession();
        try { await attendanceStore.clockIn(staffName: 'Admin', staffRole: 'Admin'); } catch (_) {}
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminWelcome()),
          );
        }
      } else {
        _failedAttempts++;
        final remaining = _maxAttempts - _failedAttempts;
        setState(() {
          _errorMessage = remaining > 0
              ? 'Incorrect PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'
              : 'Too many failed attempts. Please restart the app.';
          _isLoading = false;
        });
        _passwordController.clear();
      }
    } catch (_) {
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
    final isLocked = _failedAttempts >= _maxAttempts;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.width(context, 0.05),
            vertical: AppResponsive.height(context, 0.01),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  alignment: Alignment.bottomCenter,
                  width: AppResponsive.width(context, 0.5),
                  height: AppResponsive.height(context, 0.20),
                  child: Image.asset(AppImages.logo),
                ),

                SizedBox(height: AppResponsive.height(context, 0.02)),

                Text(
                  'Admin Login',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: AppResponsive.height(context, 0.04)),

                // Error banner
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
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade700,
                              fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.0, desktop: 15.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppResponsive.height(context, 0.02)),
                ],

                // Password label
                Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Admin PIN',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(height: AppResponsive.height(context, 0.01)),

                // PIN field
                AppTextField(
                  obscureText: _obscurePassword,
                  controller: _passwordController,
                  hint: 'Enter admin PIN',
                  icon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !isLocked,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'PIN is required';
                    if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return 'PIN must be 4–6 digits';
                    return null;
                  },
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: AppResponsive.height(context, 0.03)),

                // Login button
                CommonButton(
                  width: width,
                  height: AppResponsive.height(context, 0.065),
                  onTap: (isLocked || _isLoading) ? () {} : _handleLogin,
                  bgcolor: (isLocked || _isLoading) ? Colors.grey : AppColors.primary,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Center(
                          child: Text(
                            isLocked ? 'Locked' : 'Login',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                ),

                SizedBox(height: AppResponsive.height(context, 0.02)),

                // Back button
                CommonButton(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => Dashboard()),
                  ),
                  width: width,
                  height: height * 0.065,
                  bgcolor: Colors.white,
                  bordercolor: AppColors.primary,
                  child: Center(
                    child: Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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
}