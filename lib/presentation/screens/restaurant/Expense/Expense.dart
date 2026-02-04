import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/viewexpense.dart';
import 'package:unipos/util/color.dart';

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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: DrawerManage(issync: false, isDelete: false, islogout: false),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.menu, color: AppColors.white, size: 24),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense Management',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          selectedFilter,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 10 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      size: isTablet ? 22 : 20,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tabs Section
          Container(
            color: AppColors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = "Add Expense";
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selectedFilter == "Add Expense" ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFilter == "Add Expense" ? AppColors.primary : AppColors.divider,
                          width: selectedFilter == "Add Expense" ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_rounded,
                            size: 20,
                            color: selectedFilter == "Add Expense" ? AppColors.white : AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add Expense',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selectedFilter == "Add Expense" ? AppColors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = "View Expense";
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selectedFilter == "View Expense" ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFilter == "View Expense" ? AppColors.primary : AppColors.divider,
                          width: selectedFilter == "View Expense" ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 20,
                            color: selectedFilter == "View Expense" ? AppColors.white : AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'View Expense',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selectedFilter == "View Expense" ? AppColors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(child: _getBody()),
        ],
      ),
    );
  }
}

