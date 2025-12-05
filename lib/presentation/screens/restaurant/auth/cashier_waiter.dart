import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/presentation/screens/restaurant/auth/admin_login.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/manuListViewWithNavigation.dart';
import 'package:unipos/util/restaurant/images.dart';

class CashierWaiter extends StatefulWidget {
  @override
  _CashierWaiterState createState() => _CashierWaiterState();
}

class _CashierWaiterState extends State<CashierWaiter> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      backgroundColor: screenBGColor,
     
      body: SingleChildScrollView(
       
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          
          children: [
             Container(
              padding: EdgeInsets.all(10), 
              alignment: Alignment.center,
              height: height * 0.20,
              width:width * 0.5,
              child: Image.asset(logo)),
              Padding(
                padding: const EdgeInsets.all(30),
                child: Text("Select Cashier | Waiter",style: TextStyle(fontSize: 20),),
              ),
              Container(
                width: width,
                height: height*0.5,
               child: RawScrollbar(
                thumbColor: primarycolor,
                thickness: 5,
                
                
                child: 
               ListView.builder(itemCount: 10,
                itemBuilder: (context, index) {
                return MultipleListViewWithNavigation(displayTitle: 'cashier', onTap: (){
                  Navigator.push(context,MaterialPageRoute(builder: (context)=> AdminLogin()));
                });
               })), 
               ),

            Padding(
              padding: const EdgeInsets.all(50),
              child: CommonButton(onTap: (){
                Navigator.pop(context);
              },bgcolor: Colors.white, child: Text("Back",style: TextStyle(color: primarycolor),)),
            ),
          ],
        ),
      ),
    );
  }
}
