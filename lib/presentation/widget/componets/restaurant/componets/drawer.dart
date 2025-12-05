import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/auto_backup_service.dart';

import 'package:unipos/presentation/screens/restaurant/Expense/Expense.dart';
import 'package:unipos/presentation/screens/restaurant/customiztion/customization_drawer.dart';
import 'package:unipos/presentation/screens/restaurant/end%20day/endday.dart';
import 'package:unipos/presentation/screens/restaurant/need%20help/needhelp.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/customization.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/printersetting.dart';
import 'package:unipos/presentation/screens/restaurant/start%20order/startorder.dart';
import 'package:unipos/presentation/screens/restaurant/welcome_Admin.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/Button.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/import/import.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/import/test_data_screen.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/listmenu.dart';
import 'package:unipos/util/restaurant/images.dart';
import 'package:unipos/main.dart' as main_app;

import '../../../../screens/retail/reports_screen.dart';


class Drawerr extends StatefulWidget {
  const Drawerr({super.key});

  @override
  State<Drawerr> createState() => _DrawerrState();
}

class _DrawerrState extends State<Drawerr> {
  Future<void> clearCart() async {
    try {
      await cartStore.clearCart();
      // await loadCartItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cart cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error clearing cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cart'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool _printerExpanded = false;
    bool isChecked = true;
    final height = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;

    return Drawer(
      // backgroundColor: ,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 10),
        child: SingleChildScrollView(
          child: Container(
            // color: Colors.green,
            width: width,
            child: Column(
              children: [
                Listmenu(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => AdminWelcome()));
                  },
                  title: 'Home',
                  icons: Icons.home,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,

                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),
                //clear caart
                Listmenu(
                  onTap: (){
                    Navigator.pop(context);
                    showDialog(context: context,
                        builder: (BuildContext context){
                      return AlertDialog(

                        title: Text('Are you sure you want to \n clear cart?',
                          textScaler: TextScaler.linear(1),

                          style: GoogleFonts.poppins(fontSize: 14),textAlign: TextAlign.center,),
                        // content: Text('AleartDialog Description'),
                        actions: [
                          CommonButton(
                            borderwidth: 0,
                            bordercolor: Colors.red,
                            bgcolor: Colors.red,
                            bordercircular: 0,
                            width: width * 0.3,
                              height: height * 0.04,
                              onTap: (){
                              Navigator.pop(context);
                              }, child: Text('No',
                            textScaler: TextScaler.linear(1),

                            style: GoogleFonts.poppins(color: Colors.white),)),
                          CommonButton(
                            bordercircular: 0,
                            width: width * 0.3,
                              height: height * 0.04,
                              onTap: ()async{
                              await clearCart();
                                Navigator.push(context, MaterialPageRoute(builder: (context)=> Startorder()));

                                // Navigator.pop(context);
                              }, child: Text('Yes',
                            textScaler: TextScaler.linear(1),

                            style: GoogleFonts.poppins(color: Colors.white),))
                        ],
                      );
                        },);
                  },
                  title: 'Clear Cart',
                  icons: Icons.cleaning_services_outlined,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,

                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),

                // Printer Setting
                Container(
                  // height: height *0.05,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _printerExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _printerExpanded = expanded;
                        });
                      },
                      leading: Icon(Icons.print, color: primarycolor),
                      title: Text(
                        "Printer Setting",
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                      backgroundColor: Colors.grey.shade300,
                      childrenPadding: EdgeInsets.all(10),
                      children: [
                        Column(
                          children: [
                            Container(
                              // padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
                              width: width ,
                              height: height * 0.08,
                              color: Colors.grey.shade300,
                              child: Listmenu(
                                title: 'Add Printer',
                                icons: Icons.circle,
                                color: primarycolor,
                                listcolor: Colors.grey.shade300,
                                // heightCon: 50,
                                borderwidth: 1,
                                colorb: primarycolor,
                                borderradius: 5,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=> Printersetting()));
                                  // Handle tap
                                },
                              ),
                            ),
                            SizedBox(height: 10,),
                            // Cash drawer
                            Container(
                              // padding: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
                              width: width ,
                              height: height * 0.08,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                             border: Border.all(color: primarycolor)
                              ),
                              // width: width * 0.7,
                              child: Listmenu(
                                iconsT: Checkbox(value: isChecked,
                                    onChanged: (bool?newvalue){
                                  setState(() {
                                    isChecked =newvalue!;
                                  });
                                }),
                                title: 'Cash Drawer Setting ',
                                icons: Icons.settings,
                                listcolor: Colors.grey.shade300,
                                heightCon: 45,
                                borderwidth: 0,
                                colorb: Colors.transparent,
                                borderradius: 0,
                                onTap: () {
                                  // Handle tap
                                },
                              ),
                            ),
                            SizedBox(height: 10,),

                            // Customization
                            Container(
                              // padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
                              // width: width * 0.8,
                              height: height * 0.08,
                              color: Colors.grey.shade300,
                              child: Listmenu(

                                title: 'Customize Your Printer',
                                icons: Icons.tune,
                                listcolor: Colors.grey.shade300,
                                heightCon: 50,
                                borderwidth: 1,
                                colorb: primarycolor,
                                borderradius: 5,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context)=> CustomizationPrinter()));
                                  // Handle tap
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                  height: 10,
                ),
                Listmenu(
                  onTap: (){
                    // Navigator.pop(context);
                    // showDialog(
                    //
                    //   context: context,
                    //   builder: (BuildContext context){
                    //     return CustomizationDrawer();
                    //   },);

                    Navigator.push(context,MaterialPageRoute(builder: (context)=>CustomizationDrawer() ));

                  },
                  title: 'Customization',
                  icons: Icons.dashboard_customize,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),
                Listmenu(
                  onTap: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=> ReportsScreen()));
                  },
                  title: 'Reports',
                  icons: Icons.auto_graph,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),
                Listmenu(
                  onTap: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=> ExpenseScreen()));
                  },
                  title: 'Expenses',
                  icons: Icons.wallet,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),

                    Listmenu(
            onTap: () {
              // Close the drawer/page first
              Navigator.pop(context);

              // Then show dialog after popping
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  // Start 5-second timer to close the dialog
                  Timer(
                    Duration(seconds: 5),
                        () {
                      Navigator.of(dialogContext, rootNavigator: true).pop(); // closes the dialog
                    },
                  );

                  return AlertDialog(
                    actions: [
                      Container(
                        padding: EdgeInsets.all(10),
                        width: width,
                        height: height * 0.4,
                        child: Column(
                          children: [
                            Lottie.asset(
                              syncanimation,
                              width: width * 0.5,
                              height: height * 0.2 ,
                            ),
                            SizedBox(height: 25),
                            Text(
                              'Sync in Progress...',
                              style: GoogleFonts.poppins(color: primarycolor),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Please wait while we update your data...',
                              textScaler: TextScaler.linear(1),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(),
                            )
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            title: 'Sync Data',
            icons: Icons.sync,
            listcolor: Colors.grey.shade300,
            heightCon: height * 0.07,
            borderwidth: 0,
            colorb: Colors.transparent,
            borderradius: 2,
                    ),
                SizedBox(
                  height: 10,
                ),
                Listmenu(

                  title: 'Sync Order',
                  icons: Icons.sync,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),
                Listmenu(
                  onTap: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=>
                        EndDayDrawer()
                    ));
                  },
                  title: 'End Day',
                  icons: Icons.sunny_snowing,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),

                Listmenu(
                  title: 'Import/Export',
                  icons: Icons.cleaning_services_outlined,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                  onTap: ()async{
                    Navigator.pop(context);

                    // Load initial status once
                    bool initialEnabled = await AutoBackupService.isAutoBackupEnabled();
                    String? initialBackup = await AutoBackupService.getLastBackupDate();

                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext){
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return AlertDialog(
                              title: Center(
                                child: Text('Backup & Restore',
                                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
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
                                        color: initialEnabled ? Colors.green.shade50 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: initialEnabled ? Colors.green.shade300 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                initialEnabled ? Icons.check_circle : Icons.cancel,
                                                color: initialEnabled ? Colors.green : Colors.grey,
                                              ),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Daily Auto Backup',
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                              Switch(
                                                value: initialEnabled,
                                                onChanged: (value) async {
                                                  // Update immediately
                                                  setState(() {
                                                    initialEnabled = value;
                                                  });

                                                  // Save in background
                                                  await AutoBackupService.setAutoBackupEnabled(value);

                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(value
                                                          ? '✅ Auto backup enabled!'
                                                          : 'Auto backup disabled'),
                                                        duration: Duration(seconds: 2),
                                                      ),
                                                    );
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
                                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
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
                                label: Text('Download Backup',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                                ),
                                onPressed: ()async{
                                  final outerContext = context;
                                  Navigator.pop(outerContext);

                                  // Show loading dialog and get the navigator
                                  final navigatorState = Navigator.of(outerContext, rootNavigator: true);
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
                                    filePath = await CategoryImportExport.exportToDownloads();
                                  } catch (e) {
                                    debugPrint('❌ Backup error: $e');
                                  } finally {
                                    // Always close the dialog no matter what
                                    debugPrint('🔄 Attempting to close dialog...');
                                    try {
                                      navigatorState.pop();
                                      debugPrint('✅ Dialog closed successfully');
                                    } catch (e) {
                                      debugPrint('❌ Error closing dialog: $e');
                                    }
                                  }

                                  // Show result after dialog is closed
                                  await Future.delayed(Duration(milliseconds: 300));

                                  if (filePath == null) {
                                    if (outerContext.mounted) {
                                      ScaffoldMessenger.of(outerContext).showSnackBar(
                                        const SnackBar(
                                          content: Text('❌ Backup failed'),
                                          duration: Duration(seconds: 3),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  if (outerContext.mounted) {
                                    ScaffoldMessenger.of(outerContext).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '✅ Backup saved successfully!\n📁 Location: Downloads folder',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: Duration(seconds: 5),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
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
                                label: Text('Choose Folder',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                                ),
                                onPressed: ()async{
                                  Navigator.pop(context);

                                  // Show folder picker first
                                  String? selectedDirectory;
                                  try {
                                    selectedDirectory = await FilePicker.platform.getDirectoryPath();
                                  } catch (e) {
                                    debugPrint('❌ Folder picker error: $e');
                                    final globalContext = main_app.navigatorKey.currentContext;
                                    if (globalContext != null && globalContext.mounted) {
                                      ScaffoldMessenger.of(globalContext).showSnackBar(
                                        SnackBar(
                                          content: Text('❌ Error selecting folder: $e'),
                                          duration: Duration(seconds: 3),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  if (selectedDirectory == null) {
                                    final globalContext = main_app.navigatorKey.currentContext;
                                    if (globalContext != null && globalContext.mounted) {
                                      ScaffoldMessenger.of(globalContext).showSnackBar(
                                        const SnackBar(
                                          content: Text('Folder selection cancelled'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Use global context for dialog after folder picker
                                  final globalContext = main_app.navigatorKey.currentContext;
                                  if (globalContext == null) {
                                    debugPrint('❌ Global context is null after folder picker');
                                    return;
                                  }

                                  // Show loading dialog using global navigator
                                  final navigatorState = Navigator.of(globalContext, rootNavigator: true);
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
                                    // Create backup in temp location
                                    filePath = await CategoryImportExport.exportAllData();

                                    if (filePath != null) {
                                      // Copy to selected folder
                                      final backupFile = File(filePath);
                                      final fileName = filePath.split('/').last;
                                      final newPath = '$selectedDirectory/$fileName';
                                      await backupFile.copy(newPath);
                                      debugPrint('✅ Backup copied to: $newPath');
                                    }
                                  } catch (e) {
                                    debugPrint('❌ Backup error: $e');
                                  } finally {
                                    // Always close dialog
                                    debugPrint('🔄 Attempting to close dialog...');
                                    try {
                                      navigatorState.pop();
                                      debugPrint('✅ Dialog closed successfully');
                                    } catch (e) {
                                      debugPrint('❌ Error closing dialog: $e');
                                    }
                                  }

                                  // Show result after dialog closes
                                  await Future.delayed(Duration(milliseconds: 300));

                                  final finalContext = main_app.navigatorKey.currentContext;
                                  if (finalContext == null) return;

                                  if (filePath == null) {
                                    ScaffoldMessenger.of(finalContext).showSnackBar(
                                      const SnackBar(
                                        content: Text('❌ Backup creation failed'),
                                        duration: Duration(seconds: 3),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final fileName = filePath.split('/').last;
                                  ScaffoldMessenger.of(finalContext).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '✅ Backup saved successfully!\n📁 $fileName',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                      duration: Duration(seconds: 5),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
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
                                label: Text('Import Backup',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                                ),
                                onPressed: ()async{
                                  Navigator.pop(context);

                                  // Show loading dialog
                                  final navigatorState = Navigator.of(context, rootNavigator: true);

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
                                                      Text('Importing backup...\nPlease wait',
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
                                            importSuccess = await CategoryImportExport.importAllData(context);
                                          } catch (e) {
                                            debugPrint('Import error in drawer: $e');
                                          } finally {
                                            // Always dismiss dialog
                                            if (navigatorState.mounted) {
                                              navigatorState.pop();
                                              debugPrint('✅ Dialog dismissed via navigator state');
                                            }

                                            // Only show restart dialog if import was successful
                                            if (importSuccess) {
                                              await Future.delayed(Duration(milliseconds: 300));

                                              final globalContext = main_app.navigatorKey.currentContext;
                                              if (globalContext != null) {
                                                showDialog(
                                                  context: globalContext,
                                                  barrierDismissible: false,
                                                  builder: (BuildContext dialogContext) {
                                                    return AlertDialog(
                                                      title: Text('Import Completed', style: GoogleFonts.poppins()),
                                                      content: Text(
                                                        'Data imported successfully!\n\nPlease close and restart the app.',
                                                        style: GoogleFonts.poppins(),
                                                      ),
                                                      actions: [
                                                        CommonButton(
                                                          borderwidth: 0,
                                                          bordercircular: 5,
                                                          width: MediaQuery.of(dialogContext).size.width * 0.3,
                                                          height: MediaQuery.of(dialogContext).size.height * 0.05,
                                                          onTap: () {
                                                            exit(0);
                                                          },
                                                          child: Text(
                                                            'Close App',
                                                            style: GoogleFonts.poppins(color: Colors.white),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                debugPrint('⚠️ Global context is null');
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                )
                                )

                            );
                          }
                        );
                      },
                    );
                  },
                ),


                SizedBox(
                  height: 10,
                ),

                // Test Data Generator (for testing backup)
                Listmenu(
                  onTap: (){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=> TestDataScreen()));
                  },
                  title: 'Test Data Generator',
                  icons: Icons.data_object,
                  listcolor: Colors.orange.shade100,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),

                Listmenu(
                  onTap:(){
                    Navigator.push(context, MaterialPageRoute(builder: (context)=> NeedhelpDrawer()));
                  },
                  title: 'Need Help?',
                  icons: Icons.person,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),
                Listmenu(
                  title: 'Language',
                  icons: Icons.language,
                  listcolor: Colors.grey.shade300,
                  heightCon: height * 0.07,
                  borderwidth: 0,
                  colorb: Colors.transparent,
                  borderradius: 2,
                ),
                SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


