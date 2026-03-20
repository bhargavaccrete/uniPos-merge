import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/restaurant/db/saved_printer_model.dart';
import '../../../data/repositories/restaurant/printer_repository.dart';

part 'printer_store.g.dart';

/// MobX store pattern: public class = private mixin with generated code
class PrinterStore = _PrinterStore with _$PrinterStore;

abstract class _PrinterStore with Store {
  final PrinterRepository _repository;

  /// Repository is injected via constructor — same pattern as ShiftStore, OrderStore, etc.
  _PrinterStore(this._repository);

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED PRINTERS — persisted in Hive, survive app restarts
  // ══════════════════════════════════════════════════════════════════════════

  /// All saved printers from Hive (both BT and WiFi)
  @observable
  ObservableList<SavedPrinterModel> savedPrinters =
      ObservableList<SavedPrinterModel>();

  /// The printer assigned for KOT printing (kitchen ticket)
  /// Loaded from Hive where isDefault=true AND role='kot' or 'both'
  @observable
  SavedPrinterModel? defaultKotPrinter;

  /// The printer assigned for receipt/bill printing
  /// Loaded from Hive where isDefault=true AND role='receipt' or 'both'
  @observable
  SavedPrinterModel? defaultReceiptPrinter;

  // ══════════════════════════════════════════════════════════════════════════
  // BLUETOOTH DISCOVERY — transient state, not persisted
  // ══════════════════════════════════════════════════════════════════════════

  /// Devices found during Bluetooth scan (live, cleared on each new scan)
  @observable
  ObservableList<Printer> discoveredDevices = ObservableList<Printer>();

  /// True while BLE scan is active — drives the scanning indicator in UI
  @observable
  bool isScanning = false;

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECTION & PRINT STATE — drives UI feedback
  // ══════════════════════════════════════════════════════════════════════════

  @observable
  bool isConnecting = false;

  @observable
  String connectionStatus = 'disconnected';

  @observable
  String? errorMessage;

  /// True while bytes are being sent to a printer — shows loading indicator
  @observable
  bool isPrinting = false;

  // ══════════════════════════════════════════════════════════════════════════
  // COMPUTED — derived from observables, auto-update when source changes
  // ══════════════════════════════════════════════════════════════════════════

  /// Used by RestaurantPrintHelper to decide: direct thermal or PDF fallback?
  @computed
  bool get hasDefaultKotPrinter => defaultKotPrinter != null;

  @computed
  bool get hasDefaultReceiptPrinter => defaultReceiptPrinter != null;

  /// Filtered lists for the printer settings UI tabs
  @computed
  List<SavedPrinterModel> get bluetoothPrinters =>
      savedPrinters.where((p) => p.isBluetooth).toList();

  @computed
  List<SavedPrinterModel> get wifiPrinters =>
      savedPrinters.where((p) => p.isWifi).toList();

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Persistence (Hive CRUD)
  // ══════════════════════════════════════════════════════════════════════════

  /// Load all saved printers + resolve defaults from SharedPreferences.
  /// Called on app startup and after any save/delete operation.
  ///
  /// Default assignments are stored in SharedPreferences (not on the model)
  /// so KOT default and Receipt default are truly independent.
  @action
  Future<void> loadSavedPrinters() async {
    try {
      final printers = await _repository.getAllPrinters();
      savedPrinters = ObservableList.of(printers);

      // Resolve KOT and Receipt defaults independently from SharedPreferences.
      // A printer with role='both' CAN be default for both simultaneously.
      defaultKotPrinter = await _repository.getDefaultPrinterForRole('kot');
      defaultReceiptPrinter =
          await _repository.getDefaultPrinterForRole('receipt');

      print('🖨️ PrinterStore loaded: ${printers.length} printers, '
          'KOT default=${defaultKotPrinter?.name ?? "none"}, '
          'Receipt default=${defaultReceiptPrinter?.name ?? "none"}');
    } catch (e) {
      errorMessage = 'Failed to load printers: $e';
    }
  }

  /// Save a printer to Hive then reload the list
  @action
  Future<void> savePrinter(SavedPrinterModel printer) async {
    try {
      await _repository.savePrinter(printer);
      await loadSavedPrinters();
    } catch (e) {
      errorMessage = 'Failed to save printer: $e';
    }
  }

  @action
  Future<void> deletePrinter(String id) async {
    try {
      await _repository.deletePrinter(id);
      await loadSavedPrinters();
    } catch (e) {
      errorMessage = 'Failed to delete printer: $e';
    }
  }

  /// Mark a printer as default for its role, un-default others.
  /// e.g., setDefaultForRole('abc-123', 'kot') makes it the KOT printer.
  @action
  Future<void> setDefaultForRole(String printerId, String role) async {
    try {
      await _repository.setDefaultPrinter(printerId, role);
      await loadSavedPrinters();
    } catch (e) {
      errorMessage = 'Failed to set default: $e';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — WiFi Printer Management
  // ══════════════════════════════════════════════════════════════════════════

  /// Add a WiFi/LAN printer by IP and port.
  /// WiFi printers don't need discovery — staff enters IP manually.
  /// Port 9100 is the standard raw printing port for thermal printers.
  @action
  Future<void> addWifiPrinter({
    required String name,
    required String ip,
    int port = 9100,
    int paperSize = 80,
    String role = 'both',
  }) async {
    final printer = SavedPrinterModel(
      id: const Uuid().v4(),
      name: name,
      type: 'wifi',
      address: '$ip:$port',
      paperSize: paperSize,
      role: role,
      isDefault: savedPrinters.isEmpty, // First printer auto-becomes default
    );
    await savePrinter(printer);
  }

  /// Test if a WiFi printer is reachable (TCP connect test, no data sent)
  @action
  Future<bool> testWifiConnection(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Bluetooth Discovery & Save
  // ══════════════════════════════════════════════════════════════════════════

  /// Start scanning for nearby Bluetooth (BLE) printers.
  /// Results stream into discoveredDevices via listener.
  @action
  Future<void> startBluetoothScan() async {
    if (isScanning) return;
    isScanning = true;
    errorMessage = null;
    discoveredDevices.clear();

    try {
      // Step 1: Start the scan — this is async, populates an internal list
      await FlutterThermalPrinter.instance.getPrinters(
        connectionTypes: [ConnectionType.BLE],
      );

      // Step 2: Listen to devicesStream — emits updated device lists
      // as new BLE devices are discovered nearby
      FlutterThermalPrinter.instance.devicesStream.listen(
        (List<Printer> printers) {
          discoveredDevices = ObservableList.of(printers);
        },
        onError: (e) {
          errorMessage = 'Bluetooth scan error: $e';
          isScanning = false;
        },
      );
    } catch (e) {
      errorMessage = 'Failed to start scan: $e';
      isScanning = false;
    }
  }

  @action
  void stopScan() {
    FlutterThermalPrinter.instance.stopScan();
    isScanning = false;
  }

  /// Start scanning for USB printers.
  /// USB discovery uses the platform's USB API — no permissions needed.
  @action
  Future<void> startUsbScan() async {
    if (isScanning) return;
    isScanning = true;
    errorMessage = null;
    discoveredDevices.clear();

    try {
      await FlutterThermalPrinter.instance.getPrinters(
        connectionTypes: [ConnectionType.USB],
      );

      FlutterThermalPrinter.instance.devicesStream.listen(
        (List<Printer> printers) {
          discoveredDevices = ObservableList.of(printers);
        },
        onError: (e) {
          errorMessage = 'USB scan error: $e';
          isScanning = false;
        },
      );
    } catch (e) {
      errorMessage = 'Failed to scan USB: $e';
      isScanning = false;
    }
  }

  /// Save a discovered USB device with a custom name and settings
  @action
  Future<void> saveUsbPrinter({
    required Printer device,
    required String name,
    int paperSize = 80,
    String role = 'both',
  }) async {
    final printer = SavedPrinterModel(
      id: const Uuid().v4(),
      name: name,
      type: 'usb',
      address: device.address ?? device.vendorId ?? '',
      paperSize: paperSize,
      role: role,
    );
    await savePrinter(printer);
  }

  /// Save a discovered Bluetooth device with a custom name and settings
  @action
  Future<void> saveBluetoothPrinter({
    required Printer device,
    required String name,
    int paperSize = 80,
    String role = 'both',
  }) async {
    final printer = SavedPrinterModel(
      id: const Uuid().v4(),
      name: name,
      type: 'bluetooth',
      address: device.address ?? '',
      paperSize: paperSize,
      role: role,
      isDefault: savedPrinters.isEmpty,
    );
    await savePrinter(printer);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Sending Bytes to Printer
  // ══════════════════════════════════════════════════════════════════════════

  /// Main entry point for printing. Takes raw ESC/POS bytes + target printer.
  /// Returns true if print succeeded, false otherwise.
  /// Called by RestaurantPrintHelper and EscPosReceiptBuilder.
  @action
  Future<bool> sendBytes(List<int> bytes, SavedPrinterModel printer) async {
    isPrinting = true;
    errorMessage = null;

    try {
      if (printer.isWifi) {
        return await _sendViaWifi(bytes, printer.address);
      } else if (printer.isBluetooth) {
        return await _sendViaBluetooth(bytes, printer.address);
      } else if (printer.type == 'usb') {
        return await _sendViaUsb(bytes, printer.address, printer.name);
      }
      errorMessage = 'Unknown printer type: ${printer.type}';
      return false;
    } catch (e) {
      errorMessage = 'Print failed: $e';
      return false;
    } finally {
      isPrinting = false;
    }
  }

  /// WiFi: Open TCP socket → dump bytes → close.
  /// Stateless — no persistent connection needed.
  /// Port 9100 is the industry standard for raw thermal printing.
  Future<bool> _sendViaWifi(List<int> bytes, String address) async {
    // Parse "192.168.1.100:9100" → ip + port
    final parts = address.split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

    Socket? socket;
    try {
      socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 5));
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
      return true;
    } catch (e) {
      errorMessage = 'WiFi print failed ($ip:$port): $e';
      return false;
    } finally {
      await socket?.close();
    }
  }

  /// Bluetooth: Connect via flutter_thermal_printer → send bytes.
  /// Keeps connection alive for 30s to handle rapid consecutive prints
  /// (e.g., KOT + immediate bill print).
  Future<bool> _sendViaBluetooth(List<int> bytes, String address) async {
    try {
      final printer = Printer(address: address);
      await FlutterThermalPrinter.instance.connect(printer);
      await FlutterThermalPrinter.instance.printData(
        printer,
        bytes,
        longData: true, // Handles large receipts by chunking
      );
      // Delayed disconnect — keeps BLE link alive for follow-up prints
      Future.delayed(const Duration(seconds: 30), () {
        FlutterThermalPrinter.instance.disconnect(printer);
      });
      return true;
    } catch (e) {
      errorMessage = 'Bluetooth print failed: $e';
      return false;
    }
  }

  /// USB: Connect via flutter_thermal_printer platform channel → send bytes.
  /// Uses the same connect/printData API as Bluetooth, but with USB transport.
  Future<bool> _sendViaUsb(List<int> bytes, String address, String name) async {
    try {
      final printer = Printer(
        address: address,
        name: name,
        connectionType: ConnectionType.USB,
      );
      await FlutterThermalPrinter.instance.connect(printer);
      await FlutterThermalPrinter.instance.printData(
        printer,
        bytes,
        longData: true,
      );
      return true;
    } catch (e) {
      errorMessage = 'USB print failed: $e';
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Test Print
  // ══════════════════════════════════════════════════════════════════════════

  /// Sends a simple test ticket to verify the printer is working.
  /// Uses raw ESC/POS commands (no ReceiptBuilder needed).
  @action
  Future<bool> testPrint(SavedPrinterModel printer) async {
    // Raw ESC/POS byte commands for a simple test ticket
    final List<int> bytes = [
      0x1B, 0x40, // ESC @ — Initialize/reset printer
      0x1B, 0x61, 0x01, // ESC a 1 — Center alignment
      0x1B, 0x21, 0x30, // ESC ! 0x30 — Double height + double width
      ...'UniPOS\n'.codeUnits,
      0x1B, 0x21, 0x00, // ESC ! 0x00 — Normal text size
      ...'Test Print\n'.codeUnits,
      ...'-'.padRight(32, '-').codeUnits,
      ...'\n'.codeUnits,
      ...'Printer: ${printer.name}\n'.codeUnits,
      ...'Type: ${printer.type.toUpperCase()}\n'.codeUnits,
      ...'Paper: ${printer.paperSize}mm\n'.codeUnits,
      ...'Role: ${printer.role}\n'.codeUnits,
      ...'Status: Connected OK\n'.codeUnits,
      ...'-'.padRight(32, '-').codeUnits,
      ...'\n\n\n'.codeUnits,
      0x1D, 0x56, 0x01, // GS V 1 — Partial paper cut
    ];

    return await sendBytes(bytes, printer);
  }
}
