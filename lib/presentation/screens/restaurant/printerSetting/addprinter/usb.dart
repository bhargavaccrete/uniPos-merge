import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

/// USB Printer discovery and setup screen.
///
/// Similar flow to Bluetooth — scan for connected USB devices, tap Save.
/// No permissions needed (unlike Bluetooth which requires Location).
/// USB printers are typically used on:
/// - Windows: wired counter receipt printer
/// - Android: USB OTG cable to thermal printer
class Usb extends StatefulWidget {
  const Usb({super.key});

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
        final devices = printerStore.discoveredDevices;

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discovered USB Devices (${devices.length})',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...devices.map((d) {
              final DiscoveredPrinter device = d as DiscoveredPrinter;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListTile(
                  leading: Icon(Icons.usb, color: AppColors.info),
                  title: Text(
                    device.name ?? 'USB Printer',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'VID: ${device.vendorId ?? device.address ?? "Unknown"}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary),
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

  /// Save dialog — same structure as Bluetooth save dialog
  Future<void> _showSaveDialog(DiscoveredPrinter device) async {
    final nameController =
        TextEditingController(text: device.name ?? 'USB Printer');
    int paperSize = 80;
    // Role is assigned later by the slot on the Printer Management screen.
    const String role = 'receipt';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialogShell(
          title: 'Save USB Printer',
          accent: AppColors.primary,
          icon: Icons.usb,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VID: ${device.vendorId ?? device.address ?? "Unknown"}',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Printer Name',
                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                  border: const OutlineInputBorder(),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text('Paper Size',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Radio<int>(
                      value: 58,
                      groupValue: paperSize,
                      onChanged: (v) =>
                          setDialogState(() => paperSize = v!),
                      activeColor: AppColors.primary),
                  Text('58mm', style: GoogleFonts.poppins(fontSize: 13)),
                  const SizedBox(width: 16),
                  Radio<int>(
                      value: 80,
                      groupValue: paperSize,
                      onChanged: (v) =>
                          setDialogState(() => paperSize = v!),
                      activeColor: AppColors.primary),
                  Text('80mm', style: GoogleFonts.poppins(fontSize: 13)),
                ],
              ),
            ],
          ),
          actions: [
            appDialogCancelButton(ctx),
            const SizedBox(width: 12),
            appDialogPrimaryButton(
              label: 'Save',
              onPressed: () async {
                await printerStore.saveUsbPrinter(
                  device: device,
                  name: nameController.text.trim(),
                  paperSize: paperSize,
                  role: role,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  NotificationService.instance.showSuccess(
                      'Printer "${nameController.text.trim()}" saved');
                }
              },
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
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
