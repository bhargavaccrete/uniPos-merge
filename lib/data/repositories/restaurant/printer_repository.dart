import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unipos/core/constants/hive_box_names.dart';
import '../../models/restaurant/db/saved_printer_model.dart';

/// Repository layer for saved thermal printers (Restaurant)
/// Handles all Hive database operations for printer configuration.
///
/// Default printer assignments are stored in SharedPreferences (not on the
/// model's isDefault field) so that KOT default and Receipt default are
/// truly independent. A single printer with role='both' can be the default
/// for KOT, Receipt, or both simultaneously without conflict.
class PrinterRepository {
  late Box<SavedPrinterModel> _printerBox;

  // SharedPreferences keys for default printer IDs
  static const String _defaultKotPrinterKey = 'default_kot_printer_id';
  static const String _defaultReceiptPrinterKey = 'default_receipt_printer_id';

  PrinterRepository() {
    _printerBox =
        Hive.box<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
  }

  /// Save (insert or update) a printer
  Future<void> savePrinter(SavedPrinterModel printer) async {
    await _printerBox.put(printer.id, printer);
  }

  /// Get printer by ID
  Future<SavedPrinterModel?> getPrinterById(String id) async {
    return _printerBox.get(id);
  }

  /// Get all saved printers
  Future<List<SavedPrinterModel>> getAllPrinters() async {
    final list = _printerBox.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get the default printer for a given role ('kot' or 'receipt').
  ///
  /// Reads the printer ID from SharedPreferences, then looks up the model.
  /// Also validates that the printer's role is compatible (e.g., a printer
  /// with role='receipt' can't be the KOT default).
  Future<SavedPrinterModel?> getDefaultPrinterForRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = role == 'kot' ? _defaultKotPrinterKey : _defaultReceiptPrinterKey;
    final printerId = prefs.getString(key);

    if (printerId == null) return null;

    final printer = _printerBox.get(printerId);
    if (printer == null) {
      // Printer was deleted — clear the stale reference
      await prefs.remove(key);
      return null;
    }

    // Validate role compatibility
    if (printer.role != role && printer.role != 'both') {
      // Printer's role doesn't match — clear stale reference
      await prefs.remove(key);
      return null;
    }

    return printer;
  }

  /// Set a printer as default for a specific role ('kot' or 'receipt').
  ///
  /// Stored in SharedPreferences — completely independent per role.
  /// Setting KOT default does NOT affect Receipt default and vice versa.
  Future<void> setDefaultPrinter(String id, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = role == 'kot' ? _defaultKotPrinterKey : _defaultReceiptPrinterKey;
    await prefs.setString(key, id);
  }

  /// Clear default assignment for a role
  Future<void> clearDefaultPrinter(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = role == 'kot' ? _defaultKotPrinterKey : _defaultReceiptPrinterKey;
    await prefs.remove(key);
  }

  /// Delete a printer by ID. Also clears any default assignments pointing to it.
  Future<void> deletePrinter(String id) async {
    final prefs = await SharedPreferences.getInstance();

    // Clear default references if this printer was a default
    if (prefs.getString(_defaultKotPrinterKey) == id) {
      await prefs.remove(_defaultKotPrinterKey);
    }
    if (prefs.getString(_defaultReceiptPrinterKey) == id) {
      await prefs.remove(_defaultReceiptPrinterKey);
    }

    await _printerBox.delete(id);
  }

  /// Get total printer count
  Future<int> getPrinterCount() async {
    return _printerBox.length;
  }

  /// Get printers filtered by type ('bluetooth' or 'wifi')
  Future<List<SavedPrinterModel>> getPrintersByType(String type) async {
    return _printerBox.values.where((p) => p.type == type).toList();
  }
}
