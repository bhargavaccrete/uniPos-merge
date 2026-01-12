import 'package:flutter/material.dart';

import 'retail_routes.dart';
import 'restaurant_routes.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
    ...RestaurantRoutes.routes,
    ...RetailRoutes.routes,
  };
}
