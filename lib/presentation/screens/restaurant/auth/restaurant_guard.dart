import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';

/// Wraps protected restaurant screens.
///
/// - Checks [RestaurantSession.isLoggedIn] synchronously (no SharedPreferences hit).
/// - Checks [permissionKey] against [RestaurantSession.canAccess] if provided.
/// - Listens to [RestaurantSession.sessionExpiredNotifier] for inactivity logout.
/// - Wraps child with a [GestureDetector] that resets the inactivity timer on touch.
class RestaurantGuard extends StatefulWidget {
  final Widget child;
  final String? permissionKey;
  const RestaurantGuard({super.key, required this.child, this.permissionKey});

  @override
  State<RestaurantGuard> createState() => _RestaurantGuardState();
}

class _RestaurantGuardState extends State<RestaurantGuard> {
  // null = pending redirect, true = allowed, 'denied' = role denied
  Object? _state;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    RestaurantSession.sessionExpiredNotifier.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    RestaurantSession.sessionExpiredNotifier.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _checkAuth() {
    if (!RestaurantSession.isLoggedIn) {
      // Defer navigation — context not ready for navigation in initState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context, RouteNames.restaurantLogin, (_) => false);
        }
      });
      return;
    }

    if (widget.permissionKey != null &&
        !RestaurantSession.canAccess(widget.permissionKey!)) {
      _state = 'denied';
      return;
    }

    _state = true;
  }

  void _onSessionExpired() {
    if (!RestaurantSession.sessionExpiredNotifier.value) return;
    if (!mounted) return;
    RestaurantSession.clearSession();
    Navigator.pushNamedAndRemoveUntil(
        context, RouteNames.restaurantLogin, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_state == 'denied') return const _AccessDeniedScreen();
    if (_state != true) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Reset inactivity timer on any touch interaction
    return GestureDetector(
      onTap: RestaurantSession.resetInactivityTimer,
      onPanUpdate: (_) => RestaurantSession.resetInactivityTimer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Access Denied',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text("You don't have permission to view this page.",
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Go Back',
                  style: GoogleFonts.poppins(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}