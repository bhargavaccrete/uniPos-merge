import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/images.dart';

import '../../../constants/restaurant/color.dart';
import '../../../main.dart';
import '../../../util/restaurant/images.dart';
import '../../../util/restaurant/responsive_helper.dart';
import '../../widget/componets/restaurant/componets/Button.dart';
import 'AuthSelectionScreen.dart';
import 'auth/admin_login.dart';
import 'auth/cashier_waiter.dart';
import 'auth/login.dart';
import 'need help/needhelp.dart';
import 'package:unipos/util/color.dart';
class Dashboard extends StatelessWidget {
  Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    print("this is the device cat ---- ${appStore.deviceCategory}");
    Future<void> logout() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clears isLoggedIn, email, and password
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => loginScreen()),
      );
    }

    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Container(
          width: width,
          height: height,
          padding: ResponsiveHelper.responsiveSymmetricPadding(context,
            horizontalPercent: 0.03,
            verticalPercent: 0.01,
          ),
          // color: Colors.red,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                alignment: Alignment.bottomCenter,
                height: ResponsiveHelper.responsiveHeight(context, 0.15),

                width: ResponsiveHelper.responsiveWidth(context, 0.5),

                child: Image.asset(
                  AppImages.logo,
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.02),

              ),
              Text(
                  'DashBoard',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveTextSize(context, 20),
                    fontWeight: FontWeight.w600,)
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.02),

              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AdminLogin()));
                      },
                      child: Container(
                        height: ResponsiveHelper.responsiveHeight(context, 0.12),

                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        // color: Colors.green,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_2_outlined,
                              color: AppColors.primary,
                              size:ResponsiveHelper.responsiveTextSize(context, 40),
                            ),
                            Text(
                              'Admin',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.03),

                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CashierWaiter()));
                      },
                      child: Container(
                        height: ResponsiveHelper.responsiveHeight(context, 0.12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size:ResponsiveHelper.responsiveTextSize(context, 40),

                              color: AppColors.primary,
                            ),
                            // SizedBox(height: 5),
                            Text('Cashier|Waiter',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                                    fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.02),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => NeedhelpDrawer()));
                      },
                      child: Container(
                        height: ResponsiveHelper.responsiveHeight(context, 0.12),

                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent_outlined,
                              size:ResponsiveHelper.responsiveTextSize(context, 40),

                              color: AppColors.primary,
                            ),
                            // SizedBox(
                            //   height: 5,
                            // ),
                            Text('Support',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                                    fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.03),

                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: Text('Are you sure you want to logout?',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.responsiveTextSize(context, 15),
                                  )),
                              actions: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    CommonButton(
                                      bordercolor: Colors.red,
                                      bordercircular: 2,
                                      width: ResponsiveHelper.responsiveWidth(context, 0.3),

                                      height: ResponsiveHelper.responsiveHeight(context, 0.05),

                                      bgcolor: Colors.red,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("Cancel",style: GoogleFonts.poppins(
                                        fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
                                      ),),
                                    ),
                                    SizedBox(
                                      width: ResponsiveHelper.responsiveWidth(context, 0.01),

                                    ),
                                    CommonButton(
                                      bordercircular: 2,
                                      width: width * 0.3,
                                      height: height * 0.05,
                                      bgcolor: AppColors.primary,
                                      onTap: () {
                                        Navigator.push(context,
                                            MaterialPageRoute(builder: (context) => AuthSelectionScreen()));
                                        ;
                                      },
                                      child: Text("Yes",style: GoogleFonts.poppins(  fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
                                      ),),
                                    ),
                                  ],
                                ),
                              ],
                            ));
                      },
                      child: Container(
                        height: ResponsiveHelper.responsiveHeight(context, 0.12),

                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_outlined,
                              size:ResponsiveHelper.responsiveTextSize(context, 40),

                              color: AppColors.primary,
                            ),
                            // SizedBox(
                            //   height: 5,
                            // ),
                            Text('Logout',
                                textScaler: TextScaler.linear(1),

                                style: GoogleFonts.poppins(
                                    fontSize: ResponsiveHelper.responsiveTextSize(context, 16),
                                    fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

