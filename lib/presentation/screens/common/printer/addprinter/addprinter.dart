import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/Blutooth.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/usb.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/wifi.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/windows_printer.dart';

/// One transport tab: its label, its body, and whether it can work here.
class _PrinterTab {
  final String label;
  final Widget body;
  final bool enabled;

  const _PrinterTab({
    required this.label,
    required this.body,
    this.enabled = true,
  });
}

class AddPrinter extends StatefulWidget {
  /// When set, a printer saved here is immediately pointed at that slot
  /// (`'receipt'` or `'kot'`).
  ///
  /// Retail passes `'receipt'`: it has one slot and no Printer Management
  /// screen, so saving a printer IS choosing it. Restaurant leaves this null —
  /// its slot cards do the assigning, and auto-claiming a slot there would
  /// silently reroute the Billing or Kitchen printer.
  final String? assignToRole;

  const AddPrinter({super.key, this.assignToRole});

  @override
  State<AddPrinter> createState() => _AddPrinterState();
}

class _AddPrinterState extends State<AddPrinter>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  late final List<_PrinterTab> _tabs;

  /// `Platform` throws on web, so every check is kIsWeb-guarded — the idiom
  /// already used in `device_payload_service.dart` and `print_service.dart`.
  static bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    // Length is derived from the same list that builds the bar and the views,
    // so the three can never fall out of step.
    tabController = TabController(length: _tabs.length, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
  }

  /// On Windows, `flutter_thermal_printer` is a stub — its Bluetooth and USB
  /// methods return NotImplemented, so those tabs cannot ever find a device.
  /// They stay visible (a user who came looking for Bluetooth deserves an
  /// answer) but are disabled and point at the Windows tab instead.
  List<_PrinterTab> _buildTabs() {
    final role = widget.assignToRole;
    return [
      _PrinterTab(label: 'WIFI/LAN', body: WifiLan(assignToRole: role)),
      if (_isWindows)
        _PrinterTab(
          label: 'Windows',
          body: WindowsPrinterTab(assignToRole: role),
        ),
      _PrinterTab(
        label: 'Bluetooth',
        body: _isWindows
            ? const _UnsupportedOnWindows(transport: 'Bluetooth')
            : Bluthooth(assignToRole: role),
        enabled: !_isWindows,
      ),
      _PrinterTab(
        label: 'USB',
        body: _isWindows
            ? const _UnsupportedOnWindows(transport: 'USB')
            : Usb(assignToRole: role),
        enabled: !_isWindows,
      ),
    ];
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Printer Setting',
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: TabBar(
            controller: tabController,
            isScrollable: _tabs.length > 3,
            tabAlignment: _tabs.length > 3 ? TabAlignment.start : null,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: _tabs
                .map((t) => Tab(
                      child: Text(
                        t.label,
                        // Disabled tabs are still reachable — tapping one shows
                        // the explanation rather than doing nothing.
                        style: t.enabled
                            ? null
                            : const TextStyle(color: Colors.white38),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: _tabs.map((t) => t.body).toList(),
      ),
    );
  }
}

/// Shown in place of the Bluetooth/USB tabs on Windows.
class _UnsupportedOnWindows extends StatelessWidget {
  final String transport;

  const _UnsupportedOnWindows({required this.transport});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 44, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                '$transport is not supported on Windows',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Connect the printer in Windows Settings first, then pick it '
                'from the Windows tab. $transport printers paired with this PC '
                'appear there too.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
