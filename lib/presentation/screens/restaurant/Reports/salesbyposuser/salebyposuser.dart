import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyposuser/todayByPosUser.dart';
import 'package:unipos/util/color.dart';
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
      case "This Week":
      case "Month Wisee":
      case "Year Wisee":
      case "Custome":
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 64, color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  'Feature Not Available',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'POS user tracking is not yet implemented in the order system.\n\nTo enable this feature, orders need to track which POS user created them.',
                  textScaler: TextScaler.linear(1),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return Center(
          child: Text('NO DATA AVAILABLE'),
        );
    }
  }
// foodchow
  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
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
            selectedFilter == title ?AppColors.primary : Colors.white,
            foregroundColor:
            selectedFilter == title ? Colors.white :AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.primary))),
        child: Text(title));
  }

// CommonButton;
}
