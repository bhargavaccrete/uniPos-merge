import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbytradingsesison/daywisebytrading.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbytradingsesison/monthwisebytrading.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbytradingsesison/thisweekbytrading.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbytradingsesison/todaybytrading.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbytradingsesison/yearwisebytrading.dart';

class Salesbytrading extends StatefulWidget {
  const Salesbytrading({super.key});

  @override
  State<Salesbytrading> createState() => _SalesbytradingState();
}

class _SalesbytradingState extends State<Salesbytrading> {
  String selectedFilter = "Today";

  Widget _getBody(){
    switch(selectedFilter){
      case "Today":
        return Todaybytrading();
      case "Day Wise":
        return DayWisebytrading();
      case "This Week":
        return ThisWeekbytrading();
      case "Month Wise":
        return MonthWisebytrading();
      case "Year Wise":
        return YearWisebytrading();
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
        title: Text("Sales by Trading Session",
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
            //   child: Text('Sales By Session',
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
