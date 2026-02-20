import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:uuid/uuid.dart';

import '../../../../util/common/currency_helper.dart';

class Addexpence extends StatefulWidget {
  const Addexpence({super.key});

  @override
  State<Addexpence> createState() => _AddexpenceState();
}

class _AddexpenceState extends State<Addexpence> {
  DateTime? _dateselect;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    expenseCategoryStore.loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickedDate(BuildContext context) async {
    DateTime? _pickedDate = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        initialDate: DateTime.now(),
        lastDate: DateTime(2100));

    if (_pickedDate != null) {
      setState(() {
        _dateselect = _pickedDate;
      });
    }
  }

  String? selectedCategoryId;
  String Dropvalue2 = 'Cash';
  final List<String> items2 = ['Cash','Card/Online','Other'];

  Future<void> _addExpense() async {
    if (_isSaving) return;

    if (_dateselect == null) {
      NotificationService.instance.showError('Please select a date');
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      NotificationService.instance.showError('Please enter amount');
      return;
    }
    if (selectedCategoryId == null) {
      NotificationService.instance.showError('Please select a category');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      NotificationService.instance.showError('Please enter a valid amount greater than 0');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Combine selected date with current time (not just midnight)
      // This ensures expenses show up in EOD reports filtered by day start time
      final now = DateTime.now();
      final expenseDateTime = DateTime(
        _dateselect!.year,
        _dateselect!.month,
        _dateselect!.day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
      );

      final expense = Expense(
        id: Uuid().v4(),
        dateandTime: expenseDateTime,
        amount: amount,
        categoryOfExpense: selectedCategoryId,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        paymentType: Dropvalue2,
      );

      final success = await expenseStore.addExpense(expense);
      if (success) {
        NotificationService.instance.showSuccess('Expense added successfully');
        _clearForm();
      } else {
        NotificationService.instance.showError('Failed to add expense');
      }
    } catch (e) {
      NotificationService.instance.showError('Failed to add expense. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    setState(() {
      _dateselect = null;
      selectedCategoryId = null;
      Dropvalue2 = 'Cash';
    });
    _amountController.clear();
    _reasonController.clear();
  }






  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Manage Category Button
            Container(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.restaurantExpenseCategory);
                },
                icon: Icon(Icons.category_rounded, size: isTablet ? 20 : 18),
                label: Text(
                  'Manage Categories',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary, width: 2),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            // Form Container
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Amount Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => _pickedDate(context),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _dateselect != null ? AppColors.primary : AppColors.divider,
                                    width: _dateselect != null ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: _dateselect != null ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _dateselect == null
                                            ? "Select Date"
                                            : "${_dateselect!.day}/${_dateselect!.month}/${_dateselect!.year}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _dateselect != null ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount (${CurrencyHelper.currentSymbol})',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Enter amount',
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
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Category
                  Text(
                    'Category',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10),
                  Observer(
                    builder: (context) {
                      final categories = expenseCategoryStore.enabledCategories;
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedCategoryId,
                            hint: Text(
                              'Select Category',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            items: categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category.id,
                                child: Text(
                                  category.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                selectedCategoryId = value;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 20),

                  // Reason
                  Text(
                    'Reason',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _reasonController,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Enter reason (optional)',
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

                  SizedBox(height: 20),

                  // Payment Type
                  Text(
                    'Payment Type',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: Dropvalue2,
                        items: items2.map((String itemm) {
                          return DropdownMenuItem<String>(
                            value: itemm,
                            child: Text(
                              itemm,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            Dropvalue2 = value!;
                          });
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Add Expense',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),



            ],
          ),
        ),
    );
  }
}
