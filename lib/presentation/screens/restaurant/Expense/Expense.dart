import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:billberrylite/presentation/screens/restaurant/Expense/viewexpense.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

import '../../../../util/common/app_responsive.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String selectedFilter = "Add Expense";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Add Expense":
        return Addexpence();
      case "View Expense":
        return ViewExpense();
      default:
        return Addexpence();
    }
  }

  Widget _buildTab(String label, IconData icon, BuildContext context) {
    final isSelected = selectedFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = label),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.smallSpacing(context),
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceMedium,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppResponsive.smallIconSize(context),
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
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
      appBar: buildPrimaryAppBar(title: 'Expenses'),
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
            // White strip spans the window; only the two tabs are capped, so
            // they do not stretch to ~700px each on a laptop.
            child: AppResponsive.constrainedContent(
              context: context,
              maxWidth: AppResponsive.maxContentWidth(context),
              heightFactor: 1,
              child: Row(
                children: [
                  _buildTab('Add Expense', Icons.add_circle_rounded, context),
                  SizedBox(width: 8),
                  _buildTab('View Expense', Icons.list_alt_rounded, context),
                ],
              ),
            ),
          ),

          // Body
          Expanded(child: _getBody()),
        ],
      ),
    );
  }
}
