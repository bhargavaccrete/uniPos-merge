import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/data/models/restaurant/db/expensemodel_315.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

class ManageCategory extends StatefulWidget {
  const ManageCategory({super.key});

  @override
  State<ManageCategory> createState() => _ManageCategoryState();
}



class _ManageCategoryState extends State<ManageCategory> {
  final TextEditingController categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    expenseCategoryStore.loadCategories();
  }

  @override
  void dispose() {
    categoryController.dispose();
    super.dispose();
  }

  Future<void> AddECategory() async {
    final name = categoryController.text.trim();

    if (name.isEmpty) {
      NotificationService.instance.showError('Category name cannot be empty');
      return;
    }

    final isDuplicate = expenseCategoryStore.categories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (isDuplicate) {
      NotificationService.instance.showError('A category with this name already exists');
      return;
    }

    final category = ExpenseCategory(
      id: Uuid().v4(),
      name: name,
    );

    final success = await expenseCategoryStore.addCategory(category);
    if (success) {
      NotificationService.instance.showSuccess('Category added successfully');
      _clear();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _clear() {
    setState(() {
      categoryController.clear();
    });
  }

  Future<void> _delete(String id) async {
    await expenseCategoryStore.deleteCategory(id);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Manage Categories',
        titleFontSize: AppResponsive.headingFontSize(context),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          // Add Button Section
          Container(
            color: AppColors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: SizedBox(
              width: double.infinity,
              height: isTablet ? 54 : 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Widget formContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.add_circle_rounded, size: isTablet ? 26 : 24, color: AppColors.primary),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add New Category',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: AppColors.divider),
                      Text(
                        'Category Name',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 10),
                      AppTextField(
                        controller: categoryController,
                        hint: 'Enter category name',
                        icon: Icons.category_outlined,
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: isTablet ? 52 : 48,
                        child: ElevatedButton(
                          onPressed: () => AddECategory(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Add Category',
                            style: GoogleFonts.poppins(fontSize: isTablet ? 16 : 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  );

                  if (isTablet) {
                    showDialog(
                      context: context,
                      builder: (context) => AppDialogShell(
                        title: 'Add New Category',
                        accent: AppColors.primary,
                        icon: Icons.add_circle_rounded,
                        body: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category Name',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 10),
                            AppTextField(
                              controller: categoryController,
                              hint: 'Enter category name',
                              icon: Icons.category_outlined,
                            ),
                          ],
                        ),
                        actions: [
                          appDialogCancelButton(context),
                          const SizedBox(width: 12),
                          appDialogPrimaryButton(
                            label: 'Add Category',
                            onPressed: () => AddECategory(),
                          ),
                        ],
                      ),
                    );
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (BuildContext context) {
                        return Container(
                          padding: EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 0,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Center(
                                  child: Container(
                                    margin: EdgeInsets.only(top: 12, bottom: 16),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.divider,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                formContent,
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
                icon: Icon(Icons.add_circle_rounded, size: isTablet ? 20 : 18),
                label: Text(
                  'Add New Category',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Categories List
          Expanded(
            child: Observer(
              builder: (context) {
                final allcategory = expenseCategoryStore.categories;

                if (allcategory.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            size: isTablet ? 64 : 56,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No categories found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add your first category to get started',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  itemCount: allcategory.length,
                  itemBuilder: (context, index) {
                    final category = allcategory[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.03),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: category.isEnabled
                                  ? AppColors.primary.withValues(alpha:0.1)
                                  : AppColors.textSecondary.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.category_rounded,
                              color: category.isEnabled ? AppColors.primary : AppColors.textSecondary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              category.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Switch(
                            value: category.isEnabled,
                            onChanged: (bool value) async {
                              final updatedCategory = ExpenseCategory(
                                id: category.id,
                                name: category.name,
                                isEnabled: value,
                              );
                              await expenseCategoryStore.updateCategory(updatedCategory);
                            },
                            activeColor: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final confirm = await showAppConfirmDialog(
                                  context: context,
                                  title: 'Delete Category',
                                  message:
                                      'Are you sure you want to delete "${category.name}"?',
                                  confirmLabel: 'Delete',
                                  accent: AppColors.danger,
                                  icon: Icons.delete_outline,
                                );
                                if (confirm) {
                                  await _delete(category.id);
                                }
                              },
                              icon: Icon(
                                Icons.delete_rounded,
                                color: Colors.red,
                                size: isTablet ? 22 : 20,
                              ),
                              tooltip: 'Delete',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
