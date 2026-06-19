import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/data/models/restaurant/db/saved_printer_model.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';
import 'package:unipos/util/restaurant/print_settings.dart';
import 'package:unipos/presentation/widget/componets/common/primary_app_bar.dart';

/// Printer Management — two role slots (Billing + Kitchen, mutually exclusive),
/// a Bill Format selector (Thermal/A4), and a behavior explainer.
/// Tapping a slot opens a picker of saved printers (+ Add Printer).
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
            Observer(
              builder: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _slotCard(
                    title: 'Billing Printer',
                    subtitle: 'Bills & reports',
                    icon: Icons.receipt_long,
                    printer: printerStore.defaultReceiptPrinter,
                    role: 'receipt',
                  ),
                  _slotCard(
                    title: 'Kitchen Printer',
                    subtitle: 'KOT (always thermal)',
                    icon: Icons.restaurant_menu,
                    printer: printerStore.defaultKotPrinter,
                    role: 'kot',
                  ),
                ],
              ),
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

  // ── Slot card ──────────────────────────────────────────────────────────────
  Widget _slotCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required SavedPrinterModel? printer,
    required String role,
  }) {
    final configured = printer != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPrinterPickerSheet(role),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(subtitle,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                if (configured) ...[
                  Text('${printer.name}  ·  ${printer.type.toUpperCase()} · ${printer.paperSize}mm',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Configured',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.success)),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => _testPrint(printer),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: Text('Test Print',
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ] else
                  Text('Not set — tap to add a printer',
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Picker sheet ─────────────────────────────────────────────────────────
  void _showPrinterPickerSheet(String role) {
    final roleLabel = role == 'kot' ? 'Kitchen' : 'Billing';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Observer(
          builder: (_) {
            final printers = printerStore.savedPrinters;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$roleLabel Printer',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Pick a saved printer or add a new one',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    if (printers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No saved printers yet.',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.textSecondary)),
                      )
                    else
                      ...printers.map((p) => _pickerRow(ctx, p, role)),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.add, color: AppColors.primary),
                      title: Text('Add Printer',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      subtitle: Text('Bluetooth · WiFi · USB',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.textSecondary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(
                                context, RouteNames.restaurantAddPrinter)
                            .then((_) => printerStore.loadSavedPrinters());
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

  Widget _pickerRow(BuildContext sheetCtx, SavedPrinterModel p, String role) {
    // A printer can serve only one slot; flag if it currently holds the other.
    final isThisSlot = role == 'kot'
        ? printerStore.defaultKotPrinter?.id == p.id
        : printerStore.defaultReceiptPrinter?.id == p.id;
    final otherSlotName = printerStore.defaultKotPrinter?.id == p.id
        ? (role == 'receipt' ? 'Kitchen' : null)
        : printerStore.defaultReceiptPrinter?.id == p.id
            ? (role == 'kot' ? 'Billing' : null)
            : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        p.isBluetooth
            ? Icons.bluetooth
            : p.isUsb
                ? Icons.usb
                : Icons.wifi,
        color: AppColors.info,
      ),
      title: Text(p.name,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${p.type.toUpperCase()} · ${p.paperSize}mm'
        '${otherSlotName != null ? '  · currently $otherSlotName' : ''}',
        style: GoogleFonts.poppins(
            fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: isThisSlot
          ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
          : IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: AppColors.danger),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(p.id, p.name),
            ),
      onTap: () async {
        // Role follows the slot; assigning releases the other slot (repo rule).
        await printerStore.savePrinter(p.copyWith(role: role));
        await printerStore.setDefaultForRole(p.id, role);
        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        if (mounted) {
          NotificationService.instance.showSuccess(
              '${p.name} set as ${role == 'kot' ? 'Kitchen' : 'Billing'} printer');
        }
      },
    );
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

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _testPrint(SavedPrinterModel printer) async {
    final success = await printerStore.testPrint(printer);
    if (!mounted) return;
    if (success) {
      NotificationService.instance.showSuccess('Test print sent!');
    } else {
      NotificationService.instance
          .showError(printerStore.errorMessage ?? 'Test print failed');
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) -
                    AppResponsive.dialogWidth(context)) /
                2)
            .clamp(40.0, 200.0)
        : 24.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(horizontal: hInset, vertical: 24),
        title: Text('Delete Printer', style: GoogleFonts.poppins()),
        content: Text('Remove "$name" from saved printers?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await printerStore.deletePrinter(id);
      if (mounted) {
        NotificationService.instance.showSuccess('Printer removed');
      }
    }
  }
}
