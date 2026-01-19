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
        return OnlineOrderDesktop();
      case "In Progress (0)":
        return Online_InProgress();
      case "Completed (0)":
        return Online_Completed();
      case "Missed (0)":
        return Online_Missed();
        // case "Reservation (0)":
        // return OnlineReservationDesktop();
      default:
        return Center(
          child: Text('NO Data Available'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
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
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
              color: Colors.white,
              width: 2.0,
            )),
            // color: Colors.white,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                // color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/icons/dinner.png'),
            ),
          ),
          SizedBox(width: 10),
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
              color: Colors.white,
              width: 2.0,
            )),
            // color: Colors.white,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                // color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/icons/volume.png'),
            ),
          ),
          SizedBox(width: 10),
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
              color: Colors.white,
              width: 2.0,
            )),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Image.asset('assets/icons/home.png'),
            ),
          ),
          SizedBox(width: 10),
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
              color: Colors.white,
              width: 2.0,
            )),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Image.asset('assets/icons/internet.png'),
            ),
          ),
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

                    width: width * 0.15,
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
                    width: width * 0.15,
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
                    width: width * 0.15,
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
                    width: width * 0.15,
                    title: 'Missed (0)',
                    selectedFilter: selectedFilter,
                    onpressed: () {
                      setState(() {
                        selectedFilter = 'Missed (0)';
                      });
                    },
                  ),
                  // SizedBox(
                  //   width: 10,
                  // ),
                  // Filterbutton(
                  //   width: width * 0.15,
                  //   title: 'Reservation (0)',
                  //   selectedFilter: selectedFilter,
                  //   onpressed: () {
                  //     setState(() {
                  //       selectedFilter = 'Reservation (0)';
                  //     });
                  //   },
                  // ),
                ],
              ),
            ),
            // Expanded(child: _getBody())
            SizedBox(
              height: 10,
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      width: width * 0.5,
                      height: height * 9,
                      // color: Colors.green,
                      child: _getBody(),
                    ),
                  ),
                  Container(
                    width: width * 0.4,
                    height: height * 9,
                    color: Color(0xFFeef2ff),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Container(
                              width: width * 0.2,
                              height: height * 0.1,
                              child: Image.asset(
                                  'assets/images/shopping-list_5688524.png')),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          'No Order Details Found',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        Text('Tap To View Details')
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

// CommonButton;
}
