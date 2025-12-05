import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/restaurant/color.dart';
import '../../../util/restaurant/images.dart';
import 'AuthSelectionScreen.dart';
import 'dashboard.dart';


class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _navigateAfterSplash();
   // Timer(
   //   Duration(seconds: 3),
   //     ()=> Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=> AuthSelectionScreen()))
   // ) ;
  }

  Future<void> _navigateAfterSplash ()async{
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn')?? false;

    Timer(Duration(seconds: 3),(){
      if(isLoggedIn){
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=> Dashboard()),
        );
      }else{
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=> AuthSelectionScreen()),
        );
      }
    });
  }
  @override
  Widget build(BuildContext context) {
   final width = MediaQuery.of(context).size.width * 1;
   final height = MediaQuery.of(context).size.height * 1;
    return Center(
      child: Container(
        height: height * 0.5,
        width: width * 0.5,
        color:screenBGColor,
        child:Image.asset(logo,
         ) ,
        // child:Image.asset('assets/images/BillBerry1_processed.jpg') ,
      ),
    );
  }
}
