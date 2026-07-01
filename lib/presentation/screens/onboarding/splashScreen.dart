import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/util/images.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/domain/services/common/device_id_service.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';
import '../../../util/color.dart';
import '../../../util/responsive.dart';

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
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Fade animation for text
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    // Slide animation for text
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

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
        Navigator.pushReplacementNamed(context, '/retail-billing');
      } else if (AppConfig.isRestaurant) {
        LicenseStore.navigateToNextScreen(context);
      } else {
        // Setup complete but no business mode - navigate to walkthrough
        Navigator.pushReplacementNamed(context, '/walkthrough');
      }
    } else {
      final businessDetailsRepo = locator<BusinessDetailsRepository>();
      final savedDetails = businessDetailsRepo.get();
      if (savedDetails != null && (savedDetails.storeName?.isNotEmpty ?? false)) {
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
              AppColors.primary.withOpacity(0.8), // Medium blue
              AppColors.secondary.withOpacity(0.6), // Light green tint
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: FieldPatternPainter(
                  animation: _shimmerAnimation,
                ),
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
                            width: Responsive.isMobile(context) ? 180 : 220,
                            height: Responsive.isMobile(context) ? 180 : 220,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Image.asset(
                                  AppImages.logo, // Update with your actual logo path
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
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
                                  stops: [
                                    0.0,
                                    _shimmerAnimation.value,
                                    1.0,
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'Bill Berry Lite',
                                  style: TextStyle(
                                    fontSize: Responsive.isMobile(context) ? 42 : 54,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unified Point of Sale Solution',
                                style: TextStyle(
                                  fontSize: Responsive.isMobile(context) ? 16 : 19,
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
                  SizedBox(height: Responsive.isMobile(context) ? 80 : 60),
                  // Loading indicator
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: SizedBox(
                          width: Responsive.isMobile(context) ? 50 : 58,
                          height: Responsive.isMobile(context) ? 50 : 58,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.8),
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
                              AppConfig.retailEnabled ? Icons.store : Icons.restaurant,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppConfig.retailEnabled
                                  ? 'Retail • Restaurant • Services'
                                  : 'Restaurant POS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: Responsive.isMobile(context) ? 14 : 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.point_of_sale, color: Colors.white70, size: Responsive.isMobile(context) ? 20 : 22),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Empowering Businesses, Simplifying Sales',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: Responsive.isMobile(context) ? 12 : 14,
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
      ..color = Colors.white.withOpacity(0.05)
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

