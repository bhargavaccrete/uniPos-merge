import 'package:flutter/material.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/core/routes/app_routes.dart';
import 'package:unipos/core/routes/routes_name.dart';

import 'package:unipos/server/server.dart';
import 'package:unipos/util/common/currency_helper.dart';

import 'domain/store/restaurant/appStore.dart';
import 'util/common/decimal_settings.dart';
import 'util/restaurant/staticswitch.dart';
import 'util/restaurant/print_settings.dart';
import 'util/restaurant/order_settings.dart';
import 'domain/services/retail/retail_printer_settings_service.dart';
final appStore = AppStore();

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with Flutter and register common adapters
  // await HiveInit.init();


  // // Initialize AppConfig (stores business mode selection)
  // await AppConfig.init();


// Open common boxes (needed regardless of business mode)



  // Initialize Hive FIRST, then AppConfig
  await HiveInit.init();
  await AppConfig.init();


  // Initialize business-specific boxes if business mode is already set
  // (This handles the case where app is restarted after initial setup)

  await HiveInit.openCommonBoxes();
  await HiveInit.initializeBusinessBoxes();

  // Setup GetIt dependency injection
  // IMPORTANT: This must be called AFTER boxes are initialized
  await setupServiceLocator();


    // Load restaurant customization settings from SharedPreferences
  if (AppConfig.isRestaurant) {
    // await AppSettings.load();
    // print('⚙️  Restaurant settings loaded');
    //
    // // Load print customization settings
    // await PrintSettings.load();
    // print('🖨️  Print settings loaded');
    //
    // // Load decimal precision settings
    // await DecimalSettings.load();
    // print('💰 Decimal precision loaded: ${DecimalSettings.precision} places');
    //
    // // Load order settings
    // await OrderSettings.load();
    // print('📋 Order settings loaded');
    //
    // // Load currency settings
    // await CurrencyHelper.load();
    // print('💰 Currency loaded: ${CurrencyHelper.currentCurrencyCode}');


   await  Future.wait([
      AppSettings.load(),
      PrintSettings.load(),
      DecimalSettings.load(),
      OrderSettings.load(),
      CurrencyHelper.load()
    ]);





     startServer();
    print('🚀 UniPOS Local Server Started');

  } else if (AppConfig.isRetail) {
    // Load retail printer settings from SharedPreferences
    // await RetailPrinterSettingsService().initialize();
    // print('🖨️  Retail printer settings loaded');
    //
    // // Load decimal precision settings (shared with restaurant)
    // await DecimalSettings.load();
    // print('💰 Decimal precision loaded: ${DecimalSettings.precision} places');
    //
    // // Load currency settings (shared with restaurant)
    // await CurrencyHelper.load();
    // print('💰 Currency loaded: ${CurrencyHelper.currentCurrencyCode}');

  await Future.wait([
    RetailPrinterSettingsService().initialize(),
    DecimalSettings.load(),
    CurrencyHelper.load()
  ]);


  }

  // Debug: Print initialization status
  print('🔧 App Initialization Complete');
  print('   Business Mode: ${AppConfig.businessMode.name}');
  print('   Setup Complete: ${AppConfig.isSetupComplete}');
  print('   Retail Boxes Open: ${HiveInit.areRetailBoxesOpen}');

  runApp(const UniPOSApp());
}

class UniPOSApp extends StatelessWidget {
  const UniPOSApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'UniPOS',
      debugShowCheckedModeBanner: false,
      // theme: ThemeData(
      //   AppColors.primary: AppColors.primary,
      //   scaffoldBackgroundColor: AppColors.lightNeutral,
      //   appBarTheme: const AppBarTheme(
      //     backgroundColor: AppColors.primary,
      //     elevation: 0,
      //   ),
      //   elevatedButtonTheme: ElevatedButtonThemeData(
      //     style: ElevatedButton.styleFrom(
      //       backgroundColor: AppColors.primary,
      //       foregroundColor: Colors.white,
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(8),
      //       ),
      //     ),
      //   ),
      // ),
      // Define all your routes here
   /*   routes: {
        // Core Routes
        '/': (context) => const SplashScreen(),
        '/walkthrough': (context) => const WalkthroughScreen(),
        '/userSelectionScreen': (context) => const UserSelectionScreen(),
        '/existingUserRestoreScreen': (context) => const ExistingUserRestoreScreen(),
        '/setup-wizard': (context) => const SetupWizardScreen(),

        // Restaurant Routes
        '/restaurant-login': (context) => const RestaurantLogin(),
        '/restaurant-home': (context) => const AdminWelcome(),

        // Retail Routes
        '/retail-billing': (context) => const RetailPosScreen(),
        '/retail-menu': (context) => const HomeScreen(),
        
        // -- Retail: Sales --
        '/checkout': (context) => const CheckoutScreen(),
        '/parked-sales': (context) => const ParkedSalesScreen(),
        // Note: '/sale-return' removed as it requires arguments

        // -- Retail: Inventory --
        '/inventory': (context) => const InventoryScreen(),
        '/add-product': (context) => const AddProductScreen(),
        '/categories': (context) => const CategoryManagementScreen(),
        '/stock-alerts': (context) => const StockAlertsScreen(),

        // -- Retail: Customers --
        '/customers': (context) => const CustomerListScreen(),
        '/credit-reports': (context) => const CreditReportsScreen(),

        // -- Retail: Purchasing --
        '/suppliers': (context) => const SupplierListScreen(),
        '/purchase-orders': (context) => const PurchaseOrderListScreen(),
        '/add-purchase': (context) => const AddPurchaseScreen(),
        '/purchase-history': (context) => const PurchaseHistoryScreen(),
        // Note: '/material-receiving' removed as it requires arguments

        // -- Retail: Reports --
        '/reports': (context) => const ReportsScreen(),
        '/sales-history': (context) => const SalesHistoryScreen(),
        '/eod-report': (context) => const EODReportScreen(), // Fixed class name
        '/gst-report': (context) => const GstReportScreen(),

        // -- Retail: Settings --
        '/settings': (context) => const SettingsScreen(),
        '/store-info': (context) => const StoreInfoSettingsScreen(),
        '/gst-settings': (context) => const GstSettingsScreen(),
        '/payment-setup': (context) => const PaymentSetupScreen(),
        '/staff-setup': (context) => const StaffSetupScreen(),
        '/backup': (context) => const BackupScreen(),
      },*/

      // Handle unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Page Not Found'),
              backgroundColor: const Color(0xFF2E7D32),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found: ${settings.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          ),
        );
      },

      // Set initial route
      initialRoute: RouteNames.splash,
      routes: AppRoutes.routes,

    );
  }
}