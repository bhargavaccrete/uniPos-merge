import 'package:flutter/material.dart';
import '../../../../data/models/retail/printer_settings_model.dart';
import '../../../../domain/services/retail/retail_printer_settings_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = RetailPrinterSettingsService();
  late RetailPrinterSettings _settings;

  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  final _termsController = TextEditingController();
  final _poweredByController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _printerService.initialize();
    setState(() {
      _settings = _printerService.settings;
      _headerController.text = _settings.headerText;
      _footerController.text = _settings.footerText;
      _termsController.text = _settings.termsAndConditionsText;
      _poweredByController.text = _settings.poweredByText;
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    _termsController.dispose();
    _poweredByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: _resetToDefaults,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Test Print',
            onPressed: _testPrint,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPaperSizeSection(),
          const SizedBox(height: 24),
          _buildLogoSection(),
          const SizedBox(height: 24),
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildInvoiceDetailsSection(),
          const SizedBox(height: 24),
          _buildItemDetailsSection(),
          const SizedBox(height: 24),
          _buildPricingSection(),
          const SizedBox(height: 24),
          _buildPaymentSection(),
          const SizedBox(height: 24),
          _buildFooterSection(),
          const SizedBox(height: 24),
          _buildPrintBehaviorSection(),
          const SizedBox(height: 24),
          _buildFormattingSection(),
        ],
      ),
    );
  }

  // ==================== PAPER SIZE SECTION ====================
  Widget _buildPaperSizeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paper Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Paper Size', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<PaperSize>(
              segments: const [
                ButtonSegment(
                  value: PaperSize.mm58,
                  label: Text('58mm'),
                  icon: Icon(Icons.receipt),
                ),
                ButtonSegment(
                  value: PaperSize.mm80,
                  label: Text('80mm'),
                  icon: Icon(Icons.receipt_long),
                ),
                ButtonSegment(
                  value: PaperSize.a4,
                  label: Text('A4'),
                  icon: Icon(Icons.description),
                ),
              ],
              selected: {_settings.paperSize},
              onSelectionChanged: (Set<PaperSize> newSelection) {
                _printerService.setPaperSize(newSelection.first);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== LOGO SECTION ====================
  Widget _buildLogoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logo Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Logo'),
              subtitle: const Text('Display store logo on invoice'),
              value: _settings.showLogo,
              onChanged: (value) {
                _printerService.setShowLogo(value);
                _loadSettings();
              },
            ),
            if (_settings.showLogo) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Logo Image'),
                subtitle: Text(_settings.logoPath ?? 'Using default logo'),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  // TODO: Implement image picker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image picker coming soon')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== HEADER SECTION ====================
  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Header Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Header'),
              value: _settings.showHeader,
              onChanged: (value) {
                _printerService.setShowHeader(value);
                _loadSettings();
              },
            ),
            if (_settings.showHeader) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _headerController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Header Text',
                    hintText: 'e.g., Welcome to our store!',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _printerService.setHeaderText(value),
                ),
              ),
              SwitchListTile(
                title: const Text('Store Name'),
                value: _settings.showStoreName,
                onChanged: (value) {
                  _printerService.setShowStoreName(value);
                  _loadSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Store Address'),
                value: _settings.showStoreAddress,
                onChanged: (value) {
                  _printerService.setShowStoreAddress(value);
                  _loadSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Store Phone'),
                value: _settings.showStorePhone,
                onChanged: (value) {
                  _printerService.setShowStorePhone(value);
                  _loadSettings();
                },
              ),
              SwitchListTile(
                title: const Text('Store Email'),
                value: _settings.showStoreEmail,
                onChanged: (value) {
                  _printerService.setShowStoreEmail(value);
                  _loadSettings();
                },
              ),
              SwitchListTile(
                title: const Text('GST Number'),
                value: _settings.showGSTNumber,
                onChanged: (value) {
                  _printerService.setShowGSTNumber(value);
                  _loadSettings();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== INVOICE DETAILS SECTION ====================
  Widget _buildInvoiceDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Invoice Number'),
              value: _settings.showInvoiceNumber,
              onChanged: (value) {
                _printerService.setShowInvoiceNumber(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Invoice Date'),
              value: _settings.showInvoiceDate,
              onChanged: (value) {
                _printerService.setShowInvoiceDate(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Invoice Time'),
              value: _settings.showInvoiceTime,
              onChanged: (value) {
                _printerService.setShowInvoiceTime(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Customer Details'),
              value: _settings.showCustomerDetails,
              onChanged: (value) {
                _printerService.setShowCustomerDetails(value);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ITEM DETAILS SECTION ====================
  Widget _buildItemDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Variant Details'),
              subtitle: const Text('Size, Color, Weight'),
              value: _settings.showVariantDetails,
              onChanged: (value) {
                _printerService.setShowVariantDetails(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('HSN Code'),
              value: _settings.showHSNCode,
              onChanged: (value) {
                _printerService.setShowHSNCode(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Barcode'),
              value: _settings.showBarcode,
              onChanged: (value) {
                _printerService.setShowBarcode(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Item Discount'),
              value: _settings.showItemDiscount,
              onChanged: (value) {
                _printerService.setShowItemDiscount(value);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PRICING SECTION ====================
  Widget _buildPricingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing & Tax',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('MRP'),
              value: _settings.showMRP,
              onChanged: (value) {
                _printerService.setShowMRP(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Subtotal'),
              value: _settings.showSubtotal,
              onChanged: (value) {
                _printerService.setShowSubtotal(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Discount'),
              value: _settings.showDiscount,
              onChanged: (value) {
                _printerService.setShowDiscount(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Tax'),
              value: _settings.showTax,
              onChanged: (value) {
                _printerService.setShowTax(value);
                _loadSettings();
              },
            ),
            if (_settings.showTax)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: SwitchListTile(
                  title: const Text('Tax Breakdown'),
                  subtitle: const Text('Show CGST/SGST separately'),
                  value: _settings.showTaxBreakdown,
                  onChanged: (value) {
                    _printerService.setShowTaxBreakdown(value);
                    _loadSettings();
                  },
                ),
              ),
            SwitchListTile(
              title: const Text('Grand Total'),
              value: _settings.showGrandTotal,
              onChanged: (value) {
                _printerService.setShowGrandTotal(value);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PAYMENT SECTION ====================
  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Payment Method'),
              value: _settings.showPaymentMethod,
              onChanged: (value) {
                _printerService.setShowPaymentMethod(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Split Payment'),
              subtitle: const Text('Show multiple payment methods'),
              value: _settings.showSplitPayment,
              onChanged: (value) {
                _printerService.setShowSplitPayment(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Amount Received'),
              value: _settings.showAmountReceived,
              onChanged: (value) {
                _printerService.setShowAmountReceived(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Change Given'),
              value: _settings.showChangeGiven,
              onChanged: (value) {
                _printerService.setShowChangeGiven(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Loyalty Points'),
              value: _settings.showLoyaltyPoints,
              onChanged: (value) {
                _printerService.setShowLoyaltyPoints(value);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOOTER SECTION ====================
  Widget _buildFooterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Footer Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Footer'),
              value: _settings.showFooter,
              onChanged: (value) {
                _printerService.setShowFooter(value);
                _loadSettings();
              },
            ),
            if (_settings.showFooter) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _footerController,
                  decoration: const InputDecoration(
                    labelText: 'Footer Text',
                    hintText: 'e.g., Thank you, Visit Again!',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _printerService.setFooterText(value),
                ),
              ),
            ],
            SwitchListTile(
              title: const Text('Terms & Conditions'),
              value: _settings.showTermsAndConditions,
              onChanged: (value) {
                _printerService.setShowTermsAndConditions(value);
                _loadSettings();
              },
            ),
            if (_settings.showTermsAndConditions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _termsController,
                  decoration: const InputDecoration(
                    labelText: 'Terms & Conditions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) => _printerService.setTermsAndConditionsText(value),
                ),
              ),
            SwitchListTile(
              title: const Text('Powered By'),
              value: _settings.showPoweredBy,
              onChanged: (value) {
                _printerService.setShowPoweredBy(value);
                _loadSettings();
              },
            ),
            if (_settings.showPoweredBy)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _poweredByController,
                  decoration: const InputDecoration(
                    labelText: 'Powered By Text',
                    hintText: 'e.g., Powered by YourCompany',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _printerService.setPoweredByText(value),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== PRINT BEHAVIOR SECTION ====================
  Widget _buildPrintBehaviorSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Print Behavior',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Auto Print After Sale'),
              subtitle: const Text('Automatically print invoice after checkout'),
              value: _settings.autoPrintAfterSale,
              onChanged: (value) {
                _printerService.setAutoPrintAfterSale(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Show Print Dialog'),
              subtitle: const Text('Show preview before printing'),
              value: _settings.showPrintDialog,
              onChanged: (value) {
                _printerService.setShowPrintDialog(value);
                _loadSettings();
              },
            ),
            ListTile(
              title: const Text('Number of Copies'),
              subtitle: Text('${_settings.numberOfCopies} ${_settings.numberOfCopies == 1 ? "copy" : "copies"}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _settings.numberOfCopies > 1
                        ? () {
                            _printerService.setNumberOfCopies(_settings.numberOfCopies - 1);
                            _loadSettings();
                          }
                        : null,
                  ),
                  Text('${_settings.numberOfCopies}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _settings.numberOfCopies < 5
                        ? () {
                            _printerService.setNumberOfCopies(_settings.numberOfCopies + 1);
                            _loadSettings();
                          }
                        : null,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Open Cash Drawer'),
              subtitle: const Text('Open cash drawer after printing'),
              value: _settings.openCashDrawer,
              onChanged: (value) {
                _printerService.setOpenCashDrawer(value);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FORMATTING SECTION ====================
  Widget _buildFormattingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Formatting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Font Size', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<FontSize>(
              segments: const [
                ButtonSegment(value: FontSize.small, label: Text('Small')),
                ButtonSegment(value: FontSize.medium, label: Text('Medium')),
                ButtonSegment(value: FontSize.large, label: Text('Large')),
              ],
              selected: {_settings.fontSize},
              onSelectionChanged: (Set<FontSize> newSelection) {
                _printerService.setFontSize(newSelection.first);
                _loadSettings();
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Bold Product Names'),
              value: _settings.boldProductNames,
              onChanged: (value) {
                _printerService.setBoldProductNames(value);
                _loadSettings();
              },
            ),
            SwitchListTile(
              title: const Text('Show Borders'),
              value: _settings.showBorders,
              onChanged: (value) {
                _printerService.setShowBorders(value);
                _loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text('This will reset all printer settings to default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _printerService.resetToDefaults();
      _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test print feature coming soon')),
    );
    // TODO: Implement test print with sample invoice
  }
}