import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/drawer.dart';



class StartorderD extends StatefulWidget {
  const StartorderD({super.key});

  @override
  State<StartorderD> createState() => _StartorderDState();
}

class _StartorderDState extends State<StartorderD> {
  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height * 1;
    double width = MediaQuery.of(context).size.width * 1;
    return  Scaffold(
      appBar:AppBar(
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 1),
        elevation: 5,
        title: Text('Orange',style: GoogleFonts.poppins(fontWeight: FontWeight.w600),),
        actions: [
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
                  color: Colors.white,
                  width: 2.0,
                )),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text('15'),
                  SizedBox(width: 5,),
                  Image.asset('assets/icons/restaurant.png')
                  // Container(
                  //   padding: EdgeInsets.all(10),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     shape: BoxShape.circle
                  //   ),
                  //   child: ,),
                ],
              ),
            ),
          ),
          SizedBox(width:25),
          Card(
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
              child: Image.asset('assets/icons/dinner.png'),),
          ),
          SizedBox(width:10),

          Card(
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
              child: Image.asset('assets/icons/volume.png'),),
          ),
          SizedBox(width:10),

          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
                  color: Colors.white,
                  width: 2.0,
                )),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle
              ),
              child: Image.asset('assets/icons/home.png'),),
          ),
          SizedBox(width:10),
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
                  color: Colors.white,
                  width: 2.0,
                )),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle
              ),
              child: Image.asset('assets/icons/printer3.png'),),
          ),
          SizedBox(width:10),
          Card(
            color: Colors.white,
            elevation: 25,
            shape: StadiumBorder(
                side: BorderSide(
                  color: Colors.white,
                  width: 2.0,
                )),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle
              ),
              child: Image.asset('assets/icons/internet.png'),),
          ),
          SizedBox(width:10),
          Card(
              color: Colors.white,
              elevation: 25,
              shape: StadiumBorder(
                  side: BorderSide(
                    color: Colors.white,
                    width: 2.0,
                  )),
              child:Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('V 5.8'),
              )
          ),
          SizedBox(width:10),
          Card(
              color: Colors.white,
              elevation: 25,
              shape: StadiumBorder(
                  side: BorderSide(
                    color: Colors.white,
                    width: 2.0,
                  )),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Image.asset('assets/icons/user.png'),
                    SizedBox(width:5),

                    Text('Admin'),
                    SizedBox(width:5),

                    Image.asset('assets/icons/arrows.png',height: 20,)
                  ],
                ),
              )
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                // color: Colors.red,
                width: width,
                height: height * 0.6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                        padding: EdgeInsets.only(left: 50),
                        width: width * 0.3,
                        // alignment: Alignment.center,
                        //   color: Colors.red,
                        child: Center(child: Image.asset('assets/images/menu.jpg',))),
                    SizedBox(height: 15),
                    Text('If Menu Is Already Added , Sync The Menu'),
                    SizedBox(height: 10,),
                    CommonButton(
                        height: height * 0.06,
                        width: width * 0.3,
                        onTap: (){},
                        child: Text("Sync Menu",style: GoogleFonts.poppins(fontWeight: FontWeight.w700),))
                  ],
                ) ,
              )
            ],
          ),
        ),
      ),
      drawer:Drawerr() ,
    );
  }
}
