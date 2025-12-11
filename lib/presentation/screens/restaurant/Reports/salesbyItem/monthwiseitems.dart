import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';

class MonthWiseItem extends StatefulWidget {
  const MonthWiseItem({super.key});

  @override
  State<MonthWiseItem> createState() => _MonthWiseItemState();
}

class _MonthWiseItemState extends State<MonthWiseItem> {
  TextEditingController SearchItem = TextEditingController();
  TextEditingController SearcItem = TextEditingController();
  List<String> monthitem = ['January', 'February','March', 'April', 'May','June', 'July', 'August','September','October','November','December'];
  List<dynamic> yearitem = [2025,2024,2023,2022,2021,2020,2019,2018,2017,2016];
  String dropDownValue1 = 'January';
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

              Text('Search Here:',style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w600),),
              Container(
                width: width * 0.6,
                // height: height *0.07,
                child: CommonTextForm(
                    controller: SearchController(),
                    hintText: "Search Item",
                    HintColor: Colors.grey,
                    icon: Icon(Icons.search,color: primarycolor,size: 30,),
                    obsecureText: false),
              ),

              SizedBox(height: 20,),
              // Container(
              //   // color: Colors.red,
              //   width: width* 0.8,
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceAround,
              //     children: [
              //       Text('Select Month',style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500),),
              //
              //       Text('Select Year',style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500)),
              //
              //     ],
              //   ),
              // ),
              //
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Container(
              //
              //       width: width * 0.35,
              //       height: height * 0.04,
              //       padding: EdgeInsets.all(5),
              //       decoration: BoxDecoration(
              //           border: Border.all(color: primarycolor)
              //       ),
              //       child: DropdownButtonHideUnderline(
              //         child: DropdownButton(
              //             value: dropDownValue1,
              //             isExpanded: true,
              //             items: monthitem.map((String items){
              //               return DropdownMenuItem(
              //                   value: items,
              //                   child: Text(items));
              //             }).toList(), onChanged: (String? newValue){
              //           setState(() {
              //             dropDownValue1 = newValue!;
              //           });
              //         }),
              //       ),
              //     ),
              //     Container(
              //       width: width * 0.35,
              //       height: height * 0.04,
              //       padding: EdgeInsets.all(5),
              //       decoration: BoxDecoration(
              //           border: Border.all(color: primarycolor)
              //       ),
              //       child: DropdownButtonHideUnderline(
              //         child: DropdownButton(
              //             value: dropdownvalue2,
              //             isExpanded: true,
              //             items: yearitem.map((dynamic items){
              //               return DropdownMenuItem(
              //                   value: items,
              //                   child: Text(items.toString()));
              //             }).toList(), onChanged: (dynamic? newValue){
              //           setState(() {
              //             dropdownvalue2 = newValue!;
              //           });
              //         }),
              //       ),
              //     ),
              //     Icon(Icons.search,size: 30,)
              //
              //   ],
              // ),
              // select month and year
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    // flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            child: Text(
                              'Select Month',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            )),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          width: width * 0.4,
                          height: height * 0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            // color: Colors.green,
                              border: Border.all(color: primarycolor)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                                value: dropDownValue1,
                                isExpanded: true,
                                items: monthitem.map((String items) {
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(
                                        items,
                                        textScaler: TextScaler.linear(1),
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ));
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    dropDownValue1 = newValue!;
                                  });
                                }),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Year',
                            textScaler: TextScaler.linear(1),
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          width: width * 0.4,
                          height: height * 0.05,
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            // color: Colors.red,
                              border: Border.all(color: primarycolor)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                                value: dropdownvalue2,
                                isExpanded: true,
                                items: yearitem.map((dynamic items) {
                                  return DropdownMenuItem(
                                      value: items,
                                      child: Text(
                                        items.toString(),
                                        textScaler: TextScaler.linear(1),
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ));
                                }).toList(),
                                onChanged: (dynamic? newValue) {
                                  setState(() {
                                    dropdownvalue2 = newValue!;
                                  });
                                }),
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: primarycolor,
                        borderRadius: BorderRadius.circular(50)
                    ),
                    child: Icon(
                      Icons.search,
                      size: 25,
                      color: Colors.white,
                    ),
                  )


                ],
              ),

              SizedBox(
                height: 25,
              ),
              CommonButton(
                  width: width * 0.5,
                  height: height * 0.07,
                  bordercircular: 5,
                  onTap: () {},
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
                                "Item Name",
                                textScaler: TextScaler.linear(1),
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
                              child: Text('Quantity',
                                  textScaler: TextScaler.linear(1),
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
                              child: Text('Total (Rs)',
                                  textScaler: TextScaler.linear(1),
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
              //       child: Text("Item Name",style: GoogleFonts.poppins(
              //           fontWeight: FontWeight.bold, color: Colors.black)),
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
              //
              //     DataRow(cells: [
              //       DataCell(Center(child: Text("1"))),
              //       DataCell(Center(child: Text("Guest"))),
              //       DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //       DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //
              //     ]),
              //     DataRow(
              //
              //         cells: [
              //
              //           DataCell(Center(child: Text("2"))),
              //           DataCell(Center(child: Text("Guest"))),
              //           DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //           DataCell(Center(child: Text("-",textAlign: TextAlign.center,))),
              //
              //         ])
              //   ],
              // )






              // table
              // Container(
              //   color: Colors.red,
              //   child: DataTable(
              //       columnSpacing: 0,
              //       columns: [
              //
              //     DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //               borderRadius: BorderRadius.only(topLeft: Radius
              //                   .circular(10),
              //                   bottomLeft: Radius.circular(10))
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.2,
              //           height: height * 0.04,
              //           child: Text("Date", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )), DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.25,
              //           height: height * 0.04,
              //           child: Text("Item Name", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )), DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.25,
              //           height: height * 0.04,
              //           child: Text("Quality", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )), DataColumn(
              //         label: Container(
              //           decoration: BoxDecoration(
              //               color: Colors.grey.shade300,
              //
              //           ),
              //           alignment: Alignment.center,
              //           width: width * 0.25,
              //           height: height * 0.04,
              //           child: Text("Total (RS)", textAlign: TextAlign.center,
              //               style: GoogleFonts.poppins(
              //                   fontWeight: FontWeight.bold,
              //                   color: Colors.black)),
              //         )),
              //   ],
              //       rows:[]),
              // )
            ],
          ),
        ),
      ),
    );
  }
}
