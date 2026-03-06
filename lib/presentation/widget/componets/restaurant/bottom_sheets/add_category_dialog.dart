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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(isDialog: true),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _formFields(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetLayout() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            const SizedBox(height: 12),
            _buildHeader(isDialog: false),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _formFields(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isDialog}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isDialog ? 16 : 4, 12, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.category_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Category',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                'Create a new menu category',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (isDialog) ...[
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
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
        Text(
          'Category Name',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _categoryNameController,
          style:
              GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter category name',
            hintStyle:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            prefixIcon:
                const Icon(Icons.category_outlined, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.surfaceLight,
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
        const SizedBox(height: 20),
        Text(
          'Category Image (optional)',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.divider, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _selectedImageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload image',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '600×400 • PNG, JPG (Max 3MB)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_selectedImageBytes != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _selectedImageBytes = null),
              icon: const Icon(Icons.close, size: 16),
              label: Text('Remove image',
                  style: GoogleFonts.poppins(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        ],
        const SizedBox(height: 24),
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
                color: Colors.white,
              ),
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
}
