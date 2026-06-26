import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';

/// Redesigned Animated logo splash.
/// The Bill Berry Lite logo plays a smooth spring scale-in + tilt entrance animation,
/// followed by a continuous floating and breathing idle animation.
/// Set against a clean, premium light canvas matching the app's overall modern UI.
/// Spans full screen width and height.
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _floatController;

  late final Animation<double> _scaleIn;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _logoRotate;

  late final Animation<double> _floatAnimation;
  late final Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    
    // Entrance animation controller (one-shot)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Continuous floating and breathing controller
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Spring/elastic scale-in curve for the logo
    _scaleIn = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    // Logo fade-in duration
    _logoFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    // Entrance rotation (slight tilt correction)
    _logoRotate = Tween<double>(begin: -0.15, end: 0.0).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    ));

    // Text animations (delayed fade + slide-up)
    _textFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    // Looping idle float offset (vertical transition)
    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    // Looping idle breathe scale factor
    _breatheAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    _entranceController.forward();
  }

  void _replay() {
    _entranceController.forward(from: 0);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // ── Animated logo with float & scale breathing ──
              AnimatedBuilder(
                animation: Listenable.merge([_entranceController, _floatController]),
                builder: (context, _) {
                  // Apply float/breathe only after entrance animation is complete
                  final floatOffset = _entranceController.isCompleted
                      ? _floatAnimation.value
                      : 0.0;
                  
                  final breatheScale = _entranceController.isCompleted
                      ? _breatheAnimation.value
                      : 1.0;

                  final scale = _scaleIn.value * breatheScale;

                  return Opacity(
                    opacity: _logoFade.value,
                    child: Transform.translate(
                      offset: Offset(0, floatOffset),
                      child: Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: _logoRotate.value,
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: Image.asset(
                              'assets/images/billberrylite.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // ── Name + tagline (delayed fade & slide) ──────────────────────
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bill Berry Lite',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unified Point of Sale Solution',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Preview-only control
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: FadeTransition(
                  opacity: _textFade,
                  child: OutlinedButton.icon(
                    onPressed: _replay,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(
                      'Replay Animation',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
