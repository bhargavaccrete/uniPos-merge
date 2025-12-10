import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/managecategory.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/models/restaurant/db/expensemodel_315.dart';

class Addexpence extends StatefulWidget {
  const Addexpence({super.key});

  @override
  State<Addexpence> createState() => _AddexpenceState();
}

class _AddexpenceState extends State<Addexpence> {
  DateTime? _dateselect;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

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

    try {
      final amount = double.parse(_amountController.text.trim());
      final expense = Expense(
        id: Uuid().v4(),
        dateandTime: _dateselect!,
        amount: amount,
        categoryOfExpense: selectedCategoryId,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        paymentType: Dropvalue2,
      );

      await expenseStore.addExpense(expense);
      NotificationService.instance.showSuccess('Expense added successfully');
      _clearForm();
    } catch (e) {
      NotificationService.instance.showError('Please enter a valid amount');
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
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          // color: Colors.red,
          // padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Expense',
                      textScaler: TextScaler.linear(1),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  CommonButton(
                      bordercircular: 0,
                      bgcolor: Colors.white,
                      bordercolor: primarycolor,
                      width: width * 0.5,
                      height: height * 0.05,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context)=> ManageCategory()));
                      },
                      child: Text('Manage Category',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(color: primarycolor)))
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Divider(),
              // date and amount
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            // fontWeight: FontWeight.w500
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 15),
                        InkWell(
                          onTap: () {
                            _pickedDate(context);
                          },
                          child: Container(
                            width: width * 0.45,
                            height: height * 0.07,
                            decoration: BoxDecoration(
                                border: Border.all(color: primarycolor)),
                            child: Center(
                                child: Text(
                              _dateselect == null
                                  ? "Select Date"
                                  : "${_dateselect!.day}/${_dateselect!.month}/${_dateselect!.year}",
                              textAlign: TextAlign.start,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            )),
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount (Rs.)',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            // fontWeight: FontWeight.w400
                          ),
                          textAlign: TextAlign.start,
                        ),
                        SizedBox(height: 15),
                        Container(
                          width: width * 0.45,
                          height: height * 0.07,
                          child: CommonTextForm(
                            controller: _amountController,
                            borderc: 0,
                            obsecureText: false,
                            hintText: "Enter Amount",
                            BorderColor: primarycolor,
                            HintColor: Colors.grey,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),

              // category select
              SizedBox(height: 20),
              Text("Category",
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                  )),
              SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: Hive.box<ExpenseCategory>('expenseCategories').listenable(),
                builder: (context, Box<ExpenseCategory> box, _) {
                  final categories = box.values.where((cat) => cat.isEnabled).toList();

                  return Container(
                    padding: EdgeInsets.all(5),
                    width: width * 0.9,
                    height: height * 0.06,
                    decoration: BoxDecoration(border: Border.all(color: primarycolor)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedCategoryId,
                        hint: Text(
                          'Select Category',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                        ),
                        items: categories.map((ExpenseCategory category) {
                          return DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(
                              category.name,
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),
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
              Text('Reasone',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                fontSize: 18,
              )),
SizedBox(height:10),
              Container(
                // width: width * 0.45,
                height: height * 0.07,
                child: CommonTextForm(
                  controller: _reasonController,
                  borderc: 0,
                  obsecureText: false,
                  hintText: "Enter Reason",
                  BorderColor: primarycolor,
                  HintColor: Colors.grey,
                ),
              ),

              SizedBox(height: 20),
              Text('Payment Type',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                fontSize: 18,
              )),
              SizedBox(height:10),

              Container(
                padding: EdgeInsets.all(5),

                width: width,
                height: height * 0.06,
                decoration: BoxDecoration(
                  border: Border.all(color: primarycolor)
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    value: Dropvalue2,
                      items: items2.map((String itemm){
                      return DropdownMenuItem(
                        value: itemm,
                          child: Text(itemm,textScaler: TextScaler.linear(1),
                            style: GoogleFonts.poppins(fontSize: 14),));
                      }). toList(),
                      onChanged: (String? value){
                      setState(() {
                        Dropvalue2 = value!;
                      });
                      }),
                ),
              ),

              SizedBox(height:20),
              Container(
                alignment: Alignment.center,
                child: CommonButton(
                  bordercircular: 0,
                  width: width * 0.8,
                  height: height * 0.06,
                  onTap: _addExpense,
                  child: Text(
                    'Add',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )



            ],
          ),
        ),
      ),
    );
  }
}
