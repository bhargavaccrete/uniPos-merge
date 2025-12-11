import 'package:flutter/material.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/config/app_config.dart';
import 'package:unipos/core/init/hive_init.dart';
import 'package:unipos/presentation/screens/retail/home_screen.dart';
import 'package:unipos/presentation/screens/retail/pos_screen.dart';
import 'package:unipos/screen/existingUserRestoreScreen.dart';
import 'package:unipos/screen/setupWizardScreen.dart';
import 'package:unipos/screen/splashScreen.dart';
import 'package:unipos/screen/userSelectionScreen.dart';
import 'package:unipos/screen/walkthroughScreen.dart';
import 'package:unipos/util/color.dart';

import 'domain/store/restaurant/appStore.dart';
final appStore = AppStore();

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with Flutter and register common adapters
  await HiveInit.init();

  // Initialize AppConfig (stores business mode selection)
  await AppConfig.init();

  // Open common boxes (needed regardless of business mode)
  await HiveInit.openCommonBoxes();

  // Initialize business-specific boxes if business mode is already set
  // (This handles the case where app is restarted after initial setup)
  await HiveInit.initializeBusinessBoxes();

  // Setup GetIt dependency injection
  // IMPORTANT: This must be called AFTER boxes are initialized
  await setupServiceLocator();

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
      //   primaryColor: AppColors.primary,
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
      routes: {
        '/': (context) => const SplashScreen(),
        '/walkthrough': (context) => const WalkthroughScreen(),
        '/userSelectionScreen': (context) => const UserSelectionScreen(),
        '/existingUserRestoreScreen': (context) => const ExistingUserRestoreScreen(),
        '/setup-wizard': (context) => const SetupWizardScreen(),

        '/retail-billing': (context) => const PosScreen(),
         '/retail-menu': (context) => const HomeScreen(),


        // '/outlet-registration': (context) => const OutletRegistrationScreen(),
        // '/tax-setup': (context) => const TaxConfigurationScreen(),
        // '/category-setup': (context) => const CategorySetupScreen(),
        // '/inventory-setup': (context) => const InventorySetupScreen(),
        // '/payment-setup': (context) => const PaymentSetupScreen(),
        // '/staff-setup': (context) => const StaffSetupScreen(),
        // '/printer-setup': (context) => const PrinterSetupScreen(),
        // '/login': (context) => const LoginScreen(),
        // '/dashboard': (context) => const DashboardScreen(),
        // '/adminDashboard': (context) => const AdminDashboardScreen(),
        // '/pos': (context) => const POSScreen(),
        // '/inventory': (context) => const InventoryScreen(),
        // '/customers': (context) => const CustomersScreen(),
        // '/reports': (context) => const ReportsScreen(),
        // '/settings': (context) => const SettingsScreen(),
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
      initialRoute: '/',
    );
  }
}