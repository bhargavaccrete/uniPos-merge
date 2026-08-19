import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/license_lock_screen.dart';

/// Route wrapper enforcing plan **entitlements** for retail, mirroring
/// `RestaurantGuard` — but entitlement + licence only: retail has no role or
/// staff session of its own (`AuthService` is admin-only).
///
/// Reactive by design: the body sits in an [Observer], so a mid-session revoke,
/// expiry or plan downgrade re-renders an already-open screen. Evaluating once
/// at route-build time would let a revoked device keep whatever it had open.
class RetailGuard extends StatelessWidget {
  final Widget child;

  /// A `RetailEntKeys.*` string, or null for an always-open route.
  final String? entitlementKey;

  /// Granted if ANY of these is granted — for a screen fronting several
  /// individually-keyed parts.
  final List<String>? entitlementAnyOf;

  const RetailGuard({
    super.key,
    required this.child,
    this.entitlementKey,
    this.entitlementAnyOf,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final lic = locator<LicenseStore>();

        // Licence gate — but ONLY for a device that has actually been licensed.
        // Retail that never activated has `licenseInfo == null` and stays fully
        // open, which is the pre-backend behaviour we must not regress. Once a
        // licence exists, an expiry/suspension/revoke locks instead of silently
        // reopening the app (see PlanEnforce._bypassed).
        if (lic.licenseInfo != null &&
            (!lic.isLicensed || !lic.hasVerifiedManifest)) {
          // Recovery comes from this Observer re-rendering once the store
          // updates, so the callback has nothing to do — same as RestaurantGuard.
          return LicenseLockScreen(onActivated: () {});
        }

        // Entitlements go through PlanEnforce rather than Entitlements directly,
        // so the retail bypass rule lives in exactly one place.
        final key = entitlementKey;
        if (key != null && !PlanEnforce.allows(key)) {
          return const _RetailUpgradeRequiredScreen();
        }

        final anyOf = entitlementAnyOf;
        if (anyOf != null && !PlanEnforce.allowsAny(anyOf)) {
          return const _RetailUpgradeRequiredScreen();
        }

        return child;
      },
    );
  }
}

/// Hard blocker shown when a retail route is denied by the plan.
class _RetailUpgradeRequiredScreen extends StatelessWidget {
  const _RetailUpgradeRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  size: 64, color: Colors.amber.shade700),
              const SizedBox(height: 16),
              const Text(
                'Not in your plan',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'This feature isn’t included in your current plan.\n'
                'Please contact Bill Berry to upgrade.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
