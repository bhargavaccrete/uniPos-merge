import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          'Order Settings',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isTablet ? 22 : 20,
                    color: AppColors.primary,
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(width: 10),
                  Text(
                    'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
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
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
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
                SizedBox(width: 8),
                Filterbutton(
                  title: 'dine in',
                  selectedFilter: selectedFilter,
                  onpressed: () {
                    setState(() {
                      selectedFilter = "dine in";
                    });
                  },
                ),
                SizedBox(width: 8),
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
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
          SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
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