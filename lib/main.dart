import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/core/routes/app_routes.dart';
import 'package:unipos/core/routes/routes_name.dart';

import 'package:unipos/server/server.dart';
import 'package:unipos/util/common/currency_helper.dart';

import 'domain/store/restaurant/appStore.dart';
import 'domain/services/common/notification_service.dart';
import 'util/common/decimal_settings.dart';
import 'util/restaurant/staticswitch.dart';
import 'util/restaurant/print_settings.dart';
import 'util/restaurant/order_settings.dart';
import 'domain/services/retail/retail_printer_settings_service.dart';
final appStore = AppStore();

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 🔴 CRITICAL: Catch ALL errors to prevent white screen
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🔴🔴🔴 FLUTTER ERROR CAUGHT 🔴🔴🔴');
    print('Exception: ${details.exception}');
    print('Stack trace: ${details.stack}');
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await _initializeApp();
    } catch (e, stackTrace) {
      print('🔴🔴🔴 INITIALIZATION ERROR 🔴🔴🔴');
      print('Error: $e');
      print('Stack trace: $stackTrace');

      // Show error screen instead of white screen
      runApp(ErrorApp(error: e.toString()));
      return;
    }

    runApp(const UniPOSApp());
  }, (error, stackTrace) {
    print('🔴🔴🔴 ZONE ERROR CAUGHT 🔴🔴🔴');
    print('Error: $error');
    print('Stack trace: $stackTrace');
  });
}

Future<void> _initializeApp() async {
  print('🚀 Starting app initialization...');

  // Initialize Hive with Flutter and register common adapters
  // await HiveInit.init();


  // // Initialize AppConfig (stores business mode selection)
  // await AppConfig.init();


// Open common boxes (needed regardless of business mode)



  // Initialize Hive FIRST, then AppConfig
  print('📦 Step 1/7: Initializing Hive...');
  await HiveInit.init();
  print('✅ Hive initialized');

  print('⚙️  Step 2/7: Initializing AppConfig...');
  await AppConfig.init();
  print('✅ AppConfig initialized - Mode: ${AppConfig.businessMode.name}');

  // Initialize business-specific boxes if business mode is already set
  // (This handles the case where app is restarted after initial setup)
  print('📦 Step 3/7: Opening common boxes...');
  await HiveInit.openCommonBoxes();
  print('✅ Common boxes opened');

  print('📦 Step 4/7: Initializing business boxes...');
  await HiveInit.initializeBusinessBoxes();
  print('✅ Business boxes initialized');

  // Setup GetIt dependency injection
  // IMPORTANT: This must be called AFTER boxes are initialized
  print('💉 Step 5/7: Setting up service locator...');
  await setupServiceLocator();
  print('✅ Service locator ready');


  // Load restaurant customization settings from SharedPreferences
  print('⚙️  Step 6/7: Loading app settings...');
  if (AppConfig.isRestaurant) {
    print('   Loading restaurant settings...');
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


    await Future.wait([
      AppSettings.load(),
      PrintSettings.load(),
      DecimalSettings.load(),
      OrderSettings.load(),
      CurrencyHelper.load()
    ]);
    print('   ✅ Restaurant settings loaded');





    // Start the local server with proper error handling
    print('🌐 Step 7/7: Starting local server...');
    try {
      await startServer();
      print('   ✅ UniPOS Local Server Started Successfully');
    } catch (e, stackTrace) {
      print('   ⚠️  Failed to start UniPOS Local Server: $e');
      print('   Stack trace: $stackTrace');
      // Continue app initialization even if server fails
      print('   ℹ️  App will continue without local server');
    }

  } else if (AppConfig.isRetail) {
    print('   Loading retail settings...');
    await Future.wait([
      RetailPrinterSettingsService().initialize(),
      DecimalSettings.load(),
      CurrencyHelper.load()
    ]);
    print('   ✅ Retail settings loaded');
  } else {
    print('   ⚠️  No business mode set - running in setup mode');
  }

  // Debug: Print initialization status
  print('');
  print('✅✅✅ APP INITIALIZATION COMPLETE ✅✅✅');
  print('   Business Mode: ${AppConfig.businessMode.name}');
  print('   Setup Complete: ${AppConfig.isSetupComplete}');
  print('   Retail Boxes Open: ${HiveInit.areRetailBoxesOpen}');
  print('');
}

// Error screen to show instead of white screen
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[700]),
                SizedBox(height: 24),
                Text(
                  'App Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Check the console logs for detailed error information',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

      // Wrap all routes with NotificationOverlay using builder
      builder: (context, child) {
        return NotificationOverlay(
          service: NotificationService.instance,
          child: child ?? const SizedBox.shrink(),
        );
      },

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