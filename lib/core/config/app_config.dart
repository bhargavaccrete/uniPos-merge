import 'package:hive/hive.dart';

/// Business mode enum for the app
enum BusinessMode { none, restaurant, retail }

/// App Configuration - Stores app-wide settings including business type
///
/// IMPORTANT: Once business mode is set, it CANNOT be changed.
/// This ensures data integrity and prevents mixing restaurant/retail data.
///
/// Usage:
/// ```dart
/// // Initialize in main.dart before runApp
/// await AppConfig.init();
///
/// // Check business mode
/// if (AppConfig.isRestaurant) { ... }
/// if (AppConfig.isRetail) { ... }
///
/// // Set business mode (ONE TIME ONLY - in setup wizard)
/// await AppConfig.setBusinessMode(BusinessMode.restaurant);
/// ```
class AppConfig {
  AppConfig._(); // Private constructor

  static const String _boxName = 'appConfigBox';
  static const String _businessModeKey = 'businessMode';
  static const String _isSetupCompleteKey = 'isSetupComplete';
  static const String _appVersionKey = 'appVersion';
  static const String _firstLaunchDateKey = 'firstLaunchDate';

  static Box? _box;

  /// Initialize AppConfig - MUST be called before accessing any properties
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    // Set first launch date if not already set
    if (!_box!.containsKey(_firstLaunchDateKey)) {
      await _box!.put(_firstLaunchDateKey, DateTime.now().toIso8601String());
    }
  }

  /// Get the config box (throws if not initialized)
  static Box get box {
    if (_box == null) {
      throw Exception('AppConfig not initialized. Call AppConfig.init() first.');
    }
    return _box!;
  }

  /// Check if AppConfig is initialized
  static bool get isInitialized => _box != null;

  // ==================== BUSINESS MODE ====================

  /// Get current business mode
  static BusinessMode get businessMode {
    final mode = box.get(_businessModeKey, defaultValue: 'none') as String;
    switch (mode) {
      case 'restaurant':
        return BusinessMode.restaurant;
      case 'retail':
        return BusinessMode.retail;
      default:
        return BusinessMode.none;
    }
  }

  /// Set business mode (ONE TIME ONLY)
  ///
  /// Throws an exception if business mode is already set.
  /// This is intentional to prevent changing business type after initial setup.
  static Future<void> setBusinessMode(BusinessMode mode) async {
    if (businessMode != BusinessMode.none) {
      throw Exception(
        'Business mode already set to ${businessMode.name}. '
        'Cannot change business mode after initial setup.',
      );
    }
    if (mode == BusinessMode.none) {
      throw Exception('Cannot set business mode to none.');
    }
    await box.put(_businessModeKey, mode.name);
  }

  /// Check if business mode is set
  static bool get isBusinessModeSet => businessMode != BusinessMode.none;

  /// Check if app is in restaurant mode
  static bool get isRestaurant => businessMode == BusinessMode.restaurant;

  /// Check if app is in retail mode
  static bool get isRetail => businessMode == BusinessMode.retail;

  /// Get business mode as string (for display)
  static String get businessModeDisplayName {
    switch (businessMode) {
      case BusinessMode.restaurant:
        return 'Restaurant';
      case BusinessMode.retail:
        return 'Retail';
      case BusinessMode.none:
        return 'Not Set';
    }
  }

  // ==================== SETUP STATUS ====================

  /// Check if initial setup is complete
  static bool get isSetupComplete {
    return box.get(_isSetupCompleteKey, defaultValue: false) as bool;
  }

  /// Mark setup as complete
  static Future<void> setSetupComplete(bool value) async {
    await box.put(_isSetupCompleteKey, value);
  }

  // ==================== APP INFO ====================

  /// Get app version stored in config
  static String? get storedAppVersion {
    return box.get(_appVersionKey) as String?;
  }

  /// Update stored app version
  static Future<void> setAppVersion(String version) async {
    await box.put(_appVersionKey, version);
  }

  /// Get first launch date
  static DateTime? get firstLaunchDate {
    final dateStr = box.get(_firstLaunchDateKey) as String?;
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // ==================== RESET (FOR DEVELOPMENT ONLY) ====================

  /// Reset all app config - USE WITH CAUTION
  ///
  /// This is primarily for development/testing purposes.
  /// In production, this should require additional confirmation.
  static Future<void> resetConfig() async {
    await box.clear();
    // Re-set first launch date
    await box.put(_firstLaunchDateKey, DateTime.now().toIso8601String());
  }

  /// Force set business mode - DEVELOPMENT ONLY
  ///
  /// This bypasses the one-time restriction.
  /// Should NEVER be used in production.
  static Future<void> forceSetBusinessMode(BusinessMode mode) async {
    await box.put(_businessModeKey, mode.name);
  }

  // ==================== DEBUG INFO ====================

  /// Get all config values as a map (for debugging)
  static Map<String, dynamic> get debugInfo {
    return {
      'businessMode': businessMode.name,
      'isSetupComplete': isSetupComplete,
      'storedAppVersion': storedAppVersion,
      'firstLaunchDate': firstLaunchDate?.toIso8601String(),
      'isInitialized': isInitialized,
    };
  }

  @override
  String toString() {
    return 'AppConfig(businessMode: ${businessMode.name}, isSetupComplete: $isSetupComplete)';
  }
}