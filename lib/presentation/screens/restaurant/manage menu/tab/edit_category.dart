import 'package:flutter/material.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/util/restaurant/audit_trail_helper.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';

class EditCategory extends StatefulWidget {
  final Category category;
  const EditCategory({super.key, required this.category});

  @override
  State<EditCategory> createState() => _EditCategoryState();
}

class _EditCategoryState extends State<EditCategory> {
  late final TextEditingController nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.category.name);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final trimmedName = nameController.text.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Category name cannot be empty');
      return;
    }

    // Duplicate name check (excluding this category itself)
    final duplicate = categoryStore.categories.any((c) =>
        c.id != widget.category.id &&
        c.name.toLowerCase() == trimmedName.toLowerCase());
    if (duplicate) {
      NotificationService.instance
          .showError('A category with this name already exists');
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final updated = widget.category.copyWith(
        name: trimmedName,
      );
      AuditTrailHelper.trackEdit(updated,
          editedBy:
              RestaurantSession.staffName ?? RestaurantSession.effectiveRole);
      await categoryStore.updateCategory(updated);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(

          'Edit Category',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name Field ─────────────────────────────────────────────
            AppTextField(
              controller: nameController,
              label: 'Category Name',
              hint: 'Enter category name',
              icon: Icons.category_outlined,
              required: true,
            ),

            const SizedBox(height: 32),

            // ── Save Button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline,
                        color: Colors.white),
                label: Text(
                  _isSaving ? 'Saving…' : 'Update Category',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
