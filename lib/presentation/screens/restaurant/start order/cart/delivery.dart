import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
class Delivery extends StatelessWidget {
  const Delivery({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Column(
            children: [
              // item Row
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                color: Colors.teal.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items',
                      style:
                      TextStyle(fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.0, desktop: 20.0), fontWeight: FontWeight.w500),
                    ),
                    Text('Qty',
                        style: TextStyle(
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.0, desktop: 20.0), fontWeight: FontWeight.w500)),
                    Text('Amount',
                        style: TextStyle(
                            fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.0, desktop: 20.0), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),

              // NewOrder
              SizedBox(
                height: 10,
              ),
              Container(
                alignment: Alignment.center,
                width: width * 0.3,
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(width: 2, color: AppColors.primary),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(
                  'New Order',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0)),
                ),
              ),

              // Items

              SizedBox(height: 10,),
              Container(
                alignment: Alignment.topCenter,
                height: height * 0.5,
                // color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fruit Punch'),
                    Row(
                      children: [
                        Icon(Icons.remove,color: AppColors.primary,),
                        SizedBox(width: 5,),
                        Container(
                          alignment: Alignment.center,
                          width: width * 0.06,
                          height: height * 0.04,
                          decoration: BoxDecoration(
                            // color: Colors.red,
                              border: Border.all(color: AppColors.textSecondary),
                              shape: BoxShape.circle),
                          child: Text(
                            '1',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        SizedBox(width: 5,),
                        Icon(Icons.add,color: AppColors.primary,)
                      ],
                    ),

                    Text('149.00',style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 16.0, tablet: 17.0, desktop: 18.0),fontWeight: FontWeight.bold),)
                  ],
                ),
              ),




              CommonButton(
                  width: width*0.3,
                  height: height * 0.05,
                  onTap: (){}, child: Center(child: Text('Add Item',style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500,fontSize: AppResponsive.getValue(context, mobile: 14.0, tablet: 15.0, desktop: 16.0)),))),
              SizedBox(height: 10,),

              Container(
                width: width,
                height: height * 0.5,
                color: Colors.indigo.shade50,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total:',style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 20.0, tablet: 21.0, desktop: 22.0),fontWeight: FontWeight.bold),),
                        Text('Rs.149.00',style: GoogleFonts.poppins(fontSize: AppResponsive.getValue(context, mobile: 20.0, tablet: 21.0, desktop: 22.0),fontWeight: FontWeight.bold),)
                      ],
                    ),
                    SizedBox(height: 25,),
                    // button
                    CommonButton(
                        width: width,
                        height: height * 0.06,
                        onTap: (){}, child: Center(child: Text('Settle & Print Bill ',style: GoogleFonts.poppins(color: Colors.white,fontWeight: FontWeight.w500,fontSize: AppResponsive.getValue(context, mobile: 18.0, tablet: 19.0, desktop: 20.0)),))),


                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
