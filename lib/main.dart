import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/routes/app_routes.dart';
import 'package:billberrylite/core/routes/routes_name.dart';

import 'package:billberrylite/server/server.dart';
import 'package:billberrylite/util/common/currency_helper.dart';

import 'domain/store/restaurant/appStore.dart';
import 'domain/store/restaurant/license_store.dart';
import 'domain/services/common/notification_service.dart';
import 'util/common/decimal_settings.dart';
import 'util/restaurant/staticswitch.dart';
import 'util/restaurant/restaurant_session.dart';
import 'util/restaurant/print_settings.dart';
import 'util/restaurant/order_settings.dart';
import 'domain/services/retail/retail_printer_settings_service.dart';
import 'domain/services/restaurant/auto_backup_service.dart';
import 'domain/services/common/local_notification_service.dart';
import 'domain/services/common/firebase_messaging_service.dart';
import 'domain/services/common/notification_sync.dart';
import 'package:billberrylite/presentation/screens/retail/login_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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

    // Poppins is bundled locally (assets/fonts/, registered in pubspec.yaml)
    // so GoogleFonts.poppins() must never try to fetch it over the network —
    // this app needs to work fully offline.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Enable Wake Lock to prevent device from going to sleep
    WakelockPlus.enable();

    try {
      await _initializeApp();
    } catch (e, stackTrace) {
      print('🔴🔴🔴 INITIALIZATION ERROR 🔴🔴🔴');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      runApp(ErrorApp(error: e.toString()));
      return;
    }

    runApp(const BillBerryApp());

    // Ask for notification permission once the Activity is truly RESUMED.
    // Firing from addPostFrameCallback alone is unreliable on cold start: the
    // first frame paints during the launch-screen transition, before the
    // Android 13+ activity resumes, so the POST_NOTIFICATIONS dialog is
    // silently dropped (it only appeared on the *second* launch).
    if (AppConfig.isBusinessModeSet) {
      _NotificationPermissionRequester.scheduleOnResume();
    }
  }, (error, stackTrace) {
    print('🔴🔴🔴 ZONE ERROR CAUGHT 🔴🔴🔴');
    print('Error: $error');
    print('Stack trace: $stackTrace');
  });
}

/// Requests the Android 13+ notification permission on the first confirmed
/// `resumed` lifecycle event, then removes itself. Waiting for `resumed` (not
/// just the first frame) is what makes the POST_NOTIFICATIONS prompt reliable
/// on a cold start — see the call site in [main].
class _NotificationPermissionRequester with WidgetsBindingObserver {
  _NotificationPermissionRequester._();
  bool _done = false;

  static void scheduleOnResume() {
    final r = _NotificationPermissionRequester._();
    // Already resumed (warm start)? go now. Else wait for the resumed event.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      r._fire();
    } else {
      WidgetsBinding.instance.addObserver(r);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fire();
  }

  void _fire() {
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.removeObserver(this);
    LocalNotificationService.instance.requestPermissionIfNeeded();
  }
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

  // Pre-load license cache so RestaurantGuard can check synchronously.
  await locator<LicenseStore>().loadCachedLicense();
  print('🔑 License cache loaded');

  // Fire server validation in background — does not block startup.
  // The RestaurantGuard Observer reacts automatically if status changes.
  locator<LicenseStore>().checkStatusInBackground();


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
      CurrencyHelper.load(),
      RestaurantSession.load(),
    ]);
    RestaurantSession.initLifecycle(); // pause/resume handling for auto-logout
    print('   ✅ Restaurant settings loaded');

    // Start auto-backup timer (runs hourly, triggers daily backups)
    AutoBackupService.initialize();
    print('   ✅ Auto-backup service initialized');

    // Start local server FIRST — captain/KDS clients connect to :9090 on launch,
    // so it must bind before anything slower (notifications) runs. Fire-and-forget.
    print('🌐 Starting local server (background)...');
    startServer().then((_) {
      print('   ✅ Bill Berry Lite Local Server Started Successfully');
    }).catchError((e) {
      print('   ⚠️  Failed to start Bill Berry Lite Local Server: $e');
    });

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

  // ==================== NOTIFICATIONS (both modes) ====================
  // Shared by restaurant and retail: one Hive box, one store, one screen.
  // `NotificationSync` picks which startup checks to run for the active mode.
  //
  // Deliberately placed AFTER the mode branches so restaurant keeps its
  // original ordering — the local server is already binding by now, and
  // notifications are slow enough that they must not delay it.
  //
  // Both blocks are wrapped so a failure (exact-alarm permission denied on
  // Android 13/14, a missing Firebase config) can never break or block
  // startup. Permission is requested AFTER the first frame (see main()),
  // because the Android 13+ prompt needs a resumed activity.
  if (AppConfig.isBusinessModeSet) {
    try {
      await LocalNotificationService.instance.init();
      await notificationStore.load();
      await NotificationSync.runStartupChecks();
      print('   ✅ Local notifications ready');
    } catch (e) {
      print('   ⚠️  Local notifications init failed (non-fatal): $e');
    }

    // Firebase Cloud Messaging (push). Runs after local notifications because
    // foreground pushes are rendered through that plugin's channels. No-op on
    // desktop/web (no google-services config for those platforms here).
    try {
      await FirebaseMessagingService.instance.init();
      print('   ✅ Firebase push notifications ready');
    } catch (e) {
      print('   ⚠️  Firebase messaging init failed (non-fatal): $e');
    }
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

class BillBerryApp extends StatelessWidget {
  const BillBerryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Bill Berry Lite',
      debugShowCheckedModeBanner: false,

      // Wrap all routes with NotificationOverlay + app-wide inactivity handling + global back exit protection.
      builder: (context, child) {
        return NotificationOverlay(
          service: NotificationService.instance,
          child: _SessionActivityWrapper(
            child: _GlobalBackProtection(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
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
      // Always cold-start at splash. On a full restart the platform can replay
      // a stale route name (e.g. the screen the app was last on), which Flutter
      // can't resolve as an initial route and warns about. This pins startup to
      // the splash screen — splash then routes to login/home based on state.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute(
          settings: const RouteSettings(name: RouteNames.splash),
          builder: AppRoutes.routes[RouteNames.splash]!,
        ),
      ],

    );
  }
}

/// App-wide inactivity handling, mounted once at the MaterialApp root (via
/// `builder`) so it works on EVERY screen regardless of how it was navigated
/// to — unlike the per-screen RestaurantGuard, which the post-login home
/// bypassed (the home is built directly, not via the guarded named route).
///   • Resets the inactivity timer on any pointer touch — a raw [Listener], so
///     it can't be swallowed by a child widget's gesture arena.
///   • Forces logout when [RestaurantSession.sessionExpiredNotifier] fires.
class _SessionActivityWrapper extends StatefulWidget {
  final Widget child;
  const _SessionActivityWrapper({required this.child});

  @override
  State<_SessionActivityWrapper> createState() => _SessionActivityWrapperState();
}

class _SessionActivityWrapperState extends State<_SessionActivityWrapper> {
  @override
  void initState() {
    super.initState();
    RestaurantSession.sessionExpiredNotifier.addListener(_onExpired);
  }

  @override
  void dispose() {
    RestaurantSession.sessionExpiredNotifier.removeListener(_onExpired);
    super.dispose();
  }

  void _onExpired() {
    if (!RestaurantSession.sessionExpiredNotifier.value) return;
    if (!RestaurantSession.isLoggedIn) {
      // Nothing to log out of — just clear the stale flag.
      RestaurantSession.sessionExpiredNotifier.value = false;
      return;
    }
    RestaurantSession.clearSession(); // clears session + resets the flag
    if (AppConfig.isRetail) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        RouteNames.restaurantLogin,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (RestaurantSession.isLoggedIn) {
          RestaurantSession.resetInactivityTimer();
        }
      },
      child: widget.child,
    );
  }
}

/// App-wide back-button protection:
///   • If popping navigates back inside the app (`Navigator.canPop()` is true),
///     it pops the top screen immediately without showing any message.
///   • If popping would exit/close the app (`Navigator.canPop()` is false), it
///     intercepts the back press, shows a floating SnackBar ("Press back again
///     to exit"), and requires a second back press within 2 seconds to exit.
class _GlobalBackProtection extends StatefulWidget {
  final Widget child;
  const _GlobalBackProtection({required this.child});

  @override
  State<_GlobalBackProtection> createState() => _GlobalBackProtectionState();
}

class _GlobalBackProtectionState extends State<_GlobalBackProtection> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // If popping navigates back to a previous screen inside the app, pop normally.
        final nav = navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }

        // Navigator cannot pop further — popping would exit/close the app.
        // Prompt for double-press before exiting.
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;

        rootScaffoldMessengerKey.currentState?.clearSnackBars();
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Press back again to exit',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: widget.child,
    );
  }
}
