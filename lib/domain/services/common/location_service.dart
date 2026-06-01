import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Builds the location block sent to the licensing API on activation.
/// Gracefully falls back to 0.0/0.0 if GPS is unavailable or denied.
class LocationService {
  static Future<Map<String, dynamic>> build() async {
    double lat = 0.0;
    double lon = 0.0;
    String ip = '';

    // GPS coordinates (skip on web — browser prompt handled separately)
    if (!kIsWeb) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 10));
          lat = position.latitude;
          lon = position.longitude;
        }
      } catch (_) {}
    }

    // Public IP via ipify — lightweight plain-text response
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) ip = response.body.trim();
    } catch (_) {}

    return {'latitude': lat, 'longitude': lon, 'ip': ip};
  }
}
