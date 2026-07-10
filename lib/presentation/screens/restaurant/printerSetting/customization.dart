import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/plan/plan_gate.dart';
import 'package:billberrylite/domain/services/retail/store_settings_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/restaurant/print_settings.dart';
import '../../../../util/common/app_responsive.dart';

class CustomizationPrinter extends StatefulWidget {
  const CustomizationPrinter({super.key});

  @override
  State<CustomizationPrinter> createState() => _CustomizationPrinterState();
}

class _CustomizationPrinterState extends State<CustomizationPrinter> {
  final _footerController = TextEditingController();
  final _storeSettings = StoreSettingsService();

  Uint8List? _logoBytes;
  bool _isLogoBusy = false;

  @override
  void initState() {
    super.initState();
    // Load print settings when screen opens, then seed the footer field.
    PrintSettings.load().then((_) {
      if (mounted) {
        setState(() => _footerController.text = PrintSettings.footerMessage);
      }
    });
    _loadLogo();
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    final bytes = await _storeSettings.getStoreLogo();
    if (mounted) setState(() => _logoBytes = bytes);
  }

  Future<void> _pickLogo() async {
    setState(() => _isLogoBusy = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        NotificationService.instance.showError('Logo must be under 2 MB');
        return;
      }

      final saved = await _storeSettings.setStoreLogo(bytes);
      if (!saved) {
        NotificationService.instance.showError('Could not save logo. Please try again.');
        return;
      }
      if (mounted) setState(() => _logoBytes = bytes);
      NotificationService.instance.showSuccess('Logo updated');
    } catch (e) {
      debugPrint('Error picking logo: $e');
      NotificationService.instance.showError('Could not open the gallery.');
    } finally {
      if (mounted) setState(() => _isLogoBusy = false);
    }
  }

  Future<void> _removeLogo() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove Logo?',
      message: 'The logo will no longer print on receipts. You can add it again anytime.',
      confirmLabel: 'Remove',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed != true) return;

    setState(() => _isLogoBusy = true);
    final removed = await _storeSettings.deleteStoreLogo();
    if (!mounted) return;
    setState(() {
      _isLogoBusy = false;
      if (removed) _logoBytes = null;
    });

    if (removed) {
      NotificationService.instance.showSuccess('Logo removed');
    } else {
      NotificationService.instance.showError('Could not remove logo. Please try again.');
    }
  }

  // Group settings by category
  final Map<String, List<Map<String, dynamic>>> _settingGroups = {
    'Store Information': [
      {'key': 'Restaurant Logo', 'icon': Icons.image_outlined, 'description': 'Show store logo at the top of receipts'},
      {'key': 'Restaurant Name', 'icon': Icons.restaurant, 'description': 'Show restaurant name on receipts'},
      {'key': 'Restaurant Address', 'icon': Icons.location_on, 'description': 'Show restaurant address'},
      {'key': 'Restaurant Mobile No', 'icon': Icons.phone, 'description': 'Show contact number'},
    ],
    'Order Details': [
      {'key': 'Order ID', 'icon': Icons.numbers, 'description': 'Show order/bill number'},
      {'key': 'Ordered Time', 'icon': Icons.access_time, 'description': 'Show order date and time'},
      {'key': 'Order Type', 'icon': Icons.shopping_bag, 'description': 'Show order type (Dine-in/Takeaway)'},
      {'key': 'Customer Name', 'icon': Icons.person, 'description': 'Show customer name if available'},
    ],
    'Payment & Pricing': [
      {'key': 'Payment Type', 'icon': Icons.payment, 'description': 'Show payment method (Cash/Card/UPI)'},
      {'key': 'Tax', 'icon': Icons.percent, 'description': 'Show GST/tax breakdown'},
      {'key': 'Subtotal', 'icon': Icons.calculate, 'description': 'Show subtotal before tax'},
      {'key': 'Payment Paid', 'icon': Icons.money, 'description': 'Show cash received and change'},
      {'key': 'UPI QR', 'icon': Icons.qr_code_2, 'description': 'Show UPI Scan & Pay QR on unpaid bills'},
    ],
    // "Powered by Bill Berry Lite" is no longer a shop toggle — it is controlled
    // by the admin via the `billing.invoice.print` license entitlement.
  };

  Future<void> _resetSettings() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Reset Settings?',
      message:
          'This will restore all print settings to their default values. Are you sure?',
      confirmLabel: 'Reset',
      accent: AppColors.danger,
      icon: Icons.refresh_rounded,
    );

    if (confirmed == true) {
      await PrintSettings.resetToDefaults();
      setState(() => _footerController.text = PrintSettings.footerMessage);
      NotificationService.instance.showSuccess('Settings reset to defaults');
    }
  }

  /// Store logo shown at the top of receipts. Saved to `BusinessDetails` in Hive,
  /// which is what the receipt builders read at print time.
  Widget _buildLogoCard(BuildContext context, bool isTablet) {
    final hasLogo = _logoBytes != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.image_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Logo',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'The image printed at the top of every bill',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                child: _isLogoBusy
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : hasLogo
                        ? Image.memory(_logoBytes!, fit: BoxFit.contain)
                        : Icon(Icons.storefront_outlined,
                            color: AppColors.textSecondary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLogoBusy ? null : _pickLogo,
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        label: Text(
                          hasLogo ? 'Change' : 'Add Logo',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (hasLogo) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _isLogoBusy ? null : _removeLogo,
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
          if (!PrintSettings.showRestaurantLogo && hasLogo) ...[
            const SizedBox(height: 10),
            Text(
              'Logo printing is turned off below — this image will not appear on receipts.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  /// Editable footer / "Thank You" message that prints at the bottom of bills.
  Widget _buildFooterMessageCard(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Footer Message',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'The "Thank You" note printed at the bottom of every bill',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _footerController,
            hint: 'e.g. Thank you! Visit us again!',
            icon: Icons.edit_note_rounded,
            maxLines: 2,
            minLines: 1,
            maxLength: 120,
            onChanged: (v) => PrintSettings.setFooterMessage(v),
          ),
        ],
      ),
    );
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
              'Print Customization',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: AppResponsive.headingFontSize(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Configure receipt fields',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.9),
                fontSize: AppResponsive.smallFontSize(context),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reset to Defaults',
            onPressed: _resetSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder<Map<String, bool>>(
        valueListenable: PrintSettings.settingsNotifier,
        builder: (context, settings, child) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 700 : double.infinity),
              child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
              /*  Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTablet ? 16 : 14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.info, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customize Your Receipts',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Toggle options to show or hide information on printed bills and KOTs',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),*/

                // Store logo (image itself — the on/off toggle is below)
                _buildLogoCard(context, isTablet),

                SizedBox(height: 16),

                // Dynamic footer / "Thank You" message
                _buildFooterMessageCard(context, isTablet),

                SizedBox(height: 24),

                // Settings Groups
                ..._settingGroups.entries.map((group) {
                  return _buildSettingGroup(
                    context,
                    group.key,
                    group.value,
                    settings,
                    isTablet,
                  );
                }),

                // Footer
                SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done, color: AppColors.success, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Settings auto-save',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingGroup(
    BuildContext context,
    String groupTitle,
    List<Map<String, dynamic>> groupSettings,
    Map<String, bool> currentSettings,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 10),
              Text(
                groupTitle,
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 17 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        // Settings Cards
        ...groupSettings.map((setting) {
          final key = setting['key'] as String;
          final icon = setting['icon'] as IconData;
          final description = setting['description'] as String;
          final isEnabled = currentSettings[key] ?? false;
          // Watermark is forced ON unless the plan is entitled to remove it
          // (`removeWatermark` → PlanGate.showWatermark). `shown` drives the
          // visuals; `locked` disables input.
          final bool locked = key == 'Powered By' && PlanGate.showWatermark;
          final bool shown = locked ? true : isEnabled;

          return Container(
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: shown ? AppColors.primary.withOpacity(0.3) : AppColors.divider,
                width: shown ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: shown
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: shown ? 8 : 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (locked) {
                    NotificationService.instance.showInfo(
                        'Upgrade to Premium to remove the "Powered by Bill Berry Lite" footer.');
                    return;
                  }
                  await PrintSettings.updateSetting(key, !isEnabled);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 16 : 14),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: shown
                              ? AppColors.primary.withOpacity(0.1)
                              : AppColors.surfaceMedium,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: shown ? AppColors.primary : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14),

                      // Title and Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    key,
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 15 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: shown ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (locked) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.lock_rounded,
                                      size: 14, color: AppColors.textSecondary),
                                ],
                              ],
                            ),
                            SizedBox(height: 3),
                            Text(
                              locked
                                  ? 'Included on the Free plan — upgrade to Premium to hide'
                                  : description,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Toggle Switch (disabled when locked)
                      Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: shown,
                          onChanged: locked
                              ? null
                              : (value) async {
                                  await PrintSettings.updateSetting(key, value);
                                },
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        SizedBox(height: 20),
      ],
    );
  }
}
