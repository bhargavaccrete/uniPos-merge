import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/dashboard.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/common/app_responsive.dart';

import '../welcome_Admin.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  TextEditingController PasswordController = TextEditingController();

  final _formkey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    ValueNotifier obsecurepass = ValueNotifier(true);
    PasswordController.text = '123456';
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Container(
          width: width,
          height: height,
          // color: Colors.red,
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.width(context, 0.03),
            vertical: AppResponsive.height(context, 0.01),
          ),
          // color: Color(0xff1C3F6FF),
          child: Form(
            key: _formkey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image Logo
                Container(
                  // color: Colors.red,
                  alignment: Alignment.bottomCenter,
                  width: AppResponsive.width(context, 0.5) ,
                  height: AppResponsive.height(context, 0.20),
                  child: Image.asset(AppImages.logo),
                ),
                SizedBox(height: AppResponsive.height(context, 0.02),
                ),
                // text Admin
                Text('Admin Login',
                    // textScaler: TextScaler.linear(1.2),

                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),

                SizedBox(height: AppResponsive.height(context, 0.05),),

                // password
                Container(
                  // width: width * 0.75,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password',
                    style: GoogleFonts.poppins(
                        fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                        fontWeight: FontWeight.w600),
                  ),
                ),

                SizedBox(
                  height: AppResponsive.height(context, 0.01),
                ),

                // Textform
                SizedBox(
                  width: width ,
                  child: ValueListenableBuilder(
                    valueListenable: obsecurepass,
                    builder: (context, value, child) {
                      return CommonTextForm(
                        obsecureText: value,
                        controller: PasswordController,
                        hintText: 'Enter Password',
                        validator: (value) {
                          if (value == null || value.isEmpty || value.length < 6) {
                            return value!.isEmpty ? "Please Enter Password" : 'Please Enter Six Digit';
                          }
                        },
                        gesture: GestureDetector(
                            onTap: () {
                              obsecurepass.value = !obsecurepass.value;
                            },
                            child: obsecurepass.value == true
                                ? Icon(
                              Icons.visibility_off,
                              color: AppColors.primary,
                            )
                                : Icon(
                              Icons.visibility,
                              color: AppColors.primary,
                            )),
                      );
                    },
                  ),
                ),

                SizedBox(
                  height: AppResponsive.height(context, 0.02),
                ),

                // Login button
                CommonButton(
                  width: width,
                  onTap: () {
                    if (_formkey.currentState!.validate()) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AdminWelcome()));
                    }
                  },
                  child: Center(
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(color: Colors.white,
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                            fontWeight: FontWeight.w400),
                      )),
                  height: AppResponsive.height(context, 0.065),
                ),

                SizedBox(
                  height: AppResponsive.height(context, 0.02),

                ),
                // Text pass
                RichText(
                    text: TextSpan(
                        text: 'Default Password for Admin is ',

                        style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.4, desktop: 16.8),
                            color: Colors.grey.shade700),
                        children: [
                          TextSpan(
                            text: '123456',
                            style: GoogleFonts.poppins(
                                fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.4, desktop: 16.8),
                                color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1),
                          )
                        ])),

                SizedBox(
                  height: AppResponsive.height(context, 0.02),
                ),
                // back button

                CommonButton(
                  onTap: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Dashboard()));
                  },
                  width: width,
                  height: height * 0.065,
                  child: Center(
                      child: Text(
                        'Back',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      )),
                  bgcolor: Colors.white,
                  bordercolor: AppColors.primary,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
