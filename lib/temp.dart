import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import your utilities
import '../util/color.dart';
import '../util/responsive.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({Key? key}) : super(key: key);

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentStep = 0;
  final int _totalSteps = 7;

  // Step completion tracking
  final Map<int, bool> _stepsCompleted = {
    0: false, // Welcome
    1: false, // Business Type
    2: false, // Store Details
    3: false, // Tax Setup
    4: false, // Payment Methods
    5: false, // Staff Setup
    6: false, // Review & Complete
  };

  // Business Type Selection
  String? _selectedBusinessType;

  // Store Details Controllers
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

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
      duration: const Duration(milliseconds: 600),
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
      begin: const Offset(0.1, 0),
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
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _stepsCompleted[_currentStep] = true;
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipStep() {
    _nextStep();
  }

  void _completeSetup() {
    Navigator.pushReplacementNamed(context, '/outlet-registration');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
        // Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store,
                        size: 30,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildSidebarSteps(),
              ),
            ],
          ),
        ),

        // Main Content
        Expanded(
          child: Column(
            children: [
              _buildHeader(isDesktop: true),
              _buildProgressBar(isDesktop: true),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.symmetric(horizontal: 40),
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

  Widget _buildHeader({bool isDesktop = false}) {
    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Wizard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (_currentStep > 0)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('Exit Setup'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.darkNeutral),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({bool isDesktop = false}) {
    return Container(
      height: 4,
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 20),
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
                width: constraints.maxWidth * ((_currentStep + 1) / _totalSteps),
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

  Widget _buildSidebarSteps() {
    final steps = [
      StepInfo('Welcome', Icons.waving_hand),
      StepInfo('Business Type', Icons.business),
      StepInfo('Store Details', Icons.store),
      StepInfo('Tax Setup', Icons.receipt),
      StepInfo('Payment Methods', Icons.payment),
      StepInfo('Staff Setup', Icons.people),
      StepInfo('Review', Icons.check_circle),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final isActive = _currentStep == index;
        final isCompleted = _stepsCompleted[index] ?? false;

        return InkWell(
          onTap: isCompleted ? () {
            setState(() {
              _currentStep = index;
            });
            _pageController.jumpToPage(index);
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withOpacity(0.1) : null,
              border: Border(
                left: BorderSide(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success
                        : isActive
                        ? AppColors.primary
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Icon(
                      steps[index].icon,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  steps[index].title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? AppColors.darkNeutral : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSteps() {
    return [
      _buildWelcomeStep(),
      _buildBusinessTypeStep(),
      _buildStoreDetailsStep(),
      _buildTaxSetupStep(),
      _buildPaymentMethodsStep(),
      _buildStaffSetupStep(),
      _buildReviewStep(),
    ];
  }

  Widget _buildWelcomeStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.rocket_launch,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Welcome to UniPOS Setup',
                  style: TextStyle(
                    fontSize: Responsive.isMobile(context) ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  'Let\'s get your store up and running in just a few minutes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Features
                _buildFeatureItem(
                  Icons.timer,
                  'Quick Setup',
                  'Complete setup in under 10 minutes',
                ),
                _buildFeatureItem(
                  Icons.security,
                  'Secure & Private',
                  'Your data is encrypted and stored locally',
                ),
                _buildFeatureItem(
                  Icons.support_agent,
                  'Support Available',
                  'Get help anytime during setup',
                ),

                const SizedBox(height: 50),

                ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Let\'s Start',
                    style: TextStyle(
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
    );
  }

  Widget _buildBusinessTypeStep() {
    final businessTypes = [
      BusinessType('Retail Store', Icons.store, 'General retail and shopping'),
      BusinessType('Restaurant', Icons.restaurant, 'Food service and dining'),
      BusinessType('Services', Icons.build, 'Professional services'),
      BusinessType('Grocery', Icons.shopping_basket, 'Supermarket and grocery'),
      BusinessType('Pharmacy', Icons.medical_services, 'Medical and pharmacy'),
      BusinessType('Other', Icons.category, 'Other business types'),
    ];

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your Business Type',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNeutral,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This helps us customize UniPOS for your needs',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.2,
                ),
                itemCount: businessTypes.length,
                itemBuilder: (context, index) {
                  final type = businessTypes[index];
                  final isSelected = _selectedBusinessType == type.title;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBusinessType = type.title;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            type.icon,
                            size: 40,
                            color: isSelected ? AppColors.primary : Colors.grey[600],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            type.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.darkNeutral,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedBusinessType != null ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreDetailsStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Basic details about your store',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),

                TextFormField(
                  controller: _storeNameController,
                  decoration: InputDecoration(
                    labelText: 'Store Name*',
                    prefixIcon: Icon(Icons.store, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Store name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _ownerNameController,
                  decoration: InputDecoration(
                    labelText: 'Owner Name*',
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Owner name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number*',
                          prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email, color: AppColors.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Store Address',
                    prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _gstController,
                  decoration: InputDecoration(
                    labelText: 'GST Number (Optional)',
                    prefixIcon: Icon(Icons.receipt_long, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _nextStep();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaxSetupStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 80,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Tax Setup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Configure tax settings later in Settings',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _skipStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Skip for Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.payment,
                  size: 80,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Setup payment options later in Settings',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _skipStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Skip for Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffSetupStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.people,
                  size: 80,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 20),
                Text(
                  'Staff Setup',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add staff members later in Settings',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _skipStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      child: const Text('Skip for Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Setup Complete!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Your store is ready to use',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),

                // Summary
                Container(
                  padding: const EdgeInsets.all(20),
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
                      _buildSummaryItem('Business Type', _selectedBusinessType ?? 'Not Set'),
                      _buildSummaryItem('Store Name', _storeNameController.text),
                      _buildSummaryItem('Owner', _ownerNameController.text),
                      _buildSummaryItem('Phone', _phoneController.text),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go to Dashboard',
                    style: TextStyle(
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
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkNeutral,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkNeutral,
            ),
          ),
        ],
      ),
    );
  }
}

class StepInfo {
  final String title;
  final IconData icon;

  StepInfo(this.title, this.icon);
}

class BusinessType {
  final String title;
  final IconData icon;
  final String description;

  BusinessType(this.title, this.icon, this.description);
}