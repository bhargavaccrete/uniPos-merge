import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/thisweekbyvoid.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/todaybyvoid.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/yearbyvoid.dart';

import '../../../../../constants/restaurant/color.dart';
import 'customebyvoid.dart';
import 'monthbyvoid.dart';
import 'package:unipos/util/color.dart';
class VoidOrderReport extends StatefulWidget {
  const VoidOrderReport({super.key});

  @override
  State<VoidOrderReport> createState() => _VoidOrderReportState();
}

class _VoidOrderReportState extends State<VoidOrderReport> {
  String selectedFilter = "Today";

  Widget _getBody(){
    switch(selectedFilter){
      case "Today":
        return TodayByVoid();
        case "This Week":
        return WeekByVoid();
      case "Month Wise":
        return MonthbyVoid();
      case "Year Wise":
        return YearWisebyVoid();
      case "Custom":
        return CustomByVoid();
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
        backgroundColor: AppColors.primary,
        title: Text("Void Order Report",    textScaler: TextScaler.linear(1),
            style: GoogleFonts.poppins(fontSize:20,color: Colors.white,fontWeight: FontWeight.w500)
        ),
        centerTitle: true,
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios,color: Colors.white,)),
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 5,vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // Text('Refund Details',
            //   textScaler: TextScaler.linear(1),
            //   style: GoogleFonts.poppins(fontWeight: FontWeight.bold,fontSize: 18),),
            // SizedBox(height: 10,),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton('Today'),

                  SizedBox(width: 10,),
                  _filterButton('This Week'),
                  SizedBox(width: 10,),
                  _filterButton('Month Wise'),
                  SizedBox(width: 10,),
                  _filterButton('Year Wise'),
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
            backgroundColor: selectedFilter==title ? AppColors.primary: Colors.white,
            foregroundColor: selectedFilter==title ? Colors.white : AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.primary)
            )
        ),
        child: Text(title));
  }

// CommonButton;

}
