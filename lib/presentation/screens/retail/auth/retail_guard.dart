import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/domain/store/restaurant/license_store.dart';
import 'package:billberrylite/presentation/screens/restaurant/auth/license_lock_screen.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/presentation/widget/componets/common/access_denied_screen.dart';

/// Route wrapper enforcing licence, **role** and plan entitlements for retail,
/// mirroring `RestaurantGuard`.
///
/// Retail DOES have a staff session: `AuthService.login` resolves a staff PIN
/// and calls `RestaurantSession.saveStaffSession`, so `staffRole` is populated
/// and `canAccess` answers for retail keys.
///
/// Reactive by design for licence and plan: the body sits in an [Observer], so
/// a mid-session revoke, expiry or downgrade re-renders an already-open screen.
/// The ROLE check is not reactive — it can't change without a re-login, and
/// `RestaurantGuard` evaluates it the same way.
class RetailGuard extends StatelessWidget {
  final Widget child;

  /// A `RestaurantSession.canAccess` feature key, or null for a route open to
  /// every role. Checked BEFORE the plan: "you may not" outranks "you could buy
  /// this".
  final String? permissionKey;

  /// A `RetailEntKeys.*` string, or null for an always-open route.
  final String? entitlementKey;

  /// Granted if ANY of these is granted — for a screen fronting several
  /// individually-keyed parts.
  final List<String>? entitlementAnyOf;

  const RetailGuard({
    super.key,
    required this.child,
    this.permissionKey,
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

        // Role gate. Ahead of the plan check so a cashier is told "ask a
        // manager" rather than "upgrade your plan" for something no upgrade
        // would give them.
        final perm = permissionKey;
        if (perm != null && !RestaurantSession.canAccess(perm)) {
          return const AccessDeniedScreen();
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
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        maxWidth: AppResponsive.maxFormWidth(context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 64,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  'Not in your plan',
                  style: TextStyle(
                    fontSize: AppResponsive.headingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This feature isn’t included in your current plan.\n'
                  'Please contact Bill Berry to upgrade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: Colors.grey.shade600,
                  ),
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
      ),
    );
  }
}
