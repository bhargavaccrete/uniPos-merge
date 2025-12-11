import 'package:flutter/material.dart';

import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/restaurant/componets/manyListViewWithBottomSheet.dart';



class Taxragistration extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.height * 1;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(onPressed: (){Navigator.of(context).pop();}, icon: Icon(Icons.arrow_back_ios_new_outlined)),
        elevation: 1,
        actions: [
          Padding(padding:
          EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person),
                Text('Admin')
              ],
            ),)
        ],
      ),

      body:
      SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          // height: height * 0.6,
          child: Column(
            children: [
              Container(
                height: height *0.7,

                // color: Colors.green,
                child: MultipleListView(
                  ShowText: "Text Ragistration",

                  lists: [['TAX NAME : ','DRR','TAX NUMBER : ','25412']], ),
              ),

              CommonButton(
                  bgcolor: Colors.grey,
                  bordercolor: Colors.grey,
                  height: height * 0.08,
                  width: width * 0.9,
                  bordercircular: 10,
                  onTap: (){}, child:Text("Add Tax Name & Number",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),) ),
            ],
          ),
        ),
      ),



    );
  }
}