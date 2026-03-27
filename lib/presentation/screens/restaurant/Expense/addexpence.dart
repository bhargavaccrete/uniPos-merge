import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:uuid/uuid.dart';

import '../../../../util/common/currency_helper.dart';

class Addexpence extends StatefulWidget {
  const Addexpence({super.key});

  @override
  State<Addexpence> createState() => _AddexpenceState();
}

class _AddexpenceState extends State<Addexpence> {
  DateTime? _dateselect;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSaving = false;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    expenseCategoryStore.loadCategories();
  }

  @override
  void dispose() {
    _dateController.dispose();
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
        _dateController.text = DateFormat('dd/MM/yyyy').format(_pickedDate);
      });
    }
  }

  String? selectedCategoryId;
  String Dropvalue2 = 'Cash';
  final List<String> items2 = ['Cash','Card/Online','Other'];

  Future<void> _addExpense() async {
    if (_isSaving) return;

    // Validate category separately (not an AppTextField)
    setState(() {
      _categoryError = selectedCategoryId == null ? 'Please select a category' : null;
    });

    final formValid = _formKey.currentState!.validate();
    if (!formValid || _categoryError != null) return;

    final amount = double.parse(_amountController.text.trim());

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
      _categoryError = null;
    });
    _formKey.currentState?.reset();
    _dateController.clear();
    _amountController.clear();
    _reasonController.clear();
  }






  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);

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
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Amount Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _dateController,
                          label: 'Date',
                          hint: 'Select Date',
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: () => _pickedDate(context),
                          validator: (value) {
                            if (_dateselect == null) return 'Please select a date';
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: AppTextField(
                          controller: _amountController,
                          label: 'Amount (${CurrencyHelper.currentSymbol})',
                          hint: 'Enter amount',
                          icon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Please enter amount';
                            final amount = double.tryParse(value.trim());
                            if (amount == null || amount <= 0) return 'Enter a valid amount greater than 0';
                            return null;
                          },
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
                                _categoryError = null;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (_categoryError != null)
                    Padding(
                      padding: EdgeInsets.only(left: 12, top: 6),
                      child: Text(
                        _categoryError!,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                      ),
                    ),

                  SizedBox(height: 20),

                  // Reason
                  AppTextField(
                    controller: _reasonController,
                    label: 'Reason',
                    hint: 'Enter reason (optional)',
                    icon: Icons.notes_rounded,
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
            ),



            ],
          ),
        ),
    );
  }
}
