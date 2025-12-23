import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/presentation/widget/componets/restaurant/componets/togglelist.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customize Your Printer',
          textScaler: TextScaler.linear(1),
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Reset button
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: () async {
              await PrintSettings.resetToDefaults();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Print settings reset to defaults'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Map<String, bool>>(
        valueListenable: PrintSettings.settingsNotifier,
        builder: (context, settings, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Toggle options to show/hide on printed bills and KOTs',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Print settings list
                ...settings.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: SwitchList(
                      title: entry.key,
                      isvalue: entry.value,
                      onChanged: (bool newValue) async {
                        await PrintSettings.updateSetting(entry.key, newValue);
                      },
                    ),
                  );
                }).toList(),

                // Footer info
                SizedBox(height: 20),
                Center(
                  child: Text(
                    'Settings auto-save and apply to all future prints',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}