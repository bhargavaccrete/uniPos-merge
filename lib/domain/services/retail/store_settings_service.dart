import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billberrylite/data/repositories/business_details_repository.dart';

/// Service for managing store/business settings
class StoreSettingsService {
  static const String _keyStoreName = 'store_name';
  static const String _keyStoreAddress = 'store_address';
  static const String _keyStorePhone = 'store_phone';
  static const String _keyStoreEmail = 'store_email';
  static const String _keyStoreGST = 'store_gst_number';
  static const String _keyOwnerName = 'store_owner_name';
  static const String _keyStoreCity = 'store_city';
  static const String _keyStoreState = 'store_state';
  static const String _keyStorePincode = 'store_pincode';
  // Offline UPI "scan & pay" config printed on unpaid bills.
  static const String _keyUpiId = 'store_upi_id';
  static const String _keyUpiPayee = 'store_upi_payee';
  static const String _keyUpiQr = 'store_upi_qr_b64'; // base64-encoded QR image

  final _businessDetailsRepo = BusinessDetailsRepository();

  /// Get store name
  Future<String?> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreName);
  }

  /// Set store name
  Future<bool> setStoreName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStoreName, name);
  }

  /// Get store address
  Future<String?> getStoreAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreAddress);
  }

  /// Set store address
  Future<bool> setStoreAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStoreAddress, address);
  }

  /// Get store phone
  Future<String?> getStorePhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStorePhone);
  }

  /// Set store phone
  Future<bool> setStorePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStorePhone, phone);
  }

  /// Get store email
  Future<String?> getStoreEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreEmail);
  }

  /// Set store email
  Future<bool> setStoreEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStoreEmail, email);
  }

  /// Get GST number
  Future<String?> getGSTNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreGST);
  }

  /// Set GST number
  Future<bool> setGSTNumber(String gst) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStoreGST, gst);
  }

  // ── UPI (offline scan-and-pay on the bill) ─────────────────────────────────

  /// Merchant UPI ID / VPA (e.g. "merchant@okhdfc"). Null/empty = not set.
  Future<String?> getUpiId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUpiId);
  }

  Future<bool> setUpiId(String upiId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyUpiId, upiId.trim());
  }

  /// Payee name shown in the UPI deep link (falls back to store name).
  Future<String?> getUpiPayeeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUpiPayee);
  }

  Future<bool> setUpiPayeeName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyUpiPayee, name.trim());
  }

  /// Merchant's own static UPI QR image (printed as-is if provided).
  Future<Uint8List?> getUpiQrImage() async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString(_keyUpiQr);
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Save (or clear, when [bytes] is null) the merchant QR image.
  Future<bool> setUpiQrImage(Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null) return prefs.remove(_keyUpiQr);
    return prefs.setString(_keyUpiQr, base64Encode(bytes));
  }

  /// Get owner name
  Future<String?> getOwnerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOwnerName);
  }

  /// Set owner name
  Future<bool> setOwnerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyOwnerName, name);
  }

  /// Get store city
  Future<String?> getStoreCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreCity);
  }

  /// Set store city
  Future<bool> setStoreCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStoreCity, city);
  }

  /// Get store state
  Future<String?> getStoreState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreState);
  }

  /// Set store state
  Future<bool> setStoreState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStoreState, state);
  }

  /// Get store pincode
  Future<String?> getStorePincode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStorePincode);
  }

  /// Set store pincode
  Future<bool> setStorePincode(String pincode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyStorePincode, pincode);
  }

  /// Get store logo as Uint8List from Hive
  Future<Uint8List?> getStoreLogo() async {
    try {
      final businessDetails = _businessDetailsRepo.get();
      return businessDetails?.logo;
    } catch (e) {
      print('Error getting logo from Hive: $e');
      return null;
    }
  }

  /// Set store logo from Uint8List to Hive
  Future<bool> setStoreLogo(Uint8List logoBytes) async {
    try {
      final currentDetails = _businessDetailsRepo.get();
      if (currentDetails == null) {
        print('Error: No business details found in Hive');
        return false;
      }

      // Update only the logo field
      final updatedDetails = currentDetails.copyWith(logo: logoBytes);
      await _businessDetailsRepo.save(updatedDetails);
      return true;
    } catch (e) {
      print('Error saving logo to Hive: $e');
      return false;
    }
  }

  /// Delete store logo from Hive
  Future<bool> deleteStoreLogo() async {
    try {
      final currentDetails = _businessDetailsRepo.get();
      if (currentDetails == null) {
        print('Error: No business details found in Hive');
        return false;
      }

      // Update with null logo
      final updatedDetails = currentDetails.copyWith(logo: null);
      await _businessDetailsRepo.save(updatedDetails);
      return true;
    } catch (e) {
      print('Error deleting logo from Hive: $e');
      return false;
    }
  }

  /// Get complete store address formatted for receipts
  Future<String> getFormattedAddress() async {
    final address = await getStoreAddress();
    final city = await getStoreCity();
    final state = await getStoreState();
    final pincode = await getStorePincode();

    final parts = <String>[];
    if (address != null && address.isNotEmpty) parts.add(address);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (state != null && state.isNotEmpty) parts.add(state);
    if (pincode != null && pincode.isNotEmpty) parts.add(pincode);

    return parts.join(', ');
  }

  /// Save all store settings at once
  Future<bool> saveAllSettings({
    required String storeName,
    String? ownerName,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? gstNumber,
  }) async {
    try {
      await setStoreName(storeName);
      if (ownerName != null) await setOwnerName(ownerName);
      if (address != null) await setStoreAddress(address);
      if (city != null) await setStoreCity(city);
      if (state != null) await setStoreState(state);
      if (pincode != null) await setStorePincode(pincode);
      if (phone != null) await setStorePhone(phone);
      if (email != null) await setStoreEmail(email);
      if (gstNumber != null) await setGSTNumber(gstNumber);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all store settings
  Future<bool> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.remove(_keyStoreName);
      await prefs.remove(_keyStoreAddress);
      await prefs.remove(_keyStorePhone);
      await prefs.remove(_keyStoreEmail);
      await prefs.remove(_keyStoreGST);
      await prefs.remove(_keyUpiId);
      await prefs.remove(_keyUpiPayee);
      await prefs.remove(_keyUpiQr);
      await prefs.remove(_keyOwnerName);
      await prefs.remove(_keyStoreCity);
      await prefs.remove(_keyStoreState);
      await prefs.remove(_keyStorePincode);
      // Note: Logo is stored in Hive via BusinessDetails, not SharedPreferences
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if store settings are configured
  Future<bool> isStoreConfigured() async {
    final storeName = await getStoreName();
    return storeName != null && storeName.isNotEmpty;
  }
}