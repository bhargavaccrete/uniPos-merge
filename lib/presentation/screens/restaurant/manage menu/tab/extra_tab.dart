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
import 'package:unipos/util/restaurant/images.dart';
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

  bool isveg = false, hasSize = false;
  Map<String, TextEditingController> _variantPriceControllers = {};
  List<VariantModel> _availableVariants = [];
  Set<String> _selectedVariants = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableVariants();
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
    _variantPriceControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(child: _buildExtrasList(size)),
            _buildAddButton(size),
          ],
        ),
      ),
    );
  }

  Widget _buildExtrasList(Size size) {
    return Observer(
      builder: (_) {
        final allExtras = extraStore.extras.toList();

        if (allExtras.isEmpty) {
          return _buildEmptyState(size);
        }

        return ListView.builder(
          itemCount: allExtras.length,
          itemBuilder: (context, index) => _buildExtraCard(allExtras[index], index, size),
        );
      },
    );
  }

  Widget _buildEmptyState(Size size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            AppImages.notfoundanimation,
            height: size.height * 0.3,
          ),
          Text(
            'No Extras Found',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraCard(Extramodel extra, int index, Size size) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              extra.Ename,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: _buildActionButtons(extra, index),
          ),
          const Divider(),
          _buildToppingsList(extra, index),
          _buildAddToppingButton(size, extra, index),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Extramodel extra, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          Icons.edit,
          Colors.grey.shade300,
              () => _openExtraBottomSheet(extra: extra, index: index),
        ),
        const SizedBox(width: 5),
        _buildIconButton(
          Icons.delete,
          Colors.red,
              () => _showDeleteDialog(extra),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          icon,
          color: color == Colors.red ? Colors.white : null,
        ),
      ),
    );
  }

  Widget _buildToppingsList(Extramodel extra, int extraIndex) {
    if (extra.topping?.isEmpty ?? true) return const SizedBox();

    return Column(
      children: extra.topping!.asMap().entries.map((entry) {
        final toppingIndex = entry.key;
        final topping = entry.value;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Checkbox(value: true, onChanged: null),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topping.name, style: const TextStyle(fontSize: 16)),
                    Text(
                      '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(topping.price)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: topping.isveg ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  topping.isveg ? 'Veg' : 'Non-Veg',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openToppingBottomSheet(
                  extra: extra,
                  toppingIndex: toppingIndex,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.edit, color: Colors.grey),
                ),
              ),
              InkWell(
                onTap: () => _deleteTopping(extra, toppingIndex),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.delete, color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddToppingButton(Size size, Extramodel extra, int index) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CommonButton(
        width: size.width * 0.8,
        height: size.height * 0.06,
        bordercircular: 5,
        bordercolor: AppColors.primary,
        bgcolor: Colors.white,
        onTap: () => _openToppingBottomSheet(extra: extra),
        child: Text(
          'Add Topping Names',
          style: GoogleFonts.poppins(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildAddButton(Size size) {
    return CommonButton(
      bordercircular: 30,
      width: size.width * 0.5,
      height: size.height * 0.06,
      onTap: _openExtraBottomSheet,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 5),
          Text(
            'Add Extras',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Bottom Sheet Methods
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildExtraBottomSheet(),
      ),
    );
  }

  Widget _buildExtraBottomSheet() {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.35,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSheetHeader(
            editingIndex == null ? 'Add Extras Category' : 'Edit Extra Category',
          ),
          const SizedBox(height: 20),
          _buildTextField(_extrasController, "Extra Category Name (English)"),
          const SizedBox(height: 20),
          CommonButton(
            bordercircular: 10,
            height: size.height * 0.05,
            width: size.width * 0.5,
            onTap: _addOrEditExtra,
            child: Text(
              editingIndex == null ? 'Add' : 'Update',
              style: GoogleFonts.poppins(color: Colors.white),
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

      // Setup variant price controllers and selected variants
      _variantPriceControllers.clear();
      _selectedVariants.clear();
      if (hasSize && topping.variantPrices != null) {
        for (var variant in _availableVariants) {
          if (topping.variantPrices!.containsKey(variant.id)) {
            _selectedVariants.add(variant.id);
            _variantPriceControllers[variant.id] = TextEditingController(
                text: topping.variantPrices![variant.id]?.toString() ?? topping.price.toString()
            );
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildToppingBottomSheet(extra),
      ),
    );
  }

  Widget _buildToppingBottomSheet(Extramodel extra) {
    final size = MediaQuery.of(context).size;

    return StatefulBuilder(
      builder: (context, setModalState) => Container(
        height: size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSheetHeader('Add Topping'),
              const SizedBox(height: 10),
              _buildExtraCategoryInfo(extra.Ename),
              const SizedBox(height: 15),
              _buildTextField(_toppingController, "Topping Name"),
              const SizedBox(height: 15),
              _buildVegNonVegSelector(setModalState),
              _buildCheckboxRow(setModalState),
              if (!hasSize) _buildTextField(_priceController, "Add Price"),
              if (hasSize) _buildVariantPricesSection(setModalState),
              const SizedBox(height: 20),
              CommonButton(
                width: size.width * 0.4,
                height: size.height * 0.05,
                onTap: () => _saveTopping(extra),
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        InkWell(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.cancel, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey),
        border: const OutlineInputBorder(),
        labelText: label,
      ),
    );
  }

  Widget _buildExtraCategoryInfo(String categoryName) {
    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          text: 'Extra Category: ',
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
          children: [
            TextSpan(
              text: categoryName,
              style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegNonVegSelector(StateSetter setModalState) {
    return Row(
      children: [
        Expanded(child: _buildVegOption(true, setModalState)),
        const SizedBox(width: 10),
        Expanded(child: _buildVegOption(false, setModalState)),
      ],
    );
  }

  Widget _buildVegOption(bool isVegOption, StateSetter setModalState) {
    final size = MediaQuery.of(context).size;
    final isSelected = isveg == isVegOption;

    return InkWell(
      onTap: () => setModalState(() => isveg = isVegOption),
      child: Container(
        alignment: Alignment.center,
        height: size.height * 0.06,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: isVegOption ? Colors.green : Colors.red),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.circle,
                color: isVegOption ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isVegOption ? 'Veg' : 'Non-Veg',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(StateSetter setModalState) {
    return Row(
      children: [
        Checkbox(
          value: hasSize,
          onChanged: (value) {
            setModalState(() {
              hasSize = value!;
              if (hasSize) {
                // Initialize variant price controllers when hasSize is enabled
                _variantPriceControllers.clear();
                _selectedVariants.clear();
                for (var variant in _availableVariants) {
                  _variantPriceControllers[variant.id] = TextEditingController(
                      text: _priceController.text.isEmpty ? '0' : _priceController.text
                  );
                }
              } else {
                // Clear variant price controllers when hasSize is disabled
                _variantPriceControllers.values.forEach((controller) => controller.dispose());
                _variantPriceControllers.clear();
                _selectedVariants.clear();
              }
            });
          },
        ),
        Text('Contains Size', style: GoogleFonts.poppins(fontSize: 14)),
      ],
    );
  }

  Widget _buildVariantPricesSection(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Select Sizes and Set Prices:',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        ..._availableVariants.map((variant) {
          final isSelected = _selectedVariants.contains(variant.id);
          final controller = _variantPriceControllers[variant.id];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setModalState(() {
                      if (value == true) {
                        _selectedVariants.add(variant.id);
                        _variantPriceControllers[variant.id] = TextEditingController(
                            text: _priceController.text.isEmpty ? '0' : _priceController.text
                        );
                      } else {
                        _selectedVariants.remove(variant.id);
                        _variantPriceControllers[variant.id]?.dispose();
                        _variantPriceControllers.remove(variant.id);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    variant.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: controller,
                    enabled: isSelected,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
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
    );
  }

  // Action Methods
  Future<void> _addOrEditExtra() async {
    final trimmedName = _extrasController.text.trim();
    if (trimmedName.isEmpty) return;

    try {
      if (editingIndex != null) {
        // Get the current extra from store
        final allExtras = extraStore.extras.toList();
        final currentExtra = allExtras[editingIndex!];

        final updatedExtra = Extramodel(
          Id: currentExtra.Id,
          Ename: trimmedName,
          topping: currentExtra.topping, // Preserve existing toppings
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
      // Handle error - show snackbar or dialog
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
      NotificationService.instance.showError(
        'Error: $e',
      );


    }
  }

  Future<void> _saveTopping(Extramodel extra) async {
    if (_toppingController.text.trim().isEmpty) return;

    // Prepare variant prices if hasSize is true
    Map<String, double>? variantPrices;
    double basePrice = 0.0;

    if (hasSize && _variantPriceControllers.isNotEmpty) {
      variantPrices = {};
      for (var entry in _variantPriceControllers.entries) {
        final price = double.tryParse(entry.value.text) ?? 0.0;
        variantPrices[entry.key] = price;
        // Use the first variant price as base price
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
      NotificationService.instance.showError(
        'Error: $e',
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  Future<void> _deleteTopping(Extramodel extra, int toppingIndex) async {
    try {
      await extraStore.removeTopping(extra.Id, toppingIndex);
    } catch (e) {
      NotificationService.instance.showError(
        'Error: $e',
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  void _showDeleteDialog(Extramodel extra) {
    final size = MediaQuery.of(context).size;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: size.height * 0.4,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, size: 80, color: AppColors.primary),
            const SizedBox(height: 15),
            Text(
              'Delete Extra',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete this extra?',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CommonButton(
                    bordercircular: 8,
                    height: 45,
                    bordercolor: Colors.grey,
                    bgcolor: Colors.white,
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: CommonButton(
                    bordercircular: 8,
                    height: 45,
                    bordercolor: Colors.red,
                    bgcolor: Colors.red,
                    onTap: () => _deleteExtra(extra),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExtra(Extramodel extra) async {
    try {
      await extraStore.deleteExtra(extra.Id);
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      NotificationService.instance.showError(
        'Error deleting extra: $e',
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error deleting extra: $e')),
      // );
    }
  }
}
