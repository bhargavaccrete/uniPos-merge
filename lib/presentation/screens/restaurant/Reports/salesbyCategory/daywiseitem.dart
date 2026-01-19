import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/color.dart';
import '../../../../../constants/restaurant/color.dart';

class DayWiseCategory extends StatefulWidget {
  const DayWiseCategory({super.key});

  @override
  State<DayWiseCategory> createState() => _DayWiseCategoryState();
}

class _DayWiseCategoryState extends State<DayWiseCategory> {
  TextEditingController SearchCategory = TextEditingController();

  DateTime? _fromDate;
  // Function to show the Date Picker
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));

    if (pickedDate != null) {
      setState(() {
        _fromDate = pickedDate;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery
        .of(context)
        .size
        .height * 1;
    final width = MediaQuery
        .of(context)
        .size
        .width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child:Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                width: width * 0.6,
                child: CommonTextForm(
                    controller: SearchCategory,
                    hintText: "Search Category",
                    HintColor: Colors.grey,
                    icon: Icon(Icons.search,color: AppColors.primary,size: 30,),
                    obsecureText: false),
              ),
              SizedBox(height: 20,),
              Text('Select Date:',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontSize: 18,fontWeight: FontWeight.w500),),

              Row(
                children: [
                  InkWell(
                    onTap: () {
                      _pickDate(context);
                    },
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        width: width * 0.6,
                        height: height * 0.05,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            // color: Colors.red,
                            borderRadius: BorderRadius.circular(5)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fromDate == null
                                  ? ' DD/MM/yyyy'
                                  : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Icon(Icons.date_range)
                          ],
                        )),
                  ),
                  SizedBox(width: 10,),
                  Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle),
                      child: Icon(Icons.search,size: 30,color: Colors.white,))
                ],
              ),



              SizedBox(height: 20,),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined, color: Colors.white,),
                      Text('Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),)
                    ],)),

              SizedBox(height: 25,),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                    headingRowHeight: 50,
                    columnSpacing: 2,
                    headingRowColor: WidgetStateProperty.all(Colors.grey[300]),
                    border: TableBorder.all(
                      // borderRadius: BorderRadius.circular(5),
                        color: Colors.white),
                    decoration: BoxDecoration(
                      // borderRadius:BorderRadiusDirectional.only(topStart: Radius.circular(15),bottomStart: Radius.circular(15)),
                      // color: Colors.green,

                    ),
                    columns: [
                      DataColumn(
                          columnWidth: FixedColumnWidth(width * 0.2),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),
                              child: Text('Date',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.3),

                          // columnWidth:FlexColumnWidth(width * 0.1),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text(
                                "Category Name",  textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,
                              ))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.2),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Quantity',  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.3),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Total (Rs)',  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                    ],
                    rows: [
                      // DataRow(
                      //   cells: [
                      //     DataCell(
                      //       Center(child: Text('Farm fresh')),
                      //     ),
                      //     DataCell(
                      //       Center(child: Text('0')),
                      //     ),
                      //     DataCell(
                      //       Center(child: Text('3')),
                      //     ), DataCell(
                      //       Center(child: Text('3')),
                      //     ),
                      //   ],
                      // ),
                      // DataRow(
                      //   cells: [
                      //     DataCell(
                      //       Center(child: Text('Fruit punch')),
                      //     ),
                      //     DataCell(
                      //       Center(child: Text('0')),
                      //     ),
                      //     DataCell(
                      //       Center(child: Text('2')),
                      //     ),DataCell(
                      //       Center(child: Text('2')),
                      //     ),
                      //   ],
                      // ),
                    ]),
              )


              // DataTable(
              //
              //   columnSpacing: 3,
              //   decoration: BoxDecoration(
              //     // color: Colors.grey.shade300,
              //       shape: BoxShape.rectangle,
              //       borderRadius: BorderRadius.circular(20)
              //   ),
              //   border: TableBorder.all(
              //       borderRadius: BorderRadius.circular(5),
              //       color: Colors.transparent),
              //   columns: [
              //
              //     DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //               borderRadius: BorderRadius.only(topLeft:Radius.circular(10),bottomLeft:Radius.circular(10) )
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.2,
              //           // height: height * 0.05,
              //           child: Text("Date",textAlign: TextAlign.center,style: GoogleFonts.poppins(
              //               fontWeight: FontWeight.bold, color: Colors.black)),
              //         )),
              //
              //
              //     DataColumn(label: Container(
              //       decoration: BoxDecoration(
              //         color: Colors.grey.shade300,
              //       ),
              //       alignment: Alignment.center,
              //       width: width * 0.25,
              //       // height: height * 0.05,
              //       child: Text("Category \n Name",style: GoogleFonts.poppins(
              //           fontWeight: FontWeight.bold, color: Colors.black),textAlign: TextAlign.center,),
              //     )),
              //     DataColumn(label: Container(
              //       decoration: BoxDecoration(
              //         color: Colors.grey.shade300,
              //       ),
              //       alignment: Alignment.center,
              //       width: width * 0.2,
              //       // height: height * 0.05,
              //       child: Text("Quantity",style: GoogleFonts.poppins(
              //           fontWeight: FontWeight.bold, color: Colors.black)),
              //     )),
              //
              //     DataColumn(label: Container(
              //
              //       decoration: BoxDecoration(
              //         borderRadius: BorderRadius.only(topRight:Radius.circular(10),bottomRight:Radius.circular(10) ),
              //
              //         color: Colors.grey.shade300,
              //       ),
              //       alignment: Alignment.center,
              //       width: width * 0.2,
              //       // height: height * 0.05,
              //       child:Text("Total(Rs.)",style: GoogleFonts.poppins(
              //           fontWeight: FontWeight.bold, color: Colors.black)),
              //     )),
              //   ],
              //
              //   rows: [
              //     //
              //     // DataRow(cells: [
              //     //   DataCell(Center(child: Text("1"))),
              //     //   DataCell(Center(child: Text("Guest"))),
              //     //   DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //     //   DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //     //
              //     // ]),
              //     // DataRow(
              //     //
              //     //     cells: [
              //     //
              //     //       DataCell(Center(child: Text("2"))),
              //     //       DataCell(Center(child: Text("Guest"))),
              //     //       DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //     //       DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //     //
              //     //     ])
              //   ],
              // ),


            ],
          ),
        ),
      ),
    );
  }
}
