import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import '../../../../../constants/restaurant/color.dart';

class CustomerListByRevenue extends StatefulWidget {
  const CustomerListByRevenue({super.key});

  @override
  State<CustomerListByRevenue> createState() => _CustomerListByRevenueState();
}

class _CustomerListByRevenueState extends State<CustomerListByRevenue> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Customer List Report',
            textScaler: TextScaler.linear(1),
            style: GoogleFonts.poppins(fontSize:20,color: Colors.white,fontWeight: FontWeight.w500)
        ),
        centerTitle: true,
        backgroundColor: primarycolor,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   'Customer List By Revenue',
              //   textScaler: TextScaler.linear(1),
              //   style: GoogleFonts.poppins(
              //       fontWeight: FontWeight.w600, fontSize: 18),
              // ),
              //
              // SizedBox(
              //   height: 25,
              // ),
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

              DataTable(
                headingRowHeight: 50,
                columnSpacing: 3,
                headingRowColor: WidgetStateProperty.all(Colors.grey[300]),

                decoration: BoxDecoration(
                  // color: Colors.grey.shade300,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20)),
                border: TableBorder.all(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.white),
                columns: [
                  DataColumn(
                      headingRowAlignment: MainAxisAlignment.center,

                      label: Container(
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10))),
                        alignment: Alignment.center,
                        width: width * 0.15,
                        // height: height * 0.05,
                        child: Text("Sr No",
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 14),),
                      )),
                  DataColumn(
                      label: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                        ),
                        alignment: Alignment.center,
                        width: width * 0.3,
                        // height: height * 0.05,
                        child: Text("Customber\n  Name",
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 14),),
                      )),
                  DataColumn(
                      label: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                        ),
                        alignment: Alignment.center,
                        width: width * 0.2,
                        // height: height * 0.05,
                        child: Text("Mobile",
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 14),),
                      )),
                  DataColumn(
                      label: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10)),
                          color: Colors.grey.shade300,
                        ),
                        alignment: Alignment.center,
                        width: width * 0.3,
                        // height: height * 0.05,
                        child: Text("Revenue",
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 14),),
                      )),
                ],
                rows: [
                  DataRow(cells: [
                    DataCell(Center(child: Text("1"))),
                    DataCell(Center(child: Text("Guest"))),
                    DataCell(Center(
                        child: Text(
                          "-",
                          textAlign: TextAlign.center,
                        ))),
                    DataCell(Center(
                        child: Text(
                          "559",
                          textAlign: TextAlign.center,
                        ))),
                  ]),
                  DataRow(cells: [
                    DataCell(Center(child: Text("2"))),
                    DataCell(Center(child: Text("Guest"))),
                    DataCell(Center(
                        child: Text(
                          "-",
                          textAlign: TextAlign.center,
                        ))),
                    DataCell(Center(
                        child: Text(
                          "559",
                          textAlign: TextAlign.center,
                        ))),
                  ])
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
