import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/viewexpense.dart';

import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String selectedFilter = "Add Expense";

  Widget _getBody(){
    switch(selectedFilter){
      case "Add Expense":
        return Addexpence();
        case "View Expense":
          return ViewExpense();
          default:
            return  Addexpence();
    }
  }

  // Widget _getBody(){
  //   switch(selectedFilter){
  //     case "Day Wise":
  //       return DayWisebyDaily();
  //     case "MonthWise":
  //       return MonthWisebyDaily();
  //     case "Custome":
  //       return CustomeDaily();
  //     default:
  //       return Center(
  //         child: Text('NO Data AVAILABE'),
  //       );
  //   }
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.person_2_outlined,size: 30,),
                Text('Admin',style: GoogleFonts.poppins(),)
              ],
            ),
          ),
        ],
      ),
      drawer: DrawerManage(issync: false, isDelete: false, islogout: false),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
        child:  Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Expense
            Text('Expense',style: GoogleFonts.poppins(fontSize: 18,fontWeight: FontWeight.w600),),

            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [


                Filterbutton(
                    borderc: 0,
                    title: "Add Expense",
                    selectedFilter: selectedFilter,
                    onpressed: (){
                  setState(() {
                    selectedFilter = "Add Expense";
                  });
                    }),
                SizedBox(width:20),
                Filterbutton(
                    borderc: 0,
                    title: "View Expense",
                    selectedFilter: selectedFilter,
                    onpressed: (){
                  setState(() {
                    selectedFilter = "View Expense";
                  });
                    })
                         ],
            ),
            Divider(),
            Expanded(child: _getBody())


          ],
        ),
      ),
    );
  }
}
