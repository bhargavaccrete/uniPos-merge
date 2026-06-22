/// OFFLINE FALLBACK DEFAULTS for the Free plan. The server's `entitlements`
/// block is the real source of truth and overrides these; they are used only
/// when offline or when the server omits a value. See docs/UniPOS_Plans_Final.
class FeatureCatalog {
  FeatureCatalog._();

  /// Features OFF on the Free plan ("locked door"). Off here = needs a paid plan.
  static const Set<String> premiumOnly = {
    'inventory',
    'shifts',
    'cashDrawer',
    'expenses',
    'advancedReports',
    'export',
    'captainApp',
    'kds',
    'loyalty',
    'removeWatermark',
  };

  /// Free-plan count caps ("counter"). Absent key = uncapped. -1 = unlimited.
  static const Map<String, int> freeLimits = {
    'menuItems': 25,
    'categories': 3,
    'tables': 4,
    'staff': 1,
    'customers': 20,
    'printers': 1,
  };

  /// Free-plan report/history window in days ("window").
  static const int freeHistoryWindowDays = 7;
}
