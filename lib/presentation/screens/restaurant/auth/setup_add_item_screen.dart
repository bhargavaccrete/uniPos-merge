import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_db.dart';
import 'package:unipos/data/models/restaurant/db/itemmodel_302.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';
import 'package:unipos/presentation/screens/restaurant/auth/category_management_screen.dart';
import 'package:unipos/presentation/screens/restaurant/item/add_more_info_screen.dart';
import 'package:unipos/presentation/screens/restaurant/import/bulk_import_test_screen_v3.dart';
import 'package:unipos/data/models/restaurant/db/taxmodel_314.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_tax.dart';

/// Complete Restaurant Add Item Screen for Setup Wizard
/// Production-ready with full validation, image upload, and category management
class SetupAddItemScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const SetupAddItemScreen({
    Key? key,
    this.onNext,
    this.onPrevious,
  }) : super(key: key);

  @override
  State<SetupAddItemScreen> createState() => _SetupAddItemScreenState();
}

class _SetupAddItemScreenState extends State<SetupAddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();

  // Required Fields
  final _itemNameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  // Optional Fields
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  String? _savedImagePath;

  // Veg/Non-Veg
  String _itemType = 'Veg'; // Default: Veg

  // Selling Method
  bool _isSoldByWeight = false;
  String? _selectedUnit; // kg, gm
  final List<String> _units = ['kg', 'gm'];

  // Inventory Management
  bool _trackInventory = false;
  bool _allowOrderWhenOutOfStock = false;
  final _stockController = TextEditingController();

  // Variants, Choices, Extras (from Add More Info screen)
  List<String> _selectedVariantIds = [];
  List<String> _selectedChoiceIds = [];
  List<String> _selectedExtraIds = [];

  // Tax selection
  List<Tax> _availableTaxes = [];
  List<String> _selectedTaxIds = [];
  bool _didLoadDependencies = false; // Guard to prevent excessive reloading

  // Items added counter
  int _itemsAdded = 0;
  int _totalItemsInDatabase = 0;

  @override
  void initState() {
    super.initState();
    _loadItemCount();
    _loadTaxes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload taxes when screen becomes visible again (e.g., after returning from Tax Setup)
    // This ensures taxes added in previous steps are displayed
    if (_didLoadDependencies) {
      _loadTaxes();
    }
    _didLoadDependencies = true;
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  // ============ LOAD ITEM COUNT ============

  Future<void> _loadItemCount() async {
    try {
      final itemBox = await itemsBoxes.getItemBox();
      setState(() {
        _totalItemsInDatabase = itemBox.length;
      });
    } catch (e) {
      // Ignore errors during count
    }
  }

  // ============ LOAD TAXES ============

  Future<void> _loadTaxes() async {
    try {
      final taxes = await TaxBox.getAllTax();
      setState(() {
        _availableTaxes = taxes;
      });
    } catch (e) {
      print('Error loading taxes: $e');
    }
  }

  // ============ IMAGE UPLOAD ============

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _saveImageToLocalStorage(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final productImagesDir = Directory('${directory.path}/product_images');

      if (!await productImagesDir.exists()) {
        await productImagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'img_$timestamp.jpg';
      final savedImage = await imageFile.copy('${productImagesDir.path}/$fileName');

      return savedImage.path;
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _savedImagePath = null;
    });
  }

  // ============ CATEGORY SELECTION ============

  Future<void> _showCategorySelection() async {
    final result = await Navigator.push<Category>(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryManagementScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategoryId = result.id;
        _selectedCategoryName = result.name;
      });
    }
  }

  // ============ VALIDATION ============

  List<String> _validateForm() {
    List<String> errors = [];

    if (_itemNameController.text.trim().isEmpty) {
      errors.add('Item name is required');
    }

    if (_priceController.text.trim().isEmpty) {
      errors.add('Price is required');
    } else {
      final price = double.tryParse(_priceController.text.trim());
      if (price == null) {
        errors.add('Price must be a valid number');
      } else if (price <= 0) {
        errors.add('Price must be greater than 0');
      }
    }

    if (_selectedCategoryId == null) {
      errors.add('Category is required');
    }

    if (_isSoldByWeight && _selectedUnit == null) {
      errors.add('Unit must be selected when selling by weight');
    }

    return errors;
  }

  void _showValidationDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Missing Required Fields',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors.map((error) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: primarycolor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ ADD MORE INFO ============

  Future<void> _navigateToAddMoreInfo() async {
    // Validate required fields first
    final errors = _validateForm();
    if (errors.isNotEmpty) {
      _showValidationDialog(errors);
      return;
    }

    // Navigate to Add More Info screen
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMoreInfoScreen(
          initialData: {
            'choiceIds': _selectedChoiceIds,
            'extraIds': _selectedExtraIds,
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedChoiceIds = List<String>.from(result['choiceIds'] ?? []);
        _selectedExtraIds = List<String>.from(result['extraIds'] ?? []);
      });
    }
  }

  // ============ CALCULATE TAX RATE ============

  /// Calculate total tax rate from selected tax IDs
  Future<double> _calculateTotalTaxRate() async {
    if (_selectedTaxIds.isEmpty) return 0.0;

    try {
      double totalRate = 0.0;

      // Load all selected taxes and sum their rates
      for (final taxId in _selectedTaxIds) {
        final taxBox = await TaxBox.getTaxBox();
        final tax = taxBox.get(taxId);
        if (tax != null && tax.taxperecentage != null) {
          totalRate += tax.taxperecentage!;
        }
      }

      print('📊 Calculated total tax rate: $totalRate% from ${_selectedTaxIds.length} taxes');
      return totalRate / 100; // Convert percentage to decimal (5% -> 0.05)
    } catch (e) {
      print('❌ Error calculating tax rate: $e');
      return 0.0;
    }
  }

  /// Calculate total tax percentage (synchronous version for UI)
  double _calculateTotalTaxPercentage() {
    if (_selectedTaxIds.isEmpty) return 0.0;

    double totalRate = 0.0;
    for (final taxId in _selectedTaxIds) {
      final tax = _availableTaxes.firstWhere(
        (t) => t.id == taxId,
        orElse: () => Tax(id: '', taxname: '', taxperecentage: 0),
      );
      if (tax.taxperecentage != null) {
        totalRate += tax.taxperecentage!;
      }
    }
    return totalRate;
  }

  /// Calculate price with tax
  double _calculatePriceWithTax() {
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) return 0.0;

    final basePrice = double.tryParse(priceText) ?? 0.0;
    final taxPercentage = _calculateTotalTaxPercentage();
    final taxAmount = basePrice * (taxPercentage / 100);

    return basePrice + taxAmount;
  }

  // ============ SAVE ITEM ============

  Future<void> _saveItem() async {
    // Validate all fields
    final errors = _validateForm();
    if (errors.isNotEmpty) {
      _showValidationDialog(errors);
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Save image if selected
      if (_selectedImage != null) {
        _savedImagePath = await _saveImageToLocalStorage(_selectedImage!);
      }

      // Calculate tax rate from selected taxes
      final taxRate = await _calculateTotalTaxRate();

      // Create item
      final item = Items(
        id: _uuid.v4(),
        name: _itemNameController.text.trim(),
        categoryOfItem: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        imagePath: _savedImagePath ?? '',
        isVeg: _itemType == 'Veg' ? 'Veg' : 'Non-Veg',
        isSoldByWeight: _isSoldByWeight,
        unit: _isSoldByWeight ? _selectedUnit : null,
        trackInventory: _trackInventory,
        stockQuantity: _trackInventory
            ? double.tryParse(_stockController.text.trim()) ?? 0.0
            : 0.0,
        allowOrderWhenOutOfStock: _allowOrderWhenOutOfStock,
        choiceIds: _selectedChoiceIds,
        extraId: _selectedExtraIds,
        taxIds: _selectedTaxIds.isNotEmpty ? _selectedTaxIds : null,
        taxRate: taxRate > 0 ? taxRate : null, // Apply calculated tax rate
        isEnabled: true,
        createdTime: DateTime.now(),
        editCount: 0,
      );

      // Save to Hive
      final itemBox = await itemsBoxes.getItemBox();
      await itemBox.put(item.id, item);
      await itemBox.flush();
      await itemBox.compact();

      // Close loading
      if (mounted) Navigator.pop(context);

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item "${item.name}" added successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Reset form
      _resetForm();

      // Increment counters
      setState(() {
        _itemsAdded++;
        _totalItemsInDatabase++;
      });
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving item: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _itemNameController.clear();
      _priceController.clear();
      _descriptionController.clear();
      _stockController.clear();
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _selectedImage = null;
      _savedImagePath = null;
      _itemType = 'Veg';
      _isSoldByWeight = false;
      _selectedUnit = null;
      _trackInventory = false;
      _allowOrderWhenOutOfStock = false;
      _selectedVariantIds = [];
      _selectedChoiceIds = [];
      _selectedExtraIds = [];
      _selectedTaxIds = [];
    });
  }

  // ============ BUILD UI ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: widget.onPrevious != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: widget.onPrevious,
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Menu Items',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_totalItemsInDatabase > 0)
            Text(
              '$_totalItemsInDatabase item${_totalItemsInDatabase > 1 ? 's' : ''} in database',
              style: GoogleFonts.poppins(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.upload_file, color: primarycolor),
          tooltip: 'Bulk Import',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BulkImportTestScreenV3(),
              ),
            );
            // Reload item count after bulk import
            await _loadItemCount();
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBulkImportCard(),
            const SizedBox(height: 20),
            _buildSectionHeader('Basic Information', Icons.info_outline),
            const SizedBox(height: 15),
            _buildBasicInfoSection(),
            const SizedBox(height: 25),
            _buildSectionHeader('Item Type', Icons.restaurant),
            const SizedBox(height: 15),
            _buildItemTypeSection(),
            const SizedBox(height: 25),
            _buildSectionHeader('Selling Method', Icons.scale),
            const SizedBox(height: 15),
            _buildSellingMethodSection(),
            const SizedBox(height: 25),
            _buildSectionHeader('Inventory Management', Icons.inventory_2_outlined),
            const SizedBox(height: 15),
            _buildInventorySection(),
            const SizedBox(height: 25),
            _buildSectionHeader('Tax Selection', Icons.receipt_long),
            const SizedBox(height: 15),
            _buildTaxSection(),
            const SizedBox(height: 25),
            _buildSectionHeader('Additional Options', Icons.extension),
            const SizedBox(height: 15),
            _buildAdditionalOptionsSection(),
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primarycolor, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBulkImportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primarycolor.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primarycolor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primarycolor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.table_chart,
                  size: 32,
                  color: primarycolor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Import Items',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload multiple items at once using Excel',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BulkImportTestScreenV3(),
                      ),
                    );
                    // Reload item count after bulk import
                    await _loadItemCount();
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(
                    'Start Bulk Import',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primarycolor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Download template, add items, and import back',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Name (Required)
          CommonTextForm(
            controller: _itemNameController,
            labelText: 'Item Name*',
            hintText: 'e.g., Margherita Pizza',
            obsecureText: false,
            icon: const Icon(Icons.restaurant_menu),
          ),
          const SizedBox(height: 15),

          // Price (Required)
          CommonTextForm(
            controller: _priceController,
            labelText: 'Price*',
            hintText: '0.00',
            obsecureText: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: const Icon(Icons.currency_rupee),
          ),
          const SizedBox(height: 15),

          // Category (Required)
          InkWell(
            onTap: _showCategorySelection,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.category, color: primarycolor),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category*',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedCategoryName ?? 'Select or Add Category',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: _selectedCategoryName != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _selectedCategoryName != null
                                ? Colors.black87
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Description (Optional)
          CommonTextForm(
            controller: _descriptionController,
            labelText: 'Description (Optional)',
            hintText: 'Brief description of the item',
            obsecureText: false,
            maxline: 3,
            icon: const Icon(Icons.description),
          ),
          const SizedBox(height: 15),

          // Image Upload
          _buildImageUploadSection(),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Image (Optional)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedImage != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: _removeImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to upload image',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'From Gallery',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItemTypeSection() {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: _buildItemTypeOption(
              'Veg',
              Icons.circle,
              Colors.green,
              _itemType == 'Veg',
              () => setState(() => _itemType = 'Veg'),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildItemTypeOption(
              'Non-Veg',
              Icons.circle,
              Colors.red,
              _itemType == 'Non-Veg',
              () => setState(() => _itemType = 'Non-Veg'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTypeOption(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellingMethodSection() {
    return Container(
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
          Row(
            children: [
              Expanded(
                child: _buildSellingMethodOption(
                  'By Unit',
                  Icons.shopping_bag,
                  !_isSoldByWeight,
                  () => setState(() {
                    _isSoldByWeight = false;
                    _selectedUnit = null;
                  }),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildSellingMethodOption(
                  'By Weight',
                  Icons.scale,
                  _isSoldByWeight,
                  () => setState(() => _isSoldByWeight = true),
                ),
              ),
            ],
          ),
          if (_isSoldByWeight) ...[
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: InputDecoration(
                labelText: 'Select Unit*',
                labelStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.straighten, color: primarycolor),
              ),
              items: _units.map((unit) {
                return DropdownMenuItem<String>(
                  value: unit,
                  child: Text(unit, style: GoogleFonts.poppins()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedUnit = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSellingMethodOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? primarycolor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? primarycolor.withOpacity(0.1) : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? primarycolor : Colors.grey[600], size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primarycolor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Container(
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
          SwitchListTile(
            title: Text(
              'Track Inventory',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Monitor stock levels for this item',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            value: _trackInventory,
            activeColor: primarycolor,
            onChanged: (value) => setState(() {
              _trackInventory = value;
              if (!value) {
                _allowOrderWhenOutOfStock = false;
                _stockController.clear();
              }
            }),
          ),
          if (_trackInventory) ...[
            const Divider(),
            const SizedBox(height: 10),
            CommonTextForm(
              controller: _stockController,
              labelText: 'Current Stock',
              hintText: '0',
              obsecureText: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              icon: const Icon(Icons.inventory),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: Text(
                'Allow Order When Out of Stock',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Customers can order even when stock is 0',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: _allowOrderWhenOutOfStock,
              activeColor: primarycolor,
              onChanged: (value) => setState(() => _allowOrderWhenOutOfStock = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaxSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_availableTaxes.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'No taxes available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Add taxes in Setup Wizard Tax Settings first',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Select applicable taxes for this item:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            ..._availableTaxes.map((tax) {
              final isSelected = _selectedTaxIds.contains(tax.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primarycolor.withOpacity(0.1) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? primarycolor : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedTaxIds.add(tax.id);
                      } else {
                        _selectedTaxIds.remove(tax.id);
                      }
                    });
                  },
                  title: Text(
                    tax.taxname,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '${tax.taxperecentage?.toStringAsFixed(2) ?? '0.00'}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  activeColor: primarycolor,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              );
            }).toList(),
            if (_selectedTaxIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedTaxIds.length} tax${_selectedTaxIds.length > 1 ? 'es' : ''} selected',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Price Preview with Tax
              if (_priceController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Price Preview',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Base Price:',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '₹${_priceController.text}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tax (${_calculateTotalTaxPercentage().toStringAsFixed(2)}%):',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '+₹${((double.tryParse(_priceController.text) ?? 0) * _calculateTotalTaxPercentage() / 100).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Final Price:',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '₹${_calculatePriceWithTax().toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primarycolor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalOptionsSection() {
    final hasSelections = _selectedVariantIds.isNotEmpty ||
        _selectedChoiceIds.isNotEmpty ||
        _selectedExtraIds.isNotEmpty;

    return Container(
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
      child: InkWell(
        onTap: _navigateToAddMoreInfo,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasSelections ? primarycolor : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
            color: hasSelections ? primarycolor.withOpacity(0.05) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                Icons.extension,
                color: hasSelections ? primarycolor : Colors.grey[600],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add More Info',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasSelections
                          ? 'Variants: ${_selectedVariantIds.length}, Choices: ${_selectedChoiceIds.length}, Extras: ${_selectedExtraIds.length}'
                          : 'Add variants, choices, and extras',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: hasSelections ? primarycolor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CommonButton(
              onTap: _saveItem,
              bgcolor: primarycolor,
              bordercircular: 10,
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Add Item',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onNext != null) ...[
            const SizedBox(width: 15),
            CommonButton(
              onTap: widget.onNext!,
              bgcolor: _totalItemsInDatabase > 0 ? Colors.green : Colors.grey[600]!,
              bordercircular: 10,
              height: ResponsiveHelper.responsiveHeight(context, 0.06),
              width: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _totalItemsInDatabase > 0 ? Icons.arrow_forward : Icons.skip_next,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _totalItemsInDatabase > 0 ? 'Continue' : 'Skip',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
