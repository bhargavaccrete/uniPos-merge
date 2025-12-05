import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/util/restaurant/images.dart';


class Online_Completed extends StatefulWidget {
  const Online_Completed({super.key});

  @override
  State<Online_Completed> createState() => _Online_CompletedState();
}

class _Online_CompletedState extends State<Online_Completed> {
DateTime? _datepicker;
  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
    context: context,
initialDate: DateTime.now(),
firstDate: DateTime(2000), 
lastDate: DateTime(2100));
    
    if(pickedDate!= null){
      setState(() {
        _datepicker = pickedDate;
      });
    }
}
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            children: [
              // Manage menu and button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Online Order',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  Container(
                    width:width * 0.2,
                    height: height * 0.04,
                    decoration: BoxDecoration(
                        border: Border.all(color: primarycolor)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            decoration:BoxDecoration(
                              border: Border.all(color: primarycolor),
                              shape: BoxShape.circle,

                            ),
                            child: Icon(Icons.volume_mute_outlined,color: Colors.deepOrange,)),
                        Text('Mute',style: GoogleFonts.poppins(fontWeight: FontWeight.w600),)
                      ],
                    ),
                  )
                ],
              ),
              SizedBox(height:10,),
              Container(
                // color: Colors.green,
                width: width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle,color: Colors.green,size: 10,),
                        SizedBox(width: 5,),

                        Text('Paid',style: GoogleFonts.poppins(color: Colors.green,fontSize: 15),),
                        SizedBox(width: 10,),

                        Icon(Icons.circle,color: Colors.red,size: 10,),
                        SizedBox(width: 5,),

                        Text('UnPaid',style: GoogleFonts.poppins(color: Colors.red,fontSize: 15),),
                      ],
                    ),

                    InkWell(
                      onTap: (){
                        _pickDate(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.grey)
                        ),
                        child: Row(
                          children: [

                            Icon(Icons.date_range,color: primarycolor,),
                            Text(
                              _datepicker == null
                                  ? 'Date Filter'
                                  : '${_datepicker!.year}-${_datepicker!.month}-${_datepicker!.day}',style: GoogleFonts.poppins(color: primarycolor),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),


              Container(
                // alignment: Alignment.bottomCenter,
                width: width,
                height: height * 0.7,
                // color: Colors.red,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Lottie.asset(notfoundanimation,height: height * 0.3),
                    Text('No Order Found',style: GoogleFonts.poppins(fontWeight: FontWeight.w600,fontSize: 16),)

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

