import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/eodmodel_317.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/dailyClosingReports/customedaily.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/dailyClosingReports/daywisedaily.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/dailyClosingReports/monthwisedaily.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyClosingReport extends StatefulWidget {
  const DailyClosingReport({super.key});

  @override
  State<DailyClosingReport> createState() => _DailyClosingReportState();
}

class _DailyClosingReportState extends State<DailyClosingReport> {
  String selectedFilter = "Day Wise";

  Widget _getBody(){
    switch(selectedFilter){
      case "Day Wise":
        return DayWisebyDaily();
      case "MonthWise":
        return MonthWisebyDaily();
      case "Custom":
        return CustomeDaily();
      default:
        return Center(
          child: Text('NO DATA AVAILABE'),
        );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primarycolor,
        title: Text("Daily Closing Report",    textScaler: TextScaler.linear(1),
            style: GoogleFonts.poppins(fontSize:20,color: Colors.white,fontWeight: FontWeight.w500)
        ),
        centerTitle: true,
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios,color: Colors.white,)),
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
        child: Column(
          children: [
          //   Container(
          //     alignment: Alignment.bottomLeft,
          //     child: Text('Daily Closing Report',
          //         textScaler: TextScaler.linear(1)
          // ,style: GoogleFonts.poppins(
          //       fontSize: 18,fontWeight: FontWeight.w600,
          //     ),),
          //   ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [

                  _filterButton('Day Wise'),
                  SizedBox(width: 10,),
                  _filterButton('MonthWise'),
                  SizedBox(width: 10,),
                  _filterButton('Custom'),
                ],
              ),
            ),
            Expanded(child: _getBody())


          ],
        ),
      ),
    );

  }

  Widget _filterButton(String title){
    return ElevatedButton(
        onPressed: (){
          setState(() {
            selectedFilter = title;
          });

        },

        style: ElevatedButton.styleFrom(
            backgroundColor: selectedFilter==title ? primarycolor : Colors.white,
            foregroundColor: selectedFilter==title ? Colors.white : primarycolor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: primarycolor)
            )
        ),
        child: Text(title));
  }

// CommonButton;

}
