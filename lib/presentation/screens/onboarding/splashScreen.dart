import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/util/images.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/domain/services/common/device_id_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import 'package:billberrylite/presentation/screens/retail/login_screen.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';

// Import your color and responsive utilities
// import '../util/color.dart';
// import '../util/responsive.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _shimmerController;
  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Shimmer effect controller
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Logo scale and rotation animation
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Fade animation for text
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Slide animation for text
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Shimmer animation
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(_shimmerController);

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      _textController.forward();
    });

    // Navigate to login after delay
    _navigateToHome();
  }

  _navigateToHome() async {
    // Use minimum display time for better UX
    // Show splash for at least 2 seconds while performing any initialization
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)), // Minimum display time
      _performInitialization(), // Any additional initialization tasks
    ]);

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    // Captain runs as its own standalone app now (unipos_captain) — the POS is
    // only the server for it. No captain client here.

    // Check if setup is complete
    if (AppConfig.isSetupComplete) {
      // Setup is complete - navigate to appropriate screen based on business mode
      if (AppConfig.isRetail) {
        // Licence first, admin login second — an expired or revoked device must
        // reach the lock screen, not the till. A retail device that never
        // activated has licenseInfo == null and falls straight through, which
        // keeps the pre-licensing behaviour intact.
        final lic = locator<LicenseStore>();
        if (lic.licenseInfo != null &&
            (!lic.isLicensed || !lic.hasVerifiedManifest)) {
          if (!mounted) return;
          LicenseStore.navigateToNextScreen(context);
          return;
        }

        // Gate retail behind admin login — restores an existing session if
        // one was saved (admin_session), otherwise sends to LoginScreen.
        final loggedIn = await authService.initialize();
        if (!mounted) return;
        if (loggedIn) {
          Navigator.pushReplacementNamed(context, '/retail-billing');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else if (AppConfig.isRestaurant) {
        LicenseStore.navigateToNextScreen(context);
      } else {
        // Setup complete but no business mode - navigate to walkthrough
        Navigator.pushReplacementNamed(context, '/walkthrough');
      }
    } else {
      final businessDetailsRepo = locator<BusinessDetailsRepository>();
      final savedDetails = businessDetailsRepo.get();
      if (savedDetails != null &&
          (savedDetails.storeName?.isNotEmpty ?? false)) {
        // User already started setup wizard - resume setup wizard directly
        Navigator.pushReplacementNamed(context, RouteNames.setupWizard);
      } else {
        final skipWalkthrough = prefs.getBool('skip_walkthrough') ?? false;

        if (skipWalkthrough) {
          // User chose to skip walkthrough - go directly to user selection
          Navigator.pushReplacementNamed(context, '/userSelectionScreen');
        } else {
          // Show walkthrough to new users
          Navigator.pushReplacementNamed(context, '/walkthrough');
        }
      }
    }
  }

  // Placeholder for any initialization tasks
  Future<void> _performInitialization() async {
    // Pre-load device ID into cache so it's ready instantly everywhere
    await DeviceIdService.init();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary, // Deep blue
              AppColors.primary.withValues(alpha: 0.8), // Medium blue
              AppColors.secondary.withValues(alpha: 0.6), // Light green tint
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: FieldPatternPainter(animation: _shimmerAnimation),
              ),
            ),
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo from Assets
                  AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value,
                        child: Transform.rotate(
                          angle: (1 - _logoAnimation.value) * 2,
                          child: Container(
                            // Was a two-value `Responsive.isMobile ? 180 : 220`
                            // — that helper breaks at 850px, so a 700px tablet
                            // got the phone size while every AppResponsive call
                            // around it already reported "tablet".
                            width: AppResponsive.getValue(
                              context,
                              mobile: 180.0,
                              tablet: 200.0,
                              desktop: 220.0,
                            ),
                            height: AppResponsive.getValue(
                              context,
                              mobile: 180.0,
                              tablet: 200.0,
                              desktop: 220.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: AppResponsive.padding(context),
                                child: Image.asset(
                                  AppImages
                                      .logo, // Update with your actual logo path
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    height: AppResponsive.getValue(
                      context,
                      mobile: 40.0,
                      tablet: 44.0,
                      desktop: 48.0,
                    ),
                  ),
                  // Animated Text
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.white,
                                    AppColors.accent,
                                    Colors.white,
                                  ],
                                  stops: [0.0, _shimmerAnimation.value, 1.0],
                                ).createShader(bounds),
                                child: Text(
                                  'Bill Berry Lite',
                                  style: GoogleFonts.poppins(
                                    // Well above the font ladder's top step
                                    // (20), so a raw getValue is the sanctioned
                                    // form — but it now has a desktop value,
                                    // which the two-branch ternary never did.
                                    fontSize: AppResponsive.getValue(
                                      context,
                                      mobile: 42.0,
                                      tablet: 48.0,
                                      desktop: 54.0,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: AppResponsive.smallSpacing(context),
                              ),
                              Text(
                                'Unified Point of Sale Solution',
                                style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.subheadingFontSize(
                                    context,
                                  ),
                                  color: Colors.white70,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Deliberately INVERTED — more breathing room on a phone,
                  // less on a wide screen. Preserved through the conversion.
                  SizedBox(
                    height: AppResponsive.getValue(
                      context,
                      mobile: 80.0,
                      tablet: 70.0,
                      desktop: 60.0,
                    ),
                  ),
                  // Loading indicator
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: SizedBox(
                          width: AppResponsive.getValue(
                            context,
                            mobile: 50.0,
                            tablet: 54.0,
                            desktop: 58.0,
                          ),
                          height: AppResponsive.getValue(
                            context,
                            mobile: 50.0,
                            tablet: 54.0,
                            desktop: 58.0,
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Bottom tagline
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              AppConfig.retailEnabled
                                  ? Icons.store
                                  : Icons.restaurant,
                              color: Colors.white70,
                              size: AppResponsive.iconSize(context),
                            ),
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Text(
                              AppConfig.retailEnabled
                                  ? 'Retail • Restaurant • Services'
                                  : 'Restaurant POS',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: AppResponsive.bodyFontSize(context),
                              ),
                            ),
                            SizedBox(
                              width: AppResponsive.smallSpacing(context),
                            ),
                            Icon(
                              Icons.point_of_sale,
                              color: Colors.white70,
                              size: AppResponsive.iconSize(context),
                            ),
                          ],
                        ),
                        SizedBox(height: AppResponsive.smallSpacing(context)),
                        Text(
                          'Empowering Businesses, Simplifying Sales',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: AppResponsive.smallFontSize(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for background pattern
class FieldPatternPainter extends CustomPainter {
  final Animation<double> animation;

  FieldPatternPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw field lines pattern
    for (int i = 0; i < 20; i++) {
      final y = size.height * (i / 20);
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 20) {
        path.lineTo(x, y + math.sin(x * 0.01 + animation.value * 2) * 10);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
