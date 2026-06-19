import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/domain/services/restaurant/notification_service.dart';
import 'package:unipos/presentation/widget/componets/common/app_text_field.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/common/app_responsive.dart';

/// WiFi/LAN Printer setup screen.
///
/// Two sections:
/// 1. Manual entry form — staff enters IP, port, name, paper size, role
/// 2. Saved WiFi printers list — shows previously saved printers from Hive
///
/// WiFi printers don't need discovery (unlike Bluetooth). Staff types the IP
/// address found on the printer's config page, tests the connection, and saves.
class WifiLan extends StatefulWidget {
  const WifiLan({super.key});

  @override
  State<WifiLan> createState() => _WifiLanState();
}

class _WifiLanState extends State<WifiLan> {
  // Form controllers — manage the text input state
  final _nameController = TextEditingController(text: 'WiFi Printer');
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');

  // Selection state for radio buttons
  int _paperSize = 80; // 58 or 80 mm
  // Role is assigned later by the slot on the Printer Management screen
  // (Billing vs Kitchen); a neutral default is fine here.
  final String _role = 'receipt';

  // UI feedback state
  bool _isTesting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load saved printers when screen opens
    printerStore.loadSavedPrinters();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
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
            // ── SECTION 1: Add New WiFi Printer Form ──
            _buildAddPrinterForm(),
            const SizedBox(height: 24),

            // ── SECTION 2: Saved WiFi Printers List ──
            _buildSavedPrintersList(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 1: Add Printer Form
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildAddPrinterForm() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title with icon chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.wifi, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Add WiFi/LAN Printer',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Printer name — helps staff identify printers
            // ("Kitchen Printer", "Bar Printer", "Counter Printer")
            AppTextField(
              controller: _nameController,
              label: 'Printer Name',
              hint: 'e.g., Kitchen Printer',
              icon: Icons.label_outline,
            ),
            const SizedBox(height: 12),

            // IP Address — the printer's local network address
            // Staff finds this on the printer's settings page or config printout
            AppTextField(
              controller: _ipController,
              label: 'IP Address',
              hint: 'e.g., 192.168.1.100',
              icon: Icons.router_outlined,
              keyboardType: TextInputType.number,
              required: true,
            ),
            const SizedBox(height: 12),

            // Port — almost always 9100 (raw printing standard)
            // We pre-fill this; staff rarely changes it
            AppTextField(
              controller: _portController,
              label: 'Port',
              hint: '9100',
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Paper size selector — determines character width per line
            // 80mm = 48 chars/line (standard), 58mm = 32 chars/line (compact)
            Text('Paper Size',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Row(
              children: [
                _radioOption<int>(
                  value: 58,
                  groupValue: _paperSize,
                  label: '58mm',
                  onChanged: (v) => setState(() => _paperSize = v!),
                ),
                const SizedBox(width: 16),
                _radioOption<int>(
                  value: 80,
                  groupValue: _paperSize,
                  label: '80mm',
                  onChanged: (v) => setState(() => _paperSize = v!),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons — Test and Save
            Row(
              children: [
                // Test Connection — opens TCP socket to IP:port without sending data
                // Shows success/failure immediately
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find, size: 18),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Save Printer — validates input and saves to Hive
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePrinter,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save Printer',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 2: Saved WiFi Printers List
  // Wrapped in Observer — auto-rebuilds when printerStore changes
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSavedPrintersList() {
    return Observer(
      builder: (_) {
        final wifiPrinters = printerStore.wifiPrinters;

        if (wifiPrinters.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No WiFi printers saved yet',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved WiFi Printers',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // Each saved printer as a card with info + actions
            ...wifiPrinters.map((printer) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.wifi, color: AppColors.info),
                    // Printer name + connection details
                    title: Text(
                      printer.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${printer.address} | ${printer.paperSize}mm',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    // Action buttons: Test print + Delete
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Test print — sends a test ticket to verify it works
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
                        // Delete — removes from Hive with confirmation
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: AppColors.danger),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(printer.id, printer.name),
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
  // HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════════════

  /// Generic radio button option used for paper size and role selectors
  Widget _radioOption<T>({
    required T value,
    required T groupValue,
    required String label,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<T>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: GoogleFonts.poppins(fontSize: 13)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ACTIONS — Test, Save, Delete
  // ════════════════════════════════════════════════════════════════════════

  /// Test connection — tries TCP connect to the entered IP:port.
  /// Doesn't send any data, just verifies the printer is reachable on the network.
  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      NotificationService.instance.showError('Please enter an IP address');
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    setState(() => _isTesting = true);

    final success = await printerStore.testWifiConnection(ip, port);

    if (mounted) {
      setState(() => _isTesting = false);
      if (success) {
        NotificationService.instance
            .showSuccess('Connected to $ip:$port');
      } else {
        NotificationService.instance
            .showError('Cannot reach $ip:$port — check IP and network');
      }
    }
  }

  /// Save printer — validates form, then calls printerStore.addWifiPrinter()
  /// which creates a SavedPrinterModel and persists to Hive.
  Future<void> _savePrinter() async {
    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    // Validation
    if (ip.isEmpty) {
      NotificationService.instance.showError('IP address is required');
      return;
    }
    if (name.isEmpty) {
      NotificationService.instance.showError('Printer name is required');
      return;
    }

    setState(() => _isSaving = true);

    await printerStore.addWifiPrinter(
      name: name,
      ip: ip,
      port: port,
      paperSize: _paperSize,
      role: _role,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      NotificationService.instance.showSuccess('Printer "$name" saved');

      // Clear form for next entry
      _ipController.clear();
      _nameController.text = 'WiFi Printer';
      _portController.text = '9100';
    }
  }

  /// Delete with confirmation dialog
  Future<void> _confirmDelete(String id, String name) async {
    final hInset = !AppResponsive.isMobile(context)
        ? ((AppResponsive.screenWidth(context) - AppResponsive.dialogWidth(context)) / 2).clamp(40.0, 200.0)
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
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
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
