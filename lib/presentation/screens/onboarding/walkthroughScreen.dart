import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import your utilities
import 'package:billberrylite/core/config/app_config.dart';
import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';
import '../../../util/responsive.dart';

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({Key? key}) : super(key: key);

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<WalkthroughItem> _walkthroughItems = [
    WalkthroughItem(
      title: 'All-in-One POS',
      description: AppConfig.retailEnabled
          ? 'Manage sales, billing, and products from a single unified platform designed for retail and restaurants'
          : 'Manage sales, billing, and products from a single unified platform built for your restaurant',
      icon: Icons.dashboard_customize,
      color: AppColors.primary,
      features: AppConfig.retailEnabled
          ? ['Restaurant Mode', 'Retail Mode']
          : ['Dine-In', 'Takeaway'],
    ),
    WalkthroughItem(
      title: 'Smart Product Management',
      description: 'Track stock levels in real-time, get low-stock alerts, and manage menu categories and options',
      icon: Icons.inventory_2,
      color: AppColors.secondary,
      features: ['Stock Tracking', 'Low Stock Alerts', 'Menu Customization'],
    ),
    WalkthroughItem(
      title: 'Sales & Expense Reports',
      description: 'Monitor your daily sales, track business expenses, and view shift summaries to stay on top of your business',
      icon: Icons.analytics,
      color: AppColors.accent,
      features: ['Sales Summaries', 'Expense Tracking', 'Shift Reports'],
    ),
    WalkthroughItem(
      title: 'Secure Cash & Staff',
      description: 'Log staff attendance, track shift handovers, and record cash drawer movements',
      icon: Icons.security,
      color: AppColors.orange,
      features: ['Cash In / Out', 'Staff Attendance', 'Secure PIN Login'],
    ),
  ];

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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _goToNextPage() {
    if (_currentPage < _walkthroughItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToNext();
    }
  }

  void _skipWalkthrough() {
    _navigateToNext();
  }

  void _navigateToNext() async {
    // Save preference if "Don't show again" is checked
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('skip_walkthrough', true);
    }

    if (!mounted) return;

    // Navigate to the next screen - use pushNamed to allow back navigation
    Navigator.pushNamed(context, '/userSelectionScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
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
    return Column(
      children: [
        // Skip button
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.mediumSpacing(context),
              vertical: AppResponsive.smallSpacing(context),
            ),
            child: TextButton(
              onPressed: _skipWalkthrough,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppResponsive.buttonFontSize(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Page content
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _walkthroughItems.length,
            itemBuilder: (context, index) {
              return _buildPageContent(_walkthroughItems[index], isMobile: true);
            },
          ),
        ),

        // Bottom navigation
        _buildBottomNavigation(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        // Left side - illustration
        Expanded(
          flex: 5,
          child: Container(
            color: _walkthroughItems[_currentPage].color.withOpacity(0.1),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _walkthroughItems.length,
              itemBuilder: (context, index) {
                return _buildIllustration(_walkthroughItems[index]);
              },
            ),
          ),
        ),

        // Right side - content
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _skipWalkthrough,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _buildTextContent(_walkthroughItems[_currentPage]),
                ),

                _buildBottomNavigation(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side - illustration
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _walkthroughItems[_currentPage].color.withOpacity(0.1),
                  _walkthroughItems[_currentPage].color.withOpacity(0.05),
                ],
              ),
            ),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _walkthroughItems.length,
              itemBuilder: (context, index) {
                return _buildIllustration(_walkthroughItems[index]);
              },
            ),
          ),
        ),

        // Right side - content
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                // Background decoration
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _walkthroughItems[_currentPage].color.withOpacity(0.1),
                    ),
                  ),
                ),
                Column(
                  children: [
                    // Skip button
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextButton(
                          onPressed: _skipWalkthrough,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: _walkthroughItems[_currentPage].color,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildTextContent(_walkthroughItems[_currentPage])
                    ),

                    _buildBottomNavigation(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageContent(WalkthroughItem item, {bool isMobile = false}) {
    final illustrationSize = isMobile
        ? AppResponsive.height(context, 0.17).clamp(90.0, 140.0)
        : AppResponsive.isTablet(context) ? 220.0 : 300.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.mediumSpacing(context),
            vertical: AppResponsive.smallSpacing(context),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIllustration(item, size: illustrationSize),
                SizedBox(height: AppResponsive.mediumSpacing(context)),
                _buildTextContent(item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIllustration(WalkthroughItem item, {double size = 300}) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main icon
                Icon(
                  item.icon,
                  size: size * 0.4,
                  color: item.color,
                ),

                // // Feature badges
                // ...List.generate(item.features.length, (index) {
                //   final angle = (index * 2 * 3.14159) / item.features.length;
                //   return Positioned(
                //     left: size / 2 + (size * 0.35) * (1 + angle.sign * 0.5) - 40,
                //     top: size / 2 + (size * 0.35) * (1 + angle.sign * 0.5) - 20,
                //     child: Transform.rotate(
                //       angle: angle,
                //       child: Container(
                //         padding: const EdgeInsets.symmetric(
                //           horizontal: 12,
                //           vertical: 6,
                //         ),
                //         decoration: BoxDecoration(
                //           color: item.color,
                //           borderRadius: BorderRadius.circular(20),
                //         ),
                //         child: Text(
                //           item.features[index],
                //           style: const TextStyle(
                //             color: Colors.white,
                //             fontSize: 10,
                //             fontWeight: FontWeight.w600,
                //           ),
                //         ),
                //       ),
                //     ),
                //   );
                // }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(WalkthroughItem item) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.getValue(context, mobile: 8.0, tablet: 40.0, desktop: 60.0),
          vertical: AppResponsive.smallSpacing(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.title,
              style: TextStyle(
                fontSize: AppResponsive.getValue(context, mobile: 20.0, tablet: 26.0, desktop: 32.0),
                fontWeight: FontWeight.bold,
                color: item.color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              item.description,
              style: TextStyle(
                fontSize: AppResponsive.bodyFontSize(context),
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            // Feature chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppResponsive.smallSpacing(context),
              runSpacing: AppResponsive.smallSpacing(context),
              children: item.features.map((feature) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.mediumSpacing(context),
                    vertical: AppResponsive.smallSpacing(context) - 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: AppResponsive.smallIconSize(context),
                        color: item.color,
                      ),
                      SizedBox(width: AppResponsive.smallSpacing(context) - 2),
                      Text(
                        feature,
                        style: TextStyle(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: item.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _walkthroughItems.length,
                  (index) => _buildPageIndicator(index == _currentPage),
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button (show only if not on first page)
              _currentPage > 0
                  ? TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios, size: 16,color:_walkthroughItems[_currentPage].color),
                    const SizedBox(width: 4),
                     Text('Back',style: TextStyle(color:_walkthroughItems[_currentPage].color,fontWeight:FontWeight.w600),),
                  ],
                ),
              )
                  : const SizedBox(width: 80),

              // Next/Get Started button
              ElevatedButton(
                onPressed: _goToNextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _walkthroughItems[_currentPage].color,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.getValue(context, mobile: 24.0, tablet: 30.0, desktop: 36.0),
                    vertical: AppResponsive.getValue(context, mobile: 12.0, tablet: 14.0, desktop: 15.0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _currentPage == _walkthroughItems.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppResponsive.buttonFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: AppResponsive.smallSpacing(context) - 4),
                    Icon(
                      _currentPage == _walkthroughItems.length - 1
                          ? Icons.check
                          : Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: AppResponsive.smallIconSize(context),
                    ),
                  ],
                ),
              ),
            ],
          ),


        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? _walkthroughItems[_currentPage].color
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class WalkthroughItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  WalkthroughItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}

