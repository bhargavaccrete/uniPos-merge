
import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/pastorder.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';
import 'activeorder.dart';
class Order extends StatefulWidget {
  final OrderModel? existingOrder;
  const Order({super.key, this.existingOrder});

  @override
  State<Order> createState() => _OrderState();
}

class _OrderState extends State<Order> {
  String selectedFilter = "Active Order";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Active Order":
        return Activeorder();
      case "Past Order":
        return Pastorder();
      default:
        return Center(
          child: Text('NO DATA'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Filterbutton(
                        title: 'Active Order',
                        selectedFilter: selectedFilter,
                        onpressed: () {
                          setState(() {
                            selectedFilter = 'Active Order';
                          });
                        },
                      ),
                      // _filterButton('Active Order'),
                      SizedBox(
                        width: 10,
                      ),
                      Filterbutton(
                        title: 'Past Order',
                        selectedFilter: selectedFilter,
                        onpressed: () {
                          setState(() {
                            selectedFilter = 'Past Order';
                          });
                        },
                      ),

                      SizedBox(
                        width: 30,
                      ),
                    ],
                  ),
                  Container(
                      height: height * 0.04,
                      width: width * 0.15,
                      decoration: BoxDecoration(
                          color: primarycolor,
                          borderRadius: BorderRadius.circular(5)),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white,
                      ))
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
