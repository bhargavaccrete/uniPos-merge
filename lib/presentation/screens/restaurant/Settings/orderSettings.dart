import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

import '../../../../util/restaurant/order_settings.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';
import '../../../widget/componets/restaurant/componets/toggleSwitch.dart';

class Ordersettings extends StatefulWidget {
  @override
  _orderSettingsState createState() => _orderSettingsState();
}

class _orderSettingsState extends State<Ordersettings> {
  String selectedFilter = "Take Away";

  @override
  void initState() {
    super.initState();
    // Load order settings when screen opens
    OrderSettings.load();
  }

  Widget _getBody() {
    switch (selectedFilter) {
      case "Take Away":
        return takeAway();
      case "dine in":
        return dineIn();
      case "Home Delivery":
        return homeDelivery();
      default:
        return takeAway();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Order Settings',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.headingFontSize(context),
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.mediumSpacing(context),
              vertical: AppResponsive.smallSpacing(context),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppResponsive.smallBorderRadius(context)),
                  ),
                  child: Icon(
                    Icons.person,
                    size: AppResponsive.iconSize(context),
                    color: AppColors.primary,
                  ),
                ),
                if (AppResponsive.isTablet(context) || AppResponsive.isDesktop(context)) ...[
                  SizedBox(width: AppResponsive.smallSpacing(context)),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            width: double.infinity,
            padding: AppResponsive.padding(context),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: AppResponsive.shadowBlurRadius(context),
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: AppResponsive.isDesktop(context)
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Filterbutton(
                        title: 'Take Away',
                        selectedFilter: selectedFilter,
                        onpressed: () {
                          setState(() {
                            selectedFilter = "Take Away";
                          });
                        },
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Filterbutton(
                        title: 'dine in',
                        selectedFilter: selectedFilter,
                        onpressed: () {
                          setState(() {
                            selectedFilter = "dine in";
                          });
                        },
                      ),
                      SizedBox(width: AppResponsive.mediumSpacing(context)),
                      Filterbutton(
                        title: 'Home Delivery',
                        selectedFilter: selectedFilter,
                        onpressed: () {
                          setState(() {
                            selectedFilter = "Home Delivery";
                          });
                        },
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Filterbutton(
                          title: 'Take Away',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "Take Away";
                            });
                          },
                        ),
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Filterbutton(
                          title: 'dine in',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "dine in";
                            });
                          },
                        ),
                        SizedBox(width: AppResponsive.smallSpacing(context)),
                        Filterbutton(
                          title: 'Home Delivery',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "Home Delivery";
                            });
                          },
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: AppResponsive.screenPadding(context),
              child: _getBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget takeAway() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: AppResponsive.cardPadding(context),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: OrderSettings.enableTakeAwayNotifier,
            builder: (context, isEnabled, child) {
              return ToggleSwitch(
                widthc: 0.9,
                initialValue: isEnabled,
                label: "Enable Take Away?",
                onChanged: (value) async {
                  await OrderSettings.setEnableTakeAway(value);
                },
              );
            },
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.medium),
          ValueListenableBuilder<bool>(
            valueListenable: OrderSettings.showTakeAwayDialogNotifier,
            builder: (context, showDialog, child) {
              return ToggleSwitch(
                widthc: 0.9,
                initialValue: showDialog,
                label: "Enable Place Order Dialog?",
                onChanged: (value) async {
                  await OrderSettings.setShowTakeAwayDialog(value);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget dineIn() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: AppResponsive.cardPadding(context),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: OrderSettings.enableDineInNotifier,
            builder: (context, isEnabled, child) {
              return ToggleSwitch(
                widthc: 0.9,
                initialValue: isEnabled,
                label: "Enable Dine In?",
                onChanged: (value) async {
                  await OrderSettings.setEnableDineIn(value);
                },
              );
            },
          ),
          AppResponsive.verticalSpace(context, size: SpacingSize.medium),
          ValueListenableBuilder<bool>(
            valueListenable: OrderSettings.showDineInDialogNotifier,
            builder: (context, showDialog, child) {
              return ToggleSwitch(
                widthc: 0.9,
                initialValue: showDialog,
                label: "Enable Place Order Dialog?",
                onChanged: (value) async {
                  await OrderSettings.setShowDineInDialog(value);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget homeDelivery() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: AppResponsive.shadowBlurRadius(context),
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: AppResponsive.cardPadding(context),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: OrderSettings.enableDeliveryNotifier,
            builder: (context, isEnabled, child) {
              return ToggleSwitch(
                widthc: 0.9,
                initialValue: isEnabled,
                label: "Enable Home Delivery?",
                onChanged: (value) async {
                  await OrderSettings.setEnableDelivery(value);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}