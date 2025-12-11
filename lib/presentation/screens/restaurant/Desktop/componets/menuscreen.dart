import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Desktop/componets/ListMenuD.dart';
import 'package:unipos/util/restaurant/images.dart';
import 'package:unipos/util/restaurant/responsive_helper.dart';


class MenuscreenDesktop extends StatefulWidget {
  const MenuscreenDesktop({super.key});

  @override
  State<MenuscreenDesktop> createState() => _MenuscreenDesktopState();
}

class _MenuscreenDesktopState extends State<MenuscreenDesktop> {
  // double _elevationCard = 4.0; // Initial elevation
  // final double _hoverElevation = 20.0; // Elevation on hover
  // final double _defaultElevation = 4.0; // Default elevation

  double  elevationcard = 5;
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return
      Scaffold(
        appBar: AppBar(
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
                // Navigator.push(context, MaterialPageRoute(builder: (context)=> OnlineDesktop()));
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
}

