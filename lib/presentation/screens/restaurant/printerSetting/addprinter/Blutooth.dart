import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/domain/services/restaurant/thermal_printer_service.dart';
import 'package:unipos/util/color.dart';

/// Bluetooth Printer discovery and setup screen.
///
/// Three sections:
/// 1. Scanning status banner — shows while BLE scan is active
/// 2. Discovered devices list — devices found during current scan
/// 3. Saved Bluetooth printers — previously saved printers from Hive
///
/// Unlike WiFi (manual IP), Bluetooth requires active scanning.
/// The FAB triggers a BLE scan, discovered devices appear in real-time,
/// and staff taps "Save" on the device they want to use.
class Bluthooth extends StatefulWidget {
  const Bluthooth({super.key});

  @override
  State<Bluthooth> createState() => _BluthoothhState();
}

class _BluthoothhState extends State<Bluthooth> {
  @override
  void initState() {
    super.initState();
    printerStore.loadSavedPrinters();
  }

  @override
  void dispose() {
    // Stop scanning when leaving the screen to save battery
    printerStore.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECTION 1: Scanning Status Banner ──
            _buildScanningBanner(),

            // ── SECTION 2: Discovered Devices ──
            _buildDiscoveredDevices(),
            const SizedBox(height: 24),

            // ── SECTION 3: Saved Bluetooth Printers ──
            _buildSavedPrintersList(),
          ],
        ),
      ),
      // FAB triggers Bluetooth scan
      // Positioned at bottom-right, same style as original stub
      floatingActionButton: Observer(
        builder: (_) => FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: printerStore.isScanning ? _stopScan : _startScan,
          child: Icon(
            printerStore.isScanning ? Icons.stop : Icons.bluetooth_searching,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 1: Scanning Banner
  // Shows a blue banner with progress indicator while scan is active.
  // Disappears when scan stops.
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
                  'Scanning for Bluetooth printers...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Tap "Stop" text to end scan early
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
  // SECTION 2: Discovered Devices
  // Live list of BLE devices found during scan. Each device shows
  // name + MAC address + Save/Test buttons.
  // Wrapped in Observer — updates in real-time as devices are found.
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDiscoveredDevices() {
    return Observer(
      builder: (_) {
        final devices = printerStore.discoveredDevices;

        // Show prompt when no scan has happened yet
        if (devices.isEmpty && !printerStore.isScanning) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.bluetooth_searching,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Tap the scan button to find\nnearby Bluetooth printers',
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
              child: Text(
                'Looking for devices...',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discovered Devices (${devices.length})',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // Cast each device explicitly — ObservableList iteration
            // can lose type info in some MobX versions
            ...devices.map((d) {
              final DiscoveredPrinter device = d as DiscoveredPrinter;
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(Icons.bluetooth,
                      color: AppColors.info),
                  // Device name from BLE advertisement
                  // Some printers broadcast a name, others show as "Unknown"
                  title: Text(
                    device.name ?? 'Unknown Device',
                    style:
                        GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  // MAC address — unique identifier for this device
                  subtitle: Text(
                    device.address ?? 'No address',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Save button — opens dialog to configure name/size/role
                      TextButton(
                        onPressed: () => _showSaveDialog(device),
                        child: Text('Save',
                            style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
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
  // SECTION 3: Saved Bluetooth Printers
  // Same pattern as WiFi's saved list — Observer-wrapped, with test/delete
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSavedPrintersList() {
    return Observer(
      builder: (_) {
        final btPrinters = printerStore.bluetoothPrinters;

        if (btPrinters.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Bluetooth Printers',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...btPrinters.map((printer) => Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Icon(
                      (printerStore.defaultKotPrinter?.id == printer.id ||
                          printerStore.defaultReceiptPrinter?.id == printer.id)
                          ? Icons.star
                          : Icons.bluetooth_connected,
                      color: (printerStore.defaultKotPrinter?.id == printer.id ||
                          printerStore.defaultReceiptPrinter?.id == printer.id)
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      printer.name,
                      style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${printer.address} | ${printer.paperSize}mm | ${printer.role.toUpperCase()}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Test print — sends test ticket via Bluetooth
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
  // ACTIONS — Scan, Save, Delete
  // ════════════════════════════════════════════════════════════════════════

  /// Start BLE scan — first requests permissions, then triggers discovery.
  ///
  /// Android requires both Bluetooth and Location permissions for BLE scanning.
  /// permission_handler (already in pubspec) handles the runtime request.
  /// We ask for permissions HERE (not at app startup) because only staff
  /// who use Bluetooth printers should be prompted.
  Future<void> _startScan() async {
    // Request Bluetooth permissions (Android 12+ needs SCAN + CONNECT)
    final btStatus = await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    // Android also requires Location for BLE discovery
    final locStatus = await Permission.locationWhenInUse.request();

    if (btStatus.isDenied || locStatus.isDenied) {
      if (mounted) {
        NotificationService.instance.showError(
            'Bluetooth and Location permissions are required to scan');
      }
      return;
    }

    printerStore.startBluetoothScan();
  }

  void _stopScan() {
    printerStore.stopScan();
  }

  /// Show save dialog — staff enters a name, picks paper size and role.
  /// Called when staff taps "Save" on a discovered device.
  Future<void> _showSaveDialog(DiscoveredPrinter device) async {
    final nameController =
        TextEditingController(text: device.name ?? 'BT Printer');
    int paperSize = 80;
    String role = 'both';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder lets us call setState inside the dialog
        // to update radio buttons without rebuilding the whole screen
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Save Printer', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device address (read-only, for reference)
                Text(
                  device.address ?? 'Unknown address',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),

                // Printer name — editable, defaults to BLE advertised name
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

                // Paper size
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
                      activeColor: AppColors.primary,
                    ),
                    Text('58mm', style: GoogleFonts.poppins(fontSize: 13)),
                    const SizedBox(width: 16),
                    Radio<int>(
                      value: 80,
                      groupValue: paperSize,
                      onChanged: (v) =>
                          setDialogState(() => paperSize = v!),
                      activeColor: AppColors.primary,
                    ),
                    Text('80mm', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),

                // Role
                Text('Printer Role',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Radio<String>(
                      value: 'kot',
                      groupValue: role,
                      onChanged: (v) =>
                          setDialogState(() => role = v!),
                      activeColor: AppColors.primary,
                    ),
                    Text('KOT', style: GoogleFonts.poppins(fontSize: 13)),
                    Radio<String>(
                      value: 'receipt',
                      groupValue: role,
                      onChanged: (v) =>
                          setDialogState(() => role = v!),
                      activeColor: AppColors.primary,
                    ),
                    Text('Receipt',
                        style: GoogleFonts.poppins(fontSize: 13)),
                    Radio<String>(
                      value: 'both',
                      groupValue: role,
                      onChanged: (v) =>
                          setDialogState(() => role = v!),
                      activeColor: AppColors.primary,
                    ),
                    Text('Both', style: GoogleFonts.poppins(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await printerStore.saveBluetoothPrinter(
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: Text('Save',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  /// Delete with confirmation
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
