import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/presentation/screens/restaurant/tabbar/pastorder.dart';
import 'package:billberrylite/util/color.dart';

import '../../../../constants/restaurant/color.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../util/common/app_responsive.dart';
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
        return Center(child: Text('NO DATA'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Tab Buttons
          Container(
            padding: AppResponsive.padding(context),
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
                      // 14/16 falls between named steps — a raw ladder keeps
                      // mobile and tablet exact and adds the missing desktop rung.
                      padding: EdgeInsets.symmetric(
                        vertical: AppResponsive.getValue(
                          context,
                          mobile: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: selectedFilter == 'Active Order'
                            ? AppColors.primary
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                        border: Border.all(
                          color: selectedFilter == 'Active Order'
                              ? AppColors.primary
                              : AppColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: AppResponsive.iconSize(context),
                            color: selectedFilter == 'Active Order'
                                ? AppColors.white
                                : AppColors.textSecondary,
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Text(
                            'Active Orders',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.buttonFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: selectedFilter == 'Active Order'
                                  ? AppColors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppResponsive.mediumSpacing(context)),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = 'Past Order';
                      });
                    },
                    child: Container(
                      // 14/16 falls between named steps — a raw ladder keeps
                      // mobile and tablet exact and adds the missing desktop rung.
                      padding: EdgeInsets.symmetric(
                        vertical: AppResponsive.getValue(
                          context,
                          mobile: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: selectedFilter == 'Past Order'
                            ? AppColors.primary
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(
                          AppResponsive.borderRadius(context),
                        ),
                        border: Border.all(
                          color: selectedFilter == 'Past Order'
                              ? AppColors.primary
                              : AppColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: AppResponsive.iconSize(context),
                            color: selectedFilter == 'Past Order'
                                ? AppColors.white
                                : AppColors.textSecondary,
                          ),
                          SizedBox(width: AppResponsive.smallSpacing(context)),
                          Text(
                            'Past Orders',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.buttonFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: selectedFilter == 'Past Order'
                                  ? AppColors.white
                                  : AppColors.textSecondary,
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

          // Cap the CONTENT, not the tab strip above it — same split
          // manage_menu_screen uses. The children (ActiveOrder / PastOrder)
          // stay uncapped so nothing is constrained twice.
          Expanded(
            child: AppResponsive.constrainedContent(
              context: context,
              maxWidth: AppResponsive.maxContentWidth(context),
              alignment: Alignment.topCenter,
              child: _getBody(),
            ),
          ),
        ],
      ),
    );
  }
}
