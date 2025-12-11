import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class ComparisonByMonth extends StatefulWidget {
  const ComparisonByMonth({super.key});

  @override
  State<ComparisonByMonth> createState() => _ComparisonByMonthState();
}

class _ComparisonByMonthState extends State<ComparisonByMonth> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Comparison By Month',
          textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(fontSize:20,color: Colors.white,fontWeight: FontWeight.w500)
          ,),
        centerTitle: true,
        backgroundColor: primarycolor,
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios,color: Colors.white,)),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text('Item Report',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontWeight:FontWeight.w600,fontSize: 18),),
              SizedBox(height: 10,),
              Text('Comparison of Current Month with Previous \n Month',
                textScaler: TextScaler.linear(1),
                style: GoogleFonts.poppins(fontWeight:FontWeight.w400,fontSize: 16),),

              SizedBox(height: 10,),
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
                          columnWidth:FixedColumnWidth(width *0.25),

                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  bottomLeft: Radius.circular(50),
                                ),
                              ),

                              child: Text('Details',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ))),
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
                              child: Text("Previous Month",textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),))),
                      DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,

                          columnWidth:FixedColumnWidth(width *0.35),

                          label: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Text('Current Month',textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),)))
                    ],

                    rows: [
                      DataRow(
                        cells: [
                          DataCell(
                            Center(child: Text('Total Orders',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('3',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('2',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                        ],
                      ),
                      DataRow(
                        cells: [
                          DataCell(

                            Text('Total Amount',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),),
                          ),
                          DataCell(
                            Center(child: Text('559.00',textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),)),
                          ),
                          DataCell(
                            Center(child: Text('1205.00',textScaler: TextScaler.linear(1),
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
