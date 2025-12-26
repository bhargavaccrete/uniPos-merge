import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/retail/printer_settings_model.dart';

/// Service to manage retail printer settings
/// Singleton pattern with SharedPreferences persistence
class RetailPrinterSettingsService {
  static final RetailPrinterSettingsService _instance =
      RetailPrinterSettingsService._internal();

  factory RetailPrinterSettingsService() => _instance;

  RetailPrinterSettingsService._internal();

  static const String _settingsKey = 'retail_printer_settings';

  RetailPrinterSettings _settings = const RetailPrinterSettings();
  bool _isInitialized = false;

  /// Get current printer settings
  RetailPrinterSettings get settings => _settings;

  /// Initialize and load settings from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(settingsJson);
        _settings = RetailPrinterSettings.fromJson(json);
      } catch (e) {
        print('Error loading printer settings: $e');
        // Use default settings if loading fails
        _settings = const RetailPrinterSettings();
      }
    }

    _isInitialized = true;
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = jsonEncode(_settings.toJson());
    await prefs.setString(_settingsKey, settingsJson);
  }

  /// Update all settings at once
  Future<void> updateSettings(RetailPrinterSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
  }

  // ==================== PAPER CONFIGURATION ====================

  Future<void> setPaperSize(PaperSize size) async {
    int width = size == PaperSize.mm58 ? 58 : size == PaperSize.mm80 ? 80 : 210;
    _settings = _settings.copyWith(paperSize: size, paperWidth: width);
    await _saveSettings();
  }

  // ==================== LOGO SETTINGS ====================

  Future<void> setShowLogo(bool show) async {
    _settings = _settings.copyWith(showLogo: show);
    await _saveSettings();
  }

  Future<void> setLogoPath(String? path) async {
    _settings = _settings.copyWith(logoPath: path);
    await _saveSettings();
  }

  Future<void> setLogoHeight(double height) async {
    _settings = _settings.copyWith(logoHeight: height);
    await _saveSettings();
  }

  // ==================== HEADER SETTINGS ====================

  Future<void> setShowHeader(bool show) async {
    _settings = _settings.copyWith(showHeader: show);
    await _saveSettings();
  }

  Future<void> setHeaderText(String text) async {
    _settings = _settings.copyWith(headerText: text);
    await _saveSettings();
  }

  Future<void> setShowStoreName(bool show) async {
    _settings = _settings.copyWith(showStoreName: show);
    await _saveSettings();
  }

  Future<void> setShowStoreAddress(bool show) async {
    _settings = _settings.copyWith(showStoreAddress: show);
    await _saveSettings();
  }

  Future<void> setShowStorePhone(bool show) async {
    _settings = _settings.copyWith(showStorePhone: show);
    await _saveSettings();
  }

  Future<void> setShowStoreEmail(bool show) async {
    _settings = _settings.copyWith(showStoreEmail: show);
    await _saveSettings();
  }

  Future<void> setShowGSTNumber(bool show) async {
    _settings = _settings.copyWith(showGSTNumber: show);
    await _saveSettings();
  }

  // ==================== INVOICE DETAILS ====================

  Future<void> setShowInvoiceNumber(bool show) async {
    _settings = _settings.copyWith(showInvoiceNumber: show);
    await _saveSettings();
  }

  Future<void> setShowInvoiceDate(bool show) async {
    _settings = _settings.copyWith(showInvoiceDate: show);
    await _saveSettings();
  }

  Future<void> setShowInvoiceTime(bool show) async {
    _settings = _settings.copyWith(showInvoiceTime: show);
    await _saveSettings();
  }

  Future<void> setShowCustomerDetails(bool show) async {
    _settings = _settings.copyWith(showCustomerDetails: show);
    await _saveSettings();
  }

  // ==================== ITEM DETAILS ====================

  Future<void> setShowVariantDetails(bool show) async {
    _settings = _settings.copyWith(showVariantDetails: show);
    await _saveSettings();
  }

  Future<void> setShowItemDiscount(bool show) async {
    _settings = _settings.copyWith(showItemDiscount: show);
    await _saveSettings();
  }

  Future<void> setShowBarcode(bool show) async {
    _settings = _settings.copyWith(showBarcode: show);
    await _saveSettings();
  }

  Future<void> setShowHSNCode(bool show) async {
    _settings = _settings.copyWith(showHSNCode: show);
    await _saveSettings();
  }

  // ==================== PRICING & TAX ====================

  Future<void> setShowMRP(bool show) async {
    _settings = _settings.copyWith(showMRP: show);
    await _saveSettings();
  }

  Future<void> setShowSubtotal(bool show) async {
    _settings = _settings.copyWith(showSubtotal: show);
    await _saveSettings();
  }

  Future<void> setShowDiscount(bool show) async {
    _settings = _settings.copyWith(showDiscount: show);
    await _saveSettings();
  }

  Future<void> setShowTax(bool show) async {
    _settings = _settings.copyWith(showTax: show);
    await _saveSettings();
  }

  Future<void> setShowTaxBreakdown(bool show) async {
    _settings = _settings.copyWith(showTaxBreakdown: show);
    await _saveSettings();
  }

  Future<void> setShowGrandTotal(bool show) async {
    _settings = _settings.copyWith(showGrandTotal: show);
    await _saveSettings();
  }

  // ==================== PAYMENT DETAILS ====================

  Future<void> setShowPaymentMethod(bool show) async {
    _settings = _settings.copyWith(showPaymentMethod: show);
    await _saveSettings();
  }

  Future<void> setShowSplitPayment(bool show) async {
    _settings = _settings.copyWith(showSplitPayment: show);
    await _saveSettings();
  }

  Future<void> setShowAmountReceived(bool show) async {
    _settings = _settings.copyWith(showAmountReceived: show);
    await _saveSettings();
  }

  Future<void> setShowChangeGiven(bool show) async {
    _settings = _settings.copyWith(showChangeGiven: show);
    await _saveSettings();
  }

  Future<void> setShowLoyaltyPoints(bool show) async {
    _settings = _settings.copyWith(showLoyaltyPoints: show);
    await _saveSettings();
  }

  // ==================== FOOTER SETTINGS ====================

  Future<void> setShowFooter(bool show) async {
    _settings = _settings.copyWith(showFooter: show);
    await _saveSettings();
  }

  Future<void> setFooterText(String text) async {
    _settings = _settings.copyWith(footerText: text);
    await _saveSettings();
  }

  Future<void> setShowPoweredBy(bool show) async {
    _settings = _settings.copyWith(showPoweredBy: show);
    await _saveSettings();
  }

  Future<void> setPoweredByText(String text) async {
    _settings = _settings.copyWith(poweredByText: text);
    await _saveSettings();
  }

  Future<void> setShowTermsAndConditions(bool show) async {
    _settings = _settings.copyWith(showTermsAndConditions: show);
    await _saveSettings();
  }

  Future<void> setTermsAndConditionsText(String text) async {
    _settings = _settings.copyWith(termsAndConditionsText: text);
    await _saveSettings();
  }

  // ==================== PRINT BEHAVIOR ====================

  Future<void> setAutoPrintAfterSale(bool auto) async {
    _settings = _settings.copyWith(autoPrintAfterSale: auto);
    await _saveSettings();
  }

  Future<void> setNumberOfCopies(int copies) async {
    if (copies < 1) copies = 1;
    if (copies > 5) copies = 5; // Max 5 copies
    _settings = _settings.copyWith(numberOfCopies: copies);
    await _saveSettings();
  }

  Future<void> setShowPrintDialog(bool show) async {
    _settings = _settings.copyWith(showPrintDialog: show);
    await _saveSettings();
  }

  Future<void> setOpenCashDrawer(bool open) async {
    _settings = _settings.copyWith(openCashDrawer: open);
    await _saveSettings();
  }

  // ==================== FORMATTING ====================

  Future<void> setFontSize(FontSize size) async {
    _settings = _settings.copyWith(fontSize: size);
    await _saveSettings();
  }

  Future<void> setBoldProductNames(bool bold) async {
    _settings = _settings.copyWith(boldProductNames: bold);
    await _saveSettings();
  }

  Future<void> setShowBorders(bool show) async {
    _settings = _settings.copyWith(showBorders: show);
    await _saveSettings();
  }

  Future<void> setLineStyle(String style) async {
    _settings = _settings.copyWith(lineStyle: style);
    await _saveSettings();
  }

  // ==================== LANGUAGE & FORMAT ====================

  Future<void> setCurrencySymbol(String symbol) async {
    _settings = _settings.copyWith(currencySymbol: symbol);
    await _saveSettings();
  }

  Future<void> setDateFormat(String format) async {
    _settings = _settings.copyWith(dateFormat: format);
    await _saveSettings();
  }

  Future<void> setTimeFormat(String format) async {
    _settings = _settings.copyWith(timeFormat: format);
    await _saveSettings();
  }

  // ==================== UTILITY METHODS ====================

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    _settings = const RetailPrinterSettings();
    await _saveSettings();
  }

  /// Get paper size as string for UI display
  String getPaperSizeString() {
    switch (_settings.paperSize) {
      case PaperSize.mm58:
        return '58mm';
      case PaperSize.mm80:
        return '80mm';
      case PaperSize.a4:
        return 'A4';
    }
  }

  /// Get font size as string for UI display
  String getFontSizeString() {
    switch (_settings.fontSize) {
      case FontSize.small:
        return 'Small';
      case FontSize.medium:
        return 'Medium';
      case FontSize.large:
        return 'Large';
    }
  }
}