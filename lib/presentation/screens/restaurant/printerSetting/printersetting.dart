import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/addprinter.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';

class Printersetting extends StatefulWidget {
  const Printersetting({super.key});

  @override
  State<Printersetting> createState() => _PrintersettingState();
}

class _PrintersettingState extends State<Printersetting> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Printer Setting',
          textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(fontSize: 20),
        ),
        leading: BackButton(),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(children: [
            Container(
              padding: EdgeInsets.all(5),
              decoration:
                  BoxDecoration(border: Border.all(color: primarycolor)),
              width: width,
              height: height * 0.35,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.list_alt,
                      size: 50, color: Colors.deepOrangeAccent),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manually Print',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w500)),
                      Text(
                          'Tou can print KOT and order bill \nmanually by clicking Print KOT and\n Print Bill',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 12))
                    ],
                  ),
                  // SizedBox(width: 20,),
                  Icon(
                    Icons.check_circle_rounded,
                    color: primarycolor,
                    size: 40,
                  )
                ],
              ),
            ),
            SizedBox(
              height: 25,
            ),
            Container(
              padding: EdgeInsets.all(5),
              decoration:
                  BoxDecoration(border: Border.all(color: primarycolor)),
              width: width,
              height: height * 0.35,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.settings,
                      size: 50, color: Colors.deepOrangeAccent),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto Print',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w500)),
                      Text(
                          'Your Order KOt Will print Automaticaly \nas soon as new order placed as \nsoon as new order Settled',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(fontSize: 12))
                    ],
                  ),
                  // SizedBox(width: 20,),
                  Icon(
                    Icons.check_circle_rounded,
                    color: primarycolor,
                    size: 40,
                  )
                ],
              ),
            ),
            SizedBox(
              height: 25,
            ),
            // printer details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Printer Detail',
                    textScaler: TextScaler.linear(1),
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w500)),
                CommonButton(
                    bordercircular: 0,
                    width: width * 0.3,
                    height: height * 0.08,
                    onTap: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                        Text(
                          'Refresh',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(color: Colors.white),
                        )
                      ],
                    ))
              ],
            ),

            SizedBox(
              height: 25,
            ),
            Container(
              // color: Colors.red,
              height: height * 0.7,
              child: Column(
                children: [
                  Card(
                    elevation: 10,
                    child: Container(
                      alignment: Alignment.center,
                      width: width,
                      height: height * 0.2,
                      child: Text('No Printer Found',
                          textScaler: TextScaler.linear(1),
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
            CommonButton(
                borderwidth: 0,
                bordercolor: Colors.grey.shade300,
                bgcolor: Colors.grey.shade300,
                width: width * 0.6,
                height: height * 0.15,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => AddPrinter()));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                        )),
                    SizedBox(
                      width: 5,
                    ),
                    Text('Add Printer',
                        textScaler: TextScaler.linear(1),
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500))
                  ],
                ))
          ]),
        ),
      ),
    );
  }
}
