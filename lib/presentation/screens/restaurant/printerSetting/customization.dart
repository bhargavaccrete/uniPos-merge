import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/restaurant/print_settings.dart';

class CustomizationPrinter extends StatefulWidget {
  const CustomizationPrinter({super.key});

  @override
  State<CustomizationPrinter> createState() => _CustomizationPrinterState();
}

class _CustomizationPrinterState extends State<CustomizationPrinter> {
  @override
  void initState() {
    super.initState();
    // Load print settings when screen opens
    PrintSettings.load();
  }

  // Group settings by category
  final Map<String, List<Map<String, dynamic>>> _settingGroups = {
    'Store Information': [
      {'key': 'Restaurant Name', 'icon': Icons.restaurant, 'description': 'Show restaurant name on receipts'},
      {'key': 'Restaurant Address', 'icon': Icons.location_on, 'description': 'Show restaurant address'},
      {'key': 'Restaurant Mobile No', 'icon': Icons.phone, 'description': 'Show contact number'},
      {'key': 'Website Name', 'icon': Icons.language, 'description': 'Show website URL'},
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
    ],
    'Additional Options': [
      {'key': 'Powered By', 'icon': Icons.info_outline, 'description': 'Show "Powered by UniPOS" footer'},
      {'key': 'Custom Field', 'icon': Icons.edit_note, 'description': 'Show custom field if configured'},
      {'key': 'Extra Info', 'icon': Icons.add_circle_outline, 'description': 'Show additional information'},
    ],
  };

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.refresh, color: Colors.orange.shade700),
            ),
            SizedBox(width: 12),
            Text(
              'Reset Settings?',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'This will restore all print settings to their default values. Are you sure?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Reset', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PrintSettings.resetToDefaults();
      setState(() {});
      NotificationService.instance.showSuccess('Settings reset to defaults');
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;
    final deepBlue = Color(0xFF0D47A1);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 8,
        shadowColor: deepBlue.withOpacity(0.5),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [deepBlue, Color(0xFF1565C0), deepBlue.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.print_outlined, color: deepBlue, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Print Customization',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Configure receipt fields',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.refresh, color: Colors.white, size: 22),
              ),
              tooltip: 'Reset to Defaults',
              onPressed: _resetSettings,
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<Map<String, bool>>(
        valueListenable: PrintSettings.settingsNotifier,
        builder: (context, settings, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  width: width,
                  padding: EdgeInsets.all(isTablet ? 16 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
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
                                color: Colors.blue.shade900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Toggle options to show or hide information on printed bills and KOTs',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done, color: Colors.green.shade600, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Settings auto-save',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
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
                  color: Colors.grey.shade800,
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

          return Container(
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEnabled ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200,
                width: isEnabled ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isEnabled
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: isEnabled ? 8 : 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
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
                          color: isEnabled
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: isEnabled ? AppColors.primary : Colors.grey.shade500,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14),

                      // Title and Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 15 : 14,
                                fontWeight: FontWeight.w600,
                                color: isEnabled ? Colors.grey.shade900 : Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              description,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Toggle Switch
                      Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: isEnabled,
                          onChanged: (value) async {
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
