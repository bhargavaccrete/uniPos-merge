import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';


class YearWisebyComparison extends StatefulWidget {
  const YearWisebyComparison({super.key});

  @override
  State<YearWisebyComparison> createState() => _YearWisebyComparisonState();
}

class _YearWisebyComparisonState extends State<YearWisebyComparison> {
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
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text('Comparison of Current Month with Previous \n Month',
              //   textScaler: TextScaler.linear(1),
              //   style: GoogleFonts.poppins(fontWeight:FontWeight.w500,fontSize: 16),),
              // SizedBox(height: 10,),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_add_outlined,
                        color: Colors.white,
                      ),
                      Text(
                        'Export TO Excel',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),

              SizedBox(
                height: 25,
              ),

              // Container(
              //     padding: EdgeInsets.all(5),
              //     width: width,
              //     height: height * 0.06,
              //     decoration: BoxDecoration(
              //       color: Colors.grey.shade300,
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //       children: [
              //         Text(
              //           'Data',
              //           style: GoogleFonts.poppins(
              //               fontWeight: FontWeight.w500, fontSize: 16),
              //         ),
              //         Text(
              //           'Item Name',
              //           textAlign: TextAlign.center,
              //           style: GoogleFonts.poppins(
              //               fontWeight: FontWeight.w500, fontSize: 16),
              //         ),
              //         Text(
              //           'Quantity',
              //           style: GoogleFonts.poppins(
              //               fontWeight: FontWeight.w500, fontSize: 16),
              //           textAlign: TextAlign.center,
              //         ),
              //         Text(
              //           'Total(Rs.)',
              //           style: GoogleFonts.poppins(
              //               fontWeight: FontWeight.w500, fontSize: 16),
              //         ),
              //       ],
              //     ))

              // table
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
                          columnWidth:FixedColumnWidth(width *0.3),

                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),

                              child: Text('Item Name',textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          columnWidth:FixedColumnWidth(width *0.4),

                          // columnWidth:FlexColumnWidth(width * 0.1),
                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text("Previous Year\nQuantity",
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,

                          columnWidth:FixedColumnWidth(width *0.3),

                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Current Year\n Quantity',
                                  textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  textAlign: TextAlign.center)))
                    ],

                    rows: [
                      DataRow(
                        cells: [
                          DataCell(
                            Center(child: Text('Farm fresh',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('0',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('3',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                        ],
                      ),
                      DataRow(
                        cells: [
                          DataCell(
                            Center(child: Text('Fruit punch',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('0',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('2',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                        ],
                      ),
                    ]),
              )

            ],
          ),
        ),
      ),
    );
  }
}
