
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/screens/restaurant/tabbar/pastorder.dart';
import 'package:unipos/util/color.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import 'activeorder.dart';

class Order extends StatefulWidget {
  final OrderModel? existingOrder;
  const Order({super.key, this.existingOrder});

  @override
  State<Order> createState() => _OrderState();
}

class _OrderState extends State<Order> {
  String selectedFilter = "Active Order";

  Widget _getBody() {
    switch (selectedFilter) {
      case "Active Order":
        return Activeorder();
      case "Past Order":
        return Pastorder();
      default:
        return Center(
          child: Text('NO DATA'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Tab Buttons
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            color: AppColors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = 'Active Order';
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      decoration: BoxDecoration(
                        color: selectedFilter == 'Active Order' ? AppColors.primary : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFilter == 'Active Order' ? AppColors.primary : AppColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: isTablet ? 22 : 20,
                            color: selectedFilter == 'Active Order' ? AppColors.white : AppColors.textSecondary,
                          ),
                          SizedBox(width: isTablet ? 10 : 8),
                          Text(
                            'Active Orders',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 16 : 15,
                              fontWeight: FontWeight.w600,
                              color: selectedFilter == 'Active Order' ? AppColors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = 'Past Order';
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      decoration: BoxDecoration(
                        color: selectedFilter == 'Past Order' ? AppColors.primary : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFilter == 'Past Order' ? AppColors.primary : AppColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: isTablet ? 22 : 20,
                            color: selectedFilter == 'Past Order' ? AppColors.white : AppColors.textSecondary,
                          ),
                          SizedBox(width: isTablet ? 10 : 8),
                          Text(
                            'Past Orders',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 16 : 15,
                              fontWeight: FontWeight.w600,
                              color: selectedFilter == 'Past Order' ? AppColors.white : AppColors.textSecondary,
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

          Expanded(child: _getBody()),
        ],
      ),
    );
  }
}
