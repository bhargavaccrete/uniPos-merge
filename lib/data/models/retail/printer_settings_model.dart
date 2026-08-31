// Retail Printer Settings Model
// Stores all printer configuration options for invoices/receipts

enum PaperSize {
  mm58,  // 58mm thermal paper
  mm80,  // 80mm thermal paper (default)
  a4,    // A4 size for regular printers
}

enum FontSize {
  small,
  medium,
  large,
}

/// Receipt layout, matching the two thermal templates restaurant offers.
///
/// Thermal only — an A4 invoice has a fixed layout, so this is ignored there.
enum BillTemplate {
  /// Clean, structured layout with full spacing.
  simple,

  /// Compact spacing and tighter margins, to use less roll paper.
  paperSaver,
}

class RetailPrinterSettings {
  // Paper Configuration
  final PaperSize paperSize;
  final int paperWidth; // in mm

  // Logo Settings
  final bool showLogo;
  final String? logoPath;
  final double logoHeight; // in mm

  // Header Settings
  final bool showHeader;
  final String headerText;
  final bool showStoreName;
  final bool showStoreAddress;
  final bool showStorePhone;
  final bool showStoreEmail;
  final bool showGSTNumber;

  // Invoice Details
  final bool showInvoiceNumber;
  final bool showInvoiceDate;
  final bool showInvoiceTime;
  final bool showCustomerDetails;
  final bool showCustomerGST;

  // Item Details
  final bool showProductCode;
  final bool showBarcode;
  final bool showVariantDetails; // size, color, weight
  final bool showItemDiscount;

  // Pricing & Tax
  final bool showMRP;
  final bool showUnitPrice;
  final bool showSubtotal;
  final bool showDiscount;
  final bool showTax;
  final bool showTaxBreakdown; // CGST/SGST separate
  final bool showGrandTotal;

  // Payment Details
  final bool showPaymentMethod;
  final bool showSplitPayment;
  final bool showAmountReceived;
  final bool showChangeGiven;
  final bool showCreditBalance;

  // Additional Features
  final bool showLoyaltyPoints;
  final bool showTermsAndConditions;
  final String termsAndConditionsText;

  // Footer Settings
  final bool showFooter;
  final String footerText;
  final bool showPoweredBy;
  final String poweredByText;

  // Print Behavior
  final bool autoPrintAfterSale;
  final int numberOfCopies;
  final bool showPrintDialog; // Show preview before printing
  final bool openCashDrawer; // Open cash drawer after print

  // Formatting
  final FontSize fontSize;
  final bool boldProductNames;
  final bool showBorders;
  final String lineStyle; // 'solid', 'dashed', 'dotted'

  // Language & Format
  final String dateFormat; // 'dd/MM/yyyy', 'MM/dd/yyyy', etc.
  final String timeFormat; // '12h', '24h'

  /// Thermal receipt layout. Ignored for A4, which has a fixed layout.
  final BillTemplate billTemplate;

  const RetailPrinterSettings({
    // Paper Configuration
    this.paperSize = PaperSize.mm80,
    this.paperWidth = 80,
    this.billTemplate = BillTemplate.simple,

    // Logo Settings
    this.showLogo = true,
    this.logoPath,
    this.logoHeight = 20,

    // Header Settings
    this.showHeader = true,
    this.headerText = '',
    this.showStoreName = true,
    this.showStoreAddress = true,
    this.showStorePhone = true,
    this.showStoreEmail = false,
    this.showGSTNumber = true,

    // Invoice Details
    this.showInvoiceNumber = true,
    this.showInvoiceDate = true,
    this.showInvoiceTime = true,
    this.showCustomerDetails = true,
    this.showCustomerGST = false,

    // Item Details
    this.showProductCode = false,
    this.showBarcode = false,
    this.showVariantDetails = true,
    this.showItemDiscount = true,

    // Pricing & Tax
    this.showMRP = false,
    this.showUnitPrice = true,
    this.showSubtotal = true,
    this.showDiscount = true,
    this.showTax = true,
    this.showTaxBreakdown = true,
    this.showGrandTotal = true,

    // Payment Details
    this.showPaymentMethod = true,
    this.showSplitPayment = true,
    this.showAmountReceived = true,
    this.showChangeGiven = true,
    this.showCreditBalance = true,

    // Additional Features
    this.showLoyaltyPoints = true,
    this.showTermsAndConditions = false,
    this.termsAndConditionsText = 'Thank you for your business!',

    // Footer Settings
    this.showFooter = true,
    this.footerText = 'Visit Again!',
    this.showPoweredBy = false,
    this.poweredByText = 'Powered by Bill Berry Lite',

    // Print Behavior
    this.autoPrintAfterSale = false,
    this.numberOfCopies = 1,
    this.showPrintDialog = true,
    this.openCashDrawer = false,

    // Formatting
    this.fontSize = FontSize.medium,
    this.boldProductNames = true,
    this.showBorders = false,
    this.lineStyle = 'dashed',

    // Language & Format
    this.dateFormat = 'dd/MM/yyyy',
    this.timeFormat = '12h',
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'paperSize': paperSize.index,
      'paperWidth': paperWidth,
      'showLogo': showLogo,
      'logoPath': logoPath,
      'logoHeight': logoHeight,
      'showHeader': showHeader,
      'headerText': headerText,
      'showStoreName': showStoreName,
      'showStoreAddress': showStoreAddress,
      'showStorePhone': showStorePhone,
      'showStoreEmail': showStoreEmail,
      'showGSTNumber': showGSTNumber,
      'showInvoiceNumber': showInvoiceNumber,
      'showInvoiceDate': showInvoiceDate,
      'showInvoiceTime': showInvoiceTime,
      'showCustomerDetails': showCustomerDetails,
      'showCustomerGST': showCustomerGST,
      'showProductCode': showProductCode,
      'showBarcode': showBarcode,
      'showVariantDetails': showVariantDetails,
      'showItemDiscount': showItemDiscount,
      'showMRP': showMRP,
      'showUnitPrice': showUnitPrice,
      'showSubtotal': showSubtotal,
      'showDiscount': showDiscount,
      'showTax': showTax,
      'showTaxBreakdown': showTaxBreakdown,
      'showGrandTotal': showGrandTotal,
      'showPaymentMethod': showPaymentMethod,
      'showSplitPayment': showSplitPayment,
      'showAmountReceived': showAmountReceived,
      'showChangeGiven': showChangeGiven,
      'showCreditBalance': showCreditBalance,
      'showLoyaltyPoints': showLoyaltyPoints,
      'showTermsAndConditions': showTermsAndConditions,
      'termsAndConditionsText': termsAndConditionsText,
      'showFooter': showFooter,
      'footerText': footerText,
      'showPoweredBy': showPoweredBy,
      'poweredByText': poweredByText,
      'autoPrintAfterSale': autoPrintAfterSale,
      'numberOfCopies': numberOfCopies,
      'showPrintDialog': showPrintDialog,
      'openCashDrawer': openCashDrawer,
      'fontSize': fontSize.index,
      'boldProductNames': boldProductNames,
      'showBorders': showBorders,
      'lineStyle': lineStyle,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
      'billTemplate': billTemplate.index,
    };
  }

  // Create from JSON
  factory RetailPrinterSettings.fromJson(Map<String, dynamic> json) {
    return RetailPrinterSettings(
      paperSize: PaperSize.values[json['paperSize'] ?? 1],
      paperWidth: json['paperWidth'] ?? 80,
      // Index-clamped: a stored value from a future build with more templates
      // would otherwise throw a RangeError on startup.
      billTemplate: BillTemplate.values[
          ((json['billTemplate'] as int?) ?? 0)
              .clamp(0, BillTemplate.values.length - 1)],
      showLogo: json['showLogo'] ?? true,
      logoPath: json['logoPath'],
      logoHeight: json['logoHeight'] ?? 20,
      showHeader: json['showHeader'] ?? true,
      headerText: json['headerText'] ?? '',
      showStoreName: json['showStoreName'] ?? true,
      showStoreAddress: json['showStoreAddress'] ?? true,
      showStorePhone: json['showStorePhone'] ?? true,
      showStoreEmail: json['showStoreEmail'] ?? false,
      showGSTNumber: json['showGSTNumber'] ?? true,
      showInvoiceNumber: json['showInvoiceNumber'] ?? true,
      showInvoiceDate: json['showInvoiceDate'] ?? true,
      showInvoiceTime: json['showInvoiceTime'] ?? true,
      showCustomerDetails: json['showCustomerDetails'] ?? true,
      showCustomerGST: json['showCustomerGST'] ?? false,
      showProductCode: json['showProductCode'] ?? false,
      showBarcode: json['showBarcode'] ?? false,
      showVariantDetails: json['showVariantDetails'] ?? true,
      showItemDiscount: json['showItemDiscount'] ?? true,
      showMRP: json['showMRP'] ?? false,
      showUnitPrice: json['showUnitPrice'] ?? true,
      showSubtotal: json['showSubtotal'] ?? true,
      showDiscount: json['showDiscount'] ?? true,
      showTax: json['showTax'] ?? true,
      showTaxBreakdown: json['showTaxBreakdown'] ?? true,
      showGrandTotal: json['showGrandTotal'] ?? true,
      showPaymentMethod: json['showPaymentMethod'] ?? true,
      showSplitPayment: json['showSplitPayment'] ?? true,
      showAmountReceived: json['showAmountReceived'] ?? true,
      showChangeGiven: json['showChangeGiven'] ?? true,
      showCreditBalance: json['showCreditBalance'] ?? true,
      showLoyaltyPoints: json['showLoyaltyPoints'] ?? true,
      showTermsAndConditions: json['showTermsAndConditions'] ?? false,
      termsAndConditionsText: json['termsAndConditionsText'] ?? 'Thank you for your business!',
      showFooter: json['showFooter'] ?? true,
      footerText: json['footerText'] ?? 'Visit Again!',
      showPoweredBy: json['showPoweredBy'] ?? false,
      poweredByText: json['poweredByText'] ?? 'Powered by Bill Berry Lite',
      autoPrintAfterSale: json['autoPrintAfterSale'] ?? false,
      numberOfCopies: json['numberOfCopies'] ?? 1,
      showPrintDialog: json['showPrintDialog'] ?? true,
      openCashDrawer: json['openCashDrawer'] ?? false,
      fontSize: FontSize.values[json['fontSize'] ?? 1],
      boldProductNames: json['boldProductNames'] ?? true,
      showBorders: json['showBorders'] ?? false,
      lineStyle: json['lineStyle'] ?? 'dashed',
      dateFormat: json['dateFormat'] ?? 'dd/MM/yyyy',
      timeFormat: json['timeFormat'] ?? '12h',
    );
  }

  // Copy with method for immutable updates
  RetailPrinterSettings copyWith({
    PaperSize? paperSize,
    int? paperWidth,
    BillTemplate? billTemplate,
    bool? showLogo,
    String? logoPath,
    double? logoHeight,
    bool? showHeader,
    String? headerText,
    bool? showStoreName,
    bool? showStoreAddress,
    bool? showStorePhone,
    bool? showStoreEmail,
    bool? showGSTNumber,
    bool? showInvoiceNumber,
    bool? showInvoiceDate,
    bool? showInvoiceTime,
    bool? showCustomerDetails,
    bool? showCustomerGST,
    bool? showProductCode,
    bool? showBarcode,
    bool? showVariantDetails,
    bool? showItemDiscount,
    bool? showMRP,
    bool? showUnitPrice,
    bool? showSubtotal,
    bool? showDiscount,
    bool? showTax,
    bool? showTaxBreakdown,
    bool? showGrandTotal,
    bool? showPaymentMethod,
    bool? showSplitPayment,
    bool? showAmountReceived,
    bool? showChangeGiven,
    bool? showCreditBalance,
    bool? showLoyaltyPoints,
    bool? showTermsAndConditions,
    String? termsAndConditionsText,
    bool? showFooter,
    String? footerText,
    bool? showPoweredBy,
    String? poweredByText,
    bool? autoPrintAfterSale,
    int? numberOfCopies,
    bool? showPrintDialog,
    bool? openCashDrawer,
    FontSize? fontSize,
    bool? boldProductNames,
    bool? showBorders,
    String? lineStyle,
    String? dateFormat,
    String? timeFormat,
  }) {
    return RetailPrinterSettings(
      paperSize: paperSize ?? this.paperSize,
      paperWidth: paperWidth ?? this.paperWidth,
      billTemplate: billTemplate ?? this.billTemplate,
      showLogo: showLogo ?? this.showLogo,
      logoPath: logoPath ?? this.logoPath,
      logoHeight: logoHeight ?? this.logoHeight,
      showHeader: showHeader ?? this.showHeader,
      headerText: headerText ?? this.headerText,
      showStoreName: showStoreName ?? this.showStoreName,
      showStoreAddress: showStoreAddress ?? this.showStoreAddress,
      showStorePhone: showStorePhone ?? this.showStorePhone,
      showStoreEmail: showStoreEmail ?? this.showStoreEmail,
      showGSTNumber: showGSTNumber ?? this.showGSTNumber,
      showInvoiceNumber: showInvoiceNumber ?? this.showInvoiceNumber,
      showInvoiceDate: showInvoiceDate ?? this.showInvoiceDate,
      showInvoiceTime: showInvoiceTime ?? this.showInvoiceTime,
      showCustomerDetails: showCustomerDetails ?? this.showCustomerDetails,
      showCustomerGST: showCustomerGST ?? this.showCustomerGST,
      showProductCode: showProductCode ?? this.showProductCode,
      showBarcode: showBarcode ?? this.showBarcode,
      showVariantDetails: showVariantDetails ?? this.showVariantDetails,
      showItemDiscount: showItemDiscount ?? this.showItemDiscount,
      showMRP: showMRP ?? this.showMRP,
      showUnitPrice: showUnitPrice ?? this.showUnitPrice,
      showSubtotal: showSubtotal ?? this.showSubtotal,
      showDiscount: showDiscount ?? this.showDiscount,
      showTax: showTax ?? this.showTax,
      showTaxBreakdown: showTaxBreakdown ?? this.showTaxBreakdown,
      showGrandTotal: showGrandTotal ?? this.showGrandTotal,
      showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      showSplitPayment: showSplitPayment ?? this.showSplitPayment,
      showAmountReceived: showAmountReceived ?? this.showAmountReceived,
      showChangeGiven: showChangeGiven ?? this.showChangeGiven,
      showCreditBalance: showCreditBalance ?? this.showCreditBalance,
      showLoyaltyPoints: showLoyaltyPoints ?? this.showLoyaltyPoints,
      showTermsAndConditions: showTermsAndConditions ?? this.showTermsAndConditions,
      termsAndConditionsText: termsAndConditionsText ?? this.termsAndConditionsText,
      showFooter: showFooter ?? this.showFooter,
      footerText: footerText ?? this.footerText,
      showPoweredBy: showPoweredBy ?? this.showPoweredBy,
      poweredByText: poweredByText ?? this.poweredByText,
      autoPrintAfterSale: autoPrintAfterSale ?? this.autoPrintAfterSale,
      numberOfCopies: numberOfCopies ?? this.numberOfCopies,
      showPrintDialog: showPrintDialog ?? this.showPrintDialog,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      fontSize: fontSize ?? this.fontSize,
      boldProductNames: boldProductNames ?? this.boldProductNames,
      showBorders: showBorders ?? this.showBorders,
      lineStyle: lineStyle ?? this.lineStyle,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
}