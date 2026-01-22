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
        orElse: () => expenseCategoryStore.categories.first,
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
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Expense',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Date',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    InkWell(
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
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Center(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Amount (${CurrencyHelper.currentSymbol})',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    CommonTextForm(
                      controller: amountController,
                      hintText: 'Enter Amount',
                      BorderColor: AppColors.primary,
                      HintColor: Colors.grey,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      borderc: 0,
                      obsecureText: false,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Category',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Observer(
                      builder: (context) {
                        final categories = expenseCategoryStore.enabledCategories;
                        return Container(
                          padding: EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCategoryId,
                              hint: Text(
                                'Select Category',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                              ),
                              items: categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category.id,
                                  child: Text(
                                    category.name,
                                    style: GoogleFonts.poppins(fontSize: 14),
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
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    CommonTextForm(
                      controller: reasonController,
                      hintText: 'Enter Reason',
                      BorderColor: AppColors.primary,
                      HintColor: Colors.grey,
                      borderc: 0,
                      obsecureText: false,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Payment Type',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
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
                                style: GoogleFonts.poppins(fontSize: 14),
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
                          child: CommonButton(
                            bgcolor: Colors.red,
                            bordercircular: 0,
                            height: 50,
                            onTap: () async {
                              await expenseStore.deleteExpense(expense.id);
                              Navigator.pop(context);
                              _loadExpenses();
                              NotificationService.instance.showSuccess('Expense deleted successfully');
                            },
                            child: Text(
                              'Delete',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: CommonButton(
                            bordercircular: 0,
                            height: 50,
                            onTap: () async {
                              try {
                                final amount = double.parse(amountController.text.trim());
                                final updatedExpense = expense.copyWith(
                                  dateandTime: selectedDate,
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
                                NotificationService.instance.showError('Please enter a valid amount');
                              }
                            },
                            child: Text(
                              'Update',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
    );
  }

  @override
  Widget build(BuildContext context) {



    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Date',textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontSize: 14),),
                    // SizedBox(height:15),

                    InkWell(
                      onTap: (){
                        _pickFromDate(context);
                      },
                      child: Expanded(
                        child: Container(
                            padding: EdgeInsets.all(5),
                            width: width * 0.44,
                            height: height * 0.05,
                            decoration:BoxDecoration(
                                border: Border.all(color:AppColors.primary)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fromDatee == null
                                      ? ' DD/MM/YYYY'
                                      : '${_fromDatee!.day}/${_fromDatee!.month}/${_fromDatee!.year}',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                Icon(Icons.date_range)
                              ],
                            )
                        ),
                      ),
                    )
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Date',textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(fontSize: 14),),
                    // SizedBox(height:15),

                    InkWell(
                      onTap: _fromDatee ==null ? null: ()=> _pickToDate(context),
                      child: Expanded(
                        child: Container(
                            padding: EdgeInsets.all(5),
                            width: width * 0.44,
                            height: height * 0.05,
                            decoration:BoxDecoration(
                                border: Border.all(color:AppColors.primary)
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _toDate == null
                                      ? ' DD/MM/YYYY'
                                      : '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',textAlign: TextAlign.center,
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                Icon(Icons.date_range)
                              ],
                            )
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
            SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CommonButton(
                  bordercircular: 0,
                  width: width * 0.4,
                  height: height * 0.05,
                  onTap: _filterExpenses,
                  child: Text(
                    'Filter',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                CommonButton(
                  bordercircular: 0,
                  bgcolor: Colors.grey,
                  width: width * 0.4,
                  height: height * 0.05,
                  onTap: () {
                    setState(() {
                      _fromDatee = null;
                      _toDate = null;
                    });
                    expenseStore.clearDateFilter();
                  },
                  child: Text(
                    'Clear Filter',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Expanded(
              child: Observer(
                builder: (context) {
                  final filteredExpenses = expenseStore.filteredExpenses;

                  if (filteredExpenses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No expenses found',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getCategoryName(expense.categoryOfExpense),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(expense.amount)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(expense.dateandTime),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (expense.reason != null && expense.reason!.isNotEmpty)
                                Text(
                                  expense.reason!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              Text(
                                expense.paymentType ?? 'Cash',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showEditExpenseBottomSheet(expense),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

