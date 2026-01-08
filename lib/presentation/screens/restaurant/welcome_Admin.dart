import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/presentation/screens/restaurant/Reports/reports.dart';
import '../../../constants/restaurant/color.dart';
import '../../../domain/services/restaurant/day_management_service.dart';
import '../../../util/restaurant/responsive_helper.dart';
import '../../widget/componets/restaurant/componets/Button.dart';
import '../../widget/componets/restaurant/componets/listmenu.dart';
import '../../widget/restaurant/opening_balance_dialog.dart';

import 'Expense/Expense.dart';
import 'ManageStaff/manageStaff.dart';
import 'Settings/settingsScreen.dart';
import 'TaxSetting/taxSettings.dart';
import 'auth/admin_login.dart';
import 'auth/restaurant_login.dart';
import 'inventory/manage_Inventory.dart';
import 'language.dart';
import 'manage menu/managemenu.dart';
import 'start order/startorder.dart';

class AdminWelcome extends StatefulWidget {
  const AdminWelcome({super.key});

  @override
  State<AdminWelcome> createState() => _AdminWelcomeState();
}

class _AdminWelcomeState extends State<AdminWelcome> {
  @override
  void initState() {
    super.initState();
    _checkDayStarted();
  }

  Future<void> _checkDayStarted() async {
    final isDayStarted = await DayManagementService.isDayStarted();
    if (!isDayStarted && mounted) {
      // Show opening balance dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const OpeningBalanceDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // final height = MediaQuery.of(context).size.height * 1;
    // final width = MediaQuery.of(context).size.width * 1;
    return  Scaffold(
      backgroundColor: screenBGColor,
      appBar: AppBar(
          backgroundColor: screenBGColor,
          automaticallyImplyLeading: false,
          // toolbarHeight: 50,
          // backgroundColor: Colors.red,
          title: Container(
            // color: Colors.red,
              alignment: Alignment.centerLeft,
              height: ResponsiveHelper.responsiveHeight(context, 0.3),

              // width: width ,
              // color: Colors.purple,
              child: Image.asset(
                // 'assets/images/BillBerry3_processed.jpg',
                'assets/images/bblogo.png',
                width: 150,
                fit: BoxFit.fill,
              )),
          actions: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.person),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize:
                      ResponsiveHelper.responsiveTextSize(context, 14),
                    ),
                  )
                ],
              ),
            ),
          ]),
      body: SingleChildScrollView(
        child: Container(
          // alignment: Alignment.center,
          width: ResponsiveHelper.responsiveWidth(context, 1),
// width: width,
          // height: height * 0.1,
          // color: Colors.red,
          padding: ResponsiveHelper.responsiveSymmetricPadding(context,
              horizontalPercent: 0.05, verticalPercent: 0.01),
          // color: Colors.red,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.02),
              ),
              // welcom
              FittedBox(
                child: Text(
                  'Welcome Admin',
                  textScaler: TextScaler.linear(1.2),
                  style: GoogleFonts.poppins(
                      fontSize:
                      ResponsiveHelper.responsiveTextSize(context, 20),
                      fontWeight: FontWeight.w600),
                ),
              ),

              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.02),
              ),
              Text(
                'Orange',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.02),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      child: Listmenu(
                          onTap: () {


                            Navigator.push(context,MaterialPageRoute(builder: (context)=> Startorder()));
                            //
                            // ResponsiveHelper.isDesktop(context)?
                            // Navigator.push(
                            //     context,
                            //     MaterialPageRoute(
                            //         builder: (context) => StartorderD()))
                            //     :
                            // Navigator.push(
                            //     context,
                            //     MaterialPageRoute(
                            //         builder: (context) => Startorder()));
                          },
                          title: 'Start',
                          icons: (Icons.shopping_cart_sharp))),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.015),
                  ),
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Managemenu()));
                          },
                          title: 'Manage Menu',
                          icons: (Icons.manage_accounts)
                      ))
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.01),
              ),
              Row(
                children: [
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => manageStaff()));
                          },
                          title: 'Manage Staff',
                          icons: (Icons.manage_accounts_sharp))),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.015),
                  ),
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ManageInventory()));
                          },
                          title: 'Invatory',
                          icons: (Icons.inventory)
                      )
                  )
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.01),
              ),
              Row(
                children: [
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ReportsScreen()));
                          },
                          title: 'Reports',
                          icons: (Icons.auto_graph_outlined)
                      )),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.015),
                  ),
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => taxSetting(),
                                ));
                          },
                          title: 'Tax Setting',
                          icons: (Icons.settings)
                      ))
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.01),
              ),
              Row(
                children: [
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Settingsscreen()));
                          },
                          title: 'Setting',
                          icons: (Icons.settings))),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.015),
                  ),
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ExpenseScreen()));
                          },
                          title: 'Expense',
                          icons: (Icons.wallet)))
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.01),
              ),
              Row(
                children: [
                  Expanded(
                      child: Listmenu(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CompanyListScreen()));
                          },
                          title: 'Language',
                          icons: (Icons.language))),
                  SizedBox(
                    width: ResponsiveHelper.responsiveWidth(context, 0.015),
                  ),
                  Expanded(
                      child: Listmenu(
                        onTap: () {
                          _showLogoutDialog(context);
                        },
                        title: 'Logout',
                        icons: (Icons.logout),
                        color: Colors.red,
                      ))
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.responsiveHeight(context, 0.01),
              ),
              // Listmenu(title: 'start', icon: Icon(Icons.shopping_cart_sharp), titleS: 'Manage Menu', iconS: Icon(Icons.manage_accounts),)
            ],
          ),
        ),
      ),
    );
    /*  LayoutBuilder(builder: (context , constraints){
      if(constraints.maxWidth <700 ){
        return
          Scaffold(
          backgroundColor: screenBGColor,
          appBar: AppBar(
              backgroundColor: screenBGColor,
              automaticallyImplyLeading: false,
              // toolbarHeight: 50,
              // backgroundColor: Colors.red,
              title: Container(
                // color: Colors.red,
                  alignment: Alignment.centerLeft,
                  height: ResponsiveHelper.responsiveHeight(context, 0.3),

                  // width: width ,
                  // color: Colors.purple,
                  child: Image.asset(
                    // 'assets/images/BillBerry3_processed.jpg',
                    'assets/images/bblogo.png',
                    width: 150,
                    fit: BoxFit.fill,
                  )),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.person),
                      Text(
                        'Admin',
                        style: GoogleFonts.poppins(
                          fontSize:
                          ResponsiveHelper.responsiveTextSize(context, 14),
                        ),
                      )
                    ],
                  ),
                ),
              ]),
          body: SingleChildScrollView(
            child: Container(
              // alignment: Alignment.center,
              width: ResponsiveHelper.responsiveWidth(context, 1),
// width: width,
              // height: height * 0.1,
              // color: Colors.red,
              padding: ResponsiveHelper.responsiveSymmetricPadding(context,
                  horizontalPercent: 0.05, verticalPercent: 0.01),
              // color: Colors.red,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.02),
                  ),
                  // welcom
                  FittedBox(
                    child: Text(
                      'Welcome Admin',
                      textScaler: TextScaler.linear(1.2),
                      style: GoogleFonts.poppins(
                          fontSize:
                          ResponsiveHelper.responsiveTextSize(context, 20),
                          fontWeight: FontWeight.w600),
                    ),
                  ),

                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.02),
                  ),
                  Text(
                    'Orange',
                    style: GoogleFonts.poppins(fontSize: 18),
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.02),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                          child: Listmenu(
                              onTap: () {


                                Navigator.push(context,MaterialPageRoute(builder: (context)=> Startorder()));
                                //
                                // ResponsiveHelper.isDesktop(context)?
                                // Navigator.push(
                                //     context,
                                //     MaterialPageRoute(
                                //         builder: (context) => StartorderD()))
                                //     :
                                // Navigator.push(
                                //     context,
                                //     MaterialPageRoute(
                                //         builder: (context) => Startorder()));
                              },
                              title: 'Start',
                              icons: (Icons.shopping_cart_sharp))),
                      SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context, 0.015),
                      ),
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Managemenu()));
                              },
                              title: 'Manage Menu',
                              icons: (Icons.manage_accounts)
                          ))
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.01),
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => manageStaff()));
                              },
                              title: 'Manage Staff',
                              icons: (Icons.manage_accounts_sharp))),
                      SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context, 0.015),
                      ),
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ManageInventory()));
                              },
                              title: 'Invatory',
                              icons: (Icons.inventory)
                          )
                      )
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.01),
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ReportsScreen()));
                              },
                              title: 'Reports',
                              icons: (Icons.auto_graph_outlined)
                          )),
                      SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context, 0.015),
                      ),
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => taxSetting(),
                                    ));
                              },
                              title: 'Tax Setting',
                              icons: (Icons.settings)
                          ))
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.01),
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Settingsscreen()));
                              },
                              title: 'Setting',
                              icons: (Icons.settings))),
                      SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context, 0.015),
                      ),
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ExpenseScreen()));
                              },
                              title: 'Expense',
                              icons: (Icons.wallet)))
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.01),
                  ),
                  Row(
                    children: [
                      Expanded(
                          child: Listmenu(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => CompanyListScreen()));
                              },
                              title: 'Language',
                              icons: (Icons.language))),
                      SizedBox(
                        width: ResponsiveHelper.responsiveWidth(context, 0.015),
                      ),
                      Expanded(
                          child: Listmenu(
                            onTap: () {
                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) => AlertDialog(
                                    title: Text(
                                      'Are you sure you want to logout?',
                                      style: TextStyle(
                                        fontSize:
                                        ResponsiveHelper.responsiveTextSize(
                                            context, 15),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    actions: <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                        children: [
                                          CommonButton(
                                            bordercolor: Colors.red,
                                            bordercircular: 2,
                                            width: ResponsiveHelper.responsiveWidth(
                                                context, 0.2),
                                            height:
                                            ResponsiveHelper.responsiveHeight(
                                                context, 0.05),
                                            bgcolor: Colors.red,
                                            onTap: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: Text("Cancle"),
                                          ),
                                          SizedBox(
                                            width: 10,
                                          ),
                                          CommonButton(
                                            bordercircular: 2,
                                            width: ResponsiveHelper.responsiveWidth(
                                                context, 0.2),
                                            height:
                                            ResponsiveHelper.responsiveHeight(
                                                context, 0.05),
                                            bgcolor: primarycolor,
                                            onTap: () {
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          AdminLogin()));
                                            },
                                            child: Text(
                                              "Yes",
                                              style: GoogleFonts.poppins(
                                                fontSize: ResponsiveHelper
                                                    .responsiveTextSize(
                                                    context, 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ));
                            },
                            title: 'Logout',
                            icons: (Icons.logout),
                            color: Colors.red,
                          ))
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveHelper.responsiveHeight(context, 0.01),
                  ),
                  // Listmenu(title: 'start', icon: Icon(Icons.shopping_cart_sharp), titleS: 'Manage Menu', iconS: Icon(Icons.manage_accounts),)
                ],
              ),
            ),
          ),
        );
      }else{
        return Scaffold(
          appBar: AppBar(
            backgroundColor: screenBGColor,
            elevation: 10,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 1),
            title: Container(
              // color: Colors.red,
                alignment: Alignment.centerLeft,
                height: ResponsiveHelper.responsiveHeight(context, 0.3),

                // width: width ,
                // color: Colors.purple,
                child: Image.asset(
                  logo,
                  width: 150,
                  fit: BoxFit.fill,
                )),
            actions: [
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context)=> OnlineDesktop()));
                },
                child: Card(
                  color: Colors.white,
                  elevation: 25,
                  shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: 2.0,
                      )),
                  // color: Colors.white,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset('assets/icons/dinner.png'),
                  ),
                ),
              ),
              SizedBox(
                width: 5,
              ),
              VerticalDivider(
                width: 5,
              ),
              SizedBox(
                width: 5,
              ),
              Column(
                children: [
                  Image.asset(
                    'assets/icons/system-administration.png',
                    color: primarycolor,
                    width: 30,
                    height: 30,
                  ),
                  Text('Admin Panel')
                ],
              ),
              SizedBox(
                width: 5,
              ),
              VerticalDivider(
                width: 5,
              ),
              SizedBox(
                width: 5,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 5,left: 5),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/icons/support.png',
                      color: primarycolor,
                      width: 30,
                      height: 30,
                    ),
                    Text('Need Help?')
                  ],
                ),
              ),
              VerticalDivider(
                width: 5,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 5,right: 5),
                child: Row(
                  children: [
                    Icon(Icons.person),
                    Text(
                      'Admin',
                      style: GoogleFonts.poppins(fontSize: 12),
                      textScaler: TextScaler.linear(1),
                    ),
                  ],
                ),
              )
            ],
          ),
          body: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal:10 , vertical:10),
              child:
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Listmenud(Title: "Start Order",
                          onTap: () {


                            Navigator.push(context,MaterialPageRoute(builder: (context)=> Startorder()));
                            //
                            // ResponsiveHelper.isDesktop(context)?
                            // Navigator.push(
                            //     context,
                            //     MaterialPageRoute(
                            //         builder: (context) => StartorderD()))
                            //     :
                            // Navigator.push(
                            //     context,
                            //     MaterialPageRoute(
                            //         builder: (context) => Startorder()));
                          },
                          // img:'assets/icons/ecommerce.png'),
                          icons: (Icons.shopping_cart_sharp),
                        ),
                      ),
                      SizedBox(width: 10,),


                      Expanded(
                        child: Listmenud(Title: 'Manage Menu',
                            icons: (Icons.manage_accounts)

                        ),
                      ),
                      SizedBox(width: 10,),

                      Expanded(
                        child: Listmenud(Title: 'Manage Staff',
                            icons: (Icons.manage_accounts_sharp)
                        ),
                      )

                    ],
                  ),
                  Row(
                    children: [

                      Expanded(
                        child: Listmenud(
                            Title: 'Tax Setting',
                            icons: (Icons.settings)
                        ),
                      ),
                      SizedBox(width: 10,),


                      Expanded(
                        child: Listmenud(Title:'Reports',
                            icons: (Icons.auto_graph_outlined)),
                      ),

                      SizedBox(width: 10,),
                      Expanded(
                        child: Listmenud(

                            Title: 'Expense',
                            icons: (Icons.wallet)
                        ),
                      ),



                    ],
                  ),
                  Row(
                    children: [

                      Expanded(
                        child: Listmenud(
                            Title: 'Setting',
                            icons: (Icons.settings)
                        ),
                      ),
                      SizedBox(width: 10,),


                      Expanded(
                        child: Listmenud(Title:'Marketing',
                            icons: (Icons.auto_graph_outlined)),
                      ),

                      SizedBox(width: 10,),
                      Expanded(
                        child: Listmenud(

                            Title: 'LogOUt',
                            icons: (Icons.logout)
                        ),
                      ),



                    ],
                  ),
                  // InkWell(
                  //
                  //   onHover: (value){
                  //     setState(() {
                  //       elevationcard = 20;
                  //     });
                  //
                  //   },
                  //   child: Card(
                  //     elevation: elevationcard,
                  //     child:Container(
                  //       width: width * 0.3,
                  //       height: height * 0.2,
                  //       child: Column(
                  //         mainAxisAlignment: MainAxisAlignment.center,
                  //         children: [
                  //         Container(
                  //           padding: EdgeInsets.all(15),
                  //           width: width * 0.1,
                  //             height: height * 0.1,
                  //             decoration: BoxDecoration(
                  //               color: Color(0xffcbf1f0),
                  //               shape: BoxShape.circle,
                  //               // borderRadius: BorderRadius.circular(10)
                  //             ),
                  //             child: Image.asset('assets/icons/ecommerce.png')),
                  //           Text('Start Order',style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w500),)
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // )
                ],
              ),
            ),
          ),
        );
      }
    });*/
  }

  /// Improved logout dialog with better UI and proper navigation
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Colors.red,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.responsiveTextSize(context, 18),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
          ),
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  // Close dialog first
                  Navigator.of(dialogContext).pop();

                  // Clear login state from SharedPreferences
                  await _clearLoginState();

                  // Clear entire navigation stack and go to login screen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestaurantLogin(),
                    ),
                    (route) => false, // Remove all previous routes
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.responsiveTextSize(context, 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Clear login state from SharedPreferences
  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restaurant_is_logged_in', false);
  }
}
