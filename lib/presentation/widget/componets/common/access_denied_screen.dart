import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'primary_app_bar.dart';

/// Shown when a route is denied by ROLE — the signed-in staff member's role
/// doesn't cover this screen.
///
/// Distinct from the plan blocker on purpose: a plan lock is a "you could buy
/// this" message, while this is "ask someone with more access". Shared by
/// `RestaurantGuard` and `RetailGuard` so both verticals deny identically.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildPrimaryAppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      ),
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('Go Back',
                    style: GoogleFonts.poppins(color: Colors.blue)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
