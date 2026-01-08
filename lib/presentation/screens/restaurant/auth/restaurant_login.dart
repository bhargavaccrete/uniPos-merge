import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../util/restaurant/images.dart';
import '../../../../util/restaurant/responsive_helper.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import '../welcome_Admin.dart';

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

  /// Initialize default credentials if not set
  Future<void> _initializeDefaultCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    // Set default username if not exists
    if (!prefs.containsKey(_usernameKey)) {
      await prefs.setString(_usernameKey, _defaultUsername);
    }

    // Set default password if not exists
    if (!prefs.containsKey(_passwordKey)) {
      await prefs.setString(_passwordKey, _defaultPassword);
    }
  }

  /// Validate login credentials
  Future<void> _handleLogin() async {
    if (!_formkey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUsername = prefs.getString(_usernameKey) ?? _defaultUsername;
      final storedPassword = prefs.getString(_passwordKey) ?? _defaultPassword;

      final enteredUsername = _usernameController.text.trim();
      final enteredPassword = _passwordController.text;

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (enteredUsername == storedUsername && enteredPassword == storedPassword) {
        // Login successful - Save login state
        await prefs.setBool(_isLoggedInKey, true);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminWelcome()),
          );
        }
      } else {
        // Login failed
        setState(() {
          _errorMessage = 'Invalid username or password';
          _isLoading = false;
        });
      }
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
      backgroundColor: screenBGColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: width,
            height: height * 0.95,
            padding: ResponsiveHelper.responsiveSymmetricPadding(
              context,
              horizontalPercent: 0.05,
              verticalPercent: 0.02,
            ),
            child: Form(
              key: _formkey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    alignment: Alignment.center,
                    width: ResponsiveHelper.responsiveWidth(context, 0.5),
                    height: ResponsiveHelper.responsiveHeight(context, 0.20),
                    child: Image.asset(logo),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.02)),

                  // Title
                  Text(
                    'Restaurant Admin',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveTextSize(context, 24),
                      fontWeight: FontWeight.w700,
                      color: primarycolor,
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.01)),

                  Text(
                    'Login to Continue',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.05)),

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
                                fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.02)),
                  ],

                  // Username Label
                  Container(
                    width: width,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Username',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.01)),

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

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.02)),

                  // Password Label
                  Container(
                    width: width,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.01)),

                  // Password Field
                  SizedBox(
                    width: width,
                    child: CommonTextForm(
                      obsecureText: _obscurePassword,
                      controller: _passwordController,
                      hintText: 'Enter password',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      gesture: GestureDetector(
                        onTap: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        child: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: primarycolor,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.04)),

                  // Login Button
                  CommonButton(
                    width: width,
                    height: ResponsiveHelper.responsiveHeight(context, 0.065),
                    onTap: _isLoading ? () {} : _handleLogin,
                    bgcolor: _isLoading ? Colors.grey : primarycolor,
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
                                fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),

                  SizedBox(height: ResponsiveHelper.responsiveHeight(context, 0.03)),

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
                              text: 'Default credentials: ',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.responsiveTextSize(context, 13),
                                color: Colors.blue.shade700,
                              ),
                              children: [
                                TextSpan(
                                  text: 'admin / 123456',
                                  style: GoogleFonts.poppins(
                                    fontSize: ResponsiveHelper.responsiveTextSize(context, 13),
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