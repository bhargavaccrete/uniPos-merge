import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/Discount%20Order%20Report/customebydiscount.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/Discount%20Order%20Report/thisweekbydiscount.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/Discount%20Order%20Report/todaybydiscount.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/Discount%20Order%20Report/yearbydiscount.dart';

import '../../../../../constants/restaurant/color.dart';
import 'monthbydiscount.dart';

class DiscountOrderReport extends StatefulWidget {
  const DiscountOrderReport({super.key});

  @override
  State<DiscountOrderReport> createState() => _DiscountOrderReportState();
}

class _DiscountOrderReportState extends State<DiscountOrderReport> {
  String selectedFilter = "Today";

  Widget _getBody(){
    switch(selectedFilter){
      case "Today":
        return TodayByDiscount();
        case "This Week":
        return WeekByDiscount();
      case "Month Wise":
        return MonthbyDiscount();
      case "Year Wise":
        return YearWisebyDiscount();
      case "Custom":
        return CustomByDiscount();
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
        title: Text("Discount Order Report",    textScaler: TextScaler.linear(1),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //
            // Text('Refund Details',
            //   textScaler: TextScaler.linear(1),
            //   style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: 18),),
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
