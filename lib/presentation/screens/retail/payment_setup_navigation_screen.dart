import 'package:flutter/material.dart';
import 'package:unipos/presentation/screens/retail/payment_setup_screen.dart';
import 'package:unipos/presentation/screens/retail/staff_setup_screen.dart';
import 'package:unipos/util/color.dart';

/// Navigation screen that handles Payment Setup → Staff Setup flow
/// Both screens can be skipped (Setup Later option)
class PaymentSetupNavigationScreen extends StatelessWidget {
  const PaymentSetupNavigationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PaymentSetupScreen(
      onComplete: () {
        // Navigate to Staff Setup after Payment Setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const StaffSetupScreen(),
          ),
        );
      },
      onSkip: () {
        // Skip Payment Setup and go to Staff Setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const StaffSetupScreen(),
          ),
        );
      },
    );
  }
}