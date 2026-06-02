import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/Blutooth.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/usb.dart';
import 'package:unipos/presentation/screens/restaurant/printerSetting/addprinter/wifi.dart';
class AddPrinter extends StatefulWidget {
  const AddPrinter({super.key});

  @override
  State<AddPrinter> createState() => _AddPrinterState();
}

class _AddPrinterState extends State<AddPrinter> with SingleTickerProviderStateMixin{
  late TabController tabController;

  @override
  void initState() {
    // TODO: implement initState
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
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        surfaceTintColor: AppColors.primary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
        title: Text(
          'Printer Setting',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
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
            WifiLan(),
            Bluthooth(),
            Usb()
          ]),
    );
  }
}
