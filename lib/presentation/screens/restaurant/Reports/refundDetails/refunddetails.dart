import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/refundDetails/monthbyrefund.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/refundDetails/thisweekbyrefund.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/refundDetails/todaybyrefund.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/refundDetails/yearbyrefund.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/orderDetails.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

import 'customebyrefund.dart';

class RefundDetails extends StatefulWidget {
  const RefundDetails({super.key});

  @override
  State<RefundDetails> createState() => _RefundDetailsState();
}

class _RefundDetailsState extends State<RefundDetails> {
  String selectedFilter = "Today";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Today":
        return TodayByRefund();
      case "Custom":
        return CustomByRefund();
      case "Week Wise":
        return WeekByRefund();
      case "Month Wise":
        return Monthbyrefund();
      case "Year Wise":
        return YearWisebyRefund();
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
        title: Text("Refund Details",
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(
            //   'Refund Details',
            //   textScaler: TextScaler.linear(1),
            //   style: GoogleFonts.poppins(
            //       fontWeight: FontWeight.w500, fontSize: 18),
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
                  _filterButton('Custom'),
                  SizedBox(
                    width: 10,
                  ),
                  _filterButton('Week Wise'),
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
            selectedFilter == title ? AppColors.primary: Colors.white,
            foregroundColor:
            selectedFilter == title ? Colors.white : AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.primary))),
        child: Text(title));
  }

// CommonButton;
}