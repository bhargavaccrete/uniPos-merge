/*
import 'package:flutter/material.dart';
import 'package:BillBerry/componets/Button.dart';
import 'package:BillBerry/componets/Textform.dart';
import 'package:BillBerry/constant/color.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ItemsReportData.dart';

class TodayByItem extends StatefulWidget {
  final List<ItemReportData> reportData;
  const TodayByItem({super.key,
    required this.reportData,
  });

  @override
  State<TodayByItem> createState() => _TodayByItemState();
}

class _TodayByItemState extends State<TodayByItem> {
  TextEditingController SearchController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: width * 0.6,
                // height: height * 0.06,
                child: CommonTextForm(
                  controller: SearchController,
                    hintText: "Search Item",
                    HintColor: Colors.grey,
                    icon: Icon(
                      Icons.search,
                      color: primarycolor,
                      size: 30,
                    ),
                    obsecureText: false),
              ),

              SizedBox(
                height: 20,
              ),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
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

              // Container(
              //   padding: EdgeInsets.all(5),
              //   width: width ,
              //     height: height * 0.05,
              //     decoration: BoxDecoration(
              //       color: Colors.grey.shade300,
              //       borderRadius: BorderRadius.circular(12),
              //
              //     ),
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //       children: [
              //         Text('Data',style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: 18),),
              //         Text('Item Name',style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: 18),),
              //         Text('Quality',style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: 18),),
              //         Text('Total(Rs.)',style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: 18),),
              //       ],
              //     )),

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
            ],
          ),
        ),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';

import '../../../../widget/componets/restaurant/componets/Button.dart';
import 'ItemsReportData.dart';

class TodayByItem extends StatefulWidget {
  // 1. This widget accepts the report data from its parent
  final List<ItemReportData> reportData;

  const TodayByItem({
    Key? key,
    required this.reportData,
  }) : super(key: key);

  @override
  State<TodayByItem> createState() => _TodayByItemState();
}

class _TodayByItemState extends State<TodayByItem> {
  // Use a private controller for good practice
  final TextEditingController _searchController = TextEditingController();
  // 2. State variable to hold the data that is currently visible in the table
  List<ItemReportData> _filteredData = [];

  @override
  void initState() {
    super.initState();
    // Initially, the filtered list is the full list passed to the widget
    _filteredData = widget.reportData;
    // 3. Add a listener that calls _filterItems whenever the search text changes
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    // 4. Clean up the controller and listener to prevent memory leaks
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      // We always filter from the original, complete list of data
      _filteredData = widget.reportData.where((item) {
        final itemNameLower = item.itemName.toLowerCase();
        return itemNameLower.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: width * 0.6,
                child: CommonTextForm(
                    controller: _searchController, // Connect the controller
                    hintText: "Search Item",
                    HintColor: Colors.grey,
                    icon: Icon(
                      Icons.search,
                      color: primarycolor,
                      size: 30,
                    ),
                    obsecureText: false),
              ),
              const SizedBox(height: 20),
              CommonButton(
                  width: width * 0.6,
                  height: height * 0.06,
                  bordercircular: 5,
                  onTap: () {
                    // TODO: Implement Excel export logic.
                    // You can use the `_filteredData` list to export the currently visible items.
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_add_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Export TO Excel',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      )
                    ],
                  )),
              const SizedBox(height: 25),

              // Use LayoutBuilder to prevent overflow errors with DataTable
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                          headingRowHeight: 50,
                          columnSpacing: 20,
                          headingRowColor:
                          WidgetStateProperty.all(Colors.grey[200]),
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columns: [
                            // 5. Columns are updated to match the data
                            DataColumn(
                                label: Text('Item Name',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Quantity',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Total (Rs)',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold))),
                          ],
                          // 6. Rows are now dynamically generated from your filtered data list
                          rows: _filteredData.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.itemName)),
                                DataCell(Center(
                                    child:
                                    Text(item.totalQuantity.toString()))),
                                DataCell(Center(
                                    child: Text(
                                        '₹${item.totalRevenue.toStringAsFixed(2)}'))),
                              ],
                            );
                          }).toList()),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}