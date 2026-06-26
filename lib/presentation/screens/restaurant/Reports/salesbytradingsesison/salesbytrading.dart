import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbytradingsesison/daywisebytrading.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbytradingsesison/monthwisebytrading.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbytradingsesison/thisweekbytrading.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbytradingsesison/todaybytrading.dart';
import 'package:billberrylite/presentation/screens/restaurant/Reports/salesbytradingsesison/yearwisebytrading.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

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
      appBar: buildPrimaryAppBar(
        title: "Sales by Trading Session",
        centerTitle: true,
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back_ios,)),
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
