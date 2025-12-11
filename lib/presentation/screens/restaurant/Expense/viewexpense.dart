import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:unipos/data/models/restaurant/db/database/hive_expensecategory.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/expensel_316.dart';
import '../../../../data/models/restaurant/db/expensemodel_315.dart';
import '../../../widget/componets/restaurant/componets/Textform.dart';

class ViewExpense extends StatefulWidget {
  const ViewExpense({super.key});

  @override
  State<ViewExpense> createState() => _ViewExpenseState();
}

class _ViewExpenseState extends State<ViewExpense> {
  DateTime? _fromDatee;
  DateTime? _toDate;
  List<Expense> filteredExpenses = [];
  List<Expense> allExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() async {
    final expenses = await HiveExpenceL.getAllItems();
    setState(() {
      allExpenses = expenses;
      filteredExpenses = expenses;
    });
  }

  void _filterExpenses() {
    if (_fromDatee != null && _toDate != null) {
      setState(() {
        filteredExpenses = allExpenses.where((expense) {
          return expense.dateandTime.isAfter(_fromDatee!.subtract(Duration(days: 1))) &&
              expense.dateandTime.isBefore(_toDate!.add(Duration(days: 1)));
        }).toList();
      });
    } else {
      setState(() {
        filteredExpenses = allExpenses;
      });
    }
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return 'No Category';
    try {
      final box = Hive.box<ExpenseCategory>('expenseCategory');
      final category = box.get(categoryId);
      return category?.name ?? 'Unknown Category';
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
                          border: Border.all(color: primarycolor),
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
                      'Amount',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    CommonTextForm(
                      controller: amountController,
                      hintText: 'Enter Amount',
                      BorderColor: primarycolor,
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
                    ValueListenableBuilder(
                      valueListenable: Hive.box<ExpenseCategory>('expenseCategory').listenable(),
                      builder: (context, Box<ExpenseCategory> box, _) {
                        final categories = box.values.where((cat) => cat.isEnabled).toList();
                        return Container(
                          padding: EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: primarycolor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCategoryId,
                              hint: Text(
                                'Select Category',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                              ),
                              items: categories.map((ExpenseCategory category) {
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
                      BorderColor: primarycolor,
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
                        border: Border.all(color: primarycolor),
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
                              await HiveExpenceL.deleteItem(expense.id);
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
                                await HiveExpenceL.updateItem(updatedExpense);
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
                                border: Border.all(color:primarycolor)
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
                                border: Border.all(color:primarycolor)
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
                      filteredExpenses = allExpenses;
                    });
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
              child: filteredExpenses.isEmpty
                  ? Center(
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
              )
                  : ListView.builder(
                itemCount: filteredExpenses.length,
                itemBuilder: (context, index) {
                  final expense = filteredExpenses[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primarycolor,
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
                            '\u20b9${expense.amount.toStringAsFixed(2)}',
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
              ),
            )
          ],
        ),
      ),
    );
  }
}

