import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:file_picker/file_picker.dart'; // Add to pubspec.yaml

import '../../../util/color.dart';
import '../../../util/responsive.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({Key? key}) : super(key: key);

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideUpAnimation;
  late Animation<double> _scaleAnimation;

  bool _isNewUserHovered = false;
  bool _isExistingUserHovered = false;


  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToSetupWizard() {
    // Use pushNamed to allow back navigation
    Navigator.pushNamed(context, '/setup-wizard');
  }

  void _showRestoreDialog() {
    Navigator.pushNamed(context, '/existingUserRestoreScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Walkthrough',
        ),
      ),
      body: SafeArea(
        child: Responsive(
          mobile: _buildMobileLayout(),
          tablet: _buildTabletLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildHeader(),
            const SizedBox(height: 50),
            _buildUserOptions(isMobile: true),
            const SizedBox(height: 40),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeader(),
            const SizedBox(height: 60),
            _buildUserOptions(isMobile: false),
            const SizedBox(height: 60),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildUserOptions(isMobile: false),
            const SizedBox(height: 40),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo.png', // Your logo
                width: 70,
                height: 70,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.store,
                    size: 50,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Welcome to UniPOS',
            style: TextStyle(
              fontSize: Responsive.isMobile(context) ? 28 : 36,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Let\'s get you started',
            style: TextStyle(
              fontSize: Responsive.isMobile(context) ? 16 : 18,
              color: AppColors.darkNeutral.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserOptions({required bool isMobile}) {
    return SlideTransition(
      position: _slideUpAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: isMobile
            ? Column(
          children: [
            _buildUserCard(
              title: 'I\'m a New User',
              subtitle: 'Set up your store from scratch',
              description: 'Complete setup wizard to configure your outlet, tax, inventory, and more',
              icon: Icons.person_add,
              color: AppColors.primary,
              isHovered: _isNewUserHovered,
              onTap: _navigateToSetupWizard,
              onHover: (hover) {
                setState(() {
                  _isNewUserHovered = hover;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildUserCard(
              title: 'I\'m an Existing User',
              subtitle: 'Restore your data from backup',
              description: 'Import your backup file to continue where you left off',
              icon: Icons.restore,
              color: AppColors.secondary,
              isHovered: _isExistingUserHovered,
              onTap: _showRestoreDialog,
              onHover: (hover) {
                setState(() {
                  _isExistingUserHovered = hover;
                });
              },
            ),
          ],
        )
            : Row(
          children: [
            Expanded(
              child: _buildUserCard(
                title: 'I\'m a New User',
                subtitle: 'Set up your store from scratch',
                description: 'Complete setup wizard to configure your outlet, tax, inventory, and more',
                icon: Icons.person_add,
                color: AppColors.primary,
                isHovered: _isNewUserHovered,
                onTap: _navigateToSetupWizard,
                onHover: (hover) {
                  setState(() {
                    _isNewUserHovered = hover;
                  });
                },
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: _buildUserCard(
                title: 'I\'m an Existing User',
                subtitle: 'Restore your data from backup',
                description: 'Import your backup file to continue where you left off',
                icon: Icons.restore,
                color: AppColors.secondary,
                isHovered: _isExistingUserHovered,
                onTap: _showRestoreDialog,
                onHover: (hover) {
                  setState(() {
                    _isExistingUserHovered = hover;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required bool isHovered,
    required VoidCallback onTap,
    required Function(bool) onHover,
  }) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isHovered ? color : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHovered
                      ? color.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isHovered ? 20 : 10,
                  spreadRadius: isHovered ? 0 : 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkNeutral.withOpacity(0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.arrow_forward,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterInfo() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.info.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.info,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your data is stored locally and encrypted. Always keep regular backups to prevent data loss.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.darkNeutral.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
