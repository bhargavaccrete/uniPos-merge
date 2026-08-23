import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/Blutooth.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/usb.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/wifi.dart';
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

class _AddPrinterState extends State<AddPrinter> with SingleTickerProviderStateMixin{
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener((){
      setState(() {
      });
    });
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
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: const [
              Tab(text: 'WIFI/LAN'),
              Tab(text: 'Bluetooth'),
              Tab(text: 'USB'),
            ],
          ),
        ),
      ),
      body: TabBarView(
          controller: tabController,
          children: [
            WifiLan(assignToRole: widget.assignToRole),
            Bluthooth(assignToRole: widget.assignToRole),
            Usb(assignToRole: widget.assignToRole)
          ]),
    );
  }
}
