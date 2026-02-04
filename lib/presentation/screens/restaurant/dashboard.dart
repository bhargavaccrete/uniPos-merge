import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/util/images.dart';

import '../../../constants/restaurant/color.dart';
import '../../../main.dart';

import '../../../util/common/app_responsive.dart';
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
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.width(context, 0.03),
            vertical: AppResponsive.height(context, 0.01),
          ),
          // color: Colors.red,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                alignment: Alignment.bottomCenter,
                height: AppResponsive.height(context, 0.15),

                width: AppResponsive.width(context, 0.5),

                child: Image.asset(
                  AppImages.logo,
                ),
              ),
              SizedBox(
                height: AppResponsive.height(context, 0.02),

              ),
              Text(
                  'DashBoard',
                  textScaler: TextScaler.linear(1),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.getValue(context, mobile: 20.0, tablet: 22.0, desktop: 24.0),
                    fontWeight: FontWeight.w600,)
              ),
              SizedBox(
                height: AppResponsive.height(context, 0.02),

              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AdminLogin()));
                      },
                      child: Container(
                        height: AppResponsive.height(context, 0.12),

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
                              size: AppResponsive.getValue(context, mobile: 40.0, tablet: 44.0, desktop: 48.0),
                            ),
                            Text(
                              'Admin',
                              textScaler: TextScaler.linear(1),
                              style: GoogleFonts.poppins(
                                  fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppResponsive.width(context, 0.03),

                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CashierWaiter()));
                      },
                      child: Container(
                        height: AppResponsive.height(context, 0.12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: AppResponsive.getValue(context, mobile: 40.0, tablet: 44.0, desktop: 48.0),

                              color: AppColors.primary,
                            ),
                            // SizedBox(height: 5),
                            Text('Cashier|Waiter',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                                    fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(
                height: AppResponsive.height(context, 0.02),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => NeedhelpDrawer()));
                      },
                      child: Container(
                        height: AppResponsive.height(context, 0.12),

                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent_outlined,
                              size: AppResponsive.getValue(context, mobile: 40.0, tablet: 44.0, desktop: 48.0),

                              color: AppColors.primary,
                            ),
                            // SizedBox(
                            //   height: 5,
                            // ),
                            Text('Support',
                                textScaler: TextScaler.linear(1),
                                style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
                                    fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppResponsive.width(context, 0.03),

                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: Text('Are you sure you want to logout?',
                                  style: TextStyle(
                                    fontSize: AppResponsive.getValue(context, mobile: 15.0, tablet: 16.5, desktop: 18.0),
                                  )),
                              actions: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    CommonButton(
                                      bordercolor: Colors.red,
                                      bordercircular: 2,
                                      width: AppResponsive.width(context, 0.3),

                                      height: AppResponsive.height(context, 0.05),

                                      bgcolor: Colors.red,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("Cancel",style: GoogleFonts.poppins(
                                        fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.4, desktop: 16.8),
                                      ),),
                                    ),
                                    SizedBox(
                                      width: AppResponsive.width(context, 0.01),

                                    ),
                                    CommonButton(
                                      bordercircular: 2,
                                      width: AppResponsive.width(context, 0.3),
                                      height: AppResponsive.height(context, 0.05),
                                      bgcolor: AppColors.primary,
                                      onTap: () {
                                        Navigator.push(context,
                                            MaterialPageRoute(builder: (context) => AuthSelectionScreen()));
                                        ;
                                      },
                                      child: Text("Yes",style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.4, desktop: 16.8),
                                      ),),
                                    ),
                                  ],
                                ),
                              ],
                            ));
                      },
                      child: Container(
                        height: AppResponsive.height(context, 0.12),

                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.primary, width: 2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_outlined,
                              size: AppResponsive.getValue(context, mobile: 40.0, tablet: 44.0, desktop: 48.0),

                              color: AppColors.primary,
                            ),
                            // SizedBox(
                            //   height: 5,
                            // ),
                            Text('Logout',
                                textScaler: TextScaler.linear(1),

                                style: GoogleFonts.poppins(
                                    fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.6, desktop: 19.2),
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

