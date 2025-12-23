import 'package:flutter/material.dart';

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
    final screenWidth = MediaQuery.of(context).size.width * 1;
    final screenheight = MediaQuery.of(context).size.height * 1;
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        actions: [
          Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "Order Settings ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  Icon(Icons.person),
                  Text('Admin'),
                ],
              )
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              width:screenWidth*0.9 ,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
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
                  Filterbutton(
                    title: 'dine in',
                    selectedFilter: selectedFilter,
                    onpressed: () {
                      setState(() {
                        selectedFilter = "dine in";
                      });
                    },
                  ),
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
          Expanded(child: _getBody()),
        ],
      ),
    );
  }

  Widget takeAway() {
    return Column(
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
        SizedBox(height: 10),
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
    );
  }

  Widget dineIn() {
    return Column(
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
        SizedBox(height: 10),
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
    );
  }

  Widget homeDelivery() {
    return Column(
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
    );
  }
}