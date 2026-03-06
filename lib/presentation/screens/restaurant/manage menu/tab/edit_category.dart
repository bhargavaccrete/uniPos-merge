import 'dart:io';
import 'package:flutter/material.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/categorymodel_300.dart';
import 'package:unipos/util/restaurant/audit_trail_helper.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';

class EditCategory extends StatefulWidget {
  final Category category;
  const EditCategory({super.key, required this.category});

  @override
  State<EditCategory> createState() => _EditCategoryState();
}

class _EditCategoryState extends State<EditCategory> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.category.name);
    if (widget.category.imagePath != null &&
        widget.category.imagePath!.isNotEmpty) {
      _selectedImage = File(widget.category.imagePath!);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
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
        imagePath: _selectedImage != null
            ? _selectedImage!.path
            : widget.category.imagePath,
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
            Text('Category Name',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter category name',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.category_outlined,
                    color: AppColors.primary),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Image Picker ────────────────────────────────────────────
            Text('Category Image (optional)',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border:
                      Border.all(color: AppColors.divider, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage != null && _selectedImage!.existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child:
                            Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.5),
                              size: 48),
                          const SizedBox(height: 8),
                          Text('Tap to upload image',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('600×400 • PNG, JPG (Max 3MB)',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
              ),
            ),

            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedImage = null),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text('Remove image',
                      style: GoogleFonts.poppins(fontSize: 13)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                ),
              ),
            ],

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
