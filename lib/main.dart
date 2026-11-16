import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/config/app_config.dart';
import 'package:billberrylite/core/init/hive_init.dart';
import 'package:billberrylite/core/init/hive_safe_open.dart';
import 'package:billberrylite/data/repositories/business_type_repository.dart';
import 'package:billberrylite/presentation/screens/common/recovery/startup_recovery_screen.dart';
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
import 'core/init/retail_startup.dart';
import 'domain/services/retail/retail_checkout_commit.dart';
import 'domain/services/restaurant/auto_backup_service.dart';
import 'domain/services/restaurant/stock_journal.dart';
import 'domain/services/restaurant/void_order_commit.dart';
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
      await _openData();
      await _startServices();
    } on HiveStartupBlocked catch (blocked) {
      // M4: a box could not be opened safely. Nothing has started; the
      // Recovery screen continues startup only once every box opens.
      runApp(StartupRecoveryApp(
        blocked: blocked,
        onRecovered: _startAfterRecovery,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
      ));
      return;
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
    // scheduled on resume.
    _NotificationPermissionRequester.scheduleOnResume();
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

/// Recovery succeeded (every box is open): normal startup from the service
/// locator on. A failed restore attempt may already have built the locator.
Future<void> _startAfterRecovery() async {
  try {
    if (locator.isRegistered<BusinessTypeRepository>()) {
      await resetServiceLocator();
    }
    await _startServices();
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
    return;
  }
  runApp(const BillBerryApp());
  _NotificationPermissionRequester.scheduleOnResume();
}

Future<void> _openData() async {
  print('🚀 Starting app initialization...');

  // Initialize Hive with Flutter and register common adapters
  // await HiveInit.init();


  // // Initialize AppConfig (stores business mode selection)
  // await AppConfig.init();


// Open common boxes (needed regardless of business mode)



  // Steps 1-4: Hive, AppConfig, common boxes, business boxes. Throws
  // HiveStartupBlocked (shown by ErrorApp) if any box could not be opened
  // safely — so nothing below can run with a missing box. Damaged originals
  // are preserved, never repaired or deleted.
  print('📦 Steps 1-4/7: Opening data...');
  await HiveInit.openStartupBoxes();
  print('✅ Data opened - Mode: ${AppConfig.businessMode.name}');
  for (final r in HiveSafeOpen.repairs) {
    print('🛟 ${r.boxName}: unfinished last write dropped; original kept at '
        '${r.preserved.path}');
  }
}

/// Everything after the data is open. Never runs while a box is missing.
Future<void> _startServices() async {

  // Setup GetIt dependency injection
  // IMPORTANT: This must be called AFTER boxes are initialized
  print('💉 Step 5/7: Setting up service locator...');
  await setupServiceLocator();
  print('✅ Service locator ready');

  // Pre-load license cache so RestaurantGuard can check synchronously.
  await locator<LicenseStore>().loadCachedLicense();
  print('🔑 License cache loaded');

  // Finish any Settle stock work a crash or force-close left unfinished,
  // before the first sale can touch the same items. Never throws; an entry
  // that still fails stays for the next Settle or start.
  if (AppConfig.isRestaurant) {
    final pending = await StockJournal.recoverAll();
    if (pending.isNotEmpty) {
      debugPrint('⚠️ Stock journal: ${pending.length} entry(ies) still pending');
    }
    // A void a stop left part-way: its record decides whether the stock return
    // is finished or the void never happened. Never throws.
    final voids = await VoidOrderCommit.recoverAll();
    if (voids.isNotEmpty) {
      debugPrint('⚠️ Void recovery: ${voids.length} entry(ies) still pending');
    }
    // An item cancel (POS or Captain) a stop left part-way: the saved order
    // decides whether its stock return is owed. Never throws.
    final cancels = await StockJournal.recoverCancels();
    if (cancels.isNotEmpty) {
      debugPrint('⚠️ Cancel recovery: ${cancels.length} entry(ies) still pending');
    }
    // Same for a goods receipt a stop left as a draft (S-06) — before any
    // sale can move the stock its interrupted lines are judged by.
    final receipts = await restaurantPurchaseOrderStore.resumeInterruptedReceipts();
    if (receipts > 0) debugPrint('📦 Finished $receipts interrupted goods receipt(s)');
  }

  // Finish any Retail sale a crash left saved but unfinished, before the first
  // sale can bill its cart again. Never throws; a failed entry stays for the
  // next start.
  if (AppConfig.isRetail) {
    final pending = await RetailCheckoutCommit.recoverAll();
    if (pending.isNotEmpty) {
      debugPrint('⚠️ Retail checkout: ${pending.length} sale(s) still pending');
    }
  }

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
    await loadRetailStartupSettings();
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
          // Scrolls: a blocked start lists every affected box and its copy.
          child: SingleChildScrollView(
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

      // App-wide Poppins. Without this there is NO textTheme at all, so any
      // `Text` without a style — and any raw `TextStyle(...)` — falls back to
      // Roboto while its `GoogleFonts.poppins` siblings render Poppins.
      //
      // `fontFamily` (not `poppinsTextTheme`) on purpose: it changes ONLY the
      // typeface. A full text theme would also impose its own font SIZES and
      // colours, which would fight the AppResponsive ladders.
      //
      // 'Poppins' is the family declared in pubspec.yaml (assets/fonts/), so
      // this resolves from the bundled TTFs with no network access.
      theme: ThemeData(fontFamily: 'Poppins'),

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

/// App-wide back-button protection: on a root screen, the first back press
/// shows "Press back again to exit"; a second within 2 seconds exits.
///
/// This is a [WidgetsBindingObserver], not a `PopScope`: `MaterialApp.builder`
/// sits ABOVE the Navigator, outside any route, where a PopScope never fires.
/// `WidgetsBinding.handlePopRoute` asks observers in registration order, and
/// WidgetsApp's own observer (registered first) runs `navigator.maybePop()`.
/// So [didPopRoute] is reached only when no screen popped or blocked the press
/// — i.e. exactly when the app would otherwise close. Screens with their own
/// `PopScope(canPop: false)` keep handling back themselves.
class _GlobalBackProtection extends StatefulWidget {
  final Widget child;
  const _GlobalBackProtection({required this.child});

  @override
  State<_GlobalBackProtection> createState() => _GlobalBackProtectionState();
}

class _GlobalBackProtectionState extends State<_GlobalBackProtection>
    with WidgetsBindingObserver {
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return true;
    }
    _lastBackPress = now;
    _showExitHint();
    return true;
  }

  void _showExitHint() {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.exit_to_app_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Press back again to exit',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
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
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
