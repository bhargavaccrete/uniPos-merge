import 'package:flutter/material.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/filterButton.dart';
import '../../online Order/Completed.dart';
import '../../online Order/inProgress.dart';
import '../../online Order/missed.dart';
import 'order.dart';

class OnlineReservationDesktop extends StatefulWidget {
  const OnlineReservationDesktop({super.key});

  @override
  State<OnlineReservationDesktop> createState() => _OnlineReservationDesktopState();
}

class _OnlineReservationDesktopState extends State<OnlineReservationDesktop> {
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
      case "Reservation (0)":
        return OnlineReservationDesktop();
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
                    SizedBox(
                      width: 10,
                    ),
                    Filterbutton(
                      width: width * 0.15,
                      title: 'Reservation (0)',
                      selectedFilter: selectedFilter,
                      onpressed: () {
                        setState(() {
                          selectedFilter = 'Reservation (0)';
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Expanded(child: _getBody())
              SizedBox(
                height: 10,
              ),
              Expanded(
                child: Container(
                  width: width * 0.5,
                  height: height * 9,
                  // color: Colors.green,
                  child: _getBody(),
                ),
              ),
            ],
          ),
        ),
    );
  }
}



