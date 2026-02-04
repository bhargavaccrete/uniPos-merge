

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/dashboard.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/manuListViewWithNavigation.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/util/common/app_responsive.dart';

import '../AuthSelectionScreen.dart';

class loginScreen extends StatefulWidget {
  const loginScreen({super.key});

  @override
  State<loginScreen> createState() => _loginScreenState();
}

class _loginScreenState extends State<loginScreen> {
  bool? isRemember = false;
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final _fromKey = GlobalKey<FormState>();

  FocusNode emailFocus = FocusNode();
  FocusNode passwordFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    ValueNotifier obsecurepass = ValueNotifier(true);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Container(
          // color: Colors.red,
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          // color: Colors.red,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // logo
              Container(
                alignment: Alignment.center,
                // color: Colors.green,
                height: AppResponsive.height(context, 0.2),
                width: AppResponsive.width(context, 0.5),
                child: Image.asset(
                  AppImages.logo,
                  // 'assets/images/BillBerry3_processed.jpg',
                ),
              ),

              //   Text login
              Container(
                width: width,
                // color: Colors.greenAccent,
                child: Text(
                  'Restaurant Login',
                  style: GoogleFonts.poppins(
                      fontSize:
                          AppResponsive.getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0),
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  // TextStyle(fontSize: 20,fontFamily: Go// )
                ),
              ),
              SizedBox(                      height: AppResponsive.height(context, 0.02),
              ),

              //   TextForm Field

              Form(
                key: _fromKey,
                child: Column(
                  // mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // email
                    Center(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        // color: Colors.pink,
                        // width: ,
                        // alignment: Alignment(0.1, 0.),
                        child: Text(
                          'Email ID',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                          ),
                          // textAlign:TextAlign.start,
                        ),
                      ),
                    ),
                    SizedBox(
                        height:
                            AppResponsive.height(context, 0.02)),
                    CommonTextForm(
                      obsecureText: false,
                      focusNode: emailFocus,
                      controller: emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "please Enter Email";
                        }
                      },
                      hintText: 'Enter Email',
                      onfieldsumbitted: (value) {
                        FocusScope.of(context).requestFocus(passwordFocus);
                      },
                    ),
                    SizedBox(
                      height: AppResponsive.height(context, 0.02),

                    ),

                    // PASSWORD
                    Center(
                      child: Container(
                        // width: width * 0.9,

                        // color: Colors.pink,
                        // width: width ,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                          ),
                          // textAlign:TextAlign.start,
                        ),
                      ),
                    ),

                    SizedBox(
                      height: 5,
                    ),
                    ValueListenableBuilder(
                        valueListenable: obsecurepass,
                        builder: (context, value, child) {
                          return CommonTextForm(
                            controller: passwordController,
                            focusNode: passwordFocus,
                            obsecureText: obsecurepass.value,
                            hintText: 'Enter Password',
                            gesture: GestureDetector(
                                onTap: () {
                                  obsecurepass.value = !obsecurepass.value;
                                },
                                child: obsecurepass.value == true
                                    ? Icon(Icons.visibility)
                                    : Icon(Icons.visibility_off)),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  value.length < 6) {
                                return value!.isEmpty
                                    ? 'Please Enter Password'
                                    : 'minimum 6 six digit Required';
                              }
                            },
                          );
                        }),
                    SizedBox(
                      height: AppResponsive.height(context, 0.02),
                    ),

                    //   forgot password
                    InkWell(
                      // onLongPress: ScaffoldMessenger.of(context),
                      // focusColor: Primarysecond,
                      onTap: () {},
                      child: Container(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.poppins(color: AppColors.primary,
                              fontSize: AppResponsive.getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0),
                        ),
                        ),
                      ),
                    ),

                    SizedBox(
                      height: AppResponsive.height(context, 0.02),

                    ),

                    //Remember Me

                    Row(
                      children: [
                        Checkbox(
                          value: isRemember,
                          activeColor: AppColors.primary,
                          onChanged: (bool? newvalue) {
                            setState(() {
                              isRemember = newvalue;
                            });
                          },
                        ),
                        Text(
                          'Remember Me',

                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),

                          ),
                        ),
                      ],
                    ),

                    CommonButton(
                      height: AppResponsive.height(context, 0.08),
                      width: width,
                      onTap: () async {
                        if (_fromKey.currentState!.validate()) {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('isLoggedIn', true);
                          await prefs.setString('email', emailController.text);
                          await prefs.setString(
                              'password', passwordController.text);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Dashboard()),
                          );
                        }
                      },
                      child: Center(
                        child: Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                          ),
                        ),
                      ),
                      bgcolor: AppColors.primary,
                    ),

                    SizedBox(
                      height: AppResponsive.height(context, 0.02),
                    ),
                    CommonButton(
                      height: AppResponsive.height(context, 0.08),
                      width: width,
                      onTap: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AuthSelectionScreen()));
                      },
                      child: Center(
                          child: Text(
                        'Back',
                        style: GoogleFonts.poppins(
                          fontSize:
                              AppResponsive.getValue(context, mobile: 18.0, tablet: 19.8, desktop: 21.6),
                          color: AppColors.primary,
                        ),
                      )),
                      bgcolor: Colors.white,
                      bordercolor: Colors.grey,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
