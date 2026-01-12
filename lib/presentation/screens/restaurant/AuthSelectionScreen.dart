import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';

import '../../../constants/restaurant/color.dart';
import '../../../constants/restaurant/font.dart';
import '../../../util/restaurant/images.dart';
import '../../widget/componets/restaurant/componets/Button.dart';
import 'auth/companyregister.dart';
import 'auth/login.dart';

class AuthSelectionScreen extends StatelessWidget {
  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height * 1;
    double width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          width: width,
          height: height,
          // color: Colors.red,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 20,vertical: 50),
          // margin: EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          // color: Colors.red,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Positioned(
                left: 100,
                child: Container(
                  // color: Colors.green,
                  height: height * 0.15,
                  width: width * 0.50,
                  alignment: Alignment.center,
                  child: Image.asset(logo),
                  // child: Image.asset('assets/images/BillBerry1_processed.jpg'),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Welcome Guest',
                style: customFont20(),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 50),
              // Login Button
              CommonButton(
                  width: width ,

                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => loginScreen()));
                    Navigator.pushNamed(context, RouteNames.restaurantChangePassword);



                  },
                  child: Center(
                      child: Text('Login',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              fontSize: 25,
                              color: Colors.white)

                      ))),
              SizedBox(height: 10),
              // Signup Button
              CommonButton(
                  width: width ,


                  onTap: () {
                    // Navigator.push(context,MaterialPageRoute(builder: (context)=>Signup()));
                    Navigator.push(context,MaterialPageRoute(builder: (context)=>Companyregister()));

                  },
                  child: Center(
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w400,
                            fontSize: 25,
                            color: Colors.white),
                      ))),
              SizedBox(height: 10),

              // Watch Demo Button
              CommonButton(
                  width: width ,

                  onTap: () {},
                  bgcolor: Colors.white,
                  child: Center(
                      child: Text(
                        'Watch Demo',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w400,
                            fontSize: 25,
                            color: primarycolor),
                      ))),
            ],
          ),
        ),
      ),
    );
  }
}
