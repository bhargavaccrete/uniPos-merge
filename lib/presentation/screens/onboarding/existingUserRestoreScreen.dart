import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/domain/store/common/customer_store.dart';
import 'package:billberrylite/domain/store/retail/product_store.dart';
import 'package:billberrylite/domain/store/retail/sale_store.dart';
import 'package:billberrylite/domain/store/retail/supplier_store.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/screens/retail/login_screen.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import '../../../util/color.dart';
import '../../../domain/services/common/unified_backup_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/init/hive_init.dart';
import '../../../core/di/service_locator.dart';

// Retail stores

class ExistingUserRestoreScreen extends StatefulWidget {
  const ExistingUserRestoreScreen({Key? key}) : super(key: key);

  @override
  State<ExistingUserRestoreScreen> createState() =>
      _ExistingUserRestoreScreenState();
}

class _ExistingUserRestoreScreenState extends State<ExistingUserRestoreScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // License store
  final LicenseStore _licenseStore = locator<LicenseStore>();
  final _licenseKeyController = TextEditingController();
  bool _licenseLoading = false;
  String? _licenseErrorMsg;

  // State variables
  int _currentStep = 0;
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _isLoading = false;
  bool _fileValidated = false;
  Map<String, dynamic>? _fileMetadata;
  bool _isRestoring = false; // Guard to prevent duplicate restore calls

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        withData: kIsWeb, // important for web: load file bytes
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        setState(() {
          if (kIsWeb) {
            // Web: path is null, use bytes and name
            _selectedFilePath = null;
            _selectedFileBytes = file.bytes; // You can keep it in memory
            _selectedFileName = file.name;
          } else {
            // Desktop/Mobile: can use file.path
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
          }
          _fileValidated = false;
        });

        _validateFile();
      }
    } catch (e) {}
  }

  Future<void> _validateFile() async {
    if (kIsWeb) {
      // Web: validate using in-memory bytes
      final bytes = _selectedFileBytes;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid file: no data found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final fileName = _selectedFileName ?? 'backup.zip';
      setState(() {
        _fileValidated = true;
        _fileMetadata = {
          'storeName': fileName.replaceAll('.zip', ''),
          'backupDate': 'Recent',
          'dataSize': _formatFileSize(bytes.length),
          'version': '1.0',
          'recordCount': 'Backup file ready to restore',
        };
      });
      return;
    }

    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid file path'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final backupFile = File(_selectedFilePath!);

      // Basic validation - check if file exists and is a zip
      if (!await backupFile.exists()) {
        throw Exception('File does not exist');
      }

      final fileSize = await backupFile.length();
      final fileName = _selectedFileName ?? 'backup.zip';

      setState(() {
        _fileValidated = true;
        _fileMetadata = {
          'storeName': fileName.replaceAll('.zip', ''),
          'backupDate': 'Recent',
          'dataSize': _formatFileSize(fileSize),
          'version': '1.0',
          'recordCount': 'Backup file ready to restore',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fileValidated = false;
        _fileMetadata = null;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() {
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

  Future<void> _restoreData() async {
    if (kIsWeb) {
      if (_selectedFileBytes == null || _selectedFileBytes!.isEmpty) return;
    } else {
      if (_selectedFilePath == null) return;
    }

    // ✅ Guard: Prevent duplicate restore calls
    if (_isRestoring) {
      debugPrint("⚠️ Restore already in progress, ignoring duplicate call");
      return;
    }

    // Clear any previous error messages
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    setState(() {
      _isLoading = true;
      _isRestoring = true;
    });

    try {
      // Import using bytes on web, file path on mobile/desktop
      final success = kIsWeb
          ? await UnifiedBackupService.importFromBytes(
              context,
              _selectedFileBytes!,
              _selectedFileName ?? 'backup.zip',
            )
          : await UnifiedBackupService.importFromFilePath(
              context,
              _selectedFilePath!,
            );

      if (!success) {
        throw Exception('Import failed - please check the backup file format');
      }

      // Reload AppConfig to get the restored business mode
      await AppConfig.init();
      debugPrint(
        "📦 AppConfig reloaded after restore: ${AppConfig.businessMode.name}",
      );

      // Initialize business-specific Hive boxes for the restored business mode
      await HiveInit.initializeBusinessBoxes();
      debugPrint(
        "📦 Business boxes initialized for: ${AppConfig.businessMode.name}",
      );

      // Register business-specific GetIt dependencies
      await registerBusinessDependencies(AppConfig.businessMode);
      debugPrint(
        "📦 Business dependencies registered for: ${AppConfig.businessMode.name}",
      );

      // ✅ CRITICAL: Force reload stores from Hive after restore
      if (AppConfig.isRetail) {
        debugPrint("📦 Reloading retail stores from Hive...");
        await _reloadRetailStores();
      } else if (AppConfig.isRestaurant) {
        debugPrint("📦 Reloading restaurant stores from Hive...");
        // Restaurant uses direct Hive access (HiveBoxes, etc.), so no manual Store reload is needed.
        // The UI will automatically fetch fresh data from the updated boxes.
      }

      setState(() {
        _isLoading = false;
        _isRestoring = false;
      });

      // Advance to license activation step
      if (mounted) {
        _nextStep();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isRestoring = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Reload retail stores from Hive after restore
  Future<void> _reloadRetailStores() async {
    try {
      // Force reload ProductStore
      if (locator.isRegistered<ProductStore>()) {
        final productStore = locator<ProductStore>();
        await productStore.loadProducts();
        debugPrint(
          "📦 ProductStore reloaded: ${productStore.products.length} products",
        );
      }

      // Force reload SaleStore
      if (locator.isRegistered<SaleStore>()) {
        final saleStore = locator<SaleStore>();
        await saleStore.loadSales();
        debugPrint("📦 SaleStore reloaded");
      }

      // Force reload CustomerStore
      if (locator.isRegistered<CustomerStore>()) {
        final customerStore = locator<CustomerStore>();
        await customerStore.loadCustomers();
        debugPrint(
          "📦 CustomerStore reloaded: ${customerStore.customers.length} customers",
        );
      }

      // Force reload SupplierStore
      if (locator.isRegistered<SupplierStore>()) {
        final supplierStore = locator<SupplierStore>();
        await supplierStore.loadSuppliers();
        debugPrint(
          "📦 SupplierStore reloaded: ${supplierStore.suppliers.length} suppliers",
        );
      }

      debugPrint("✅ All retail stores reloaded successfully");
    } catch (e, stackTrace) {
      debugPrint("⚠️ Error reloading stores: $e");
      debugPrint("Stack trace: $stackTrace");
      // Don't throw - the data is in Hive, stores will reload on next app start
    }
  }

  Future<void> _activateLicense() async {
    final key = _licenseKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _licenseErrorMsg = 'Please enter your license key');
      return;
    }
    setState(() {
      _licenseLoading = true;
      _licenseErrorMsg = null;
    });
    // Best-effort: if a business is already configured locally, re-send its
    // type/sub-type; otherwise fall back to restaurant/other.
    final details = businessDetailsRepository.get();
    final success = await _licenseStore.activateLicense(
      key,
      businessName: details?.storeName ?? '',
      businessType: AppConfig.isRetail ? 'retail' : 'restaurant',
      businessSubtype: (AppConfig.isRetail
              ? details?.retailStoreType
              : details?.restaurantStoreType) ??
          'other',
    );
    setState(() => _licenseLoading = false);
    if (success) {
      _goToDashboard();
    } else {
      setState(
        () => _licenseErrorMsg =
            _licenseStore.errorMessage ?? 'Activation failed',
      );
    }
  }

  Future<void> _goToDashboard() async {
    if (AppConfig.isRetail) {
      // Same admin-login gate as the splash screen — a restore brings back
      // the admin credential but never the session flag (denylisted), so
      // this always requires a fresh login after restoring.
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
      return;
    }
    Navigator.pushReplacementNamed(context, '/restaurant-home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.darkNeutral),
          onPressed: () {
            if (_currentStep > 0) {
              _previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Restore Your Data',
          style: TextStyle(
            color: AppColors.darkNeutral,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        // AppResponsive (600/1024), not the legacy Responsive widget
        // (850/1100): the steps inside size themselves off AppResponsive, so a
        // different set of breakpoints out here left 600–849 showing the mobile
        // tree with tablet-sized contents.
        child: AppResponsive.isDesktop(context)
            ? _buildDesktopLayout()
            : AppResponsive.isTablet(context)
            ? _buildTabletLayout()
            : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildProgressIndicator(),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildFileUploadStep(), _buildLicenseActivationStep()],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: AppResponsive.maxFormWidth(context),
        ),
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFileUploadStep(),
                  _buildLicenseActivationStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: AppResponsive.maxFormWidth(context),
        ),
        child: Row(
          children: [
            // Side panel
            Container(
              width: 250,
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepIndicator(0, 'Select Backup', Icons.upload_file),
                  _buildStepConnector(afterStep: 0),
                  _buildStepIndicator(1, 'Activate License', Icons.key_rounded),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(40),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildFileUploadStep(),
                    _buildLicenseActivationStep(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildProgressStep(0, 'Select File'),
          _buildProgressLine(0),
          _buildProgressStep(1, 'License'),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.darkNeutral : Colors.grey[500],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    bool isActive = _currentStep > step;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: isActive ? AppColors.primary : Colors.grey[300],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    bool isActive = _currentStep >= step;
    bool isCompleted = _currentStep > step;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white)
                  : Icon(
                      icon,
                      color: isActive ? Colors.white : Colors.grey[600],
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isActive ? AppColors.darkNeutral : Colors.grey[500],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({int afterStep = 0}) {
    return Container(
      margin: const EdgeInsets.only(left: 25),
      width: 2,
      height: 30,
      color: _currentStep > afterStep ? AppColors.primary : Colors.grey[300],
    );
  }

  Widget _buildFileUploadStep() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload Your Backup File',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNeutral,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select the backup file from your device',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // File upload area
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFileName != null
                          ? AppColors.success
                          : Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFileName != null
                            ? Icons.check_circle
                            : Icons.cloud_upload,
                        size: 60,
                        color: _selectedFileName != null
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _selectedFileName ?? 'Click to browse files',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedFileName != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedFileName != null
                              ? AppColors.darkNeutral
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Supported formats: .zip, .json',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),

              // File metadata
              if (_fileValidated && _fileMetadata != null) ...[
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkNeutral,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildDetailRow('Store:', _fileMetadata!['storeName']),
                      _buildDetailRow(
                        'Backup Date:',
                        _fileMetadata!['backupDate'],
                      ),
                      _buildDetailRow('Size:', _fileMetadata!['dataSize']),
                      _buildDetailRow('Version:', _fileMetadata!['version']),
                      _buildDetailRow(
                        'Records:',
                        _fileMetadata!['recordCount'],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Action buttons
              Row(
                children: [
                  if (_selectedFileName != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFileName = null;
                            _selectedFilePath = null;
                            _fileValidated = false;
                            _fileMetadata = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Remove File',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (_selectedFileName != null) const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      // Continue now performs the restore directly (the separate
                      // Confirm step was removed); the password prompt is the
                      // safety gate before this destructive action runs.
                      onPressed:
                          (_fileValidated && !_isLoading && !_isRestoring)
                          ? _restoreData
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: (_isLoading || _isRestoring)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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

  Widget _buildLicenseActivationStep() {
    final alreadyActive = _licenseStore.licenseInfo?.isActive == true;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Data restored successfully!',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                alreadyActive
                    ? 'License Already Active'
                    : 'Activate Your License',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNeutral,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                alreadyActive
                    ? 'This device already has an active license.'
                    : 'Your backup is restored. Enter your license key to unlock the app.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),

              const SizedBox(height: 30),

              if (alreadyActive) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _licenseStore.licenseInfo!.planName.isNotEmpty
                            ? _licenseStore.licenseInfo!.planName
                            : 'Licensed',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkNeutral,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.buttonHeight(context),
                  child: ElevatedButton(
                    onPressed: _goToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Go to Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                AppTextField(
                  controller: _licenseKeyController,
                  label: 'License Key',
                  hint: 'e.g. XXXX-XXXX-XXXX-XXXX',
                  icon: Icons.vpn_key_rounded,
                  enableSuggestions: false,
                  autocorrect: false,
                ),
                if (_licenseErrorMsg != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _licenseErrorMsg!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: AppResponsive.buttonHeight(context),
                  child: ElevatedButton(
                    onPressed: _licenseLoading ? null : _activateLicense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _licenseLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Activate & Continue',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkNeutral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
