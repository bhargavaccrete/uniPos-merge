// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/custom_menu.dart';
// import 'package:BillBerry/componets/listmenu.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/screens/Reports/Discount%20Order%20Report/dicountOrderReport.dart';
// import 'package:BillBerry/screens/Reports/comparison/comparisonbymonth.dart';
// import 'package:BillBerry/screens/Reports/comparison/comparisonbyweek.dart';
// import 'package:BillBerry/screens/Reports/comparison/comparisonbyyear.dart';
// import 'package:BillBerry/screens/Reports/comparisonbyproduct/comparisonproduct.dart';
// import 'package:BillBerry/screens/Reports/customer%20list%20by%20revenue/customerlistbyrevenue.dart';
// import 'package:BillBerry/screens/Reports/customerList/customerlist.dart';
// import 'package:BillBerry/screens/Reports/dailyClosingReports/dailyclosing.dart';
// import 'package:BillBerry/screens/Reports/pos%20End%20Day%20Report/posenddayreport.dart';
// import 'package:BillBerry/screens/Reports/refundDetails/refunddetails.dart';
// import 'package:BillBerry/screens/Reports/salesbyCategory/salesbycategory.dart';
// import 'package:BillBerry/screens/Reports/salesbyItem/salesbyitem.dart';
// import 'package:BillBerry/screens/Reports/salesbyTop/salesbytop.dart';
// import 'package:BillBerry/screens/Reports/salesbyposuser/salebyposuser.dart';
// import 'package:BillBerry/screens/Reports/salesbytradingsesison/salesbytrading.dart';
// import 'package:BillBerry/screens/Reports/totalsales/totalsales.dart';
// import 'package:BillBerry/screens/Reports/void%20Order%20Report/voidOrderReport.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class ReportsScreen extends StatefulWidget {
//   const ReportsScreen({super.key});
//
//   @override
//   State<ReportsScreen> createState() => _ReportsScreenState();
// }
//
// class _ReportsScreenState extends State<ReportsScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         leading: IconButton(onPressed: (){
//           Navigator.pop(context);
//         },
//           icon: Icon(Icons.arrow_back_ios_new),color: Colors.white,),
//         centerTitle: true,
//         title: Text('Operational Reports',
//           textScaler: TextScaler.linear(1),
//
//           style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500),),
//         backgroundColor: primarycolor,
//
//       ),
//       body: SingleChildScrollView(
//         child: Container(
//           padding: EdgeInsets.all(30),
//           child: Column(
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                       onTap: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context)=> Totalsales() ));
//                       },
//                       icons: Icons.shopping_bag_outlined,
//                       title: 'Total Sale'),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                       onTap: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context)=> Salesbyitem()));
//                       },
//                       icons: Icons.fastfood,color: Colors.deepOrangeAccent,
//                       title: 'Sales BY Items'),
//                 ],
//               ),
//               SizedBox(
//                 height: 15,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> SalesbyCategory()));
//                     },
//                     icons: Icons.category,
//                     color: Colors.deepOrangeAccent,
//                     title: 'Sale By Category',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                       onTap: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context)=> Salesbytrading()));
//
//                       },
//                       icons: Icons.trolley,
//                       color: Colors.deepOrangeAccent,
//                       title: 'Sales By Trading'),
//                 ],
//               ),
//               SizedBox(
//                 height: 15,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> DailyClosingReport()));
//
//                     },
//                     icons: Icons.auto_graph,
//                     color: Colors.deepOrangeAccent,
//                     title: 'Daily Closing Reports',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                       onTap: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context)=> SalesbyTop()));
//
//                       },
//                       icons: Icons.graphic_eq_outlined,
//                       color: Colors.deepOrangeAccent,
//                       title: 'Sales By Top Selling'),
//                 ],
//               ),
//               SizedBox(
//                 height: 15,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> CustomerListReport()));
//
//                     },
//                     icons: Icons.list_alt,
//                     color: primarycolor,
//                     title: 'Customer List',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                       onTap: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context)=> CustomerListByRevenue()));
//                       },
//                       icons: Icons.monetization_on_outlined,
//                       color: Colors.deepOrangeAccent,
//                       title: 'Customer List BY \n      Revenue'),
//                 ],
//               ),
//
//               SizedBox(
//                 height: 15,
//               ),
//
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> ComparisonByWeek()));
//
//                     },
//                     icons: Icons.view_week,
//                     color: primarycolor,
//                     title: 'Coparision BY Week',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> ComparisonByMonth()));
//
//                     },
//                     icons: Icons.view_week,
//                     color: primarycolor,
//                     title: 'Coparision BY Month',
//                   ),
//                 ],
//               ),SizedBox(
//                 height: 15,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> ComparisonByYear()));
//
//                     },
//                     icons: Icons.view_week,
//                     color: primarycolor,
//                     title: 'Coparision BY Year',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> ComparisonByProduct()));
//
//                     },
//                     icons: Icons.view_week,
//                     color: primarycolor,
//                     title: 'Coparision BY Product',
//                   ),
//                 ],
//               ),
//
//               SizedBox(
//                 height: 15,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> RefundDetails()));
//
//                     },
//                     icons: Icons.backspace_outlined,
//                     color: primarycolor,
//                     title: 'Refund Details',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> VoidOrderReport()));
//
//                     },
//                     icons: Icons.list_alt,
//                     color: primarycolor,
//                     title: 'Void Order Report',
//                   ),
//                 ],
//               ), SizedBox(
//                 height: 15,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> DiscountOrderReport()));
//
//                     },
//                     icons: Icons.note_alt_outlined,
//                     color: Colors.deepOrangeAccent,
//                     title: '    Discount Order     \n        Reports',
//                   ),
//                   SizedBox(
//                     width: 5,
//                   ),
//                   CustomMenu(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context)=> Posenddayreport()));
//
//                     },
//                     icons: Icons.list_alt,
//                     color: primarycolor,
//                     title: 'Pos End Day',
//                   ),
//
//                  ],
//               ),
//               SizedBox(height: 15,),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 children: [
//                   CustomMenu(onTap: (){
//                     Navigator.push(context, MaterialPageRoute(builder: (context)=>SalesByPOsUSer()));
//
//                   },
//                       icons: Icons.shopping_cart_sharp, title: 'Sales By Pos User'),
//                 ],
//               )
//
//
//
//
//
//
//
//
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/Discount%20Order%20Report/dicountOrderReport.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparison/comparisonbymonth.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparison/comparisonbyweek.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparison/comparisonbyyear.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/comparisonbyproduct/comparisonproduct.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/customer%20list%20by%20revenue/customerlistbyrevenue.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/customerList/customerlist.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/performance_statistics_report.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/pos%20End%20Day%20Report/posenddayreport.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/refundDetails/refunddetails.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyCategory/salesbycategory.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyItem/salesbyitem.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyTop/salesbytop.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbyposuser/salebyposuser.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/salesbytradingsesison/salesbytrading.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/totalsales/totalsales.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/void%20Order%20Report/voidOrderReport.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../core/routes/routes_name.dart';
import '../../../widget/componets/restaurant/componets/custom_menu.dart';
import 'dailyClosingReports/dailyclosing.dart';
import 'expenseReport/expensereport.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(onPressed: (){
          Navigator.pop(context);
        },
          icon: Icon(Icons.arrow_back_ios_new),color: Colors.white,),
        centerTitle: true,
        title: Text('Operational Reports',
          textScaler: TextScaler.linear(1),

          style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.responsiveTextSize(context, 20),
              color: Colors.white,fontWeight: FontWeight.w500),),
        backgroundColor: primarycolor,

      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(30),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomMenu(
                      onTap: () {
                        // Navigator.push(context, MaterialPageRoute(builder: (context)=> Totalsales() ));

                        Navigator.pushNamed(context, RouteNames.restaurantReportsTotalSales);

                      },
                      icons: Icons.shopping_bag_outlined,
                      title: 'Total Sale'),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                      onTap: () {
                        // Navigator.push(context, MaterialPageRoute(builder: (context)=> Salesbyitem()));
                        Navigator.pushNamed(context, RouteNames.restaurantReportsSalesBYItem);
                      },
                      icons: Icons.fastfood,color: Colors.deepOrangeAccent,
                      title: 'Sales BY Items'),
                ],
              ),
              SizedBox(
                height: 15,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomMenu(
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=> SalesbyCategory()));
                      Navigator.pushNamed(context, RouteNames.restaurantReportsSalesByCategory);
                    },
                    icons: Icons.category,
                    color: Colors.deepOrangeAccent,
                    title: 'Sale By Category',
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=> DailyClosingReport()));

                      Navigator.pushNamed(context, RouteNames.restaurantReportsDailyClosingReport);

                    },
                    icons: Icons.auto_graph,
                    color: Colors.deepOrangeAccent,
                    title: 'Daily Closing Reports',
                  ),

                ],
              ),
              SizedBox(
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [


                  CustomMenu(
                      onTap: () {
                        // Navigator.push(context, MaterialPageRoute(builder: (context)=> SalesbyTop()));

                        Navigator.pushNamed(context, RouteNames.restaurantReportsSalesByTop);


                      },
                      icons: Icons.graphic_eq_outlined,
                      color: Colors.deepOrangeAccent,
                      title: 'Sales By Top Selling'),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=> CustomerListReport()));

                      Navigator.pushNamed(context, RouteNames.restaurantReportsCustomerList);

                    },
                    icons: Icons.list_alt,
                    color: primarycolor,
                    title: 'Customer List',
                  ),

                ],
              ),


              SizedBox(
                height: 15,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomMenu(
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=> ComparisonByWeek()));
                      Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByWeek);
                    },
                    icons: Icons.view_week,
                    color: primarycolor,
                    title: 'Coparision BY Week',
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                    onTap: () {
                      Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByMonth);

                    },
                    icons: Icons.view_week,
                    color: primarycolor,
                    title: 'Coparision BY Month',
                  ),
                ],
              ),SizedBox(
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomMenu(
                    onTap: () {
                      Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByYear);

                    },
                    icons: Icons.view_week,
                    color: primarycolor,
                    title: 'Coparision BY Year',
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                    onTap: () {
                      Navigator.pushNamed(context, RouteNames.restaurantReportsComparisionByProduct);

                    },
                    icons: Icons.view_week,
                    color: primarycolor,
                    title: 'Coparision BY Product',
                  ),
                ],
              ),

              SizedBox(
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomMenu(
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=> RefundDetails()));

                      Navigator.pushNamed(context, RouteNames.restaurantReportsRefundDetails);

                    },
                    icons: Icons.backspace_outlined,
                    color: primarycolor,
                    title: 'Refund Details',
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context)=> VoidOrderReport()));

                      Navigator.pushNamed(context, RouteNames.restaurantReportsVoidOrderReport);

                    },
                    icons: Icons.list_alt,
                    color: primarycolor,
                    title: 'Void Order Report',
                  ),
                ],
              ), SizedBox(
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomMenu(
                    onTap: () {
                      Navigator.pushNamed(context, RouteNames.restaurantReportsDiscountOrderReport);

                    },
                    icons: Icons.note_alt_outlined,
                    color: Colors.deepOrangeAccent,
                    title: '    Discount Order     \n        Reports',
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  CustomMenu(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=> Posenddayreport()));

                    },
                    icons: Icons.list_alt,
                    color: primarycolor,
                    title: 'Pos End Day',
                  ),

                ],
              ),
              SizedBox(height: 15,),




              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  CustomMenu(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context)=> CustomerListByRevenue()));
                      },
                      icons: Icons.monetization_on_outlined,
                      color: Colors.deepOrangeAccent,
                      title: 'Customer List BY \n      Revenue'),
                  SizedBox(
                    width: 5,
                  ),

                  CustomMenu(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=> ExpenseReport()));
                    },
                    icons: Icons.receipt_long,
                    color: Colors.red,
                    title: 'Expense Report',
                  ),
                ],
              ),
              SizedBox(height: 15,),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CustomMenu(
                    onTap: () {
                      Navigator.pushNamed(context, RouteNames.restaurantPerformanceStats);

                    },
                    icons: Icons.analytics,
                    color: Colors.purple,
                    title: '  Performance \n      Statistics',
                  ),
                ],
              )









            ],
          ),
        ),
      ),
    );
  }
}
