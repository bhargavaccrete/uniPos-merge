import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/color.dart';
import '../../common/app_text_field.dart';
import 'image_picker_sheet.dart';

/// Dialog/Sheet for adding a new category — responsive:
/// ≥850 px wide → centered Dialog, <850 px → bottom sheet.
class AddCategoryDialog extends StatefulWidget {
  final VoidCallback? onCategoryAdded;
  final bool isDialog;

  const AddCategoryDialog({
    super.key,
    this.onCategoryAdded,
    this.isDialog = false,
  });

  static Future<bool> show(BuildContext context,
      {VoidCallback? onCategoryAdded}) async {
    bool wasAdded = false;
    final isWide = MediaQuery.of(context).size.width >= 850;

    if (isWide) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: AddCategoryDialog(
              isDialog: true,
              onCategoryAdded: () {
                wasAdded = true;
                onCategoryAdded?.call();
              },
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddCategoryDialog(
          isDialog: false,
          onCategoryAdded: () {
            wasAdded = true;
            onCategoryAdded?.call();
          },
        ),
      );
    }

    return wasAdded;
  }

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _categoryNameController = TextEditingController();
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await ImagePickerSheet.show(context);
    if (bytes != null) {
      setState(() => _selectedImageBytes = bytes);
    }
  }

  Future<void> _addCategory() async {
    final trimmedName = _categoryNameController.text.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Category name cannot be empty');
      return;
    }

    final exists = categoryStore.categories.any(
      (c) => c.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (exists) {
      NotificationService.instance
          .showError('A category with this name already exists');
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      String? imagePath;
      if (_selectedImageBytes != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final imageDir = Directory('${appDir.path}/category_images');
          if (!imageDir.existsSync()) await imageDir.create(recursive: true);
          final fileName = 'cat_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = File('${imageDir.path}/$fileName');
          await file.writeAsBytes(_selectedImageBytes!);
          imagePath = file.path;
        } catch (e) {
          debugPrint('Error saving category image: $e');
        }
      }

      final newCategory = Category(
        imagePath: imagePath,
        id: const Uuid().v4(),
        name: trimmedName,
        createdTime: DateTime.now(),
        editCount: 0,
      );

      await categoryStore.addCategory(newCategory);
      widget.onCategoryAdded?.call();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isDialog ? _buildDialogLayout() : _buildSheetLayout();
  }

  Widget _buildDialogLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(isDialog: true),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _formFields(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildHeader(isDialog: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _formFields(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isDialog}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 8, 16, 16),
      child: Row(
        children: [
          Icon(Icons.category_outlined, color: AppColors.primary, size: 24),
          const SizedBox(width: 10),
          Text(
            'Add Category',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          if (isDialog) ...[
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Category Name card ──────────────────────────────────────
        _sectionHeader('Category Name', Icons.label_outline_rounded),
        const SizedBox(height: 12),
        _card(
          child: AppTextField(
            controller: _categoryNameController,
            label: 'Category Name',
            hint: 'e.g., Beverages, Starters',
            icon: Icons.category_outlined,
            required: true,
          ),
        ),

        const SizedBox(height: 20),

        // ── Image card ───────────────────────────────────────────────
        _sectionHeader('Category Image (Optional)', Icons.image_outlined),
        const SizedBox(height: 12),
        _card(child: _buildImagePicker()),

        const SizedBox(height: 24),

        // ── Save button ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _addCategory,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_circle_outline, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving…' : 'Add Category',
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImagePicker() {
    if (_selectedImageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              _selectedImageBytes!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImageBytes = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to upload image',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            Text(
              'From Gallery',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
