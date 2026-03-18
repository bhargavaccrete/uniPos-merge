import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/stores/setup_wizard_store.dart';
import 'package:unipos/presentation/screens/onboarding/storeDetailsScreen.dart';
import 'package:unipos/presentation/screens/onboarding/taxSetupStep.dart';
import 'package:unipos/presentation/screens/onboarding/paymentSetupStep.dart';
import 'package:unipos/presentation/screens/onboarding/staffSetupStep.dart';

import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';
import '../../../util/responsive.dart';
import '../../../core/config/app_config.dart';
import '../restaurant/welcome_Admin.dart';
import 'businessTypeScreen.dart';
import 'add_product_screen.dart'; // Unified Add Product Screen
import '../restaurant/auth/setup_add_item_screen.dart'; // Restaurant-specific Add Item Screen

/// Setup Wizard Screen
/// UI Only - uses Observer to listen to store changes
/// Gets store from GetIt dependency injection
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({Key? key}) : super(key: key);

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> with TickerProviderStateMixin {
  // Get store from GetIt
  final SetupWizardStore _store = locator<SetupWizardStore>();

  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final int _totalSteps = SetupStep.getSteps().length;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();

    // Load existing data from Hive
    _store.loadExistingData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Dismiss keyboard before moving to next step
    FocusScope.of(context).unfocus();

    if (_store.currentStep < _totalSteps - 1) {
      _store.nextStep();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _previousStep() {
    // Dismiss keyboard before moving to previous step
    FocusScope.of(context).unfocus();

    if (_store.currentStep > 0) {
      _store.previousStep();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _jumpToStep(int step) {
    // Dismiss keyboard before jumping to step
    FocusScope.of(context).unfocus();

    _store.setCurrentStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _completeSetup() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Complete setup (this registers business dependencies)
      await _store.completeSetup();

      if (mounted) {
        // Close loading indicator
        Navigator.pop(context);

        // Navigate to appropriate screen based on business mode
        if (AppConfig.isRestaurant) {
          // Navigate to Restaurant Admin Welcome screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminWelcome()),
          );
        } else {
          // Navigate to Retail POS screen
          Navigator.pushReplacementNamed(context, '/retail-billing');
        }
      }
    } catch (e) {
      if (mounted) {
        // Close loading indicator
        Navigator.pop(context);

        // Show error
        NotificationService.instance.showError('Error completing setup: $e');
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need Help?'),
        content: const Text('Contact support for assistance with setup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    final progress = ((_store.currentStep + 1) / _totalSteps * 100).round();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.warning),
            const SizedBox(width: 12),
            const Text('Exit Setup?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your progress will be automatically saved.',
              style: TextStyle(fontSize: 15, color: AppColors.darkNeutral),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Setup Progress: $progress% complete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can resume setup anytime from where you left off.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Setup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              if (Navigator.canPop(context)) {
                Navigator.pop(context); // exit setup
              }
              NotificationService.instance.showSuccess('Progress saved ($progress% complete)');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Observer(
            builder: (_) => Responsive(
              mobile: _buildMobileLayout(),
              tablet: _buildTabletLayout(),
              desktop: _buildDesktopLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildHeader(),
        _buildProgressBar(),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: _buildSteps(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildHeader(),
        _buildProgressBar(),
        Expanded(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildSteps(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Observer(
          builder: (_) => SetupSidebar(
            currentStep: _store.currentStep,
            totalSteps: _totalSteps,
            onStepTap: _jumpToStep,
            onGetHelp: _showHelpDialog,
            onExit: _showExitDialog,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildDesktopHeader(),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _buildSteps(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    final steps = SetupStep.getSteps();
    final currentStepInfo = steps[_store.currentStep];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentStepInfo.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentStepInfo.description,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.timer, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Text(
                  'Est. ${currentStepInfo.estimatedTime}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(AppResponsive.isMobile(context) ? 14 : 20),
      child: Row(
        children: [
          if (_store.currentStep > 0)
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.darkNeutral),
              onPressed: _previousStep,
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Setup Wizard',
                  style: TextStyle(
                    fontSize: AppResponsive.headingFontSize(context),
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                Text(
                  'Step ${_store.currentStep + 1} of $_totalSteps',
                  style: TextStyle(fontSize: AppResponsive.smallFontSize(context), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.darkNeutral),
            onPressed: _showExitDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * ((_store.currentStep + 1) / _totalSteps),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSteps() {
    return [
      // Step 0: Welcome
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: WelcomeStep(onNext: _nextStep),
        ),
      ),

      // Step 1: Business Type - uses store
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: BusinessTypeStep(
            store: _store,
            onNext: _nextStep,
            onPrevious: _previousStep,
          ),
        ),
      ),

      // Step 2: Store Details - uses store
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StoreDetailsStep(
            store: _store,
            onNext: _nextStep,
            onPrevious: _previousStep,
          ),
        ),
      ),

      // Step 3: Tax Setup - uses store
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: TaxSetupStep(
            store: _store,
            onNext: _nextStep,
            onPrevious: _previousStep,
          ),
        ),
      ),

      // Step 4: Product Setup - Restaurant or Retail specific
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child:  Observer(
            builder: (_) => AppConfig.isRestaurant
                ? SetupAddItemScreen(
                    onNext: _nextStep,
                    onPrevious: _previousStep,
                  )
                : AddProductScreen(
                    onNext: _nextStep,
                    onPrevious: _previousStep,
                  ),
          ),
        ),
      ),

      // Step 5: Payment Methods
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: PaymentSetupStep(
            onNext: _nextStep,
            onPrevious: _previousStep,
          ),
        ),
      ),

      // Step 6: Staff Setup
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: StaffSetupStep(
            store: _store,
            onNext: _nextStep,
            onPrevious: _previousStep,
          ),
        ),
      ),

      // Step 7: Review - uses store
      SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Observer(
            builder: (_) => ReviewStep(
              selectedBusinessType: _store.selectedBusinessTypeName,
              storeName: _store.storeName,
              ownerName: _store.ownerName,
              phone: _store.phone,
              onComplete: _completeSetup,
            ),
          ),
        ),
      ),
    ];
  }

}

// ==================== SUPPORTING WIDGETS ====================

class SetupSidebar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Function(int) onStepTap;
  final VoidCallback onGetHelp;
  final VoidCallback onExit;

  const SetupSidebar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onStepTap,
    required this.onGetHelp,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.95), AppColors.primary],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: SidebarPatternPainter())),
          Column(
            children: [
              _buildLogoSection(),
              _buildProgressIndicator(),
              const SizedBox(height: 20),
              Expanded(child: _buildStepsList()),
              _buildBottomActions(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(child: Icon(Icons.store, size: 40, color: Colors.white)),
          ),
          const SizedBox(height: 15),
          const Text(
            'UniPOS Setup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentStep + 1} of $totalSteps Steps',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
              Text(
                '${((currentStep + 1) / totalSteps * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    final steps = SetupStep.getSteps();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isActive = currentStep == index;
        final isCompleted = index < currentStep;
        final isUpcoming = index > currentStep;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: MouseRegion(
            cursor: isCompleted ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: InkWell(
              onTap: isCompleted ? () => onStepTap(index) : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.2)
                      : isCompleted
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? Colors.white.withOpacity(0.3) : Colors.transparent,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success.withOpacity(0.2)
                            : isActive
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.success
                              : isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: AppColors.success, size: 18)
                            : Icon(
                          step.icon,
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(isUpcoming ? 0.5 : 0.8),
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: onGetHelp,
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Get Help'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onExit,
            icon: const Icon(Icons.exit_to_app, size: 18),
            label: const Text('Save & Exit'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class SetupStep {
  final String title;
  final IconData icon;
  final String description;
  final String estimatedTime;

  const SetupStep({
    required this.title,
    required this.icon,
    required this.description,
    required this.estimatedTime,
  });

  static List<SetupStep> getSteps() {
    return [
      const SetupStep(
        title: 'Welcome',
        icon: Icons.waving_hand,
        description: "Let's get your store up and running",
        estimatedTime: '30s',
      ),
      const SetupStep(
        title: 'Business Type',
        icon: Icons.business,
        description: 'Choose the type that best describes your business',
        estimatedTime: '1 min',
      ),
      const SetupStep(
        title: 'Store Details',
        icon: Icons.store,
        description: 'Basic details about your store',
        estimatedTime: '2 min',
      ),
      const SetupStep(
        title: 'Tax Setup',
        icon: Icons.receipt,
        description: 'Configure tax settings for your region',
        estimatedTime: '1 min',
      ),
      const SetupStep(
        title: 'Product Setup',
        icon: Icons.production_quantity_limits_outlined,
        description: 'Add your products and categories',
        estimatedTime: '3 min',
      ),
      const SetupStep(
        title: 'Payment Methods',
        icon: Icons.payment,
        description: 'Setup payment acceptance methods',
        estimatedTime: '1 min',
      ),
      const SetupStep(
        title: 'Staff Setup',
        icon: Icons.people,
        description: 'Add staff members and permissions',
        estimatedTime: '1 min',
      ),
      const SetupStep(
        title: 'Review',
        icon: Icons.check_circle,
        description: 'Review your configuration',
        estimatedTime: '30s',
      ),
    ];
  }
}

class SidebarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final y = size.height * (i * 0.25);
      canvas.drawCircle(Offset(size.width * 0.9, y), 40, paint);
    }

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 20; i++) {
      final offset = i * 30.0;
      canvas.drawLine(Offset(0, offset), Offset(offset, 0), linePaint);
    }

    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.9);
    wavePath.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.85,
      size.width * 0.5,
      size.height * 0.9,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.95,
      size.width,
      size.height * 0.9,
    );
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    canvas.drawPath(wavePath, Paint()..color = Colors.white.withOpacity(0.05));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== STEP WIDGETS ====================

class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsive.isMobile(context);
    final iconSize = isMobile ? 100.0 : 120.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rocket_launch, size: iconSize * 0.5, color: AppColors.primary),
            ),
            SizedBox(height: isMobile ? 20 : 30),
            Text(
              'Welcome to UniPOS Setup',
              style: TextStyle(
                fontSize: AppResponsive.getValue(context, mobile: 22.0, tablet: 26.0, desktop: 28.0),
                fontWeight: FontWeight.bold,
                color: AppColors.darkNeutral,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 10 : 15),
            Text(
              "Let's get your store up and running in just a few minutes",
              style: TextStyle(fontSize: AppResponsive.bodyFontSize(context), color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 24 : 40),
            _buildFeatureItem(context, Icons.timer, 'Quick Setup', 'Complete setup in under 10 minutes'),
            _buildFeatureItem(context, Icons.security, 'Secure & Private', 'Your data is encrypted and stored locally'),
            _buildFeatureItem(context, Icons.support_agent, 'Support Available', 'Get help anytime during setup'),
            SizedBox(height: isMobile ? 30 : 50),
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 36 : 50,
                  vertical: isMobile ? 12 : 15,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                "Let's Start",
                style: TextStyle(fontSize: AppResponsive.buttonFontSize(context), fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    final isMobile = AppResponsive.isMobile(context);
    final boxSize = isMobile ? 42.0 : 50.0;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 14 : 20),
      child: Row(
        children: [
          Container(
            width: boxSize,
            height: boxSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: AppResponsive.iconSize(context)),
          ),
          SizedBox(width: isMobile ? 12 : 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNeutral,
                  ),
                ),
                Text(description, style: TextStyle(fontSize: AppResponsive.smallFontSize(context), color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewStep extends StatelessWidget {
  final String? selectedBusinessType;
  final String storeName;
  final String ownerName;
  final String phone;
  final VoidCallback onComplete;

  const ReviewStep({
    super.key,
    this.selectedBusinessType,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = AppResponsive.isMobile(context);
    final iconSize = isMobile ? 80.0 : 100.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: iconSize * 0.6, color: AppColors.success),
            ),
            SizedBox(height: isMobile ? 20 : 30),
            Text(
              'Setup Complete!',
              style: TextStyle(
                fontSize: AppResponsive.getValue(context, mobile: 24.0, tablet: 26.0, desktop: 28.0),
                fontWeight: FontWeight.bold,
                color: AppColors.darkNeutral,
              ),
            ),
            SizedBox(height: isMobile ? 10 : 15),
            Text(
              'Your store is ready to use',
              style: TextStyle(fontSize: AppResponsive.bodyFontSize(context), color: Colors.grey[600]),
            ),
            SizedBox(height: isMobile ? 24 : 40),
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryItem(context, 'Business Type', selectedBusinessType ?? 'Not Set'),
                  _buildSummaryItem(context, 'Store Name', storeName.isEmpty ? 'Not Set' : storeName),
                  _buildSummaryItem(context, 'Owner', ownerName.isEmpty ? 'Not Set' : ownerName),
                  _buildSummaryItem(context, 'Phone', phone.isEmpty ? 'Not Set' : phone),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 24 : 40),
            ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 36 : 50,
                  vertical: isMobile ? 12 : 15,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Go to Dashboard',
                style: TextStyle(color: AppColors.white, fontSize: AppResponsive.buttonFontSize(context), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppResponsive.smallFontSize(context), color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w600,
              color: AppColors.darkNeutral,
            ),
          ),
        ],
      ),
    );
  }
}
