import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/viewexpense.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';

import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../../../util/common/app_responsive.dart';

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

  Widget _buildTab(String label, IconData icon, BuildContext context) {
    final isSelected = selectedFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = label),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceMedium,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppResponsive.smallIconSize(context), color: isSelected ? Colors.white : AppColors.textSecondary),
              SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context), fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: DrawerManage(issync: false, isDelete: false, islogout: false),
      appBar: buildPrimaryAppBar(
        title: 'Expenses',
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: AppColors.white,
            padding: EdgeInsets.fromLTRB(
              AppResponsive.largeSpacing(context),
              AppResponsive.mediumSpacing(context),
              AppResponsive.largeSpacing(context),
              AppResponsive.mediumSpacing(context),
            ),
            child: Row(
              children: [
                _buildTab('Add Expense', Icons.add_circle_rounded, context),
                SizedBox(width: 8),
                _buildTab('View Expense', Icons.list_alt_rounded, context),
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