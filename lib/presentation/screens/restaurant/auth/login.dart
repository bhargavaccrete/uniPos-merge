// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:BillBerry/componets/Button.dart';
// import 'package:BillBerry/componets/Textform.dart';
// import 'package:BillBerry/constant/color.dart';
// import 'package:BillBerry/screens/AuthSelectionScreen.dart';
// import 'package:BillBerry/screens/dashboard.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:BillBerry/utils/responsive_helper.dart';
// class loginScreen extends StatefulWidget {
//   const loginScreen({super.key});
//
//   @override
//   State<loginScreen> createState() => _loginScreenState();
// }
//
// class _loginScreenState extends State<loginScreen> {
//   bool? isRemember = false;
//   TextEditingController emailController = TextEditingController();
//   TextEditingController passwordController = TextEditingController();
//
//   final _fromKey = GlobalKey<FormState>();
//
//   FocusNode emailFocus = FocusNode();
//   FocusNode passwordFocus = FocusNode();
//
//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery.of(context).size.height * 1;
//     final width = MediaQuery.of(context).size.width * 1;
//
//     ValueNotifier obsecurepass = ValueNotifier(true);
//     return Scaffold(
//       backgroundColor: screenBGColor,
//       body: SingleChildScrollView(
//         child: Container(
//           // color: Colors.red,
//           width: width,
//           height: height,
//           padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
//           // color: Colors.red,
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // logo
//               Container(
//                 alignment: Alignment.center,
//                 // color: Colors.green,
//                 height: height * 0.12,
//                 width: width ,
//                 child: Image.asset(
//                   'assets/images/BillBerry3_processed.jpg',
//                 ),
//               ),
//
//               //   Text login
//               Container(
//                 width: width,
//                 // color: Colors.greenAccent,
//                 child: Text('Restaurant Login',
//                     style: GoogleFonts.poppins(
//                         fontSize: 20, fontWeight: FontWeight.w600),textAlign: TextAlign.center,
//                     // TextStyle(fontSize: 20,fontFamily: Go// )
//                     ),
//               ),
//               SizedBox(height: 25),
//
//               //   TextForm Field
//
//               Form(
//                 key: _fromKey,
//                 child: Column(
//                   // mainAxisAlignment: MainAxisAlignment.start,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // email
//                     Center(
//                       child: Container(
//                         alignment: Alignment.centerLeft,
//                         // color: Colors.pink,
//                         // width: ,
//                         // alignment: Alignment(0.1, 0.),
//                         child: Text(
//                           'Email ID',
//                           style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold, fontSize: 18),
//                           // textAlign:TextAlign.start,
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 5),
//                     CommonTextForm(
//                       obsecureText: false,
//                       focusNode: emailFocus,
//                       controller: emailController,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return "please Enter Email";
//                         }
//                       },
//                       hintText: 'Enter Email',
//                       onfieldsumbitted: (value) {
//                         FocusScope.of(context).requestFocus(passwordFocus);
//                       },
//                     ),
//                     SizedBox(
//                       height: 20,
//                     ),
//
//                     // PASSWORD
//                     Center(
//                       child: Container(
//                         // width: width * 0.9,
//
//                         // color: Colors.pink,
//                         // width: width ,
//                         alignment: Alignment.centerLeft,
//                         child: Text(
//                           'Password',
//                           style: GoogleFonts.poppins(
//                               fontWeight: FontWeight.bold, fontSize: 18),
//                           // textAlign:TextAlign.start,
//                         ),
//                       ),
//                     ),
//
//                     SizedBox(
//                       height: 5,
//                     ),
//                     ValueListenableBuilder(
//                         valueListenable: obsecurepass,
//                         builder: (context, value, child) {
//                           return CommonTextForm(
//                             controller: passwordController,
//                               focusNode: passwordFocus,
//                               obsecureText: obsecurepass.value,
//                               hintText: 'Enter Password',
//                               gesture:  GestureDetector(
//                                   onTap: () {
//                                     obsecurepass.value = !obsecurepass.value;
//                                   },
//                                   child: obsecurepass.value == true
//                                       ? Icon(Icons.visibility)
//                                       : Icon(Icons.visibility_off)),
//                             validator: (value) {
//                               if (value == null ||
//                                   value.isEmpty ||
//                                   value.length < 6) {
//                                 return value!.isEmpty
//                                     ? 'Please Enter Password'
//                                     : 'minimum 6 six digit Required';
//                               }
//                             },
//
//                           );
//                         }),
//                     SizedBox(
//                       height: 10,
//                     ),
//
//                     //   forgot password
//                     InkWell(
//                       // onLongPress: ScaffoldMessenger.of(context),
//                       // focusColor: Primarysecond,
//                       onTap: () {},
//                       child: Container(
//                         alignment: Alignment.centerRight,
//                         child: Text(
//                           'Forgot Password?',
//                           style: GoogleFonts.poppins(color: primarycolor),
//                         ),
//                       ),
//                     ),
//
//                     SizedBox(
//                       height: 20,
//                     ),
//
//                     //Remember Me
//
//                     Row(
//                       children: [
//                         Checkbox(
//                           value: isRemember,
//                           activeColor: primarycolor,
//                           onChanged: (bool? newvalue) {
//                             setState(() {
//                               isRemember = newvalue;
//                             });
//                           },
//                         ),
//                         Text(
//                           'Remember Me',
//                           style: GoogleFonts.poppins(),
//                         ),
//                       ],
//                     ),
//
//
//                     CommonButton(
//                       height: height * 0.08,
//                       width: width,
//                       onTap: () async {
//                         if (_fromKey.currentState!.validate()) {
//                           SharedPreferences prefs =
//                               await SharedPreferences.getInstance();
//                           await prefs.setBool('isLoggedIn', true);
//                           await prefs.setString(
//                               'email', emailController.text);
//                           await prefs.setString(
//                               'password', passwordController.text);
//
//                           Navigator.pushReplacement(
//                             context,
//                             MaterialPageRoute(
//                                 builder: (context) => Dashboard()),
//                           );
//                         }
//                       },
//                       child: Center(
//                         child: Text(
//                           'Login',
//                           style: GoogleFonts.poppins(
//                               color: Colors.white, fontSize: 18),
//                         ),
//                       ),
//                       bgcolor: primarycolor,
//                     ),
//
//                     SizedBox(
//                       height: 10,
//                     ),
//                     CommonButton(
//                       height: height * 0.08,
//
//                       width: width ,
//                       onTap: () {
//                         Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> AuthSelectionScreen()));
//                       },
//                       child: Center(
//                           child: Text(
//                         'Back',
//                         style: GoogleFonts.poppins(
//                             color: primarycolor, fontSize: 18),
//                       )),
//                       bgcolor: Colors.white,
//                       bordercolor: Colors.grey,
//                     )
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/dashboard.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/manuListViewWithNavigation.dart';
import 'package:unipos/util/restaurant/images.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';

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
      backgroundColor: screenBGColor,
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
                height: ResponsiveHelper.responsiveHeight(context, 0.2),
                width: ResponsiveHelper.responsiveWidth(context, 0.5),
                child: Image.asset(
                  logo,
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
                          ResponsiveHelper.responsiveTextSize(context, 20),
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  // TextStyle(fontSize: 20,fontFamily: Go// )
                ),
              ),
              SizedBox(                      height: ResponsiveHelper.responsiveHeight(context, 0.02),
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
                            fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
                          ),
                          // textAlign:TextAlign.start,
                        ),
                      ),
                    ),
                    SizedBox(
                        height:
                            ResponsiveHelper.responsiveHeight(context, 0.02)),
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
                      height: ResponsiveHelper.responsiveHeight(context, 0.02),

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
                            fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
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
                      height: ResponsiveHelper.responsiveHeight(context, 0.02),
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
                          style: GoogleFonts.poppins(color: primarycolor,
                              fontSize: ResponsiveHelper.responsiveTextSize(context, 20),
                        ),
                        ),
                      ),
                    ),

                    SizedBox(
                      height: ResponsiveHelper.responsiveHeight(context, 0.02),

                    ),

                    //Remember Me

                    Row(
                      children: [
                        Checkbox(
                          value: isRemember,
                          activeColor: primarycolor,
                          onChanged: (bool? newvalue) {
                            setState(() {
                              isRemember = newvalue;
                            });
                          },
                        ),
                        Text(
                          'Remember Me',

                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.responsiveTextSize(context, 16),

                          ),
                        ),
                      ],
                    ),

                    CommonButton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.08),
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
                            fontSize: ResponsiveHelper.responsiveTextSize(
                                context, 18),
                          ),
                        ),
                      ),
                      bgcolor: primarycolor,
                    ),

                    SizedBox(
                      height: ResponsiveHelper.responsiveHeight(context, 0.02),
                    ),
                    CommonButton(
                      height: ResponsiveHelper.responsiveHeight(context, 0.08),
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
                              ResponsiveHelper.responsiveTextSize(context, 18),
                          color: primarycolor,
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
