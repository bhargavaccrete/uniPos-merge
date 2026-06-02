import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/data/models/restaurant/db/variantmodel_305.dart';
import 'package:unipos/util/images.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import '../../../../../util/restaurant/restaurant_session.dart';

class VariantTab extends StatefulWidget {
  const VariantTab({super.key});

  @override
  State<VariantTab> createState() => _VariantTabState();
}

class _VariantTabState extends State<VariantTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  TextEditingController variantController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String query = '';
  VariantModel? editingVariante;

  bool get _canEdit => RestaurantSession.isAdmin || RestaurantSession.staffRole == 'Manager';

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

    final isTablet = !AppResponsive.isMobile(context);
    if (isTablet) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: _buildBottomSheet(ctx, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, _) => _buildBottomSheet(ctx, isDialog: false),
        ),
      );
    }
  }

  Widget _buildBottomSheet(BuildContext ctx, {bool isDialog = false}) {
    final isEditing = editingVariante != null;
    final bottomInset = isDialog ? 0.0 : MediaQuery.of(ctx).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDialog
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 8, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle (sheet only) ─────────────────────────────────
          if (!isDialog)
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
    final isTablet = !AppResponsive.isMobile(context);
    final hInset = isTablet
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2)
            .clamp(40.0, 200.0)
        : 24.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
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


  @override
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Modern Search Bar
          Padding(
            padding: AppResponsive.padding(context),
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

          if (_canEdit) _buildAddButton(),
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
          padding: AppResponsive.padding(context),
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
          padding: AppResponsive.padding(context),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppResponsive.gridColumns(context, mobile: 3, tablet: 4, desktop: 5),
            crossAxisSpacing: AppResponsive.gridSpacing(context),
            mainAxisSpacing: AppResponsive.gridSpacing(context),
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: AppResponsive.shadowBlurRadius(context),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.tune, color: AppColors.primary, size: AppResponsive.iconSize(context)),
            SizedBox(width: 8),
            Expanded(child: Text(variante.name, style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (_canEdit) ...[
              InkWell(onTap: () => openBottomSheet(variante: variante), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary))),
              InkWell(onTap: () => _delete(variante.id), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red))),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
            ),
            child: Icon(Icons.tune, color: AppColors.primary, size: AppResponsive.iconSize(context)),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(variante.name, style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (_canEdit) ...[
            InkWell(onTap: () => openBottomSheet(variante: variante), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: AppResponsive.smallIconSize(context), color: AppColors.primary))),
            InkWell(onTap: () => _delete(variante.id), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline, size: AppResponsive.smallIconSize(context), color: Colors.red))),
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: AppResponsive.padding(context),
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
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => openBottomSheet(),
            icon: Icon(Icons.add, size: AppResponsive.iconSize(context)),
            label: Text('Add Variant', style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context), fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: AppResponsive.mediumSpacing(context)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
    );
  }
}