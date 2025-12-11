import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../../util/restaurant/images.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';

class StockHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        shadowColor: Colors.black,
        actions: [
          Padding(
            padding: EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(Icons.person),
                Text(
                  "Admin",
                ),
              ],
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Stock History",
                  textScaler: TextScaler.linear(1.2),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                CommonButton(
                    bordercircular: 10,
                    width: width * 0.42,
                    height: height * 0.05,
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(

                      'Add Stock',
                      textScaler: TextScaler.linear(1.2),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 12, color: Colors.white),
                    )),
              ],
            ),
          ),
          Divider(
            thickness: 1,
            color: Colors.grey,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: height * 0.5,
                // color: Colors.red,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(notfoundanimation,
                        height: height * 0.3),
                    Text(
                      'No Stock Found',
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w500),
                    )
                  ],
                ),
              ),


            ],

          ),
        ],
      ),
      drawer: DrawerManage(
        islogout: true,
        isDelete: true,
        issync: false,
      ),
    );
  }
}
