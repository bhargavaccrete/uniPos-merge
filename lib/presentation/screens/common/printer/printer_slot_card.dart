import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/util/color.dart';

/// One printer role slot — the card, its picker sheet, Test Print and delete.
///
/// Shared by restaurant (Billing + Kitchen slots) and retail (Billing only).
/// Everything it touches — [PrinterStore], [SavedPrinterModel] — is mode-agnostic;
/// the only thing that differs per mode is how "Add Printer" navigates, hence
/// [onAddPrinter] is a callback rather than a hardcoded push.
class PrinterSlotCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  /// 'receipt' (Billing) or 'kot' (Kitchen).
  final String role;

  /// Called when the picker's "Add Printer" row is tapped. The picker sheet is
  /// already popped by then; the caller reloads saved printers when it returns.
  final VoidCallback onAddPrinter;

  const PrinterSlotCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.role,
    required this.onAddPrinter,
  });

  @override
  State<PrinterSlotCard> createState() => _PrinterSlotCardState();
}

class _PrinterSlotCardState extends State<PrinterSlotCard> {
  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final printer = widget.role == 'kot'
            ? printerStore.defaultKotPrinter
            : printerStore.defaultReceiptPrinter;
        return _slotCard(printer);
      },
    );
  }

  // ── Slot card ──────────────────────────────────────────────────────────────
  Widget _slotCard(SavedPrinterModel? printer) {
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
          onTap: () => _showPrinterPickerSheet(widget.role),
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
                      child:
                          Icon(widget.icon, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(widget.subtitle,
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Observer(
          builder: (_) {
            final printers = printerStore.savedPrinters;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text('$roleLabel Printer',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Pick a saved printer or add a new one',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      // Saved printers scroll; "Add Printer" stays pinned below so
                      // it's always reachable no matter how many printers exist.
                      Flexible(
                        child: printers.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text('No saved printers yet.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: printers
                                      .map((p) => _pickerRow(ctx, p, role))
                                      .toList(),
                                ),
                              ),
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.add, color: AppColors.primary),
                        title: Text('Add Printer',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        // Bluetooth and USB can't reach a printer on Windows —
                        // don't advertise them there.
                        subtitle: Text(
                            !kIsWeb && Platform.isWindows
                                ? 'Windows · WiFi'
                                : 'Bluetooth · WiFi · USB',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary)),
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onAddPrinter();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pickerRow(BuildContext sheetCtx, SavedPrinterModel p, String role) {
    // Slots are independent, so a printer may already hold the other one —
    // flag that rather than hiding it.
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
        // WiFi is the fallback, so any new transport must be named explicitly
        // here or it silently renders as a WiFi printer.
        p.isBluetooth
            ? Icons.bluetooth
            : p.isUsb
                ? Icons.usb
                : p.isWindowsPdf
                    ? Icons.picture_as_pdf_outlined
                    : p.isWindows
                        ? Icons.desktop_windows_outlined
                        : Icons.wifi,
        color: AppColors.info,
      ),
      title: Text(p.name,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${p.type.toUpperCase()} · ${p.paperSize}mm'
        '${otherSlotName != null ? '  · also $otherSlotName' : ''}',
        style: GoogleFonts.poppins(
            fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show the "selected" check for the current slot, but ALWAYS keep the
          // delete action so an assigned printer can still be removed (deleting
          // clears its slot pointer in the repo).
          if (isThisSlot)
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: AppColors.danger),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(p.id, p.name),
          ),
        ],
      ),
      onTap: () async {
        // Slots are independent — the same printer may serve both. Save as 'both'
        // so it stays valid for whichever slot(s) point to it.
        await printerStore.savePrinter(p.copyWith(role: 'both'));
        await printerStore.setDefaultForRole(p.id, role);
        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        if (mounted) {
          NotificationService.instance.showSuccess(
              '${p.name} set as ${role == 'kot' ? 'Kitchen' : 'Billing'} printer');
        }
      },
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
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Printer',
      message: 'Remove "$name" from saved printers?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_rounded,
    );

    if (confirmed == true) {
      await printerStore.deletePrinter(id);
      if (mounted) {
        NotificationService.instance.showSuccess('Printer removed');
      }
    }
  }
}
