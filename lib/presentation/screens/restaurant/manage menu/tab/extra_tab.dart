import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/toppingmodel_304.dart';
import 'package:unipos/util/common/decimal_settings.dart';
import 'package:unipos/util/images.dart';
import '../../../../../data/models/restaurant/db/variantmodel_305.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/common/currency_helper.dart';
import '../../../../../data/models/restaurant/db/extramodel_303.dart';

class ExtraTab extends StatefulWidget {
  const ExtraTab({super.key});

  @override
  State<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends State<ExtraTab> {
  int? editingIndex, editingToppingIndex;

  final _extrasController = TextEditingController();
  final _toppingController = TextEditingController();
  final _priceController = TextEditingController();
  final _minimumController = TextEditingController();
  final _maximumController = TextEditingController();
  final _searchController = TextEditingController();

  String query = '';
  bool isveg = false, hasSize = false;
  Map<String, TextEditingController> _variantPriceControllers = {};
  List<VariantModel> _availableVariants = [];
  Set<String> _selectedVariants = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableVariants();
    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
      });
    });
  }

  void _loadAvailableVariants() {
    _availableVariants = variantStore.variants.toList();
  }

  @override
  void dispose() {
    _extrasController.dispose();
    _toppingController.dispose();
    _priceController.dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    _searchController.dispose();
    _variantPriceControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _openExtraBottomSheet({Extramodel? extra, int? index}) {
    if (extra != null) {
      _extrasController.text = extra.Ename;
      _minimumController.text = extra.minimum?.toString() ?? '';
      _maximumController.text = extra.maximum?.toString() ?? '';
      editingIndex = index;
    } else {
      _extrasController.clear();
      _minimumController.clear();
      _maximumController.clear();
      editingIndex = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildExtraBottomSheet(),
      ),
    );
  }

  Widget _buildExtraBottomSheet() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.star, color: AppColors.primary),
              ),
              SizedBox(width: 12),
              Text(
                editingIndex == null ? 'Add Extra Category' : 'Edit Extra Category',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Divider(height: 30),
          TextField(
            controller: _extrasController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              labelText: "Extra Category Name",
              labelStyle: GoogleFonts.poppins(color: Colors.grey),
              prefixIcon: Icon(Icons.edit, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _addOrEditExtra,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    editingIndex == null
                        ? Icons.add_circle_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    editingIndex == null ? 'Add' : 'Update',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openToppingBottomSheet({required Extramodel extra, int? toppingIndex}) {
    if (toppingIndex != null) {
      final topping = extra.topping![toppingIndex];
      _toppingController.text = topping.name;
      _priceController.text = topping.price.toString();
      isveg = topping.isveg;
      hasSize = topping.isContainSize ?? false;
      editingToppingIndex = toppingIndex;

      _variantPriceControllers.clear();
      _selectedVariants.clear();
      if (hasSize && topping.variantPrices != null) {
        for (var variant in _availableVariants) {
          if (topping.variantPrices!.containsKey(variant.id)) {
            _selectedVariants.add(variant.id);
            _variantPriceControllers[variant.id] = TextEditingController(
                text: topping.variantPrices![variant.id]?.toString() ??
                    topping.price.toString());
          }
        }
      }
    } else {
      _toppingController.clear();
      _priceController.clear();
      isveg = true;
      hasSize = false;
      editingToppingIndex = null;
      _variantPriceControllers.clear();
      _selectedVariants.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildToppingBottomSheet(extra),
      ),
    );
  }

  Widget _buildToppingBottomSheet(Extramodel extra) {
    return StatefulBuilder(
      builder: (context, setModalState) => Container(
        padding: EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_pizza, color: AppColors.primary),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Topping',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'To: ${extra.Ename}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: 30),

              // Topping Name
              TextField(
                controller: _toppingController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Topping Name",
                  labelStyle: GoogleFonts.poppins(color: Colors.grey),
                  prefixIcon: Icon(Icons.edit, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 15),

              // Veg/Non-Veg Selector
              Text(
                'Type',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildVegOption(true, setModalState),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _buildVegOption(false, setModalState),
                  ),
                ],
              ),
              SizedBox(height: 15),

              // Contains Size Checkbox
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: hasSize,
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        setModalState(() {
                          hasSize = value!;
                          if (hasSize) {
                            _variantPriceControllers.clear();
                            _selectedVariants.clear();
                            for (var variant in _availableVariants) {
                              _variantPriceControllers[variant.id] =
                                  TextEditingController(
                                      text: _priceController.text.isEmpty
                                          ? '0'
                                          : _priceController.text);
                            }
                          } else {
                            _variantPriceControllers.values
                                .forEach((controller) => controller.dispose());
                            _variantPriceControllers.clear();
                            _selectedVariants.clear();
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contains Size',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Enable if this topping has different sizes',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 15),

              // Price Field or Variant Prices
              if (!hasSize)
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Price",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),

              if (hasSize) _buildVariantPricesSection(setModalState),

              SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _saveTopping(extra),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Save Topping',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVegOption(bool isVegOption, StateSetter setModalState) {
    final isSelected = isveg == isVegOption;

    return InkWell(
      onTap: () => setModalState(() => isveg = isVegOption),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: isVegOption ? Colors.green : Colors.red,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.circle,
                color: isVegOption ? Colors.green : Colors.red,
                size: 14,
              ),
            ),
            SizedBox(width: 8),
            Text(
              isVegOption ? 'Veg' : 'Non-Veg',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVariantPricesSection(StateSetter setModalState) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Size-based Pricing',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Select sizes and set prices for each',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 12),
          ..._availableVariants.map((variant) {
            final isSelected = _selectedVariants.contains(variant.id);
            final controller = _variantPriceControllers[variant.id];
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (bool? value) {
                      setModalState(() {
                        if (value == true) {
                          _selectedVariants.add(variant.id);
                          _variantPriceControllers[variant.id] =
                              TextEditingController(
                                  text: _priceController.text.isEmpty
                                      ? '0'
                                      : _priceController.text);
                        } else {
                          _selectedVariants.remove(variant.id);
                          _variantPriceControllers[variant.id]?.dispose();
                          _variantPriceControllers.remove(variant.id);
                        }
                      });
                    },
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      variant.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: controller,
                      enabled: isSelected,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelText: 'Price',
                        labelStyle: GoogleFonts.poppins(fontSize: 12),
                        prefixText: CurrencyHelper.currentSymbol,
                        filled: !isSelected,
                        fillColor: !isSelected ? Colors.grey.shade100 : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _addOrEditExtra() async {
    final trimmedName = _extrasController.text.trim();
    if (trimmedName.isEmpty) return;

    try {
      if (editingIndex != null) {
        final allExtras = extraStore.extras.toList();
        final currentExtra = allExtras[editingIndex!];

        final updatedExtra = Extramodel(
          Id: currentExtra.Id,
          Ename: trimmedName,
          topping: currentExtra.topping,
        );
        await extraStore.updateExtra(updatedExtra);
      } else {
        final newExtra = Extramodel(
          Id: const Uuid().v4(),
          Ename: trimmedName,
        );
        await extraStore.addExtra(newExtra);
      }

      _extrasController.clear();
      editingIndex = null;
      Navigator.pop(context);
    } catch (e) {
      NotificationService.instance.showError('Error: $e');
    }
  }

  Future<void> _saveTopping(Extramodel extra) async {
    if (_toppingController.text.trim().isEmpty) return;

    Map<String, double>? variantPrices;
    double basePrice = 0.0;

    if (hasSize && _variantPriceControllers.isNotEmpty) {
      variantPrices = {};
      for (var entry in _variantPriceControllers.entries) {
        final price = double.tryParse(entry.value.text) ?? 0.0;
        variantPrices[entry.key] = price;
        if (basePrice == 0.0) basePrice = price;
      }
    } else {
      basePrice = double.tryParse(_priceController.text) ?? 0.0;
    }

    final topping = Topping(
      name: _toppingController.text.trim(),
      price: basePrice,
      isveg: isveg,
      isContainSize: hasSize,
      variantPrices: variantPrices,
    );

    try {
      if (editingToppingIndex != null) {
        await extraStore.updateTopping(extra.Id, editingToppingIndex!, topping);
      } else {
        await extraStore.addTopping(extra.Id, topping);
      }

      editingToppingIndex = null;
      Navigator.pop(context);
    } catch (e) {
      NotificationService.instance.showError('Error: $e');
    }
  }

  Future<void> _deleteTopping(Extramodel extra, int toppingIndex) async {
    try {
      await extraStore.removeTopping(extra.Id, toppingIndex);
    } catch (e) {
      NotificationService.instance.showError('Error: $e');
    }
  }

  Future<void> _deleteExtra(Extramodel extra) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Extra',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this extra?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await extraStore.deleteExtra(extra.Id);
      } catch (e) {
        NotificationService.instance.showError('Error deleting extra: $e');
      }
    }
  }

  int _getGridColumns(double width) {
    if (width > 1200) return 3;
    else if (width > 800) return 2;
    else return 2;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Search extras...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Extras List
          Expanded(
            child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout(size),
          ),

          // Add Extra Button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredExtras = _getFilteredExtras();

        if (filteredExtras.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredExtras.length,
          itemBuilder: (context, index) {
            final extra = filteredExtras[index];
            return _buildMobileExtraCard(extra, index);
          },
        );
      },
    );
  }

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredExtras = _getFilteredExtras();

        if (filteredExtras.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridColumns(size.width),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
          ),
          itemCount: filteredExtras.length,
          itemBuilder: (context, index) {
            final extra = filteredExtras[index];
            return _buildGridExtraCard(extra, index);
          },
        );
      },
    );
  }

  List<Extramodel> _getFilteredExtras() {
    final allExtras = extraStore.extras.toList();
    return query.isEmpty
        ? allExtras
        : allExtras.where((extra) {
            final name = extra.Ename.toLowerCase();
            final queryLower = query.toLowerCase();
            return name.contains(queryLower);
          }).toList();
  }

  Widget _buildEmptyState(double height) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(AppImages.notfoundanimation, height: height * 0.25),
          SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No Extras Found' : 'No matching extras',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (query.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Add extras to enhance your menu',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileExtraCard(Extramodel extra, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Extra Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.star, color: Colors.green.shade700, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        extra.Ename,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_pizza, size: 12, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              '${extra.topping?.length ?? 0} toppings',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _openExtraBottomSheet(extra: extra, index: index),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                      ),
                    ),
                    SizedBox(width: 8),
                    InkWell(
                      onTap: () => _deleteExtra(extra),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toppings List (Mobile)
          if (extra.topping != null && extra.topping!.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: extra.topping!.asMap().entries.map((entry) {
                  final toppingIndex = entry.key;
                  final topping = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: topping.isveg ? Colors.green : Colors.red,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.circle,
                            color: topping.isveg ? Colors.green : Colors.red,
                            size: 10,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topping.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(topping.price)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _openToppingBottomSheet(extra: extra, toppingIndex: toppingIndex),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.edit, color: Colors.blue, size: 16),
                          ),
                        ),
                        SizedBox(width: 8),
                        InkWell(
                          onTap: () => _deleteTopping(extra, toppingIndex),
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.delete, color: Colors.red, size: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Add Topping Button
          Padding(
            padding: EdgeInsets.all(16),
            child: InkWell(
              onTap: () => _openToppingBottomSheet(extra: extra),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Topping',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridExtraCard(Extramodel extra, int index) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.star, color: Colors.green.shade700, size: 20),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            extra.Ename,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${extra.topping?.length ?? 0} toppings',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toppings Preview (Grid)
          if (extra.topping != null && extra.topping!.isNotEmpty)
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 14),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView(
                  children: [
                    ...extra.topping!.take(3).map((topping) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: topping.isveg ? Colors.green : Colors.red,
                                  width: 1.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.circle,
                                color: topping.isveg ? Colors.green : Colors.red,
                                size: 7,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                topping.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (extra.topping!.length > 3)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '+${extra.topping!.length - 3} more',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Action Buttons
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _openToppingBottomSheet(extra: extra),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: AppColors.primary, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Add Topping',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openExtraBottomSheet(extra: extra, index: index),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _deleteExtra(extra),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _openExtraBottomSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add, color: AppColors.primary, size: 20),
              ),
              SizedBox(width: 10),
              Text(
                'Add Extra',
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
    );
  }
}