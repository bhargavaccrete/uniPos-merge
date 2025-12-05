import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/daywisebytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/monthwisebytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/thisweekbytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/todaybytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/yearwisebytop.dart';

import '../../../../../constants/restaurant/color.dart';

class SalesbyTop extends StatefulWidget {
  const SalesbyTop({super.key});

  @override
  State<SalesbyTop> createState() => _SalesbyTopState();
}

class _SalesbyTopState extends State<SalesbyTop> {
  String selectedFilter = "Today";

  Widget _getBody(){
    switch(selectedFilter){
      case "Today":
        return TodaybyTop();
      case "Day Wise":
        return DayWisebyTop();
      case "This Week":
        return ThisWeekbyTop();
      case "Month Wise":
        return MonthWisebyTop();
      case "Year Wise":
        return YearWisebyTop();
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
        title: Text("Sales by Top Selling",
            textScaler: TextScaler.linear(1),
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
          // Container(
          //   alignment: Alignment.bottomLeft,
          //   child: Text('Sales by Top Selling',
          //     textScaler: TextScaler.linear(1),
          //     style: GoogleFonts.poppins(
          //     fontSize: 18,fontWeight: FontWeight.w500,
          //   ),),
          // ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterButton('Today'),
                SizedBox(width: 10,),
                _filterButton('Day Wise'),
                SizedBox(width: 10,),
                _filterButton('This Week'),
                SizedBox(width: 10,),
                _filterButton('Month Wise'),
                SizedBox(width: 10,),
                _filterButton('Year Wise'),
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
          backgroundColor: selectedFilter==title ? primarycolor: Colors.white,
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
