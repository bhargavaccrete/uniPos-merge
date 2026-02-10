import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/domain/services/restaurant/auto_backup_service.dart';
import 'package:unipos/domain/services/common/unified_backup_service.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/images.dart';
import 'package:unipos/main.dart' as main_app;

class Drawerr extends StatefulWidget {
  const Drawerr({super.key});

  @override
  State<Drawerr> createState() => _DrawerrState();
}

class _DrawerrState extends State<Drawerr> {
  bool _printerExpanded = false;

  Future<void> clearCart() async {
    try {
      await cartStore.clearCart();
      if (mounted) {
        NotificationService.instance.showSuccess('Cart cleared successfully');
      }
    } catch (e) {
      print('Error clearing cart: $e');
      if (mounted) {
        NotificationService.instance.showError('Error clearing cart');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: isTablet ? 32 : 28,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'UniPOS',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 24 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'POS System',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 12,
                  horizontal: isTablet ? 12 : 8,
                ),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.home_rounded,
                    title: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantAdminWelcome);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.cleaning_services_rounded,
                    title: 'Clear Cart',
                    onTap: () {
                      Navigator.pop(context);
                      _showClearCartDialog(context);
                    },
                    isTablet: isTablet,
                  ),

                  // Printer Settings Expandable
                  _buildExpandableSection(
                    context: context,
                    icon: Icons.print_rounded,
                    title: 'Printer Settings',
                    isExpanded: _printerExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _printerExpanded = expanded;
                      });
                    },
                    children: [
                      _buildSubItem(
                        context: context,
                        icon: Icons.add_circle_outline,
                        title: 'Add Printer',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, RouteNames.restaurantPrinterSettings);
                        },
                        isTablet: isTablet,
                      ),
                      _buildSubItem(
                        context: context,
                        icon: Icons.settings_outlined,
                        title: 'Cash Drawer Setting',
                        onTap: () {},
                        isTablet: isTablet,
                      ),
                      _buildSubItem(
                        context: context,
                        icon: Icons.tune_rounded,
                        title: 'Customize Printer',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, RouteNames.restaurantPrinterCustomization);
                        },
                        isTablet: isTablet,
                      ),
                    ],
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Customization',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantCustomizationDrawer);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantReports);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Expenses',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantExpenses);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.sync_rounded,
                    title: 'Sync Data',
                    onTap: () {
                      Navigator.pop(context);
                      _showSyncDialog(context);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.sync_alt_rounded,
                    title: 'Sync Order',
                    onTap: () {},
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.sunny_snowing,
                    title: 'End Day',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantEndDay);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.import_export_rounded,
                    title: 'Import/Export',
                    onTap: () {
                      Navigator.pop(context);
                      _showImportExportDialog(context);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.data_object_rounded,
                    title: 'Test Data Generator',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantTestData);
                    },
                    isTablet: isTablet,
                    color: Colors.orange,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    title: 'Need Help?',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteNames.restaurantNeedHelp);
                    },
                    isTablet: isTablet,
                  ),

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.language_rounded,
                    title: 'Language',
                    onTap: () {},
                    isTablet: isTablet,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.primary;
    final bgColor = itemColor.withValues(alpha: 0.1);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 14 : 12,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: isTablet ? 22 : 20,
                    color: itemColor,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isExpanded,
    required Function(bool) onExpansionChanged,
    required List<Widget> children,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isExpanded ? Colors.grey.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isExpanded,
            onExpansionChanged: onExpansionChanged,
            tilePadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 6 : 4,
            ),
            childrenPadding: EdgeInsets.only(left: isTablet ? 24 : 20),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: isTablet ? 22 : 20,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildSubItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 10,
              vertical: isTablet ? 10 : 8,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: isTablet ? 18 : 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: isTablet ? 12 : 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Clear Cart?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to clear the cart?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  "No",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await clearCart();
                  Navigator.pushNamed(context, RouteNames.restaurantStartOrder);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Yes",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    Timer(
      Duration(seconds: 5),
      () {
        Navigator.of(context, rootNavigator: true).pop();
      },
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Container(
            padding: EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  AppImages.syncanimation,
                  width: 200,
                  height: 150,
                ),
                SizedBox(height: 25),
                Text(
                  'Sync in Progress...',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please wait while we update your data...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImportExportDialog(BuildContext context) async {
    bool initialEnabled = await AutoBackupService.isAutoBackupEnabled();
    String? initialBackup = await AutoBackupService.getLastBackupDate();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Center(
                child: Text(
                  'Backup & Restore',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Auto Backup Toggle
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: initialEnabled
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: initialEnabled
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                initialEnabled
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: initialEnabled
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Daily Auto Backup',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Switch(
                                value: initialEnabled,
                                onChanged: (value) async {
                                  setState(() {
                                    initialEnabled = value;
                                  });
                                  await AutoBackupService.setAutoBackupEnabled(value);
                                  if (context.mounted) {
                                    if (value) {
                                      NotificationService.instance.showSuccess('Auto backup enabled!');
                                    } else {
                                      NotificationService.instance.showSuccess('Auto backup disabled');
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          if (initialBackup != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Last backup: $initialBackup',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),

                    // Download to Downloads Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.download, color: Colors.white),
                      label: Text(
                        'Download Backup',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        final outerContext = context;
                        Navigator.pop(outerContext);

                        final navigatorState =
                            Navigator.of(outerContext, rootNavigator: true);
                        showDialog(
                          context: outerContext,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return WillPopScope(
                              onWillPop: () async => false,
                              child: AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 20),
                                    Text(
                                      'Creating backup...\nPlease wait',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        String? filePath;
                        try {
                          filePath =
                              await UnifiedBackupService.exportToDownloads();
                        } catch (e) {
                          debugPrint('❌ Backup error: $e');
                        } finally {
                          try {
                            navigatorState.pop();
                          } catch (e) {
                            debugPrint('❌ Error closing dialog: $e');
                          }
                        }

                        await Future.delayed(Duration(milliseconds: 300));

                        if (filePath == null) {
                          if (outerContext.mounted) {
                            NotificationService.instance.showError('Backup failed');
                          }
                          return;
                        }

                        if (outerContext.mounted) {
                          NotificationService.instance.showSuccess('Backup saved successfully! Location: Downloads folder');
                        }
                      },
                    ),

                    SizedBox(height: 12),

                    // Choose Folder Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.folder_open, color: Colors.white),
                      label: Text(
                        'Choose Folder',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);

                        String? selectedDirectory;
                        try {
                          selectedDirectory =
                              await FilePicker.platform.getDirectoryPath();
                        } catch (e) {
                          debugPrint('❌ Folder picker error: $e');
                          final globalContext =
                              main_app.navigatorKey.currentContext;
                          if (globalContext != null && globalContext.mounted) {
                            NotificationService.instance.showError('Error selecting folder: $e');
                          }
                          return;
                        }

                        if (selectedDirectory == null) {
                          final globalContext =
                              main_app.navigatorKey.currentContext;
                          if (globalContext != null && globalContext.mounted) {
                            NotificationService.instance.showSuccess('Folder selection cancelled');
                          }
                          return;
                        }

                        final globalContext = main_app.navigatorKey.currentContext;
                        if (globalContext == null) return;

                        final navigatorState =
                            Navigator.of(globalContext, rootNavigator: true);
                        showDialog(
                          context: globalContext,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return WillPopScope(
                              onWillPop: () async => false,
                              child: AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 20),
                                    Text(
                                      'Creating backup...\nPlease wait',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        String? filePath;
                        try {
                          filePath = await UnifiedBackupService
                              .exportToCustomFolder(selectedDirectory);
                        } catch (e) {
                          debugPrint('❌ Backup error: $e');
                        } finally {
                          try {
                            navigatorState.pop();
                          } catch (e) {
                            debugPrint('❌ Error closing dialog: $e');
                          }
                        }

                        await Future.delayed(Duration(milliseconds: 300));

                        final finalContext = main_app.navigatorKey.currentContext;
                        if (finalContext == null) return;

                        if (filePath == null) {
                          NotificationService.instance.showError('Backup creation failed');
                          return;
                        }

                        NotificationService.instance.showSuccess('Backup saved successfully! Location: $selectedDirectory');
                      },
                    ),

                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),

                    // Import Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.restore, color: Colors.white),
                      label: Text(
                        'Import Backup',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);

                        final navigatorState =
                            Navigator.of(context, rootNavigator: true);

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext dialogContext) {
                            return WillPopScope(
                              onWillPop: () async => false,
                              child: AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Importing backup...\nPlease wait',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        bool importSuccess = false;
                        try {
                          importSuccess =
                              await UnifiedBackupService.importData(context);
                        } catch (e) {
                          debugPrint('Import error in drawer: $e');
                        } finally {
                          if (navigatorState.mounted) {
                            navigatorState.pop();
                          }

                          if (importSuccess) {
                            await Future.delayed(Duration(milliseconds: 300));

                            final globalContext =
                                main_app.navigatorKey.currentContext;
                            if (globalContext != null) {
                              showDialog(
                                context: globalContext,
                                barrierDismissible: false,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    title: Text(
                                      'Import Completed',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    content: Text(
                                      'Data imported successfully!\n\nPlease close and restart the app.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          exit(0);
                                        },
                                        child: Text(
                                          'Close App',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
