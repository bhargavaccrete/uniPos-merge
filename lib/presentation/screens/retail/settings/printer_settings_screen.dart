import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/plan/mode_keys.dart';
import 'package:billberrylite/core/plan/plan_enforcement.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../../data/models/retail/printer_settings_model.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/services/retail/retail_printer_settings_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = RetailPrinterSettingsService();
  late RetailPrinterSettings _settings;

  final _footerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _printerService.initialize();
    setState(() {
      _settings = _printerService.settings;
      _footerController.text = _settings.footerText;
    });
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Printer Settings',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Configure receipt fields',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: AppResponsive.smallFontSize(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reset to Defaults',
            onPressed: _resetToDefaults,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: isTablet ? 700 : double.infinity),
          child: SingleChildScrollView(
            padding: AppResponsive.padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bill template — restaurant leads with this too. Thermal only;
                // an A4 invoice has a fixed layout.
                if (_settings.paperSize != PaperSize.a4) ...[
                  _buildTemplateSection(context, isTablet),
                  const SizedBox(height: 24),
                ],

                _sectionHeader(context, 'Store Logo'),
                const SizedBox(height: 10),
                _buildLogoCard(context, isTablet),
                const SizedBox(height: 24),

                // Toggle groups, all but Branding — that goes last so the
                // "Powered By" lock reads as a footnote, as restaurant does.
                ..._toggleGroups()
                    .entries
                    .where((g) => g.key != 'Branding')
                    .map((g) =>
                        _buildToggleGroup(context, g.key, g.value, isTablet)),

                // Footer message, immediately before Branding — restaurant's
                // ordering exactly.
                _buildTextCard(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Footer Message',
                  description: 'The thank-you note at the bottom of every bill',
                  controller: _footerController,
                  hint: 'e.g. Visit Again!',
                  onChanged: _printerService.setFooterText,
                ),
                const SizedBox(height: 24),

                ..._toggleGroups()
                    .entries
                    .where((g) => g.key == 'Branding')
                    .map((g) =>
                        _buildToggleGroup(context, g.key, g.value, isTablet)),

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_done,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Settings auto-save',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.captionFontSize(context),
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TOGGLE GROUPS ====================

  /// Exactly the fields restaurant's Print Customization offers, mapped onto
  /// retail's settings.
  ///
  /// Typed getters and setters rather than restaurant's stringly-keyed map —
  /// retail's settings model is a real class and there is no reason to give
  /// that up to match a layout.
  ///
  /// Three of restaurant's fifteen have no retail counterpart and are omitted
  /// rather than faked: Order Type (retail has no dine-in/takeaway) and the two
  /// UPI QR options (no field on RetailPrinterSettings).
  Map<String, List<_PrintToggle>> _toggleGroups() {
    final s = _settings;
    return {
      'Store Information': [
        _PrintToggle('Store Logo', Icons.image_outlined,
            'Show store logo at the top of receipts', s.showLogo,
            _printerService.setShowLogo),
        _PrintToggle('Store Name', Icons.storefront_outlined,
            'Show store name on receipts', s.showStoreName,
            _printerService.setShowStoreName),
        _PrintToggle('Store Address', Icons.location_on_outlined,
            'Show store address', s.showStoreAddress,
            _printerService.setShowStoreAddress),
        _PrintToggle('Store Mobile No', Icons.phone_outlined,
            'Show contact number', s.showStorePhone,
            _printerService.setShowStorePhone),
      ],
      'Invoice Details': [
        _PrintToggle('Invoice Number', Icons.numbers,
            'Show invoice/bill number', s.showInvoiceNumber,
            _printerService.setShowInvoiceNumber),
        // Restaurant has a single "Ordered Time"; retail stores date and time
        // as two fields, so one switch drives both rather than exposing a
        // split restaurant does not have.
        _PrintToggle('Invoice Time', Icons.access_time,
            'Show invoice date and time', s.showInvoiceDate && s.showInvoiceTime,
            _setInvoiceDateTime),
        _PrintToggle('Customer Name', Icons.person_outline,
            'Show customer name if available', s.showCustomerDetails,
            _printerService.setShowCustomerDetails),
      ],
      'Payment & Pricing': [
        _PrintToggle('Payment Type', Icons.payment,
            'Show payment method (Cash/Card/UPI)', s.showPaymentMethod,
            _printerService.setShowPaymentMethod),
        _PrintToggle('Tax', Icons.percent, 'Show GST/tax breakdown', s.showTax,
            _printerService.setShowTax),
        _PrintToggle('Subtotal', Icons.calculate_outlined,
            'Show subtotal before tax', s.showSubtotal,
            _printerService.setShowSubtotal),
        _PrintToggle('Payment Paid', Icons.money,
            'Show cash received and change', s.showAmountReceived,
            _printerService.setShowAmountReceived),
      ],
      'Branding': [
        _PrintToggle('Powered By', Icons.verified_outlined,
            'Show "Powered by Bill Berry Lite" at the bottom of the bill',
            s.showPoweredBy, _printerService.setShowPoweredBy),
      ],
    };
  }

  /// Date and time move together — restaurant exposes one control for both.
  Future<void> _setInvoiceDateTime(bool value) async {
    await _printerService.setShowInvoiceDate(value);
    await _printerService.setShowInvoiceTime(value);
  }

  Widget _buildToggleGroup(BuildContext context, String title,
      List<_PrintToggle> toggles, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, title),
        const SizedBox(height: 12),
        ...toggles.map((t) => _buildToggleCard(context, t, isTablet)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildToggleCard(
      BuildContext context, _PrintToggle toggle, bool isTablet) {
    // "Powered By" is forced ON while the admin keeps `billing.invoice.print`;
    // when that flag is off the user controls it. `shown` drives the visuals,
    // `locked` disables input. Same rule as restaurant.
    final bool locked = toggle.label == 'Powered By' &&
        PlanEnforce.allows(ModeKeys.billingInvoicePrint);
    final bool shown = locked ? true : toggle.value;

    Future<void> setValue(bool value) async {
      await toggle.onChanged(value);
      await _loadSettings();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shown
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.divider,
          width: shown ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (locked) {
              NotificationService.instance.showInfo(
                  'Upgrade to Premium to remove the "Powered by Bill Berry Lite" footer.');
              return;
            }
            setValue(!toggle.value);
          },
          child: Padding(
            padding: AppResponsive.cardPadding(context),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: shown
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceMedium,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    toggle.icon,
                    color:
                        shown ? AppColors.primary : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              toggle.label,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: shown
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (locked) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.lock_rounded,
                                size: 14, color: AppColors.textSecondary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        locked
                            ? 'Required by your plan — cannot be turned off'
                            : toggle.description,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: shown,
                    onChanged: locked ? null : setValue,
                    activeThumbColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Accent bar + title, the same section header restaurant uses.
  Widget _sectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.subheadingFontSize(context),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );

  Widget _buildTemplateSection(BuildContext context, bool isTablet) {
    final current = _settings.billTemplate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Bill Receipt Template'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _templateCard(
                context,
                title: 'Simple Invoice',
                subtitle: 'Clean, professional & structured layout',
                icon: Icons.receipt_long_outlined,
                isSelected: current == BillTemplate.simple,
                onTap: () => _setTemplate(BillTemplate.simple),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _templateCard(
                context,
                title: 'Paper Saver',
                subtitle: 'Compact layout to save roll paper',
                icon: Icons.compress_outlined,
                isSelected: current == BillTemplate.paperSaver,
                onTap: () => _setTemplate(BillTemplate.paperSaver),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setTemplate(BillTemplate template) async {
    await _printerService.setBillTemplate(template);
    await _loadSettings();
  }

  Widget _templateCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        height: 110,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The logo image itself. Its on/off toggle lives in the Store Information
  /// group below, matching restaurant.
  Widget _buildLogoCard(BuildContext context, bool isTablet) {
    final hasLogo =
        _settings.logoPath != null && File(_settings.logoPath!).existsSync();

    return _card(
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasLogo
                      ? Image.file(File(_settings.logoPath!),
                          fit: BoxFit.contain)
                      : const Icon(Icons.storefront_outlined,
                          color: AppColors.textSecondary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickLogoImage,
                          icon: const Icon(Icons.upload_outlined, size: 18),
                          label: Text(
                            hasLogo ? 'Change' : 'Add Logo',
                            style: GoogleFonts.poppins(
                              fontSize: AppResponsive.smallFontSize(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (hasLogo) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _removeLogoImage,
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: AppColors.danger,
                          tooltip: 'Remove logo',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!_settings.showLogo && hasLogo) ...[
              const SizedBox(height: 10),
              Text(
                'Logo printing is turned off below — this image will not appear '
                'on receipts.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required TextEditingController controller,
    required String hint,
    required Future<void> Function(String) onChanged,
    int maxLines = 2,
  }) {
    return _card(
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeading(context, icon, title, description),
            const SizedBox(height: 14),
            AppTextField(
              controller: controller,
              hint: hint,
              icon: Icons.edit_note_rounded,
              maxLines: maxLines,
              minLines: 1,
              maxLength: 200,
              onChanged: (v) => onChanged(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardHeading(
      BuildContext context, IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.captionFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickLogoImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        
        // Validate image size (max 2MB)
        if (bytes.length > 2 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image is too large. Please select an image under 2MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        // Get app's documents directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String logoDir = '${appDir.path}/logos';

        // Create logos directory if it doesn't exist
        final Directory logosDirectory = Directory(logoDir);
        if (!await logosDirectory.exists()) {
          await logosDirectory.create(recursive: true);
        }

        // Delete old logo file if exists
        if (_settings.logoPath != null) {
          try {
            final File oldFile = File(_settings.logoPath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (e) {
            // Ignore error if old file can't be deleted
            debugPrint('Error deleting old logo: $e');
          }
        }

        // Copy new image to permanent location
        final String fileName = 'store_logo${path.extension(image.path)}';
        final String newPath = '$logoDir/$fileName';
        final File newFile = await File(image.path).copy(newPath);

        // Save new logo path
        await _printerService.setLogoPath(newFile.path);
        _loadSettings();

        if (mounted) {
          NotificationService.instance.showSuccess('Logo updated successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error selecting image: $e');
      }
    }
  }

  Future<void> _removeLogoImage() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove Logo?',
      message: 'The logo will no longer print on receipts. '
          'You can add it again anytime.',
      confirmLabel: 'Remove',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed) {
      // Delete the logo file if it exists
      if (_settings.logoPath != null) {
        try {
          final File logoFile = File(_settings.logoPath!);
          if (await logoFile.exists()) {
            await logoFile.delete();
          }
        } catch (e) {
          debugPrint('Error deleting logo file: \$e');
        }
      }

      await _printerService.setLogoPath(null);
      _loadSettings();
      if (mounted) {
        NotificationService.instance.showSuccess('Logo removed');
      }
    }
  }

  // ==================== ACTIONS ====================

  Future<void> _resetToDefaults() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Reset Settings?',
      message: 'This will restore every print setting to its default value, '
          'including paper size and template.',
      confirmLabel: 'Reset',
      accent: AppColors.danger,
      icon: Icons.refresh_rounded,
    );

    if (confirmed) {
      await _printerService.resetToDefaults();
      _loadSettings();
      if (mounted) {
        NotificationService.instance.showSuccess('Settings reset to defaults');
      }
    }
  }
}

class _PrintToggle {
  final String label;
  final IconData icon;
  final String description;
  final bool value;
  final Future<void> Function(bool) onChanged;

  const _PrintToggle(
      this.label, this.icon, this.description, this.value, this.onChanged);
}
