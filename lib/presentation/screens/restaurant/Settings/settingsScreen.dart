import 'package:flutter/material.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/paymentsMethods.dart';

import '../../../../util/common/currency_helper.dart';
import '../../../widget/componets/restaurant/componets/drawermanage.dart';
import '../../../widget/componets/restaurant/componets/filterButton.dart';
import '../../../widget/componets/restaurant/componets/manuListViewWithNavigation.dart';
import 'package:unipos/util/common/decimal_settings.dart';

class Settingsscreen extends StatefulWidget {
  const Settingsscreen({super.key});
  @override
  _settingsScreenState createState() => _settingsScreenState();
}

class _settingsScreenState extends State<Settingsscreen> {
  String selectedCurrency = "INR";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    await DecimalSettings.load();
    // Currency is already loaded in main.dart, just get current value
    setState(() {
      selectedCurrency = CurrencyHelper.currentCurrencyCode;
    });
  }

  // Get decimal filter string from precision value
  String _getDecimalFilter(int precision) {
    switch (precision) {
      case 0:
        return "None";
      case 1:
        return "0.0";
      case 2:
        return "0.00";
      case 3:
        return "0.000";
      default:
        return "0.00";
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
              /*------ADDRESS CUSTOMIZATION--------------*/

              /*    MultipleListViewWithNavigation(
                    displayTitle: "Address Customization",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AddressCustomizationScreen()));
                    },
                  ),*/
                  MultipleListViewWithNavigation(
                    displayTitle: "Password Change",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => Changepassword()));

                      Navigator.pushNamed(context, RouteNames.restaurantChangePassword);
                    },
                  ),

                  MultipleListViewWithNavigation(
                    displayTitle: "Order Settings",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => Ordersettings()));

                      Navigator.pushNamed(context, RouteNames.restaurantOrderSettings);
                    },
                  ),

                  MultipleListViewWithNavigation(
                    displayTitle: "Payment Methods",
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => Paymentsmethods()));
                      Navigator.pushNamed(context, RouteNames.restaurantPaymentMethods);

                      },
                  ),

                  // MultipleListViewWithNavigation(
                  //   displayTitle: 'Online Order Notification Settings',
                  //   displayicon: Icons.keyboard_arrow_right,
                  //   onTap: () {
                  //     Navigator.push(context, MaterialPageRoute(builder: (context) => OrderNotificationsettings()));
                  //   },
                  // ),
                  MultipleListViewWithNavigation(
                    displayTitle: 'Performance Test Data Generator',
                    displayicon: Icons.keyboard_arrow_right,
                    onTap: () {
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => DataGeneratorScreen()));
                      Navigator.pushNamed(context, RouteNames.restaurantDataGenratorScreen);


                    },
                  ),
                  // 💰 Decimal Precision Section
                  ValueListenableBuilder<int>(
                    valueListenable: DecimalSettings.precisionNotifier,
                    builder: (context, currentPrecision, child) {
                      final selectedFilter = _getDecimalFilter(currentPrecision);

                      return MultipleListViewWithNavigation(
                        screenheightt: screenheight * 0.16,
                        displayTitle: "Decimal Precision",
                        displayicon: Icons.keyboard_arrow_down,
                        onTap: () {},
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Filterbutton(
                              title: 'None',
                              selectedFilter: selectedFilter,
                              onpressed: () async {
                                await DecimalSettings.updatePrecision(0);
                              },
                            ),
                            Filterbutton(
                              title: '0.0',
                              selectedFilter: selectedFilter,
                              onpressed: () async {
                                await DecimalSettings.updatePrecision(1);
                              },
                            ),
                            Filterbutton(
                              title: '0.00',
                              selectedFilter: selectedFilter,
                              onpressed: () async {
                                await DecimalSettings.updatePrecision(2);
                              },
                            ),
                            Filterbutton(
                              title: '0.000',
                              selectedFilter: selectedFilter,
                              onpressed: () async {
                                await DecimalSettings.updatePrecision(3);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // 💰 Currency Selection Section (Reactive)
                  ValueListenableBuilder<String>(
                    valueListenable: CurrencyHelper.currencyNotifier,
                    builder: (context, currentCurrency, child) {
                      return MultipleListViewWithNavigation(
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
                            final selectedDisplay = '${CurrencyHelper.currentSymbol} ${CurrencyHelper.currentCurrencyCode}';
                            return Filterbutton(
                              title: buttonTitle,
                              selectedFilter: selectedDisplay,
                              onpressed: () async {
                                await CurrencyHelper.setCurrency(currencyInfo.code);
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
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
