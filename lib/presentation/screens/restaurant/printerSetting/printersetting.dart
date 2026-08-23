import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/routes/routes_name.dart';
import 'package:billberrylite/presentation/screens/common/printer/printer_slot_card.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/print_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';

/// Printer Management — two role slots (Billing + Kitchen; one printer may serve
/// both), a Bill Format selector (Thermal/A4), and a behavior explainer.
/// Tapping a slot opens a picker of saved printers (+ Add Printer).
/// Bill/KOT templates live on the Customization screen.
class Printersetting extends StatefulWidget {
  const Printersetting({super.key});

  @override
  State<Printersetting> createState() => _PrintersettingState();
}

class _PrintersettingState extends State<Printersetting> {
  @override
  void initState() {
    super.initState();
    printerStore.loadSavedPrinters();
    PrintSettings.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Printer Management',
        titleFontSize: AppResponsive.headingFontSize(context),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(
                context, RouteNames.restaurantPrinterCustomization),
            icon: const Icon(Icons.tune, size: 20, color: Colors.white),
            label: Text('Customize',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Printer slots ──
            PrinterSlotCard(
              title: 'Billing Printer',
              subtitle: 'Bills & reports',
              icon: Icons.receipt_long,
              role: 'receipt',
              onAddPrinter: _openAddPrinter,
            ),
            PrinterSlotCard(
              title: 'Kitchen Printer',
              subtitle: 'KOT (always thermal)',
              icon: Icons.restaurant_menu,
              role: 'kot',
              onAddPrinter: _openAddPrinter,
            ),
            const SizedBox(height: 20),

            // ── Bill format ──
            _sectionHeader('Bill Format'),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: PrintSettings.billFormatNotifier,
              builder: (_, fmt, _) => Column(
                children: [
                  _billFormatOption(
                    label: 'Thermal',
                    note: 'Recommended · 80mm receipt',
                    value: 'thermal',
                    current: fmt,
                  ),
                  _billFormatOption(
                    label: 'A4',
                    note: 'Full-page invoice',
                    value: 'a4',
                    current: fmt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Behavior explainer ──
            ValueListenableBuilder<String>(
              valueListenable: PrintSettings.billFormatNotifier,
              builder: (_, fmt, _) => _behaviorCard(fmt == 'a4'),
            ),
          ],
        ),
      ),
    );
  }

  /// Restaurant keeps its entitlement-guarded named route for Add Printer.
  void _openAddPrinter() {
    Navigator.pushNamed(context, RouteNames.restaurantAddPrinter)
        .then((_) => printerStore.loadSavedPrinters());
  }

  // ── Bill format option ─────────────────────────────────────────────────────
  Widget _billFormatOption({
    required String label,
    required String note,
    required String value,
    required String current,
  }) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => PrintSettings.setBillFormat(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(note,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Behavior card ──────────────────────────────────────────────────────────
  Widget _behaviorCard(bool isA4) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 6),
              Text('Behavior',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _behaviorRow('Billing',
              isA4 ? 'A4 invoice (always)' : 'Printer → Thermal PDF fallback'),
          const SizedBox(height: 4),
          _behaviorRow('Kitchen', 'Printer → Thermal PDF fallback (KOT never A4)'),
        ],
      ),
    );
  }

  Widget _behaviorRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textPrimary),
        children: [
          TextSpan(
              text: '$label:  ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(
              text: value,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
              color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style:
                GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

}
