// import 'package:flutter/material.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/screens/online%20Order/Completed.dart';
// import 'package:BillBerry/screens/online%20Order/inProgress.dart';
// import 'package:BillBerry/screens/online%20Order/missed.dart';
// import 'package:BillBerry/screens/online%20Order/order.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class Online extends StatefulWidget {
//   const Online({super.key});
//
//   @override
//   State<Online> createState() => _OnlineState();
// }
//
// class _OnlineState extends State<Online>
// with SingleTickerProviderStateMixin{
//   late TabController tabController;
// @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     tabController = TabController(length:4 , vsync: this);
//     tabController.addListener((){
//       setState(() {
//
//       });
//     }) ;
// }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery.of(context).size.height * 1;
//     final width = MediaQuery.of(context).size.width * 1;
//
//     return Scaffold(
//       appBar: AppBar(
//         automaticallyImplyLeading: true,
//         title: Text('Orange'),
//         actions: [
//           Row(
//             children: [
//               Icon(Icons.person),
//               Text('Admin',style: GoogleFonts.poppins(),)
//             ],
//           )
//         ],
//         bottom: PreferredSize(
//           preferredSize: Size.fromHeight(50),
//           child: Container(
//           width: double.infinity,
//             margin: EdgeInsets.symmetric(horizontal: 10,vertical: 5),
//             decoration:BoxDecoration(
//               color: Colors.grey.shade200, // Background color
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: TabBar(
//                 controller: tabController,
//                 isScrollable: true,
//                 labelColor: Colors.white,
//                 unselectedLabelColor: Colors.grey,
//                 dividerColor: Colors.transparent,
//                 indicatorColor: Primarysecond,
//                 indicator: BoxDecoration(
//                   color: AppColors.primary,
//                     borderRadius:BorderRadius.circular(8),
//                 ),
//                 indicatorSize: TabBarIndicatorSize.tab,
//                 tabs: [
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: Tab(text: 'Order(0)',),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: Tab(text: 'In Progress(0)',),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     child: Tab(text: 'Completed(0)',),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//
//                     child: Tab(text: 'Missed(0)',),
//                   ),
//                 ]),
//           )
//         )
//       ),
//       body: TabBarView(
//         controller: tabController,
//           children: [
//             Online_order(),
//             Online_InProgress(),
//             Online_Completed(),
//             Online_Missed()
//
//       ]),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/online%20Order/Completed.dart';
import 'package:unipos/presentation/screens/restaurant/online%20Order/inProgress.dart';
import 'package:unipos/presentation/screens/restaurant/online%20Order/missed.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/filterButton.dart';

import 'order.dart';

class OnlineDesktop extends StatefulWidget {
  const OnlineDesktop({super.key});

  @override
  State<OnlineDesktop> createState() => _OnlineDesktopState();
}

class _OnlineDesktopState extends State<OnlineDesktop> {
  String selectedFilter = "Order (0)";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Order (0)":
        return Online_order();
      case "In Progress (0)":
        return Online_InProgress();
      case "Completed (0)":
        return Online_Completed();
      case "Missed (0)":
        return Online_Missed();
      default:
        return Center(
          child: Text('NO Data Available'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("Orange", style: GoogleFonts.poppins(color: Colors.black)),
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
            )),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_outlined,
                  size: 30,
                ),
                Column(
                  children: [
                    Text('Admin'),
                    Text('Admin'),
                  ],
                )
              ],
            ),
          )
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Filterbutton(
                    title: 'Order (0)',
                    selectedFilter: selectedFilter,
                    onpressed: () {
                      setState(() {
                        selectedFilter = 'Order (0)';
                      });
                    },
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Filterbutton(
                    title: 'In Progress (0)',
                    selectedFilter: selectedFilter,
                    onpressed: () {
                      setState(() {
                        selectedFilter = 'In Progress (0)';
                      });
                    },
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Filterbutton(
                    title: 'Completed (0)',
                    selectedFilter: selectedFilter,
                    onpressed: () {
                      setState(() {
                        selectedFilter = 'Completed (0)';
                      });
                    },
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Filterbutton(
                    title: 'Missed (0)',
                    selectedFilter: selectedFilter,
                    onpressed: () {
                      setState(() {
                        selectedFilter = 'Missed (0)';
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _getBody())
          ],
        ),
      ),
    );
  }

// CommonButton;
}
