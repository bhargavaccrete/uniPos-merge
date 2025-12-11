import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/paymentsMethods.dart';

import '../../../../util/restaurant/currency_helper.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';
import '../../../widget/componets/restaurant/componets/manuListViewWithNavigation.dart';
import '../../../widget/componets/restaurant/componets/toggleSwitch.dart';
import 'addressCustomizationScreen.dart';
import 'changePassword.dart';
import 'data_generator_screen.dart';
import 'orderNotificationSetting.dart';
import 'orderSettings.dart';

class Settingsscreen extends StatefulWidget {
  @override
  _settingsScreenState createState() => _settingsScreenState();
}

class _settingsScreenState extends State<Settingsscreen> {
  bool _isSelected = false;
  String selectedFilter = "None";
  String selectedCurrency = "INR";

  @override
  void initState() {
    super.initState();
    _loadSelectedCurrency();
  }

  // Load saved currency from preferences
  Future<void> _loadSelectedCurrency() async {
    final currency = await CurrencyHelper.getCurrencyCode();
    setState(() {
      selectedCurrency = currency;
    });
  }

  Widget _getBody() {
    switch (selectedFilter) {
      case "None":
        return takeAway();
      case "0.0":
        return dineIn();
      case "0.00":
        return homeDelivery();
      case "0.000":
        return delivery();
      default:
        return takeAway();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width * 1;
    final screenheight = MediaQuery.of(context).size.height * 1;
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          elevation: 1,
          actions: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                  ),
                  Text("Admin",style: TextStyle(fontSize: 15.0,fontWeight: FontWeight.bold),)
                ],
              ),
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    "Settings",
                    textScaler: TextScaler.linear(1.2),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  MultipleListViewWithNavigation(
                    displayTitle: "Address Customization",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AddressCustomizationScreen()));
                    },
                  ),
                  MultipleListViewWithNavigation(
                    displayTitle: "Password Change",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Changepassword()));
                    },
                  ),
                  MultipleListViewWithNavigation(
                    displayTitle: "Order Settings",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Ordersettings()));
                    },
                  ),
                  MultipleListViewWithNavigation(
                    displayTitle: "Payment Methods",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Paymentsmethods()));
                    },
                  ),
                  MultipleListViewWithNavigation(
                    displayTitle: 'Online Order Notification Settings',
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => OrderNotificationsettings()));
                    },
                  ),
                  MultipleListViewWithNavigation(
                    displayTitle: 'Performance Test Data Generator',
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DataGeneratorScreen()));
                    },
                  ),
                  // 👇 Fix the Decimal point section
                  MultipleListViewWithNavigation(
                    screenheightt: screenheight * 0.16,
                    displayTitle: "Decimal point",
                    displayicon: Icons.keyboard_arrow_down,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Ordersettings()));
                    },
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Filterbutton(

                          title: 'None',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "None";
                            });
                          },
                        ),
                        Filterbutton(
                          title: '0.0',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "0.0";
                            });
                          },
                        ),
                        Filterbutton(
                          title: '0.00',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "0.00";
                            });
                          },
                        ),
                        Filterbutton(
                          title: '0.000',
                          selectedFilter: selectedFilter,
                          onpressed: () {
                            setState(() {
                              selectedFilter = "0.000";
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // 💰 Currency Selection Section
                  MultipleListViewWithNavigation(
                    screenheightt: screenheight * 0.25,
                    displayTitle: "Currency Symbol",
                    displayicon: Icons.keyboard_arrow_down,
                    onTap: () {},
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: CurrencyHelper.currencies.entries.map((entry) {
                        final currencyInfo = entry.value;
                        final buttonTitle = '${currencyInfo.symbol} ${currencyInfo.code}';
                        return Filterbutton(
                          title: buttonTitle,
                          selectedFilter: '${CurrencyHelper.currencies[selectedCurrency]?.symbol ?? '\$'} $selectedCurrency',
                          onpressed: () async {
                            setState(() {
                              selectedCurrency = currencyInfo.code;
                            });
                            await CurrencyHelper.setCurrency(currencyInfo.code);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        drawer: DrawerManage(
          issync: false,
          isDelete: true,
          islogout: true,
        ));
  }
}

Widget takeAway() {
  return Column(
    children: [
      ToggleSwitch(widthc: 0.7, initialValue: false, label: "None "),
      ToggleSwitch(widthc: 0.85, initialValue: false, label: "0.0 ")
    ],
  );
}

Widget dineIn() {
  return Column(
    children: [
      ToggleSwitch(widthc: 0.5, initialValue: false, label: "0.00 "),
    ],
  );
}

Widget homeDelivery() {
  return Column(
    children: [ToggleSwitch(widthc: 0.85, initialValue: false, label: " 0.00")],
  );
}

Widget delivery() {
  return Column(
    children: [ToggleSwitch(widthc: 0.85, initialValue: false, label: " 0.000 ")],
  );
}
