import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class ThisWeekTab extends StatefulWidget {
  const ThisWeekTab({super.key});

  @override
  State<ThisWeekTab> createState() => _ThisWeekTabState();
}

class _ThisWeekTabState extends State<ThisWeekTab> {
  @override
  Widget build(BuildContext context) {

    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CommonButton
              CommonButton(
                  width:width * 0.5 ,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: (){},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_add_outlined,color: Colors.white,),
                      Text('Export TO Excel',
                        textScaler: TextScaler.linear(1),

                        style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500),)
                    ],)),

              SizedBox(height: 25,),

              Text('Total Sales Of Today(Rs.)=0',                          textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontSize: 16,fontWeight:FontWeight.w500, color: Colors.black),),
              SizedBox(height: 25,),

              Text('Total Order Count = 0',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontSize: 16,fontWeight:FontWeight.w500, color: Colors.black),),

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
                              child: Text('Date',
                                textScaler: TextScaler.linear(1),
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
                                "Invoice ID",
                                textScaler: TextScaler.linear(1),
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
                              child: Text('Customer Name',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
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
                              child: Text('Mobile No',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
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
                              child: Text('Payment Method',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
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
                              child: Text('Order Type',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
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
                              child: Text('Total Amount(Rs.)',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
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
                              child: Text('Details',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                                textAlign: TextAlign.center,))),
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



              // SingleChildScrollView(
              //   scrollDirection: Axis.horizontal,
              //   child:DataTable(
              //     columnSpacing: 5,
              //     decoration: BoxDecoration(
              //       // color: Colors.grey.shade300,
              //         shape: BoxShape.rectangle,
              //         borderRadius: BorderRadius.circular(20)
              //     ),
              //     border: TableBorder.all(
              //         borderRadius: BorderRadius.circular(5),
              //         color: Colors.transparent),
              //     columns: [
              //
              //       DataColumn(
              //           label: Container(
              //             decoration: BoxDecoration(
              //                 color: Colors.grey.shade300,
              //                 borderRadius: BorderRadius.only(topLeft:Radius.circular(10),bottomLeft:Radius.circular(10) )
              //             ),
              //             alignment: Alignment.center,
              //             width: width * 0.2,
              //             height: height * 0.04,
              //             child: Text("Date",textAlign: TextAlign.center,style: GoogleFonts.poppins(
              //                 fontWeight: FontWeight.bold, color: Colors.black)),
              //           )),
              //       DataColumn(
              //
              //           label: Container(
              //             decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //             ),
              //             alignment: Alignment.center,
              //             width: width * 0.2,
              //             height: height * 0.04,
              //             child: Text("Invoice ID",style: GoogleFonts.poppins(
              //                 fontWeight: FontWeight.bold, color: Colors.black)),
              //           )),
              //
              //       DataColumn(label: Container(
              //         decoration: BoxDecoration(
              //           color: Colors.grey.shade300,
              //         ),
              //         alignment: Alignment.center,
              //         width: width * 0.4,
              //         height: height * 0.04,
              //         child: Text("Customber Name",style: GoogleFonts.poppins(
              //             fontWeight: FontWeight.bold, color: Colors.black)),
              //       )),
              //       DataColumn(label: Container(
              //         decoration: BoxDecoration(
              //           color: Colors.grey.shade300,
              //         ),
              //         alignment: Alignment.center,
              //         width: width * 0.3,
              //         height: height * 0.04,
              //         child: Text("Mobile No",style: GoogleFonts.poppins(
              //             fontWeight: FontWeight.bold, color: Colors.black)),
              //       )),
              //       DataColumn(label: Container(
              //         decoration: BoxDecoration(
              //           color: Colors.grey.shade300,
              //         ),
              //         alignment: Alignment.center,
              //         width: width * 0.4,
              //         height: height * 0.04,
              //         child:Text("Payment Method",style: GoogleFonts.poppins(
              //             fontWeight: FontWeight.bold, color: Colors.black)),
              //       )),
              //       DataColumn(label: Container(
              //         decoration: BoxDecoration(
              //           color: Colors.grey.shade300,
              //         ),
              //         alignment: Alignment.center,
              //         width: width * 0.3,
              //         height: height * 0.04,
              //         child: Text("Order Type",style: GoogleFonts.poppins(
              //             fontWeight: FontWeight.bold, color: Colors.black)),
              //       )),
              //       DataColumn(label: Container(
              //         decoration: BoxDecoration(
              //           color: Colors.grey.shade300,
              //         ),
              //         alignment: Alignment.center,
              //         width: width * 0.4,
              //         height: height * 0.04,
              //         child: Text("Total Amount (Rs)",style: GoogleFonts.poppins(
              //             fontWeight: FontWeight.bold, color: Colors.black)),
              //       )),
              //       DataColumn(label: Container(
              //
              //         decoration: BoxDecoration(
              //           borderRadius: BorderRadius.only(topRight:Radius.circular(10),bottomRight:Radius.circular(10) ),
              //
              //           color: Colors.grey.shade300,
              //         ),
              //         alignment: Alignment.center,
              //         width: width * 0.2,
              //         height: height * 0.04,
              //         child:Text("Details",style: GoogleFonts.poppins(
              //             fontWeight: FontWeight.bold, color: Colors.black)),
              //       )),
              //     ], rows: [],
              //
              //     // rows: [
              //     //   DataRow(cells: [
              //     //     DataCell(Center(child: Text("26-3-2025"))),
              //     //     DataCell(Center(child: Text("POS01-001"))),
              //     //     DataCell(Center(child: Text("Guest",textAlign: TextAlign.center,))),
              //     //     DataCell(Center(child: Text("-"))),
              //     //     DataCell(Center(child: Text("Cash"))),
              //     //     DataCell(Center(child: Text("Take Away"))),
              //     //     DataCell(Center(child: Text("205"))),
              //     //     DataCell(
              //     //         CommonButton(
              //     //
              //     //           bordercircular: 20,
              //     //           width: width * 0.2,
              //     //           height: height * 0.04,
              //     //           child: Text('ITEMS',style: TextStyle(color: Colors.white),textAlign: TextAlign.center,),
              //     //           onTap: (){},
              //     //         )),
              //     //   ]),
              //     //   DataRow(
              //     //
              //     //       cells: [
              //     //         DataCell(Center(child: Text("26-3-2025"))),
              //     //         DataCell(Center(child: Text("POS01-001"))),
              //     //         DataCell(Center(child: Text("Guest",textAlign: TextAlign.center,))),
              //     //         DataCell(Center(child: Text("-"))),
              //     //         DataCell(Center(child: Text("Cash"))),
              //     //         DataCell(Center(child: Text("Take Away"))),
              //     //         DataCell(Center(child: Text("205"))),
              //     //         DataCell(
              //     //             CommonButton(
              //     //
              //     //               bordercircular: 20,
              //     //               width: width * 0.2,
              //     //               height: height * 0.04,
              //     //               child: Text('ITEMS',style: TextStyle(color: Colors.white),textAlign: TextAlign.center,),
              //     //               onTap: (){},
              //     //             )),
              //     //       ])
              //     // ],
              //   ),
              //
              //
              // )

            ],
          ),
        ),
      ),
    );
  }
}
