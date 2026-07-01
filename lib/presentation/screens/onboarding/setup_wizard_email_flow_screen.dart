import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/stores/setup_wizard_store.dart';
import 'package:billberrylite/presentation/screens/onboarding/storeDetailsScreen.dart';
import 'package:billberrylite/presentation/screens/onboarding/taxSetupStep.dart';
import 'package:billberrylite/presentation/screens/onboarding/paymentSetupStep.dart';
import 'package:billberrylite/presentation/screens/onboarding/staffSetupStep.dart';
import 'package:billberrylite/presentation/screens/onboarding/securitySetupStep.dart';
import 'package:billberrylite/presentation/screens/onboarding/license_email_step.dart';
import 'package:billberrylite/presentation/screens/onboarding/businessTypeScreen.dart';
import 'package:billberrylite/presentation/screens/onboarding/add_product_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/setup_add_item_screen.dart';

import '../../../util/color.dart';
import '../../../util/common/app_responsive.dart';
import '../../../util/responsive.dart';
import '../../../core/config/app_config.dart';
// Reuse the original wizard's public pieces unchanged (no edits to that file):
// WelcomeStep, ReviewStep, SetupStep (metadata holder), SidebarPatternPainter.
import 'setupWizardScreen.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// DEMO / MOCK — Email-flow Setup Wizard (Model A automation).
///
/// A standalone COPY of SetupWizardScreen with identical styling, used to show
/// the email-based licensing flow end-to-end. The ONLY structural change vs.
/// the real wizard is an extra "License" step (email request → enter key)
/// inserted right after Store Details, so the captured email auto-prefills.
///
/// The real SetupWizardScreen and its routing are left completely untouched.
/// To stay non-destructive this demo:
///   • tracks its OWN step index locally (never mutates store.currentStep), and
///   • on finish just returns to the previous screen (no completeSetup / no
///     session changes).
/// ─────────────────────────────────────────────────────────────────────────
class SetupWizardEmailFlowScreen extends StatefulWidget {
  const SetupWizardEmailFlowScreen({super.key});

  @override
  State<SetupWizardEmailFlowScreen> createState() =>
      _SetupWizardEmailFlowScreenState();
}

class _SetupWizardEmailFlowScreenState extends State<SetupWizardEmailFlowScreen>
    with TickerProviderStateMixin {
  final SetupWizardStore _store = locator<SetupWizardStore>();
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Local step index — isolated from the real wizard's store.currentStep.
  int _currentStep = 0;

  // Demo step metadata: the real steps + a License step after Store Details.
  static final List<SetupStep> _demoSteps = [
    const SetupStep(
        title: 'Welcome',
        icon: Icons.waving_hand,
        description: "Let's get your store up and running",
        estimatedTime: '30s'),
    const SetupStep(
        title: 'Business Type',
        icon: Icons.business,
        description: 'Choose the type that best describes your business',
        estimatedTime: '1 min'),
    const SetupStep(
        title: 'Store Details',
        icon: Icons.store,
        description: 'Basic details about your store',
        estimatedTime: '2 min'),
    const SetupStep(
        title: 'License',
        icon: Icons.mark_email_read_rounded,
        description: 'Get your license key by email',
        estimatedTime: '1 min'),
    const SetupStep(
        title: 'Tax Setup',
        icon: Icons.receipt,
        description: 'Configure tax settings for your region',
        estimatedTime: '1 min'),
    const SetupStep(
        title: 'Product Setup',
        icon: Icons.production_quantity_limits_outlined,
        description: 'Add your products and categories',
        estimatedTime: '3 min'),
    const SetupStep(
        title: 'Payment Methods',
        icon: Icons.payment,
        description: 'Setup payment acceptance methods',
        estimatedTime: '1 min'),
    const SetupStep(
        title: 'Staff Setup',
        icon: Icons.people,
        description: 'Add staff members and permissions',
        estimatedTime: '1 min'),
    const SetupStep(
        title: 'Security',
        icon: Icons.security_rounded,
        description: 'Set your admin PIN and backup password',
        estimatedTime: '1 min'),
    const SetupStep(
        title: 'Review',
        icon: Icons.check_circle,
        description: 'Review your configuration',
        estimatedTime: '30s'),
  ];

  int get _totalSteps => _demoSteps.length;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0.1, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
    _store.loadExistingData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _jumpToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // Non-destructive demo finish: no completeSetup, no session change.
  void _demoComplete() {
    NotificationService.instance
        .showSuccess('Demo flow complete — nothing was saved.');
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
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
        _demoBanner(),
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
        _demoBanner(),
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
        _DemoSidebar(
          steps: _demoSteps,
          currentStep: _currentStep,
          onStepTap: _jumpToStep,
        ),
        Expanded(
          child: Column(
            children: [
              _demoBanner(),
              _buildHeader(),
              _buildProgressBar(),
              Expanded(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: AppResponsive.maxFormWidth(context)),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _buildSteps(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final currentStepInfo = _demoSteps[_currentStep];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.getValue(context,
            mobile: 8.0, tablet: 12.0, desktop: 16.0),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.darkNeutral),
                onPressed: _previousStep)
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              children: [
                Text('Setup Wizard',
                    style: TextStyle(
                        fontSize: AppResponsive.headingFontSize(context),
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNeutral)),
                Text(
                    'Step ${_currentStep + 1} of $_totalSteps · ~${currentStepInfo.estimatedTime}',
                    style: TextStyle(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: Colors.grey[600])),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.close, color: AppColors.darkNeutral),
              onPressed: () => Navigator.maybePop(context)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 5,
      margin:
          EdgeInsets.symmetric(horizontal: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
          color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: constraints.maxWidth *
                  ((_currentStep + 1) / _totalSteps),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(AppResponsive.mediumSpacing(context),
          AppResponsive.smallSpacing(context), AppResponsive.mediumSpacing(context), 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo flow — email licensing preview. Nothing is saved on finish.',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps() {
    Widget anim(Widget child) => SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(opacity: _fadeAnimation, child: child),
        );

    return [
      // 0 Welcome
      anim(WelcomeStep(onNext: _nextStep)),
      // 1 Business Type
      anim(BusinessTypeStep(
          store: _store, onNext: _nextStep, onPrevious: _previousStep)),
      // 2 Store Details (captures email)
      anim(StoreDetailsStep(
          store: _store, onNext: _nextStep, onPrevious: _previousStep)),
      // 3 License via Email — the automation step (prefills the captured email)
      anim(LicenseEmailStep(
          store: _store, onNext: _nextStep, onPrevious: _previousStep)),
      // 4 Tax Setup
      anim(TaxSetupStep(
          store: _store, onNext: _nextStep, onPrevious: _previousStep)),
      // 5 Product Setup (restaurant or retail)
      anim(Observer(
        builder: (_) => AppConfig.isRestaurant
            ? SetupAddItemScreen(onNext: _nextStep, onPrevious: _previousStep)
            : AddProductScreen(onNext: _nextStep, onPrevious: _previousStep),
      )),
      // 6 Payment Methods
      anim(PaymentSetupStep(onNext: _nextStep, onPrevious: _previousStep)),
      // 7 Staff Setup
      anim(StaffSetupStep(
          store: _store, onNext: _nextStep, onPrevious: _previousStep)),
      // 8 Security
      anim(SecuritySetupStep(
          store: _store, onNext: _nextStep, onPrevious: _previousStep)),
      // 9 Review
      anim(Observer(
        builder: (_) => ReviewStep(
          storeName: _store.storeName,
          ownerName: _store.ownerName,
          phone: _store.phone,
          onComplete: _demoComplete,
        ),
      )),
    ];
  }
}

/// Demo-only sidebar — a copy of SetupSidebar parameterized by [steps] so it
/// reflects the extra License step (the original reads a fixed step list).
/// Reuses [SidebarPatternPainter] from setupWizardScreen.dart.
class _DemoSidebar extends StatelessWidget {
  final List<SetupStep> steps;
  final int currentStep;
  final Function(int) onStepTap;

  const _DemoSidebar({
    required this.steps,
    required this.currentStep,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalSteps = steps.length;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withValues(alpha: 0.95), AppColors.primary],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: SidebarPatternPainter())),
          Column(
            children: [
              const SizedBox(height: 30),
              Icon(Icons.store, size: 40, color: Colors.white),
              const SizedBox(height: 10),
              Text('Bill Berry Lite Setup — Demo',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('${currentStep + 1} of $totalSteps Steps',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    final isActive = currentStep == index;
                    final isCompleted = index < currentStep;
                    final isUpcoming = index > currentStep;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: isCompleted ? () => onStepTap(index) : null,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.2)
                                : isCompleted
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.transparent,
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
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCompleted
                                        ? AppColors.success
                                        : isActive
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          color: AppColors.success, size: 18)
                                      : Icon(step.icon,
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.7),
                                          size: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(step.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.white.withValues(
                                              alpha: isUpcoming ? 0.5 : 0.8),
                                    )),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
