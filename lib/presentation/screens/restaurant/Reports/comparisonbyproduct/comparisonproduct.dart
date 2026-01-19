import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparisonbyproduct/monthwisecomparison.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparisonbyproduct/thisweekbycomparison.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparisonbyproduct/todaybycomparison.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparisonbyproduct/yearwisebyComparison.dart';
import 'package:unipos/util/color.dart';
class ComparisonByProduct extends StatefulWidget {
  const ComparisonByProduct({super.key});

  @override
  State<ComparisonByProduct> createState() => _ComparisonByProductState();
}

class _ComparisonByProductState extends State<ComparisonByProduct> {
  String selectedFilter = "Today";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Today":
        return TodayByComparison();
      case "This Week":
        return ThisWeekbyComparison();
      case "Month Wise":
        return MonthWisebyComparison();
      case "Year Wise":
        return YearWisebyComparison();
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
        title: Text("Comparison By Product",
            textScaler: TextScaler.linear(1),
            style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500)),
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
          children: [
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
                  _filterButton('Month Wise'),
                  SizedBox(
                    width: 10,
                  ),
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

  Widget _filterButton(String title) {
    return ElevatedButton(
        onPressed: () {
          setState(() {
            selectedFilter = title;
          });
        },
        style: ElevatedButton.styleFrom(
            backgroundColor:
            selectedFilter == title ? AppColors.primary : Colors.white,
            foregroundColor:
            selectedFilter == title ? Colors.white : AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.primary))),
        child: Text(title));
  }

// CommonButton;
}
