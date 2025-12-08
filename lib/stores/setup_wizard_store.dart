import 'package:mobx/mobx.dart';
import 'package:unipos/data/models/common/business_type.dart';
import 'package:unipos/data/models/common/business_details.dart';
import 'package:unipos/models/tax_details.dart';
import 'package:unipos/data/repositories/business_type_repository.dart';
import 'package:unipos/data/repositories/business_details_repository.dart';
import 'package:unipos/data/repositories/tax_details_repository.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/core/di/service_locator.dart' as sl;

part 'setup_wizard_store.g.dart';

class SetupWizardStore = _SetupWizardStore with _$SetupWizardStore;

abstract class _SetupWizardStore with Store {
  final BusinessTypeRepository _businessTypeRepo;
  final BusinessDetailsRepository _businessDetailsRepo;
  final TaxDetailsRepository _taxDetailsRepo;

  _SetupWizardStore({
    required BusinessTypeRepository businessTypeRepo,
    required BusinessDetailsRepository businessDetailsRepo,
    required TaxDetailsRepository taxDetailsRepo,
  })  : _businessTypeRepo = businessTypeRepo,
        _businessDetailsRepo = businessDetailsRepo,
        _taxDetailsRepo = taxDetailsRepo;

  // ==================== OBSERVABLE STATE ====================

  @observable
  int currentStep = 0;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  // Business Type
  @observable
  String? selectedBusinessTypeId;

  @observable
  String? selectedBusinessTypeName;

  // Store Details
  @observable
  String storeName = '';

  @observable
  String ownerName = '';

  @observable
  String phone = '';

  @observable
  String email = '';

  @observable
  String address = '';

  @observable
  String gstin = '';

  @observable
  String pan = '';

  @observable
  String city = '';

  @observable
  String state = '';

  @observable
  String country = '';

  @observable
  String pincode = '';

  @observable
  bool isSetupComplete = false;


  /*-----------------  TAX DETAILS ---------------*///

  @observable
  bool taxEnabled = true;

  @observable
  bool taxInclusive = true;

  @observable
  double taxRate = 0.0;

  @observable
  String taxName = 'GST';

  @observable
  String? taxPlaceOfSupply;

  @observable
  bool taxApplyOnDelivery = false;

  @observable
  String? taxNotes;

  @observable
  List<dynamic>? taxRates; // List to store TaxItem objects from UI

  // ==================== COMPUTED ====================

  @computed
  bool get hasBusinessType => selectedBusinessTypeId != null;

  @computed
  bool get hasStoreDetails => storeName.isNotEmpty && ownerName.isNotEmpty && phone.isNotEmpty;

  @computed
  bool get canProceedFromBusinessType => hasBusinessType;

  @computed
  bool get canProceedFromStoreDetails => hasStoreDetails;

  @computed
  double get progressPercentage => (currentStep + 1) / 8;

  /// Check if business type selection is locked (after setup completion)
  /// Once locked, user cannot change the business type
  @computed
  bool get isBusinessTypeLocked => AppConfig.isBusinessModeSet;

  // Default business types list
  @computed
  List<Map<String, String>> get businessTypes => [
        {'id': 'retail', 'name': 'Retail Store', 'description': 'General retail and shopping', 'icon': 'store'},
        {'id': 'restaurant', 'name': 'Restaurant', 'description': 'Food service and dining', 'icon': 'restaurant'},
        {'id': 'services', 'name': 'Services', 'description': 'Professional services', 'icon': 'build'},
        {'id': 'grocery', 'name': 'Grocery', 'description': 'Supermarket and grocery', 'icon': 'shopping_basket'},
        {'id': 'pharmacy', 'name': 'Pharmacy', 'description': 'Medical and pharmacy', 'icon': 'medical_services'},
        {'id': 'other', 'name': 'Other', 'description': 'Other business types', 'icon': 'category'},
      ];

  // ==================== ACTIONS ====================

  @action
  void setCurrentStep(int step) {
    currentStep = step;
  }

  @action
  void nextStep() {
    if (currentStep < 7) {
      currentStep++;
    }
  }

  @action
  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
    }
  }

  @action
  Future<void> selectBusinessType(String id, String name) async {
    selectedBusinessTypeId = id;
    selectedBusinessTypeName = name;

    // Determine the business mode based on selection
    final mode = id == 'restaurant'
        ? BusinessMode.restaurant
        : BusinessMode.retail;

    // ignore: avoid_print
    print('selectBusinessType: id=$id, mode=$mode, isSetupComplete=${AppConfig.isSetupComplete}');

    // During setup wizard (before setup is complete), use forceSetBusinessMode
    // to allow user to change their mind. The mode is only permanently locked
    // when completeSetup() is called.
    if (!AppConfig.isSetupComplete) {
      try {
        // Use forceSetBusinessMode during setup to allow changing selection
        await AppConfig.forceSetBusinessMode(mode);
        // ignore: avoid_print
        print('selectBusinessType: AppConfig.forceSetBusinessMode completed');
      } catch (e) {
        // ignore: avoid_print
        print('selectBusinessType: AppConfig.forceSetBusinessMode failed: $e');
      }
    }

    // Always ensure Hive boxes and GetIt dependencies are initialized
    // This handles both first-time setup and cases where user goes back/forward
    try {
      // ignore: avoid_print
      print('selectBusinessType: initializing Hive boxes for $mode');
      // Initialize Hive boxes for the selected business mode
      // This is needed because the Add Product screen will access these boxes
      await HiveInit.initializeForMode(mode);
      // ignore: avoid_print
      print('selectBusinessType: Hive boxes initialized');

      // ignore: avoid_print
      print('selectBusinessType: registering GetIt dependencies for $mode');
      // Register GetIt dependencies for the selected business mode
      // This must be done after Hive boxes are opened
      await _registerBusinessDependencies(mode);
      // ignore: avoid_print
      print('selectBusinessType: GetIt dependencies registered');
    } catch (e) {
      // ignore: avoid_print
      print('selectBusinessType initialization error: $e');
    }
  }

  /// Register GetIt dependencies for the selected business mode
  Future<void> _registerBusinessDependencies(BusinessMode mode) async {
    await sl.registerBusinessDependencies(mode);
  }

  @action
  void setStoreName(String value) {
    storeName = value;
  }

  @action
  void setOwnerName(String value) {
    ownerName = value;
  }

  @action
  void setPhone(String value) {
    phone = value;
  }

  @action
  void setEmail(String value) {
    email = value;
  }

  @action
  void setAddress(String value) {
    address = value;
  }

  @action
  void setGstin(String value) {
    gstin = value;
  }

  @action
  void setPan(String value) {
    pan = value;
  }

  @action
  void setCity(String value) {
    city = value;
  }

  @action
  void setState(String value) {
    state = value;
  }

  @action
  void setCountry(String value) {
    country = value;
  }

  @action
  void setPincode(String value) {
    pincode = value;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  // Tax Actions
  @action
  void setTaxEnabled(bool value) {
    taxEnabled = value;
  }

  @action
  void setTaxInclusive(bool value) {
    taxInclusive = value;
  }

  @action
  void setTaxRate(double value) {
    taxRate = value;
  }

  @action
  void setTaxName(String value) {
    taxName = value;
  }

  @action
  void setTaxPlaceOfSupply(String? value) {
    taxPlaceOfSupply = value;
  }

  @action
  void setTaxApplyOnDelivery(bool value) {
    taxApplyOnDelivery = value;
  }

  @action
  void setTaxNotes(String? value) {
    taxNotes = value;
  }

  @action
  void setTaxRates(List<dynamic> rates) {
    taxRates = rates;
  }

  // ==================== ASYNC ACTIONS ====================

  @action
  Future<void> loadExistingData() async {
    isLoading = true;
    try {
      // Check AppConfig first for locked business mode
      if (AppConfig.isBusinessModeSet) {
        // Business mode is locked - load from AppConfig
        if (AppConfig.isRestaurant) {
          selectedBusinessTypeId = 'restaurant';
          selectedBusinessTypeName = 'Restaurant';
        } else if (AppConfig.isRetail) {
          selectedBusinessTypeId = 'retail';
          selectedBusinessTypeName = 'Retail Store';
        }
        isSetupComplete = AppConfig.isSetupComplete;
      } else {
        // Load business type from Hive if exists (during setup, before completion)
        final savedType = _businessTypeRepo.getSelectedType();
        if (savedType != null) {
          selectedBusinessTypeId = savedType.id;
          selectedBusinessTypeName = savedType.name;

          // Initialize boxes and dependencies for the saved type
          // This is crucial when restoring a setup session
          final mode = savedType.id == 'restaurant' 
              ? BusinessMode.restaurant 
              : BusinessMode.retail;
          
          await HiveInit.initializeForMode(mode);
          await _registerBusinessDependencies(mode);
        }
      }

      // Load business details if exists
      final savedDetails = _businessDetailsRepo.get();
      if (savedDetails != null) {
        storeName = savedDetails.storeName ?? '';
        ownerName = savedDetails.ownerName ?? '';
        phone = savedDetails.phone ?? '';
        email = savedDetails.email ?? '';
        address = savedDetails.address ?? '';
        gstin = savedDetails.gstin ?? '';
        pan = savedDetails.pan ?? '';
        city = savedDetails.city ?? '';
        state = savedDetails.state ?? '';
        country = savedDetails.country ?? '';
        pincode = savedDetails.pincode ?? '';
        // Use AppConfig as source of truth for setup complete status
        if (!AppConfig.isBusinessModeSet) {
          isSetupComplete = savedDetails.isSetupComplete;
        }
      }

      // Load tax details if exists
      final savedTax = _taxDetailsRepo.get();
      if (savedTax != null) {
        taxEnabled = savedTax.isEnabled;
        taxInclusive = savedTax.isInclusive;
        taxRate = savedTax.defaultRate;
        taxName = savedTax.taxName;
        taxPlaceOfSupply = savedTax.placeOfSupply;
        taxApplyOnDelivery = savedTax.applyOnDelivery;
        taxNotes = savedTax.notes;
      }
    } catch (e) {
      errorMessage = 'Failed to load data: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> saveBusinessType() async {
    if (selectedBusinessTypeId == null || selectedBusinessTypeName == null) return;

    isLoading = true;
    try {
      final businessType = BusinessType(
        id: selectedBusinessTypeId,
        name: selectedBusinessTypeName,
        description: _getDescriptionForType(selectedBusinessTypeId!),
        iconName: _getIconForType(selectedBusinessTypeId!),
        isSelected: true,
      );
      await _businessTypeRepo.saveSelectedType(businessType);
    } catch (e) {
      errorMessage = 'Failed to save business type: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> saveBusinessDetails() async {
    isLoading = true;
    try {
      final details = BusinessDetails(
        businessTypeId: selectedBusinessTypeId,
        businessTypeName: selectedBusinessTypeName,
        storeName: storeName,
        ownerName: ownerName,
        phone: phone,
        email: email,
        address: address,
        gstin: gstin,
        pan: pan,
        city: city,
        state: state,
        country: country,
        pincode: pincode,
        isSetupComplete: false,
      );
      await _businessDetailsRepo.save(details);
    } catch (e) {
      errorMessage = 'Failed to save business details: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> saveTaxDetails() async {
    isLoading = true;
    try {
      print('saveTaxDetails: taxRates = $taxRates');
      print('saveTaxDetails: taxRates length = ${taxRates?.length}');

      // Convert taxRates to TaxRateItem list
      List<TaxRateItem>? rateItems;
      if (taxRates != null && taxRates!.isNotEmpty) {
        print('saveTaxDetails: Converting ${taxRates!.length} tax rates');
        rateItems = taxRates!.map((tax) {
          print('saveTaxDetails: Converting tax - name: ${tax.name}, rate: ${tax.rate}, isDefault: ${tax.isDefault}');
          // tax is a TaxItem from UI, convert to TaxRateItem for storage
          return TaxRateItem(
            name: tax.name as String,
            rate: tax.rate as double,
            isDefault: tax.isDefault as bool,
          );
        }).toList();
        print('saveTaxDetails: Converted rateItems = $rateItems');
      } else {
        print('saveTaxDetails: No tax rates to save (taxRates is null or empty)');
      }

      final details = TaxDetails(
        isEnabled: taxEnabled,
        isInclusive: taxInclusive,
        defaultRate: taxRate,
        taxName: taxName,
        placeOfSupply: taxPlaceOfSupply,
        applyOnDelivery: taxApplyOnDelivery,
        notes: taxNotes,
        taxRates: rateItems,
      );
      print('saveTaxDetails: Saving TaxDetails with ${details.taxRates?.length ?? 0} tax rates');
      await _taxDetailsRepo.save(details);
      print('saveTaxDetails: Successfully saved tax details');
    } catch (e) {
      print('saveTaxDetails: ERROR - $e');
      errorMessage = 'Failed to save tax details: $e';
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> completeSetup() async {
    isLoading = true;
    try {
      // 1. Determine business mode
      final mode = selectedBusinessTypeId == 'restaurant'
          ? BusinessMode.restaurant
          : BusinessMode.retail;

      // 2. Lock business mode in AppConfig (ONE TIME - cannot change later)
      // Only set if not already set (prevents errors on re-running setup)
      if (!AppConfig.isBusinessModeSet) {
        await AppConfig.setBusinessMode(mode);
      }

      // 3. Ensure business dependencies are registered
      // This is critical - must happen before navigating to POS screen
      await _registerBusinessDependencies(mode);

      // 4. Save business type to Hive
      await saveBusinessType();

      // 5. Save tax details
      await saveTaxDetails();

      // 6. Save business details with setup complete flag
      final details = BusinessDetails(
        businessTypeId: selectedBusinessTypeId,
        businessTypeName: selectedBusinessTypeName,
        storeName: storeName,
        ownerName: ownerName,
        phone: phone,
        email: email,
        address: address,
        gstin: gstin,
        pan: pan,
        city: city,
        state: state,
        country: country,
        pincode: pincode,
        isSetupComplete: true,
      );
      await _businessDetailsRepo.save(details);

      // 7. Mark setup complete in AppConfig
      await AppConfig.setSetupComplete(true);

      isSetupComplete = true;
    } catch (e) {
      errorMessage = 'Failed to complete setup: $e';
      rethrow; // Re-throw so the UI can handle it
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> resetSetup() async {
    isLoading = true;
    try {
      await _businessTypeRepo.clearAll();
      await _businessDetailsRepo.clearAll();
      await _taxDetailsRepo.clearAll();

      // Reset all observable values
      currentStep = 0;
      selectedBusinessTypeId = null;
      selectedBusinessTypeName = null;
      storeName = '';
      ownerName = '';
      phone = '';
      email = '';
      address = '';
      gstin = '';
      pan = '';
      city = '';
      state = '';
      country = '';
      pincode = '';
      isSetupComplete = false;

      // Reset tax observables
      taxEnabled = true;
      taxInclusive = true;
      taxRate = 0.0;
      taxName = 'GST';
      taxPlaceOfSupply = null;
      taxApplyOnDelivery = false;
      taxNotes = null;
    } catch (e) {
      errorMessage = 'Failed to reset setup: $e';
    } finally {
      isLoading = false;
    }
  }

  // ==================== HELPER METHODS ====================

  String _getDescriptionForType(String typeId) {
    final type = businessTypes.firstWhere(
      (t) => t['id'] == typeId,
      orElse: () => {'description': 'Other business types'},
    );
    return type['description'] ?? 'Other business types';
  }

  String _getIconForType(String typeId) {
    final type = businessTypes.firstWhere(
      (t) => t['id'] == typeId,
      orElse: () => {'icon': 'category'},
    );
    return type['icon'] ?? 'category';
  }
}
