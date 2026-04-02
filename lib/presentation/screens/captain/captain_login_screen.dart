import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';
import '../../widget/componets/common/app_text_field.dart';
import '../../widget/componets/restaurant/componets/Button.dart';
import 'captain_home_screen.dart';

class CaptainLoginScreen extends StatefulWidget {
  const CaptainLoginScreen({super.key});

  @override
  State<CaptainLoginScreen> createState() => _CaptainLoginScreenState();
}

class _CaptainLoginScreenState extends State<CaptainLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;
  String? _errorMessage;
  String _posIp = '';

  static const String _posIpKey = 'captain_pos_ip';
  static const String _captainLoggedInKey = 'captain_logged_in';
  static const String _captainStaffIdKey = 'captain_staff_id';
  static const String _captainStaffNameKey = 'captain_staff_name';
  static const String _captainUsernameKey = 'captain_username';

  @override
  void initState() {
    super.initState();
    _loadPosIp();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadPosIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _posIp = prefs.getString(_posIpKey) ?? '');
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('http://$_posIp:9090/captain/auth');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'pin': _pinController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_captainLoggedInKey, true);
        await prefs.setString(_captainStaffIdKey, data['staffId'] as String);
        await prefs.setString(_captainStaffNameKey, data['name'] as String);
        await prefs.setString(_captainUsernameKey, data['username'] as String);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaptainHomeScreen()),
        );
      } else {
        setState(() => _errorMessage = data['error'] as String? ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Cannot reach POS. Check WiFi connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.width(context, 0.08),
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.restaurant_menu, size: 40, color: AppColors.accent),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Captain App',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in with your staff credentials',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // POS IP indicator (read-only, no edit)
                    if (_posIp.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi, size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              'POS: $_posIp',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 36),

                    // Username
                    AppTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'Enter your username',
                      icon: Icons.person_outline_rounded,
                      required: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username is required';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // PIN
                    AppTextField(
                      controller: _pinController,
                      label: 'PIN',
                      hint: 'Enter your PIN',
                      icon: Icons.lock_outline_rounded,
                      required: true,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'PIN is required';
                        if (!RegExp(r'^\d{4,6}$').hasMatch(v.trim())) return 'PIN must be 4–6 digits';
                        return null;
                      },
                    ),

                    // Error
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Login button
                    CommonButton(
                      width: double.infinity,
                      onTap: _isLoading ? () {} : _handleLogin,
                      bgcolor: _isLoading ? Colors.grey : AppColors.accent,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Login',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}