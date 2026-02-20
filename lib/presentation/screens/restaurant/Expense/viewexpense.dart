import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';
import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/expensel_316.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';
class ViewExpense extends StatefulWidget {
  const ViewExpense({super.key});

  @override
  State<ViewExpense> createState() => _ViewExpenseState();
}

class _ViewExpenseState extends State<ViewExpense> {
  DateTime? _fromDatee;
  DateTime? _toDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    await expenseStore.loadExpenses();
    await expenseCategoryStore.loadCategories();
  }

  void _filterExpenses() {
    expenseStore.setDateRange(_fromDatee, _toDate);
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return 'No Category';
    try {
      final category = expenseCategoryStore.categories.firstWhere(
        (cat) => cat.id == categoryId,
      );
      return category.name;
    } catch (e) {
      return 'Unknown Category';
    }
  }


  Future<void> _pickFromDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _fromDatee??DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDatee = pickedDate;
        if (_toDate != null && _toDate!.isBefore(_fromDatee!)) {
          _toDate = null;
        }
      });
      _filterExpenses();
    }
  }

  // Function to pick To Date

  Future<void> _pickToDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: _toDate ?? _fromDatee ?? DateTime.now(),
        firstDate: _fromDatee ?? DateTime(2000),
        lastDate: DateTime(2100));
    if (pickedDate != null) {
      setState(() {
        _toDate = pickedDate;
      });
      _filterExpenses();
    }
  }

  void _showEditExpenseBottomSheet(Expense expense) {
    final TextEditingController amountController = TextEditingController(text: expense.amount.toString());
    final TextEditingController reasonController = TextEditingController(text: expense.reason ?? '');
    DateTime selectedDate = expense.dateandTime;
    String? selectedCategoryId = expense.categoryOfExpense;
    String selectedPaymentType = expense.paymentType ?? 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 24,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit Expense',
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
                      'Date',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setModalState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                            SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
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
                      controller: amountController,
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
                    SizedBox(height: 16),
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
                                setModalState(() {
                                  selectedCategoryId = value;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),
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
                      controller: reasonController,
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
                    SizedBox(height: 16),
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
                          value: selectedPaymentType,
                          items: ['Cash', 'Card/Online', 'Other'].map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(
                                item,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setModalState(() {
                              selectedPaymentType = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_isSubmitting) return;
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
                                        'Delete Expense',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete this expense?',
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
                                setState(() => _isSubmitting = true);
                                try {
                                  await expenseStore.deleteExpense(expense.id);
                                  Navigator.pop(context);
                                  _loadExpenses();
                                  NotificationService.instance.showSuccess('Expense deleted successfully');
                                } finally {
                                  if (mounted) setState(() => _isSubmitting = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Delete',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_isSubmitting) return;
                              final amount = double.tryParse(amountController.text.trim());
                              if (amount == null || amount <= 0) {
                                NotificationService.instance.showError('Please enter a valid amount greater than 0');
                                return;
                              }
                              setState(() => _isSubmitting = true);
                              try {
                                // Combine selected date with current time if editing today's expense
                                final now = DateTime.now();
                                final isSameDay = selectedDate.year == now.year &&
                                                  selectedDate.month == now.month &&
                                                  selectedDate.day == now.day;

                                final expenseDateTime = isSameDay
                                    ? DateTime(
                                        selectedDate.year,
                                        selectedDate.month,
                                        selectedDate.day,
                                        now.hour,
                                        now.minute,
                                        now.second,
                                        now.millisecond,
                                      )
                                    : selectedDate;

                                final updatedExpense = expense.copyWith(
                                  dateandTime: expenseDateTime,
                                  amount: amount,
                                  categoryOfExpense: selectedCategoryId,
                                  reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                                  paymentType: selectedPaymentType,
                                );
                                await expenseStore.updateExpense(updatedExpense);
                                Navigator.pop(context);
                                _loadExpenses();
                                NotificationService.instance.showSuccess('Expense updated successfully');
                              } catch (e) {
                                NotificationService.instance.showError('Failed to update expense. Please try again.');
                              } finally {
                                if (mounted) setState(() => _isSubmitting = false);
                              }
                            },
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
                              'Update Expense',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      amountController.dispose();
      reasonController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  // GestureDetector(
                  //   onTap: () => Navigator.pop(context),
                  //   child: Container(
                  //     padding: EdgeInsets.all(12),
                  //     decoration: BoxDecoration(
                  //       color: AppColors.primary,
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: Icon(Icons.arrow_back, color: AppColors.white, size: 24),
                  //   ),
                  // ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expenses',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Observer(
                          builder: (context) {
                            final total = expenseStore.filteredExpenses.fold<double>(
                              0,
                              (sum, expense) => sum + expense.amount,
                            );
                            return Text(
                              'Total: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(total)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filters Section
          Container(
            color: AppColors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Date',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickFromDate(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _fromDatee != null ? AppColors.primary : AppColors.divider,
                              width: _fromDatee != null ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: _fromDatee != null ? AppColors.primary : AppColors.textSecondary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _fromDatee == null
                                      ? 'Start Date'
                                      : DateFormat('dd MMM yyyy').format(_fromDatee!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _fromDatee != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _fromDatee == null ? null : () => _pickToDate(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _fromDatee == null ? Colors.grey.shade100 : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _toDate != null ? AppColors.primary : AppColors.divider,
                              width: _toDate != null ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: _fromDatee == null
                                    ? Colors.grey.shade400
                                    : (_toDate != null ? AppColors.primary : AppColors.textSecondary),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _toDate == null
                                      ? 'End Date'
                                      : DateFormat('dd MMM yyyy').format(_toDate!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _fromDatee == null
                                        ? Colors.grey.shade400
                                        : (_toDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _filterExpenses,
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
                          'Apply Filter',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _fromDatee = null;
                          _toDate = null;
                        });
                        expenseStore.clearDateFilter();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceMedium,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Icon(Icons.clear, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 8),
          // Expense List
          Expanded(
            child: Observer(
              builder: (context) {
                final filteredExpenses = expenseStore.filteredExpenses;

                if (filteredExpenses.isEmpty) {
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
                            Icons.receipt_long_outlined,
                            size: isTablet ? 64 : 56,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No expenses found',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _fromDatee != null || _toDate != null
                              ? 'Try adjusting your filter'
                              : 'Add your first expense to get started',
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
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = filteredExpenses[index];
                    return GestureDetector(
                      onTap: () => _showEditExpenseBottomSheet(expense),
                      child: Container(
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
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getCategoryName(expense.categoryOfExpense),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(expense.dateandTime),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (expense.reason != null && expense.reason!.isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      expense.reason!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  SizedBox(height: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      expense.paymentType ?? 'Cash',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(expense.amount)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ],
                        ),
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

