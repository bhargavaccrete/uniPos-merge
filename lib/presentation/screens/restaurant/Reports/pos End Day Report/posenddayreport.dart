import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';


class Posenddayreport extends StatefulWidget {
  const Posenddayreport({super.key});

  @override
  State<Posenddayreport> createState() => _PosenddayreportState();
}

class _PosenddayreportState extends State<Posenddayreport> {
  DateTime? _selectedDate;
  List<String> userlist = [
    'Admin User',
    'James 1 ',
    'Aria Cyrus',
    'danial kin'
  ];
  String dropvalue = 'Admin User';

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports() async {
    // Use eodStore instead of direct Hive access
    await eodStore.loadEODReports();
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  List<EndOfDayReport> _getFilteredReports() {
    if (_selectedDate == null) {
      return eodStore.eodReports;
    }

    return eodStore.eodReports.where((report) {
      return report.date.year == _selectedDate!.year &&
          report.date.month == _selectedDate!.month &&
          report.date.day == _selectedDate!.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: Text('Pos End Day Report',
              textScaler: TextScaler.linear(1),
              style: GoogleFonts.poppins(fontSize:20,color: Colors.white,fontWeight: FontWeight.w500)
          ),
          centerTitle: true,
          leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.arrow_back_ios, color: Colors.white))),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   'End Day Report',
                //   style: GoogleFonts.poppins(
                //       fontWeight: FontWeight.w500, fontSize: 16),
                // ),
                // SizedBox(
                //   height: 25,
                // ),
                Text(
                  'Select User:',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  height: 10,
                ),
                // dropdownbutton
                Container(
                  width: width * 0.5,
                  height: height *0.06,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                      // dropdownColor: AppColors.primary,
                        value: dropvalue,
                        items: userlist.map((String items) {
                          return DropdownMenuItem(
                              value: items,
                              child: Text(
                                items,textAlign: TextAlign.center,
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ));
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            dropvalue = newValue!;
                          });
                        }),
                  ),
                ),

                SizedBox(height: 25,),

                Row(
                  children: [
                    InkWell(
                      onTap: (){
                        _pickDate(context);
                      },
                      child: Container(
                        width: width * 0.4,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(5)
                        ),
                        child:Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedDate ==null?
                            'DD/MM/YYYY'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Icon(Icons.date_range,color: AppColors.primary,)
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 25,),
                    InkWell(
                      onTap: () {
                        setState(() {}); // Refresh UI with filtered data
                      },
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(50)
                        ),
                        child: Icon(
                          Icons.search,
                          size: 25,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 25,
                ),
                // Refresh Button
                CommonButton(
                    width: width * 0.3,
                    height: height * 0.05,
                    bordercircular: 5,
                    onTap: _loadAllReports,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Refresh',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontWeight: FontWeight.w500),
                        )
                      ],
                    )),
                SizedBox(height: 10,),
                // Export Button
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
                SizedBox(height: 20,),
                // Use Observer to reactively update UI based on store state
                Observer(
                  builder: (_) {
                    if (eodStore.isLoading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final filteredReports = _getFilteredReports();

                    if (filteredReports.isEmpty) {
                      return Center(
                        child: Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                _selectedDate != null
                                    ? 'No End Day Report found for selected date'
                                    : 'No End Day Reports found',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Complete End Day process to see reports here',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
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
                            columnWidth: FixedColumnWidth(width * 0.4),
                            label: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(50),
                                    bottomLeft: Radius.circular(50),
                                  ),
                                ),
                                child: Text('Opening Date',textScaler: TextScaler.linear(1),
                                  style: GoogleFonts.poppins(fontSize: 14),))),
                        DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            columnWidth: FixedColumnWidth(width * 0.4),

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
                                  "Closing Date",textScaler: TextScaler.linear(1),
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
                                child: Text('Opening Balance(Rs.)',textScaler: TextScaler.linear(1),
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
                                child: Text('Closing Balance(Rs.)',textScaler: TextScaler.linear(1),
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
                                child: Text('Actual Cash(Rs.)',textScaler: TextScaler.linear(1),
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
                                child: Text('Cash(Rs.)',textScaler: TextScaler.linear(1),
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
                                child: Text('Card (Rs.)',textScaler: TextScaler.linear(1),
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
                                child: Text('Online(Rs.)',textScaler: TextScaler.linear(1),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    textAlign: TextAlign.center))),

                      ],
                      rows: filteredReports.map((report) {
                        final dateFormatter = DateFormat('dd/MM/yyyy');
                        final timeFormatter = DateFormat('HH:mm');

                        // Calculate payment summaries
                        double cashAmount = 0.0;
                        double cardAmount = 0.0;
                        double onlineAmount = 0.0;

                        for (var payment in report.paymentSummaries) {
                          if (payment.paymentType.toLowerCase() == 'cash') {
                            cashAmount = payment.totalAmount;
                          } else if (payment.paymentType.toLowerCase() == 'card') {
                            cardAmount = payment.totalAmount;
                          } else if (payment.paymentType.toLowerCase() == 'online' ||
                              payment.paymentType.toLowerCase() == 'upi') {
                            onlineAmount = payment.totalAmount;
                          }
                        }

                        return DataRow(
                          cells: [
                            DataCell(
                              Center(child: Text(
                                '${dateFormatter.format(report.date)} ${timeFormatter.format(report.date)}',
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                '${dateFormatter.format(report.date)} ${timeFormatter.format(report.date.add(Duration(hours: 8)))}',
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                report.openingBalance.toStringAsFixed(2),
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                report.closingBalance.toStringAsFixed(2),
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                report.cashReconciliation.actualCash.toStringAsFixed(2),
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                cashAmount.toStringAsFixed(2),
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                cardAmount.toStringAsFixed(2),
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                            DataCell(
                              Center(child: Text(
                                onlineAmount.toStringAsFixed(2),
                                style: GoogleFonts.poppins(fontSize: 12),
                              )),
                            ),
                          ],
                        );
                      }).toList()),
                    );
                  },
                )
              ]),
        ),
      ),
    );
  }
}
