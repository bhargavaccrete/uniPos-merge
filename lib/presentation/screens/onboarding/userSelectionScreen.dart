import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToSetupWizard() {
    // Licensing now happens inside the wizard's Verify Email (OTP) step, so a
    // new user goes straight to setup rather than the standalone key page.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: AppResponsive.padding(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _buildHeader(),
                  SizedBox(height: AppResponsive.extraLargeSpacing(context)),
                  _buildUserCards(isMobile: true),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  _buildFooterInfo(),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                ],
              ),
          ),
        );
      },
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: AppResponsive.maxFormWidth(context)),
        padding: AppResponsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeader(),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            _buildUserCards(isMobile: false),
            SizedBox(height: AppResponsive.largeSpacing(context)),
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
        padding: EdgeInsets.all(AppResponsive.extraLargeSpacing(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHeader(),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            _buildUserCards(isMobile: false),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final logoSize = AppResponsive.getValue(context, mobile: 80.0, tablet: 90.0, desktop: 100.0);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
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
                'assets/images/logo.png',
                width: logoSize * 0.65,
                height: logoSize * 0.65,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.store, size: logoSize * 0.5, color: AppColors.primary);
                },
              ),
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Text(
            'Welcome to UniPOS',
            style: TextStyle(
              fontSize: AppResponsive.getValue(context, mobile: 24.0, tablet: 30.0, desktop: 36.0),
              fontWeight: FontWeight.bold,
              color: AppColors.darkNeutral,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            "Choose how you'd like to start",
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              color: AppColors.darkNeutral.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCards({required bool isMobile}) {
    final useColumn = AppResponsive.isMobile(context);
    return SlideTransition(
      position: _slideUpAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: useColumn
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUserCard(
                    title: 'Create New Store',
                    subtitle: 'Start from scratch',
                    icon: Icons.add_business,
                    isHovered: _isNewUserHovered,
                    onTap: _navigateToSetupWizard,
                    onHover: (v) => setState(() => _isNewUserHovered = v),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  _buildUserCard(
                    title: 'Restore Backup',
                    subtitle: 'Continue existing',
                    icon: Icons.restore,
                    isHovered: _isExistingUserHovered,
                    onTap: _showRestoreDialog,
                    onHover: (v) => setState(() => _isExistingUserHovered = v),
                  ),
                ],
              )
            : IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildUserCard(
                      title: 'Create New Store',
                      subtitle: 'Start from scratch',
                      icon: Icons.add_business,
                      isHovered: _isNewUserHovered,
                      onTap: _navigateToSetupWizard,
                      onHover: (v) => setState(() => _isNewUserHovered = v),
                    ),
                  ),
                  SizedBox(width: AppResponsive.mediumSpacing(context)),
                  Expanded(
                    child: _buildUserCard(
                      title: 'Restore Backup',
                      subtitle: 'Continue existing',
                      icon: Icons.restore,
                      isHovered: _isExistingUserHovered,
                      onTap: _showRestoreDialog,
                      onHover: (v) => setState(() => _isExistingUserHovered = v),
                    ),
                  ),
                ],
              ),
              ),
      ),
    );
  }

  Widget _buildUserCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isHovered,
    required VoidCallback onTap,
    required Function(bool) onHover,
  }) {
    final color = AppColors.primary;
    final iconContainerSize = AppResponsive.getValue(context, mobile: 64.0, tablet: 72.0, desktop: 80.0);
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(isHovered ? 1.03 : 1.0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: AppResponsive.cardPadding(context),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
                border: Border.all(
                  color: isHovered ? color : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? color.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: isHovered ? 16 : 8,
                    spreadRadius: isHovered ? 0 : 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: iconContainerSize * 0.5, color: color),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppResponsive.subheadingFontSize(context),
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNeutral,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context) - 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: AppColors.darkNeutral.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: AppResponsive.mediumSpacing(context)),
                  Icon(Icons.arrow_forward, color: color, size: AppResponsive.iconSize(context)),
                ],
              ),
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
        padding: AppResponsive.cardPadding(context),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          border: Border.all(color: AppColors.info.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.info, size: AppResponsive.iconSize(context)),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(
              child: Text(
                'Your data is stored locally and encrypted. Always keep regular backups to prevent data loss.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppResponsive.smallFontSize(context),
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