import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/addexpence.dart';
import 'package:unipos/presentation/screens/restaurant/Expense/viewexpense.dart';
import 'package:unipos/util/color.dart';

import '../../../widget/componets/restaurant/componets/drawermanage.dart';

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

  Widget _buildTab(String label, IconData icon) {
    final isSelected = selectedFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = label),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
              SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
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
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(12, 16, 20, 12),
            color: AppColors.white,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: Icon(Icons.menu, size: 24),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Expense', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),

          // Tabs
          Container(
            color: AppColors.white,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _buildTab('Add Expense', Icons.add_circle_rounded),
                SizedBox(width: 8),
                _buildTab('View Expense', Icons.list_alt_rounded),
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