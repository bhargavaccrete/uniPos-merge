import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/core/routes/routes_name.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/util/color.dart';

/// Printer Settings screen — shows saved printers, allows managing defaults,
/// and provides navigation to add new printers and customize receipts.
///
/// Replaced the original stub that showed "No Printer Found" with a live
/// Observer-wrapped list from PrinterStore.
class Printersetting extends StatefulWidget {
  const Printersetting({super.key});

  @override
  State<Printersetting> createState() => _PrintersettingState();
}

class _PrintersettingState extends State<Printersetting> {
  @override
  void initState() {
    super.initState();
    // Load saved printers from Hive on screen open
    printerStore.loadSavedPrinters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Settings',
            style: GoogleFonts.poppins(fontSize: 20)),
        leading: const BackButton(),
        actions: [
          // Customize receipt fields button
          TextButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                  context, RouteNames.restaurantPrinterCustomization);
            },
            icon: const Icon(Icons.tune, size: 20),
            label: Text('Customize',
                style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Default Printers Summary ──
            _buildDefaultPrintersSummary(),
            const SizedBox(height: 20),

            // ── Saved Printers List ──
            _buildSavedPrintersList(),
            const SizedBox(height: 20),

            // ── Add Printer Button ──
            _buildAddPrinterButton(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Default Printers Summary — shows which printers handle KOT and Receipt
  // Quick glance: "KOT → Kitchen Printer, Receipt → Counter Printer"
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDefaultPrintersSummary() {
    return Observer(
      builder: (_) {
        final kotPrinter = printerStore.defaultKotPrinter;
        final receiptPrinter = printerStore.defaultReceiptPrinter;

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.print, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Active Printers',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),

                // KOT Printer assignment
                _defaultPrinterRow(
                  label: 'KOT Printer',
                  printerName: kotPrinter?.name,
                  printerType: kotPrinter?.type,
                  icon: Icons.restaurant_menu,
                  color: AppColors.ordersTab,
                ),
                const SizedBox(height: 8),

                // Receipt Printer assignment
                _defaultPrinterRow(
                  label: 'Receipt Printer',
                  printerName: receiptPrinter?.name,
                  printerType: receiptPrinter?.type,
                  icon: Icons.receipt_long,
                  color: AppColors.secondary,
                ),

                // Hint text when no printers configured
                if (kotPrinter == null && receiptPrinter == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'No printers configured. Add a printer below to enable direct thermal printing.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Row showing a default printer assignment: "KOT Printer → Kitchen Printer (WiFi)"
  Widget _defaultPrinterRow({
    required String label,
    required String? printerName,
    required String? printerType,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text('$label: ',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            printerName != null
                ? '$printerName (${printerType?.toUpperCase() ?? ""})'
                : 'Not set',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: printerName != null ? FontWeight.w600 : FontWeight.normal,
              color: printerName != null
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Saved Printers List — all printers from Hive, with actions
  // Each card shows: name, type, address, paper size, role, default status
  // Actions: Set as KOT default, Set as Receipt default, Test, Delete
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSavedPrintersList() {
    return Observer(
      builder: (_) {
        final printers = printerStore.savedPrinters;

        if (printers.isEmpty) {
          return Card(
            elevation: 1,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 40),
              width: double.infinity,
              child: Column(
                children: [
                  Icon(Icons.print_disabled,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No Printers Saved',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Add a Bluetooth or WiFi printer to get started',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Printers (${printers.length})',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...printers.map((printer) => Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Icon + Name + Type badge
                        Row(
                          children: [
                            Icon(
                              printer.isBluetooth
                                  ? Icons.bluetooth
                                  : printer.isUsb
                                      ? Icons.usb
                                      : Icons.wifi,
                              color: (printerStore.defaultKotPrinter?.id == printer.id ||
                                      printerStore.defaultReceiptPrinter?.id == printer.id)
                                  ? AppColors.accent
                                  : AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                printer.name,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            // Default badges — show which role(s) this printer is default for
                            ...[
                              if (printerStore.defaultKotPrinter?.id == printer.id)
                                _roleBadge('KOT', AppColors.ordersTab),
                              if (printerStore.defaultReceiptPrinter?.id == printer.id)
                                _roleBadge('RECEIPT', AppColors.secondary),
                            ],
                          ],
                        ),

                        // Row 2: Address + Paper + Role
                        Padding(
                          padding: const EdgeInsets.only(left: 32, top: 4),
                          child: Text(
                            '${printer.address} | ${printer.paperSize}mm | ${printer.role.toUpperCase()}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ),

                        // Row 3: Action buttons
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Set as KOT default
                            if (printer.isKotPrinter)
                              _actionChip(
                                label: 'Set KOT Default',
                                icon: Icons.restaurant_menu,
                                onTap: () async {
                                  await printerStore.setDefaultForRole(
                                      printer.id, 'kot');
                                  if (mounted) {
                                    NotificationService.instance.showSuccess(
                                        '${printer.name} set as KOT printer');
                                  }
                                },
                              ),
                            const SizedBox(width: 6),
                            // Set as Receipt default
                            if (printer.isReceiptPrinter)
                              _actionChip(
                                label: 'Set Receipt Default',
                                icon: Icons.receipt_long,
                                onTap: () async {
                                  await printerStore.setDefaultForRole(
                                      printer.id, 'receipt');
                                  if (mounted) {
                                    NotificationService.instance.showSuccess(
                                        '${printer.name} set as receipt printer');
                                  }
                                },
                              ),
                            const Spacer(),
                            // Test print
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 20),
                              tooltip: 'Test Print',
                              onPressed: () async {
                                final success =
                                    await printerStore.testPrint(printer);
                                if (mounted) {
                                  if (success) {
                                    NotificationService.instance
                                        .showSuccess('Test print sent!');
                                  } else {
                                    NotificationService.instance.showError(
                                        printerStore.errorMessage ??
                                            'Test print failed');
                                  }
                                }
                              },
                            ),
                            // Delete
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 20, color: AppColors.danger),
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDelete(printer.id, printer.name),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  /// Role badge shown next to printer name (e.g., "KOT" in orange, "RECEIPT" in green)
  Widget _roleBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  /// Small action chip for "Set KOT Default" / "Set Receipt Default"
  Widget _actionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Add Printer Button — navigates to AddPrinter (WiFi/BT/USB tabs)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildAddPrinterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, RouteNames.restaurantAddPrinter).then(
            // Reload printers when returning from AddPrinter screen
            (_) => printerStore.loadSavedPrinters(),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Printer',
            style:
                GoogleFonts.poppins(fontSize: 15, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Delete confirmation
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
