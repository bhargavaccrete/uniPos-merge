// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/Button.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class Salesbyitem extends StatefulWidget {
//   const Salesbyitem({super.key});
//
//   @override
//   State<Salesbyitem> createState() => _SalesbyitemState();
// }
//
// class _SalesbyitemState extends State<Salesbyitem> {
//
//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery
//         .of(context)
//         .size
//         .height * 1;
//     final width = MediaQuery
//         .of(context)
//         .size
//         .width * 1;
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(onPressed: (){
//           Navigator.pop(context);
//         }, icon: Icon(Icons.arrow_back_ios_new_outlined,color: Colors.white,)),
//         backgroundColor: primarycolor,
//         centerTitle: true,
//         title: Text('Sales By Items',style:GoogleFonts.poppins(fontWeight: FontWeight.w500,color: Colors.white)),
//       ),
//
//       body:SingleChildScrollView(
//         child: Container(
//       padding: EdgeInsets.symmetric(horizontal: 20,vertical: 10),
//           child: Column(
//             children: [
//               SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: Row(
//                   children: [
//                     CommonButton(
//                       bordercircular: 5,
//                         width: width * 0.3,
//                         height:  height * 0.04,
//                         onTap: (){}, child: Center(child: Text('Today',textAlign: TextAlign.center,style: GoogleFonts.poppins(fontSize: 16,color: Colors.white),))),
//                     SizedBox(width: 5,),
//                     CommonButton(
//                       bordercircular: 5,
//                         width: width * 0.3,
//                         height:  height * 0.04,
//                         onTap: (){}, child: Center(child: Text('Today',textAlign: TextAlign.center,style: GoogleFonts.poppins(fontSize: 16,color: Colors.white),))),
//                     SizedBox(width: 5,),
//
//                     CommonButton(
//                       bordercircular: 5,
//                         width: width * 0.3,
//                         height:  height * 0.04,
//                         onTap: (){}, child: Center(child: Text('Today',textAlign: TextAlign.center,style: GoogleFonts.poppins(fontSize: 16,color: Colors.white),))),
//                   ],
//                 ),
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }





/*
import 'package:flutter/material.dart';
import 'package:BillBerry/componets/filterButton.dart';
import 'package:BillBerry/screens/Reports/salesbyItem/daywiseitem.dart';
import 'package:BillBerry/screens/Reports/salesbyItem/monthwiseitems.dart';
import 'package:BillBerry/screens/Reports/salesbyItem/thisweek.dart';
import 'package:BillBerry/screens/Reports/salesbyItem/today.dart';
import 'package:BillBerry/screens/Reports/salesbyItem/yearwise.dart';
import 'package:BillBerry/utils/responsive_helper.dart';
import 'package:google_fonts/google_fonts.dart';

class Salesbyitem extends StatefulWidget {
  @override
  _SalesbyitemState createState() => _SalesbyitemState();
}

class _SalesbyitemState extends State<Salesbyitem> {
  String selectedFilter = "Today";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Today":
        return TodayByItem();
      case "Day Wise":
        return DayWiseItem();
      case "This Week":
        return ThisWeekItems();
      case "Month Wise Sales":
        return MonthWiseItem();
        case "Year Wise":
        return YearWiseItem();
      default:
        return Center(child: Text("No data available"));
    }
  }

  // TodayByItem();

  // Widget _dayWiseSales() {
  //   return Center(child: Text("Day Wise Sales Data"));
  // }



  // Widget _monthlySales() {
  //   return Center(child: Text("Monthly Sales Data"));
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Sales By Items",
          textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(fontSize:20,color: Colors.white),),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,color: Colors.white,),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        padding: ResponsiveHelper.responsiveSymmetricPadding(context,
        verticalPercent: 0.01,
          horizontalPercent: 0.02,
        ),
        child: Column(
          children: [

            Container(
                alignment: Alignment.bottomLeft,
                child: Text('Sales By Items',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(fontSize: 18,fontWeight: FontWeight.w500),)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Filterbutton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.05),
                      width: ResponsiveHelper.responsiveWidth(context,0.3),
                      title: 'Today',
                      selectedFilter: selectedFilter,
                      onpressed: (){
                    setState(() {
                      selectedFilter = 'Today';
                    });
                      }),
                  SizedBox(width: ResponsiveHelper.responsiveWidth(context, 0.02),),
                  Filterbutton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.05),
                      width: ResponsiveHelper.responsiveWidth(context,0.4),
                      title: 'Day Wise',
                      selectedFilter: selectedFilter,
                      onpressed: (){
                    setState(() {
                      selectedFilter = 'Day Wise';
                    });
                      }),
                  SizedBox(width: ResponsiveHelper.responsiveWidth(context, 0.02),),
                  Filterbutton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.05),
                      width: ResponsiveHelper.responsiveWidth(context,0.4),
                      title: 'This Week',
                      selectedFilter: selectedFilter,
                      onpressed: (){
                    setState(() {
                      selectedFilter = 'This Week';
                    });
                      }),
                  SizedBox(width: ResponsiveHelper.responsiveWidth(context, 0.02),),
                  Filterbutton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.05),
                      width: ResponsiveHelper.responsiveWidth(context,0.5),
                      title: 'Month Wise Sales',
                      selectedFilter: selectedFilter,
                      onpressed: (){
                    setState(() {
                      selectedFilter = 'Month Wise Sales';
                    });
                      }),
                  SizedBox(width: ResponsiveHelper.responsiveWidth(context, 0.02),),
                  Filterbutton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.05),
                      width: ResponsiveHelper.responsiveWidth(context,0.4),
                      title: 'Year wise',
                      selectedFilter: selectedFilter,
                      onpressed: (){
                    setState(() {
                      selectedFilter = 'Year Wise';
                    });
                      }),
                  SizedBox(width: ResponsiveHelper.responsiveWidth(context, 0.02),),
                  _filterButton("Today"),
                  SizedBox(width: 10,),
                  _filterButton("Day Wise"),
                  SizedBox(width: 10,),

                  _filterButton("This Week"),
                  SizedBox(width: 10,),

                  _filterButton("Month Wise Sales"),
                  SizedBox(width: 10,),

                  _filterButton("Year Wise"),
                ],
              ),
            ),
            Expanded(
              child: _getBody(),
            ),
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
        backgroundColor: selectedFilter == title ? Colors.teal : Colors.white,
        foregroundColor: selectedFilter == title ? Colors.white : Colors.teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.teal),
        ),
      ),
      child: Text(title,  textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(fontSize: 14),),
    );
  }
}
*/



// A simple data class to hold our final calculated report data

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:unipos/data/models/restaurant/db/pastordermodel_313.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyItem/thisweek.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyItem/today.dart';

import '../../../../../constants/restaurant/color.dart';
import 'ItemsReportData.dart';

class Salesbyitem extends StatefulWidget {
  @override
  _SalesbyitemState createState() => _SalesbyitemState();
}

class _SalesbyitemState extends State<Salesbyitem> {
  // State Variables
  String _selectedFilter = "Today";
  bool _isLoading = true;
  List<ItemReportData> _itemReportList = [];
  late Box<pastOrderModel> _ordersBox;

  @override
  void initState() {
    super.initState();
    // Open the Hive box and run the initial report
    _initAndLoadData();
  }

  @override
  void didUpdateWidget(covariant Salesbyitem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when returning to this screen
    _updateReportData();
  }

  Future<void> _initAndLoadData() async {
    // Box is already opened during app startup in HiveInit
    _ordersBox = Hive.box<pastOrderModel>('pastorderBox');
    _updateReportData();
  }

  void _updateReportData() {
    setState(() {
      _isLoading = true;
    });

    // Always reload from Hive to get latest data including refunds
    final allOrders = _ordersBox.values.toList();


    // --- START DEBUGGING ---
    print("---------------------------------");
    print("Checking data for filter: $_selectedFilter");
    print("Total orders found in Hive box: ${allOrders.length}");

    if (allOrders.isNotEmpty) {
      // Check the date of the very first order in the box
      print("Date of first order: ${allOrders.first.orderAt}");
      // Check if the first order has items in it
      print("Number of items in first order: ${allOrders.first.items.length}");
    }


    // Map the UI filter string to the logic string
    String periodLogicString;
    switch (_selectedFilter) {
      case "This Week":
        periodLogicString = "This Week";
        break;
      case "Month Wise Sales":
        periodLogicString = "This Month";
        break;
      case "Year Wise":
        periodLogicString = "This Year";
        break;
      case "Today":
      default:
        periodLogicString = "Today";
        break;
    }

    // Generate the report data using the functions we created
    final reportData = generateItemWiseReport(allOrders, periodLogicString);

    // Update the state with the new data
    setState(() {
      _itemReportList = reportData;
      _isLoading = false;
    });
  }

  // When a filter button is tapped
  void _onFilterSelected(String title) {
    setState(() {
      _selectedFilter = title;
      // Re-run the report logic with the new filter
      _updateReportData();
    });
  }

  Widget _getBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_itemReportList.isEmpty) {
      return const Center(child: Text("No sales data for this period."));
    }

    // Pass the calculated data to the appropriate child widget
    switch (_selectedFilter) {
      case "Today":
        return TodayByItem(reportData: _itemReportList);
      case "This Week":
        return ThisWeekItems(reportData: _itemReportList);
    // case "Day Wise":
    //   return DayWiseItem(reportData: _itemReportList); // This will need a date picker
    // case "Month Wise Sales":
    //   return MonthWiseItem(reportData: _itemReportList);
    // case "Year Wise":
    //   return YearWiseItem(reportData: _itemReportList);
      default:
      // By default, show today's data or a placeholder
        return TodayByItem(reportData: _itemReportList);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Sales By Items", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white)),
        backgroundColor: primarycolor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('Sales By Items', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500)),
            // const SizedBox(height: 8),
            // Filter Buttons Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton("Today"),
                  // _filterButton("Day Wise"), // Needs separate logic
                  _filterButton("This Week"),
                  _filterButton("Month Wise Sales"),
                  _filterButton("Year Wise"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Body of the report
            Expanded(
              child: _getBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        onPressed: () => _onFilterSelected(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedFilter == title ? primarycolor : Colors.white,
          foregroundColor: _selectedFilter == title ? Colors.white : primarycolor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side:  BorderSide(color: primarycolor),
          ),
          elevation: _selectedFilter == title ? 2 : 0,
        ),
        child: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
      ),
    );
  }
}


// --- DATA PROCESSING LOGIC WITH REFUND SUPPORT ---
// This function properly handles refunded items and quantities

List<ItemReportData> generateItemWiseReport(List<pastOrderModel> allOrders, String period) {
  final filteredOrders = filterOrders(allOrders, period);
  final Map<String, ItemReportData> itemSummary = {};

  for (final order in filteredOrders) {
    // Skip fully refunded orders
    if (order.orderStatus == 'FULLY_REFUNDED') continue;

    for (final cartItem in order.items) {
      // Calculate effective quantity (exclude refunded quantities)
      final originalQuantity = cartItem.quantity;
      final refundedQuantity = cartItem.refundedQuantity ?? 0;
      final effectiveQuantity = originalQuantity - refundedQuantity;

      // Skip items that are fully refunded
      if (effectiveQuantity <= 0) continue;

      // Calculate proportional revenue for partially refunded orders
      final orderRefundRatio = order.totalPrice > 0
          ? ((order.totalPrice - (order.refundAmount ?? 0.0)) / order.totalPrice)
          : 1.0;
      final effectiveRevenue = cartItem.totalPrice * orderRefundRatio;

      if (itemSummary.containsKey(cartItem.title)) {
        final existingItem = itemSummary[cartItem.title]!;
        existingItem.totalQuantity += effectiveQuantity;
        existingItem.totalRevenue += effectiveRevenue;
      } else {
        itemSummary[cartItem.title] = ItemReportData(
          itemName: cartItem.title,
          totalQuantity: effectiveQuantity,
          totalRevenue: effectiveRevenue,
        );
      }
    }
  }

  final reportList = itemSummary.values.toList()
    ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
  return reportList;
}

List<pastOrderModel> filterOrders(List<pastOrderModel> allOrders, String period) {
  final now = DateTime.now();
  switch (period) {
    case 'Today':
      return allOrders.where((order) => order.orderAt != null && isSameDay(order.orderAt!, now)).toList();
    case 'This Week':
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return allOrders.where((order) {
        if (order.orderAt == null) return false;
        final orderDay = DateTime(order.orderAt!.year, order.orderAt!.month, order.orderAt!.day);
        final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
        return (orderDay.isAfter(startDay) || orderDay.isAtSameMomentAs(startDay)) &&
            (orderDay.isBefore(endDay) || orderDay.isAtSameMomentAs(endDay));
      }).toList();
    case 'This Month':
      return allOrders.where((o) => o.orderAt != null && o.orderAt!.year == now.year && o.orderAt!.month == now.month).toList();
    case 'This Year':
      return allOrders.where((o) => o.orderAt != null && o.orderAt!.year == now.year).toList();
    default:
      return allOrders;
  }
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;