import 'dart:async';
import 'dart:typed_data';
import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/restaurant/db/saved_printer_model.dart';
import '../../../data/repositories/restaurant/printer_repository.dart';
import 'package:flutter/foundation.dart';
import '../../services/restaurant/thermal_printer_service.dart';

part 'printer_store.g.dart';

/// MobX store pattern: public class = private mixin with generated code
class PrinterStore = _PrinterStore with _$PrinterStore;

abstract class _PrinterStore with Store {
  final PrinterRepository _repository;
  final ThermalPrinterService _thermalService;

  /// Repository + service are injected via constructor.
  _PrinterStore(this._repository, this._thermalService);

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED PRINTERS — persisted in Hive, survive app restarts
  // ══════════════════════════════════════════════════════════════════════════

  /// All saved printers from Hive (both BT and WiFi)
  @observable
  ObservableList<SavedPrinterModel> savedPrinters =
      ObservableList<SavedPrinterModel>();

  /// The printer assigned for KOT printing (kitchen ticket)
  @observable
  SavedPrinterModel? defaultKotPrinter;

  /// The printer assigned for receipt/bill printing
  @observable
  SavedPrinterModel? defaultReceiptPrinter;

  // ══════════════════════════════════════════════════════════════════════════
  // BLUETOOTH/USB DISCOVERY — transient state, not persisted
  // ══════════════════════════════════════════════════════════════════════════

  /// Devices found during scan (live, cleared on each new scan)
  @observable
  ObservableList<DiscoveredPrinter> discoveredDevices =
      ObservableList<DiscoveredPrinter>();

  /// True while BLE/USB scan is active
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

  /// True while bytes are being sent to a printer
  @observable
  bool isPrinting = false;

  StreamSubscription<List<DiscoveredPrinter>>? _scanSubscription;

  // ══════════════════════════════════════════════════════════════════════════
  // COMPUTED
  // ══════════════════════════════════════════════════════════════════════════

  @computed
  bool get hasDefaultKotPrinter => defaultKotPrinter != null;

  @computed
  bool get hasDefaultReceiptPrinter => defaultReceiptPrinter != null;

  @computed
  List<SavedPrinterModel> get bluetoothPrinters =>
      savedPrinters.where((p) => p.isBluetooth).toList();

  @computed
  List<SavedPrinterModel> get wifiPrinters =>
      savedPrinters.where((p) => p.isWifi).toList();

  /// Whether thermal printing is supported on this platform
  bool get isPrintingSupported => _thermalService.isSupported;

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Persistence (Hive CRUD)
  // ══════════════════════════════════════════════════════════════════════════

  @action
  Future<void> loadSavedPrinters() async {
    try {
      final printers = await _repository.getAllPrinters();
      savedPrinters = ObservableList.of(printers);

      defaultKotPrinter = await _repository.getDefaultPrinterForRole('kot');
      defaultReceiptPrinter =
          await _repository.getDefaultPrinterForRole('receipt');

    } catch (e) {
      errorMessage = 'Failed to load printers: $e';
    }
  }

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

  @action
  Future<void> addWifiPrinter({
    required String name,
    required String ip,
    int port = 9100,
    int paperSize = 80,
    String role = 'both',
    String? assignRole,
  }) async {
    final printer = SavedPrinterModel(
      id: const Uuid().v4(),
      name: name,
      type: 'wifi',
      address: '$ip:$port',
      paperSize: paperSize,
      role: role,
      isDefault: savedPrinters.isEmpty,
    );
    await savePrinter(printer);
    await _assignIfRequested(printer, assignRole);
  }

  /// Point a slot at a freshly saved printer.
  ///
  /// Restaurant leaves this null — its Printer Management slots do the
  /// assigning. Retail has exactly one slot (Billing) and no slot screen, so it
  /// passes `'receipt'`: saving a printer there IS choosing it. Without this the
  /// printer lands in Hive but no `default_*_printer_id` pointer ever gets set,
  /// so `hasDefaultReceiptPrinter` stays false and nothing ever prints.
  Future<void> _assignIfRequested(
      SavedPrinterModel printer, String? assignRole) async {
    if (assignRole == null) return;
    // 'both' keeps the record valid for whichever slot(s) point at it.
    await savePrinter(printer.copyWith(role: 'both'));
    await setDefaultForRole(printer.id, assignRole);
  }

  @action
  Future<bool> testWifiConnection(String ip, int port) async {
    return _thermalService.testWifiConnection(ip, port);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Bluetooth Discovery & Save
  // ══════════════════════════════════════════════════════════════════════════

  @action
  Future<void> startBluetoothScan() async {
    if (isScanning) return;
    isScanning = true;
    errorMessage = null;
    discoveredDevices.clear();

    try {
      await _thermalService.startBleScan();

      _scanSubscription?.cancel();
      _scanSubscription = _thermalService.devicesStream.listen(
        (List<DiscoveredPrinter> printers) {
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
    _thermalService.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning = false;
  }

  @action
  Future<void> startUsbScan() async {
    if (isScanning) return;
    isScanning = true;
    errorMessage = null;
    discoveredDevices.clear();

    try {
      await _thermalService.startUsbScan();

      _scanSubscription?.cancel();
      _scanSubscription = _thermalService.devicesStream.listen(
        (List<DiscoveredPrinter> printers) {
          debugPrint('[USB] scan found ${printers.length} device(s): '
              '${printers.map((p) => '${p.name}(vid=${p.vendorId})').join(', ')}');
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

  @action
  Future<void> saveUsbPrinter({
    required DiscoveredPrinter device,
    required String name,
    int paperSize = 80,
    String role = 'both',
    String? assignRole,
  }) async {
    final printer = SavedPrinterModel(
      id: const Uuid().v4(),
      name: name,
      type: 'usb',
      // USB identity = "vendorId:productId" (mirrors WiFi's "ip:port"). Both are
      // required for the native layer to match and open the device.
      address:
          '${device.vendorId ?? device.address ?? ''}:${device.productId ?? ''}',
      paperSize: paperSize,
      role: role,
    );
    await savePrinter(printer);
    await _assignIfRequested(printer, assignRole);
  }

  @action
  Future<void> saveBluetoothPrinter({
    required DiscoveredPrinter device,
    required String name,
    int paperSize = 80,
    String role = 'both',
    String? assignRole,
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
    await _assignIfRequested(printer, assignRole);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Sending Bytes to Printer
  // ══════════════════════════════════════════════════════════════════════════

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

  Future<bool> _sendViaWifi(List<int> bytes, String address) async {
    final parts = address.split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

    try {
      return await _thermalService.sendViaWifi(bytes, ip, port);
    } catch (e) {
      errorMessage = 'WiFi print failed ($ip:$port): $e';
      return false;
    }
  }

  Future<bool> _sendViaBluetooth(List<int> bytes, String address) async {
    try {
      final device = DiscoveredPrinter(address: address, connectionType: 'BLE');
      await _thermalService.printData(device, bytes);
      // Delayed disconnect — keeps BLE link alive for follow-up prints
      Future.delayed(const Duration(seconds: 30), () {
        _thermalService.disconnect(device);
      });
      return true;
    } catch (e) {
      errorMessage = 'Bluetooth print failed: $e';
      return false;
    }
  }

  Future<bool> _sendViaUsb(
      List<int> bytes, String address, String name) async {
    try {
      // A saved USB printer stores its identity as "vendorId:productId". The
      // native layer matches on BOTH, so split them back out here — passing only
      // the vendorId made the match fail (device not found → silent no-op).
      final parts = address.split(':');
      final vendorId = parts.isNotEmpty ? parts[0] : address;
      final productId = parts.length > 1 ? parts[1] : '';
      final device = DiscoveredPrinter(
        address: address,
        vendorId: vendorId,
        productId: productId,
        name: name,
        connectionType: 'USB',
      );
      debugPrint('[USB] _sendViaUsb → vendorId=$vendorId productId=$productId '
          'name=$name bytes=${bytes.length}');
      if (productId.isEmpty) {
        debugPrint('[USB] ⚠ no productId stored — re-add this printer '
            '(old saved entry). Print will not reach the device.');
      }
      // The plugin reports success even when the USB device is gone, so verify
      // the device is still PRESENT first. (Presence, not permission — so the
      // first print can still raise the OS permission dialog.) If it's unplugged,
      // fail cleanly so the caller shows the PDF instead of a false "printed".
      if (!await _thermalService.isUsbPresent(device)) {
        errorMessage = 'Printer not available';
        debugPrint('[USB] device not present (unplugged) — caller shows PDF');
        return false;
      }
      return await _thermalService.printData(device, bytes);
    } catch (e) {
      errorMessage = 'USB print failed: $e';
      debugPrint('[USB] _sendViaUsb FAILED: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS — Test Print
  // ══════════════════════════════════════════════════════════════════════════

  @action
  Future<bool> testPrint(SavedPrinterModel printer) async {
    final List<int> bytes = [
      0x1B, 0x40,
      0x1B, 0x61, 0x01,
      0x1B, 0x21, 0x30,
      ...'Bill Berry Lite\n'.codeUnits,
      0x1B, 0x21, 0x00,
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
      0x1D, 0x56, 0x01,
    ];

    return await sendBytes(bytes, printer);
  }
}