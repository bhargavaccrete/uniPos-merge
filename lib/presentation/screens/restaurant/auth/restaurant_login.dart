import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../../util/restaurant/restaurant_auth_helper.dart';
import '../../../../util/restaurant/restaurant_session.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import '../welcome_Admin.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
class RestaurantLogin extends StatefulWidget {
  const RestaurantLogin({super.key});

  @override
  State<RestaurantLogin> createState() => _RestaurantLoginState();
}

class _RestaurantLoginState extends State<RestaurantLogin> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formkey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // SharedPreferences keys
  static const String _usernameKey = 'restaurant_admin_username';
  static const String _passwordKey = 'restaurant_admin_password';
  static const String _isLoggedInKey = 'restaurant_is_logged_in';

  // Default credentials
  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = '123456';

  @override
  void initState() {
    super.initState();
    _initializeDefaultCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Initialize default credentials if not set, and migrate plaintext → hashed.
  Future<void> _initializeDefaultCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_usernameKey)) {
      await prefs.setString(_usernameKey, _defaultUsername);
    }

    if (!prefs.containsKey(_passwordKey)) {
      await prefs.setString(_passwordKey, RestaurantAuthHelper.hashPassword(_defaultPassword));
    } else {
      final stored = prefs.getString(_passwordKey)!;
      if (!RestaurantAuthHelper.isHashed(stored)) {
        await prefs.setString(_passwordKey, RestaurantAuthHelper.hashPassword(stored));
      }
    }
  }

  /// Tries admin credentials first, then staff username + PIN.
  Future<void> _handleLogin() async {
    if (!_formkey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final enteredUsername = _usernameController.text.trim();
      final enteredPassword = _passwordController.text.trim();

      // ── 1. Try admin ──────────────────────────────────────────────────────
      final storedUsername = prefs.getString(_usernameKey) ?? _defaultUsername;
      final storedPassword = prefs.getString(_passwordKey) ?? _defaultPassword;

      if (enteredUsername == storedUsername &&
          RestaurantAuthHelper.verifyPassword(enteredPassword, storedPassword)) {
        await prefs.setBool(_isLoggedInKey, true);
        await RestaurantSession.saveAdminSession();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminWelcome()),
          );
        }
        return;
      }

      // ── 2. Try staff (username + PIN) ─────────────────────────────────────
      await staffStore.loadStaff();
      final match = staffStore.staff.where(
        (s) => s.isActive &&
            s.userName.trim() == enteredUsername &&
            RestaurantAuthHelper.verifyPassword(enteredPassword, s.pinNo.trim()),
      ).firstOrNull;

      if (match != null) {
        await prefs.setBool(_isLoggedInKey, true);
        await RestaurantSession.saveStaffSession(match);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminWelcome()),
          );
        }
        return;
      }

      // ── 3. Both failed ────────────────────────────────────────────────────
      setState(() {
        _errorMessage = 'Invalid username or password';
        _isLoading = false;
      });
    } catch (e) {
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
              key: _formkey,
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
                    'Restaurant',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 24.0, tablet: 26.4, desktop: 28.8),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.01)),

                  Text(
                    'Login to Continue',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
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
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.red.shade700,
                                fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.4, desktop: 16.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppResponsive.height(context, 0.02)),
                  ],

                  // Username Label
                  Container(
                    width: width,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Username',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.01)),

                  // Username Field
                  SizedBox(
                    width: width,
                    child: CommonTextForm(
                      obsecureText: false,
                      controller: _usernameController,
                      hintText: 'Enter username',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter username';
                        }
                        return null;
                      },
                      gesture: const Icon(Icons.person_outline),
                    ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.02)),

                  // Password Label
                  Container(
                    width: width,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.01)),

                  // Password Field
                  SizedBox(
                    width: width,
                    child: CommonTextForm(
                      obsecureText: _obscurePassword,
                      controller: _passwordController,
                      hintText: 'Enter password',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'PIN is required';
                        if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return 'PIN must be 4–6 digits';
                        return null;
                      },
                      gesture: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
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
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Center(
                            child: Text(
                              'Login',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),

                  SizedBox(height: AppResponsive.height(context, 0.03)),

                  // Default Credentials Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              text: 'Admin default: ',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.3, desktop: 15.6),
                                color: Colors.blue.shade700,
                              ),
                              children: [
                                TextSpan(
                                  text: 'admin / 123456',
                                  style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.getValue(context, mobile: 13.0, tablet: 14.3, desktop: 15.6),
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}