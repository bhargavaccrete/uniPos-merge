import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/util/restaurant/restaurant_session.dart';

import '../../../widget/componets/restaurant/componets/Button.dart';

class Logout extends StatelessWidget {
  const Logout({super.key});

  Future<void> _performLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restaurant_is_logged_in', false);
    await RestaurantSession.clearSession();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.restaurantLogin,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: <Widget>[
        CommonButton(
          onTap: () => _performLogout(context),
          child: const Text('Logout'),
        ),
        CommonButton(
          onTap: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
