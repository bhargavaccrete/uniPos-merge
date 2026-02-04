import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/data/models/restaurant/db/expensemodel_315.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/util/color.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';

class ManageCategory extends StatefulWidget {
  const ManageCategory({super.key});

  @override
  State<ManageCategory> createState() => _ManageCategoryState();
}



TextEditingController categoryController = TextEditingController();



class _ManageCategoryState extends State<ManageCategory> {
  @override
  void initState() {
    super.initState();
    expenseCategoryStore.loadCategories();
  }

  Future<void> AddECategory() async {
    if (categoryController.text.trim().isEmpty) {
      Navigator.pop(context);
      NotificationService.instance.showError('Category Name Cannot Be Empty');
      return;
    }
    final category = ExpenseCategory(
      id: Uuid().v4(),
      name: categoryController.text.trim(),
    );

    final success = await expenseCategoryStore.addCategory(category);
    if (success) {
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: Text(
          'Manage Categories',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add Button Section
          Container(
            color: AppColors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
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
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drag Handle
                              Center(
                                child: Container(
                                  margin: EdgeInsets.only(top: 12, bottom: 16),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.add_circle_rounded,
                                      size: 24,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Add New Category',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
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
                              Divider(height: 24, color: Colors.grey.shade200),

                              SizedBox(height: 20),

                              Text(
                                'Category Name',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 10),
                              TextField(
                                controller: categoryController,
                                style: GoogleFonts.poppins(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Enter category name',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.divider),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.divider),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),

                              SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => AddECategory(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Add Category',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
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
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
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
                            color: Colors.black.withOpacity(0.03),
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
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.category_rounded,
                              color: category.isEnabled ? AppColors.primary : Colors.grey,
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
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.delete_rounded, color: Colors.red, size: 24),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Delete Category',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete "${category.name}"?',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Delete',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
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
