import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/util/images.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

class VariantTab extends StatefulWidget {
  const VariantTab({super.key});

  @override
  State<VariantTab> createState() => _VariantTabState();
}

class _VariantTabState extends State<VariantTab> {
  TextEditingController variantController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String query = '';
  VariantModel? editingVariante;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() {
        query = searchController.text;
      });
    });
  }

  @override
  void dispose() {
    variantController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void openBottomSheet({VariantModel? variante}) {
    if (variante != null) {
      variantController.text = variante.name;
      editingVariante = variante;
    } else {
      variantController.clear();
      editingVariante = null;
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => _buildBottomSheet(ctx),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext ctx) {
    final isEditing = editingVariante != null;
    final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEditing ? Icons.edit_rounded : Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Variant' : 'Add Variant',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      isEditing
                          ? 'Update the variant name'
                          : 'Create a new variant option',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close, color: Colors.grey.shade500),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          Divider(height: 28, color: Colors.grey.shade100),

          // ── Variant Name field ────────────────────────────────────────
          AppTextField(
            controller: variantController,
            label: 'Variant Name',
            hint: 'e.g. Small, Medium, Large',
            icon: Icons.tune_rounded,
            required: true,
          ),
          const SizedBox(height: 20),

          // ── Action buttons ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _addOrEditVariante,
                  icon: Icon(
                    isEditing
                        ? Icons.check_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    isEditing ? 'Update Variant' : 'Add Variant',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditVariante() async {
    final trimmedName = variantController.text.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Variant name cannot be empty');
      return;
    }

    // Duplicate name check (excluding current item when editing)
    final exists = variantStore.variants.any((v) =>
        v.name.toLowerCase() == trimmedName.toLowerCase() &&
        v.id != (editingVariante?.id ?? ''));
    if (exists) {
      NotificationService.instance.showError('A variant with this name already exists');
      return;
    }

    if (editingVariante != null) {
      final updateVariante = VariantModel(id: editingVariante!.id, name: trimmedName);
      await variantStore.updateVariant(updateVariante);
    } else {
      final newvariante = VariantModel(id: Uuid().v4(), name: trimmedName);
      await variantStore.addVariant(newvariante);
    }

    variantController.clear();
    editingVariante = null;
    Navigator.pop(context);
  }

  Future<void> _delete(String id) async {
    final variant = variantStore.variants.firstWhere((v) => v.id == id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete "${variant.name}"?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text('This variant will be removed.', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500))),
        ],
      ),
    );

    if (confirmed == true) {
      await variantStore.deleteVariant(id);
    }
  }

  int _getGridColumns(double width) {
    if (width > 1200) return 5;
    else if (width > 900) return 4;
    else return 3;
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              controller: searchController,
              hint: 'Search variants…',
              icon: Icons.search_rounded,
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                  : null,
            ),
          ),

          // Variants List
          Expanded(
            child: isTablet ? _buildTabletLayout(size) : _buildMobileLayout(size),
          ),

          // Add Variant Button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredVariants = _getFilteredVariants();

        if (filteredVariants.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredVariants.length,
          itemBuilder: (context, index) {
            final variante = filteredVariants[index];
            return _buildVariantCard(variante, isGrid: false);
          },
        );
      },
    );
  }

  Widget _buildTabletLayout(Size size) {
    return Observer(
      builder: (_) {
        final filteredVariants = _getFilteredVariants();

        if (filteredVariants.isEmpty) {
          return _buildEmptyState(size.height);
        }

        return GridView.builder(
          padding: EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridColumns(size.width),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 4,
          ),
          itemCount: filteredVariants.length,
          itemBuilder: (context, index) {
            final variante = filteredVariants[index];
            return _buildVariantCard(variante, isGrid: true);
          },
        );
      },
    );
  }

  List<VariantModel> _getFilteredVariants() {
    final allvariante = variantStore.variants.toList();
    return query.isEmpty
        ? allvariante
        : allvariante.where((variant) {
            final name = variant.name.toLowerCase();
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
            query.isEmpty ? 'No Variants Found' : 'No matching variants',
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
                'Add variants to customize your items',
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

  Widget _buildVariantCard(VariantModel variante, {required bool isGrid}) {
    if (isGrid) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.tune, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(variante.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
            InkWell(onTap: () => openBottomSheet(variante: variante), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 15, color: Colors.blue))),
            InkWell(onTap: () => _delete(variante.id), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 15, color: Colors.red))),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text(variante.name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
          InkWell(onTap: () => openBottomSheet(variante: variante), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 18, color: Colors.blue))),
          InkWell(onTap: () => _delete(variante.id), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: 18, color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => openBottomSheet(),
          icon: Icon(Icons.add, size: 20),
          label: Text('Add Variant', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}