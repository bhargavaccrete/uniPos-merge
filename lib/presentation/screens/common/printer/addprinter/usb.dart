import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'save_printer_dialog.dart';
import 'slot_row_actions.dart';

/// USB Printer discovery and setup screen.
///
/// Similar flow to Bluetooth — scan for connected USB devices, tap Save.
/// No permissions needed (unlike Bluetooth which requires Location).
/// USB printers are typically used on:
/// - Windows: wired counter receipt printer
/// - Android: USB OTG cable to thermal printer
class Usb extends StatefulWidget {
  /// Slot to point at a newly saved printer — see [AddPrinter.assignToRole].
  final String? assignToRole;

  const Usb({super.key, this.assignToRole});

  @override
  State<Usb> createState() => _UsbState();
}

class _UsbState extends State<Usb> {
  @override
  void initState() {
    super.initState();
    printerStore.loadSavedPrinters();
  }

  @override
  void dispose() {
    printerStore.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScanningBanner(),
            _buildDiscoveredDevices(),
            const SizedBox(height: 24),
            _buildSavedUsbPrinters(),
          ],
        ),
      ),
      // FAB triggers USB scan
      floatingActionButton: Observer(
        builder: (_) => FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed:
              printerStore.isScanning ? _stopScan : _startScan,
          child: Icon(
            printerStore.isScanning ? Icons.stop : Icons.usb,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Scanning Banner — shows while USB scan is active
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildScanningBanner() {
    return Observer(
      builder: (_) {
        if (!printerStore.isScanning) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scanning for USB printers...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: _stopScan,
                child: Text('Stop',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.primary)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Discovered USB Devices — live list from scan
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDiscoveredDevices() {
    return Observer(
      builder: (_) {
        // discoveredDevices is shared with the Bluetooth scan; show USB only so
        // BLE results don't leak into this tab.
        final devices = printerStore.discoveredDevices
            .cast<DiscoveredPrinter>()
            .where((d) => d.connectionType == 'USB')
            .toList();

        if (devices.isEmpty && !printerStore.isScanning) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.usb_off, size: 48, color: AppColors.divider),
                  const SizedBox(height: 12),
                  Text(
                    'Connect a USB printer and\ntap the scan button',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        if (devices.isEmpty && printerStore.isScanning) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Looking for USB devices...',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 13)),
            ),
          );
        }

        // A USB-C converter/hub shows up as several USB devices (its HDMI, LAN,
        // etc.). We can't read the USB class here, so flag the obvious non-printers
        // by name and sort likely printers to the top — but keep ALL savable so a
        // printer with an odd name is never hidden.
        final sorted = devices.cast<DiscoveredPrinter>().toList()
          ..sort((a, b) =>
              (_isLikelyNonPrinter(a.name) ? 1 : 0) -
              (_isLikelyNonPrinter(b.name) ? 1 : 0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discovered USB Devices (${devices.length})',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Pick the one marked as your printer. Unsure? Save it and Test '
                'Print — the one that prints paper is your printer.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...sorted.map((device) {
              final nonPrinter = _isLikelyNonPrinter(device.name);
              final accent =
                  nonPrinter ? AppColors.warning : AppColors.success;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.5)),
                ),
                child: ListTile(
                  leading: Icon(
                    nonPrinter ? Icons.warning_amber_rounded : Icons.print,
                    color: accent,
                  ),
                  title: Text(
                    device.name ?? 'USB Printer',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    nonPrinter
                        ? 'Likely NOT a printer — part of your USB hub/converter'
                        : 'Likely your printer  ·  VID ${device.vendorId ?? device.address ?? "?"}',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: nonPrinter
                            ? AppColors.warning
                            : AppColors.textSecondary),
                  ),
                  trailing: TextButton(
                    onPressed: () => _showSaveDialog(device),
                    child: Text('Save',
                        style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Saved USB Printers — from Hive
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSavedUsbPrinters() {
    return Observer(
      builder: (_) {
        final usbPrinters =
            printerStore.savedPrinters.where((p) => p.isUsb).toList();

        if (usbPrinters.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved USB Printers',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...usbPrinters.map((printer) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListTile(
                    // In assign mode, tapping a row makes it the active printer.
                    onTap: () =>
                        setActiveForSlot(printer, widget.assignToRole),
                    leading: Icon(Icons.usb, color: AppColors.info),
                    title: Text(printer.name,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${printer.address} | ${printer.paperSize}mm',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...[activeSlotBadge(printer, widget.assignToRole)]
                            .whereType<Widget>(),
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
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: AppColors.danger),
                          tooltip: 'Delete',
                          onPressed: () =>
                              _confirmDelete(printer.id, printer.name),
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

  // ════════════════════════════════════════════════════════════════════════
  // Actions
  // ════════════════════════════════════════════════════════════════════════

  /// USB scan — no permissions needed (unlike Bluetooth)
  Future<void> _startScan() async {
    printerStore.startUsbScan();
  }

  void _stopScan() {
    printerStore.stopScan();
  }

  /// Save dialog — same structure as Bluetooth save dialog. The dialog owns its
  /// own controller (see [SavePrinterDialog]) and returns the entered values.
  Future<void> _showSaveDialog(DiscoveredPrinter device) async {
    final result = await showDialog<SavePrinterResult>(
      context: context,
      builder: (ctx) => SavePrinterDialog(
        title: 'Save USB Printer',
        icon: Icons.usb,
        subtitle: 'VID: ${device.vendorId ?? device.address ?? "Unknown"}',
        initialName: device.name ?? 'USB Printer',
      ),
    );
    if (result == null) return; // cancelled / dismissed

    // Restaurant assigns the role later via its Printer Management slots;
    // retail passes assignToRole so saving claims the Billing slot outright.
    await printerStore.saveUsbPrinter(
      device: device,
      name: result.name,
      paperSize: result.paperSize,
      role: 'receipt',
      assignRole: widget.assignToRole,
    );
    if (mounted) {
      NotificationService.instance
          .showSuccess('Printer "${result.name}" saved');
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

/// Heuristic: does this USB device name look like something OTHER than a printer
/// (an HDMI/AV adapter, LAN chip, hub, keyboard…)? Used only to flag/sort the
/// scan list — never to hide a device, since a real printer can be oddly named.
bool _isLikelyNonPrinter(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.isEmpty) return false;
  const nonPrinterHints = [
    'adapter', 'av ', 'hdmi', 'lan', 'ethernet', 'hub', 'keyboard',
    'mouse', 'audio', 'camera', 'webcam', 'storage', 'disk', 'display', 'dock',
  ];
  return nonPrinterHints.any(n.contains);
}
