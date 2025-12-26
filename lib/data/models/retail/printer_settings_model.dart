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
  final bool showHSNCode;
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
  final String currencySymbol;
  final String dateFormat; // 'dd/MM/yyyy', 'MM/dd/yyyy', etc.
  final String timeFormat; // '12h', '24h'

  const RetailPrinterSettings({
    // Paper Configuration
    this.paperSize = PaperSize.mm80,
    this.paperWidth = 80,

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
    this.showHSNCode = false,
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
    this.poweredByText = 'Powered by UniPOS',

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
    this.currencySymbol = '₹',
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
      'showHSNCode': showHSNCode,
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
      'currencySymbol': currencySymbol,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
    };
  }

  // Create from JSON
  factory RetailPrinterSettings.fromJson(Map<String, dynamic> json) {
    return RetailPrinterSettings(
      paperSize: PaperSize.values[json['paperSize'] ?? 1],
      paperWidth: json['paperWidth'] ?? 80,
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
      showHSNCode: json['showHSNCode'] ?? false,
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
      poweredByText: json['poweredByText'] ?? 'Powered by UniPOS',
      autoPrintAfterSale: json['autoPrintAfterSale'] ?? false,
      numberOfCopies: json['numberOfCopies'] ?? 1,
      showPrintDialog: json['showPrintDialog'] ?? true,
      openCashDrawer: json['openCashDrawer'] ?? false,
      fontSize: FontSize.values[json['fontSize'] ?? 1],
      boldProductNames: json['boldProductNames'] ?? true,
      showBorders: json['showBorders'] ?? false,
      lineStyle: json['lineStyle'] ?? 'dashed',
      currencySymbol: json['currencySymbol'] ?? '₹',
      dateFormat: json['dateFormat'] ?? 'dd/MM/yyyy',
      timeFormat: json['timeFormat'] ?? '12h',
    );
  }

  // Copy with method for immutable updates
  RetailPrinterSettings copyWith({
    PaperSize? paperSize,
    int? paperWidth,
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
    bool? showHSNCode,
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
    String? currencySymbol,
    String? dateFormat,
    String? timeFormat,
  }) {
    return RetailPrinterSettings(
      paperSize: paperSize ?? this.paperSize,
      paperWidth: paperWidth ?? this.paperWidth,
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
      showHSNCode: showHSNCode ?? this.showHSNCode,
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
      currencySymbol: currencySymbol ?? this.currencySymbol,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
}