import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyposuser/todayByPosUser.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/customebyvoid.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/monthbyvoid.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/thisweekbyvoid.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/yearbyvoid.dart';

class SalesByPOsUSer extends StatefulWidget {
  const SalesByPOsUSer({super.key});

  @override
  State<SalesByPOsUSer> createState() => _SalesByPOsUSerState();
}

class _SalesByPOsUSerState extends State<SalesByPOsUSer> {
  String selectedFilter = "Today";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Today":
        return TodayByposUser();
      case "Week Wise":
        return WeekByVoid();
      case "Month Wise":
        return MonthbyVoid();
      case "Year Wise":
        return YearWisebyVoid();
      case "Custome":
        return CustomByVoid();
      default:
        return Center(
          child: Text('NO DATA AVAILABE'),
        );
    }
  }
// foodchow
  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primarycolor,
        title: Text(
          "Sales By Pos User",
          textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   'Sales By Pos User',
            //   textScaler: TextScaler.linear(1),
            //   style: GoogleFonts.poppins(
            //       fontWeight: FontWeight.w500, fontSize: 16),
            // ),
            // SizedBox(
            //   height: 10,
            // ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton('Today'),
                  SizedBox(
                    width: 10,
                  ),
                  _filterButton('This Week'),
                  SizedBox(
                    width: 10,
                  ),
                  _filterButton('Month Wisee'),
                  SizedBox(
                    width: 10,
                  ),
                  _filterButton('Year Wisee'),
                  SizedBox(
                    width: 10,
                  ),
                  _filterButton('Custome'),
                ],
              ),
            ),
            Expanded(child: _getBody())
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String title) {
    return ElevatedButton(
        onPressed: () {
          setState(() {
            selectedFilter = title;
          });
        },
        style: ElevatedButton.styleFrom(
            backgroundColor:
                selectedFilter == title ?primarycolor : Colors.white,
            foregroundColor:
                selectedFilter == title ? Colors.white :primarycolor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: primarycolor))),
        child: Text(title));
  }

// CommonButton;
}
