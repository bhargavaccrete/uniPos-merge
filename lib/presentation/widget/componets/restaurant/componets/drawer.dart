import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Textform.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/domain/services/common/unified_backup_service.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/main.dart' as main_app;

import '../../../../../util/images.dart';

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
  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: AppResponsive.padding(context),
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
                      size: AppResponsive.getValue(context, mobile: 28, tablet: 32),
                    ),
                  ),
                  AppResponsive.verticalSpace(context, size: SpacingSize.medium),
                  Text(
                    'UniPOS',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 22, tablet: 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'POS System',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 13, tablet: 14),
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
                  vertical: AppResponsive.getValue(context, mobile: 12, tablet: 16),
                  horizontal: AppResponsive.getValue(context, mobile: 8, tablet: 12),
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
              padding: AppResponsive.padding(context),
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
                    size: AppResponsive.smallIconSize(context),
                    color: Colors.grey.shade600,
                  ),
                  AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                  Expanded(
                    child: Text(
                      'Version 1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.captionFontSize(context),
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
              horizontal: AppResponsive.getValue(context, mobile: 12, tablet: 16),
              vertical: AppResponsive.getValue(context, mobile: 12, tablet: 14),
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
                    size: AppResponsive.getValue(context, mobile: 20, tablet: 22),
                    color: itemColor,
                  ),
                ),
                AppResponsive.horizontalSpace(context, size: SpacingSize.medium),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 14, tablet: 15),
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
              horizontal: AppResponsive.getValue(context, mobile: 12, tablet: 16),
              vertical: AppResponsive.getValue(context, mobile: 4, tablet: 6),
            ),
            childrenPadding: EdgeInsets.only(
              left: AppResponsive.getValue(context, mobile: 20, tablet: 24),
            ),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: AppResponsive.getValue(context, mobile: 20, tablet: 22),
                color: AppColors.primary,
              ),
            ),
            title: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.getValue(context, mobile: 14, tablet: 15),
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
              horizontal: AppResponsive.getValue(context, mobile: 10, tablet: 12),
              vertical: AppResponsive.getValue(context, mobile: 8, tablet: 10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppResponsive.getValue(context, mobile: 16, tablet: 18),
                  color: AppColors.primary,
                ),
                AppResponsive.horizontalSpace(context, size: SpacingSize.small),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.getValue(context, mobile: 13, tablet: 14),
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
              child: Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: AppResponsive.getValue(context, mobile: 24, tablet: 28),
              ),
            ),
            AppResponsive.horizontalSpace(context, size: SpacingSize.small),
            Expanded(
              child: Text(
                'Clear Cart?',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.getValue(context, mobile: 18, tablet: 20),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to clear the cart?',
          style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                  padding: AppResponsive.horizontalPadding(context),
                ),
                child: Text(
                  "No",
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.buttonFontSize(context),
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AppResponsive.horizontalSpace(context, size: SpacingSize.small),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await clearCart();
                  Navigator.pushNamed(context, RouteNames.restaurantStartOrder);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: AppResponsive.horizontalPadding(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Yes",
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.buttonFontSize(context),
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
                  width: AppResponsive.getValue(context, mobile: 180, tablet: 220),
                  height: AppResponsive.getValue(context, mobile: 130, tablet: 160),
                ),
                AppResponsive.verticalSpace(context, size: SpacingSize.large),
                Text(
                  'Sync in Progress...',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: AppResponsive.getValue(context, mobile: 18, tablet: 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppResponsive.verticalSpace(context, size: SpacingSize.small),
                Text(
                  'Please wait while we update your data...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImportExportDialog(BuildContext context) {
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
                    fontSize: AppResponsive.getValue(context, mobile: 18, tablet: 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download to Downloads Button

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: Size(double.infinity, AppResponsive.buttonHeight(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.download, color: Colors.white),
                      label: Text(
                        'Download Backup',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: AppResponsive.buttonFontSize(context),
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
                                    AppResponsive.verticalSpace(context, size: SpacingSize.medium),
                                    Text(
                                      'Creating backup...\nPlease wait',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
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

                    AppResponsive.verticalSpace(context, size: SpacingSize.medium),

                    // Share Backup Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: Size(double.infinity, AppResponsive.buttonHeight(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.share, color: Colors.white),
                      label: Text(
                        'Share Backup',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: AppResponsive.buttonFontSize(context),
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
                          builder: (BuildContext ctx) {
                            return PopScope(
                              canPop: false,
                              child: AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    AppResponsive.verticalSpace(ctx, size: SpacingSize.medium),
                                    Text(
                                      'Creating backup...\nPlease wait',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(ctx)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        String? filePath;
                        try {
                          filePath = await UnifiedBackupService.exportToShare();
                        } catch (e) {
                          debugPrint('❌ Share backup error: $e');
                        } finally {
                          try {
                            navigatorState.pop();
                          } catch (e) {
                            debugPrint('❌ Error closing dialog: $e');
                          }
                        }

                        await Future.delayed(const Duration(milliseconds: 300));

                        if (filePath == null) {
                          final globalContext = main_app.navigatorKey.currentContext;
                          if (globalContext != null && globalContext.mounted) {
                            NotificationService.instance.showError('Backup creation failed');
                          }
                          return;
                        }

                        await Share.shareXFiles(
                          [XFile(filePath)],
                          subject: 'UniPOS Backup',
                        );
                      },
                    ),

                    AppResponsive.verticalSpace(context, size: SpacingSize.medium),
                    Divider(),
                    AppResponsive.verticalSpace(context, size: SpacingSize.small),

                    // Import Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: Size(double.infinity, AppResponsive.buttonHeight(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.restore, color: Colors.white),
                      label: Text(
                        'Import Backup',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: AppResponsive.buttonFontSize(context),
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
                                    AppResponsive.verticalSpace(context, size: SpacingSize.medium),
                                    Text(
                                      'Importing backup...\nPlease wait',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(fontSize: AppResponsive.bodyFontSize(context)),
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
