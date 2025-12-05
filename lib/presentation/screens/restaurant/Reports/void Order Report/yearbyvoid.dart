import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';

class YearWisebyVoid extends StatefulWidget {
  const YearWisebyVoid({super.key});

  @override
  State<YearWisebyVoid> createState() => _YearWisebyVoidState();
}

class _YearWisebyVoidState extends State<YearWisebyVoid> {
  List<dynamic> yearitem = [2025,2024,2023,2022,2021,2020,2019,2018,2017,2016];
  dynamic dropdownvalue2 = 2025 ;
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


              Text('Select Year',                          textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500)),
              SizedBox(height: 5,),

              Row(
                children: [
                  Container(
                    width: width * 0.4,
                    height: height * 0.05,
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        border: Border.all(color: primarycolor)
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton(
                          value: dropdownvalue2,
                          isExpanded: true,
                          items: yearitem.map((dynamic items){
                            return DropdownMenuItem(
                                value: items,
                                child: Text(items.toString(),textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),));
                          }).toList(), onChanged: (dynamic? newValue){
                        setState(() {
                          dropdownvalue2 = newValue!;
                        });
                      }),
                    ),
                  ),
                  SizedBox(width: 10,),
                  Container(
                    // width: width ,
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: primarycolor,
                          shape: BoxShape.circle
                      ),
                      // alignment: Alignment.bottomCenter,
                      // height: height * 0.06,'
                      child: Icon(Icons.search,size: 25,color: Colors.white,)),

                ],
              ),
              // SizedBox(height: 20,width: 20,),
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
                      Text('Export TO Excel',                          textScaler: TextScaler.linear(1),
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
                          columnWidth: FixedColumnWidth(width * 0.25),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),
                              child: Text('Date',textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.2),

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
                                "Order ID",textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,
                              ))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.4),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Customer Name',textScaler: TextScaler.linear(1),
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
                              child: Text('Mobile No',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.35),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Payment Method',textScaler: TextScaler.linear(1),
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
                              child: Text('Order Type',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth: FixedColumnWidth(width * 0.4),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Total Amount(Rs.)',textScaler: TextScaler.linear(1),
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
                              child:
                              Text('Status', textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center))),
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
                              child: Text('Details',textScaler: TextScaler.linear(1),
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

            ],
          ),
        ),
      ),
    );
  }
}
