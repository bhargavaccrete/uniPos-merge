import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../../data/models/restaurant/db/categorymodel_300.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../domain/services/restaurant/notification_service.dart';
import '../../../../../util/color.dart';
import '../../../../../util/restaurant/audit_trail_helper.dart';
import '../../../../../util/restaurant/restaurant_session.dart';
import '../../common/app_text_field.dart';

/// Dialog/Sheet for adding or editing a category — responsive:
/// ≥850 px wide → centered Dialog, <850 px → bottom sheet.
class AddCategoryDialog extends StatefulWidget {
  final VoidCallback? onCategoryAdded;
  final bool isDialog;
  final Category? editCategory;

  const AddCategoryDialog({
    super.key,
    this.onCategoryAdded,
    this.isDialog = false,
    this.editCategory,
  });

  static Future<bool> show(BuildContext context,
      {VoidCallback? onCategoryAdded, Category? editCategory}) async {
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
              editCategory: editCategory,
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
          editCategory: editCategory,
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
  bool _isSaving = false;

  bool get _isEditMode => widget.editCategory != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _categoryNameController.text = widget.editCategory!.name;
    }
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final trimmedName = _categoryNameController.text.trim();
    if (trimmedName.isEmpty) {
      NotificationService.instance.showError('Category name cannot be empty');
      return;
    }

    final exists = categoryStore.categories.any(
      (c) => (_isEditMode ? c.id != widget.editCategory!.id : true) &&
          c.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (exists) {
      NotificationService.instance
          .showError('A category with this name already exists');
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        final updated = widget.editCategory!.copyWith(name: trimmedName);
        AuditTrailHelper.trackEdit(updated,
            editedBy: RestaurantSession.staffName ?? RestaurantSession.effectiveRole);
        await categoryStore.updateCategory(updated);
      } else {
        final newCategory = Category(
          id: const Uuid().v4(),
          name: trimmedName,
          createdTime: DateTime.now(),
          editCount: 0,
        );
        await categoryStore.addCategory(newCategory);
      }
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
            )
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
            _isEditMode ? 'Edit Category' : 'Add Category',
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

        const SizedBox(height: 24),

        // ── Save button ──────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveCategory,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_isEditMode ? Icons.check_circle_outline : Icons.add_circle_outline, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving…' : (_isEditMode ? 'Update Category' : 'Add Category'),
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

}
