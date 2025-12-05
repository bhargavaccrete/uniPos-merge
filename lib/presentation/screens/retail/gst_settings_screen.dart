import 'package:flutter/material.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/retail/hive_model/category_model_215.dart';
import 'package:unipos/domain/services/retail/gst_service.dart';

import 'package:uuid/uuid.dart';

class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

class _GstSettingsScreenState extends State<GstSettingsScreen> {
  bool _taxInclusiveMode = false;
  double _defaultGstRate = 0;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _taxInclusiveMode = await gstService.isTaxInclusiveMode();
      _defaultGstRate = await gstService.getDefaultGstRate();
      _categories = await categoryModelRepository.getAllCategories();

      // Add default categories if none exist
      if (_categories.isEmpty) {
        await categoryModelRepository.addDefaultCategories();
        _categories = await categoryModelRepository.getAllCategories();
      }
    } catch (e) {
      debugPrint('Error loading GST settings: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleTaxInclusiveMode(bool value) async {
    await gstService.setTaxInclusiveMode(value);
    setState(() => _taxInclusiveMode = value);
  }

  Future<void> _updateDefaultGstRate(double rate) async {
    await gstService.setDefaultGstRate(rate);
    setState(() => _defaultGstRate = rate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('GST Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Settings Section
                  _buildSectionTitle('General Settings'),
                  const SizedBox(height: 12),
                  _buildGeneralSettingsCard(),
                  const SizedBox(height: 24),

                  // Category-wise GST Rates Section
                  _buildSectionTitle('Category-wise GST Rates'),
                  const SizedBox(height: 12),
                  _buildCategoryGstCard(),
                  const SizedBox(height: 16),

                  // Add Category Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Category'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        foregroundColor: const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // GST Rate Reference Section
                  _buildSectionTitle('Common GST Rates (India)'),
                  const SizedBox(height: 12),
                  _buildGstRateReferenceCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        children: [
          // Tax Inclusive Mode Toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tax Inclusive Pricing',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Product prices include GST',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _taxInclusiveMode,
                onChanged: _toggleTaxInclusiveMode,
                activeColor: const Color(0xFF4CAF50),
              ),
            ],
          ),
          const Divider(height: 24),

          // Default GST Rate
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Default GST Rate',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Applied when no category/product GST is set',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showDefaultGstRateDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_defaultGstRate.toInt()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGstCard() {
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: const Center(
          child: Text(
            'No categories found. Add categories to set GST rates.',
            style: TextStyle(color: Color(0xFF6B6B6B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ListTile(
            title: Text(
              category.categoryName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: category.hsnCode != null && category.hsnCode!.isNotEmpty
                ? Text('HSN: ${category.hsnCode}', style: const TextStyle(fontSize: 12))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(category.gstRate ?? 0).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showEditCategoryDialog(category),
                  color: Colors.grey[600],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGstRateReferenceCard() {
    final rates = [
      {'rate': '0%', 'items': 'Essential goods, milk, vegetables, fruits'},
      {'rate': '5%', 'items': 'Clothing under Rs.1000, footwear under Rs.500'},
      {'rate': '12%', 'items': 'Clothing Rs.1000+, footwear Rs.500-1000'},
      {'rate': '18%', 'items': 'Electronics, appliances, services'},
      {'rate': '28%', 'items': 'Luxury goods, automobiles, cosmetics'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        children: rates.map((rate) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rate['rate']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rate['items']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showDefaultGstRateDialog() async {
    final rates = GstService.commonGstRates;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default GST Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: rates.map((rate) {
            return ListTile(
              title: Text('${rate.toInt()}%'),
              leading: Radio<double>(
                value: rate,
                groupValue: _defaultGstRate,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    _updateDefaultGstRate(value);
                  }
                },
                activeColor: const Color(0xFF4CAF50),
              ),
              onTap: () {
                Navigator.pop(context);
                _updateDefaultGstRate(rate);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final hsnController = TextEditingController();
    double selectedRate = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hsnController,
                  decoration: const InputDecoration(
                    labelText: 'HSN Code (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('GST Rate', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: GstService.commonGstRates.map((rate) {
                    final isSelected = selectedRate == rate;
                    return ChoiceChip(
                      label: Text('${rate.toInt()}%'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() => selectedRate = rate);
                      },
                      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter category name')),
                  );
                  return;
                }

                final category = CategoryModel.create(
                  categoryId: const Uuid().v4(),
                  categoryName: nameController.text.trim(),
                  gstRate: selectedRate,
                  hsnCode: hsnController.text.trim().isEmpty ? null : hsnController.text.trim(),
                );

                await categoryModelRepository.addCategory(category);
                Navigator.pop(context);
                _loadSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCategoryDialog(CategoryModel category) async {
    final nameController = TextEditingController(text: category.categoryName);
    final hsnController = TextEditingController(text: category.hsnCode ?? '');
    double selectedRate = category.gstRate ?? 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hsnController,
                  decoration: const InputDecoration(
                    labelText: 'HSN Code (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('GST Rate', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: GstService.commonGstRates.map((rate) {
                    final isSelected = selectedRate == rate;
                    return ChoiceChip(
                      label: Text('${rate.toInt()}%'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() => selectedRate = rate);
                      },
                      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Category?'),
                    content: Text('Are you sure you want to delete "${category.categoryName}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await categoryModelRepository.deleteCategory(category.categoryId);
                  Navigator.pop(context);
                  _loadSettings();
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter category name')),
                  );
                  return;
                }

                final updated = category.copyWith(
                  categoryName: nameController.text.trim(),
                  gstRate: selectedRate,
                  hsnCode: hsnController.text.trim().isEmpty ? null : hsnController.text.trim(),
                );

                await categoryModelRepository.updateCategory(updated);
                Navigator.pop(context);
                _loadSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}