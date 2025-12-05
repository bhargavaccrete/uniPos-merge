import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/Blutooth.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/usb.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/wifi.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/restaurant/images.dart';

class Usb extends StatelessWidget {
  const Usb({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(child:Lottie.asset(notfoundanimation,height: height * 0.3),),
          // SizedBox(height: 10,),
          Text('No Device Found,',style: GoogleFonts.poppins(fontSize: 18,fontWeight: FontWeight.w600),)
        ],
      ),
      floatingActionButton:FloatingActionButton(
        backgroundColor: primarycolor,
        onPressed: (){},
        child: Icon(Icons.refresh,color: Colors.white,),
      ),
    );
  }
}
