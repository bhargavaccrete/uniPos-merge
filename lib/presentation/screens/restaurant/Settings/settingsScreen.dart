import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/presentation/screens/restaurant/Settings/paymentsMethods.dart';
import 'package:unipos/util/color.dart';

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
  bool _isDecimalExpanded = false;
  bool _isCurrencyExpanded = false;

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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final screenheight = size.height;

    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black87),
          title: Text(
            'Settings',
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
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navigation Options Section
                  Text(
                    'General Settings',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),

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

                  SizedBox(height: isTablet ? 24 : 20),

                  // Display Settings Section
                  Text(
                    'Display Settings',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),

                  // 💰 Decimal Precision Section
                  ValueListenableBuilder<int>(
                    valueListenable: DecimalSettings.precisionNotifier,
                    builder: (context, currentPrecision, child) {
                      final selectedFilter = _getDecimalFilter(currentPrecision);

                      return MultipleListViewWithNavigation(
                        screenheightt: screenheight * 0.16,
                        displayTitle: "Decimal Precision",
                        displayicon: _isDecimalExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        onTap: () => setState(() => _isDecimalExpanded = !_isDecimalExpanded),
                        child: _isDecimalExpanded
                            ? Wrap(
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
                              )
                            : null,
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
                        displayicon: _isCurrencyExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        onTap: () => setState(() => _isCurrencyExpanded = !_isCurrencyExpanded),
                        child: _isCurrencyExpanded
                            ? Wrap(
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
                              )
                            : null,
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
