import 'package:mobx/mobx.dart';
import '../../domain/services/common/manifest_service.dart';
import 'entitlement_keys.dart';

/// The single API the rest of the app asks about server-driven entitlements.
///
/// Backed by [ObservableMap]s so any read inside a MobX [Observer] rebuilds
/// when the manifest is replaced (plan change / revoke via sync). Every lookup
/// falls back to [kEntitlementDefaults] when a key is absent — so a varying
/// manifest only flips switches on a fixed board; missing always means off/0.
class Entitlements {
  Entitlements._();
  static final Entitlements instance = Entitlements._();

  final ObservableMap<String, dynamic> _map = ObservableMap<String, dynamic>();
  final ObservableMap<String, dynamic> _license =
      ObservableMap<String, dynamic>();

  /// True once a verified manifest has been loaded (cache or server).
  bool get hasManifest => _map.isNotEmpty;

  /// Debug only — a copy of the loaded manifest map (exactly what the server
  /// sent, BEFORE catalog defaults are applied). Used by EntitlementDebug.
  Map<String, dynamic> debugSnapshot() => Map<String, dynamic>.from(_map);

  void loadFromManifest(ManifestData data) {
    _map
      ..clear()
      ..addAll(data.entitlements);
    _license
      ..clear()
      ..addAll(data.license);
  }

  void clear() {
    _map.clear();
    _license.clear();
  }

  // ── The only lookups callers use ───────────────────────────────────────────

  /// Module / submodule / action gate. Present-and-true → allowed; false or
  /// missing → denied (restrictive default).
  bool can(String key) => (_map[key] ?? kEntitlementDefaults[key]) == true;

  /// Integer limit (count cap). Missing → catalog default (usually 0).
  int limit(String key) =>
      ((_map[key] ?? kEntitlementDefaults[key] ?? 0) as num).toInt();

  dynamic value(String key) => _map[key] ?? kEntitlementDefaults[key];

  /// Data-scope window in days; null = unlimited. A positive number caps the
  /// window; anything else (`"all"`, `false`, absent, non-numeric) = unlimited.
  int? windowDays(String key) {
    final v = value(key);
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v); // numeric string → days; else null
    return null; // 'all' handled above as String→null; bool false → null
  }

  // ── Runtime gate: manifest status + expiry + offline grace ──────────────────
  // Status codes (manifest): 1 Created, 2 Activated, 3 Expired, 4 Cancelled,
  // 5 Revoked. Validity/expiry is ALSO enforced by the RSA license layer; this
  // is the manifest's own kill-switch (cancel/revoke + maxOfflineDays).
  ({bool allowed, String? reason}) gate(DateTime? lastSync) {
    final s = (_license['status'] as num?)?.toInt();
    if (s == 4) return (allowed: false, reason: 'CANCELLED');
    if (s == 5) return (allowed: false, reason: 'REVOKED');

    final exp = _license['expiresat'];
    if (exp is String) {
      final d = DateTime.tryParse(exp);
      if (d != null && d.isBefore(DateTime.now())) {
        return (allowed: false, reason: 'EXPIRED');
      }
    }

    final maxOffline = (_license['maxOfflineDays'] as num?)?.toInt() ?? 14;
    if (lastSync != null &&
        DateTime.now().difference(lastSync).inDays > maxOffline) {
      return (allowed: false, reason: 'OFFLINE_GRACE_EXPIRED');
    }
    return (allowed: true, reason: null);
  }
}
