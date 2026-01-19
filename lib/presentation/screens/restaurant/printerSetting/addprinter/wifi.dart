import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/restaurant/images.dart';

class WifiLan extends StatelessWidget {
  const WifiLan({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(child: Lottie.asset(AppImages.notfoundanimation,height: height * 0.3),),
          // SizedBox(height: 10,),
          Text('No Device Found,',style: GoogleFonts.poppins(fontSize: 18,fontWeight: FontWeight.w600),)
        ],
      ),
      floatingActionButton:FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: (){},
        child: Icon(Icons.refresh,color: Colors.white,),
      ),
    );
  }
}
