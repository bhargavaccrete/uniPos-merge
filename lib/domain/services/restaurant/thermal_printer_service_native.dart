import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer_platform_interface.dart';

import 'thermal_printer_service_stub.dart' show DiscoveredPrinter;
export 'thermal_printer_service_stub.dart' show DiscoveredPrinter;

// ── Helpers to convert between package Printer and our DiscoveredPrinter ──

DiscoveredPrinter _toDiscovered(Printer p) => DiscoveredPrinter(
      name: p.name,
      address: p.address,
      vendorId: p.vendorId,
      productId: p.productId,
      connectionType: p.connectionType == ConnectionType.USB ? 'USB' : 'BLE',
    );

Printer _toPackagePrinter(DiscoveredPrinter d) => Printer(
      name: d.name,
      address: d.address,
      // USB devices are identified by vendorId + productId (not an address).
      // Dropping either meant the native layer could never match the device →
      // connect/print silently no-op'd (no permission dialog, no output).
      vendorId: d.vendorId,
      productId: d.productId,
      connectionType: d.connectionType == 'USB'
          ? ConnectionType.USB
          : ConnectionType.BLE,
    );

/// Native implementation — wraps flutter_thermal_printer + dart:io Socket.
class ThermalPrinterService {
  final _instance = FlutterThermalPrinter.instance;

  Stream<List<DiscoveredPrinter>> get devicesStream =>
      _instance.devicesStream.map(
        (list) => list.map(_toDiscovered).toList(),
      );

  Future<void> startBleScan() async {
    await _instance.getPrinters(connectionTypes: [ConnectionType.BLE]);
  }

  Future<void> startUsbScan() async {
    debugPrint('[USB] startUsbScan → requesting USB printers…');
    await _instance.getPrinters(connectionTypes: [ConnectionType.USB]);
  }

  void stopScan() {
    _instance.stopScan();
  }

  Future<void> connect(DiscoveredPrinter device) async {
    await _instance.connect(_toPackagePrinter(device));
  }

  Future<void> disconnect(DiscoveredPrinter device) async {
    await _instance.disconnect(_toPackagePrinter(device));
  }

  Future<bool> printData(DiscoveredPrinter device, List<int> bytes) async {
    final isUsb = device.connectionType == 'USB';
    final printer = _toPackagePrinter(device);
    debugPrint('[USB] printData → type=${device.connectionType} name=${device.name} '
        'address=${device.address} vendorId=${device.vendorId} '
        'productId=${device.productId} bytes=${bytes.length}');
    try {
      // USB: printText() opens the device, requests permission, and writes on its
      // own — it never uses the event sink. Calling connect() first routes to the
      // package's sendDevice() → events.success(), which NPEs whenever no
      // devicesStream listener is active (i.e. any print outside an open scan).
      // connect() is only needed to establish the GATT link for Bluetooth, so we
      // skip it for USB and go straight to the write.
      if (!isUsb) {
        await _instance.connect(printer);
        debugPrint('[USB] connect OK → sending ${bytes.length} bytes');
      }
      await _instance.printData(printer, bytes, longData: true);
      debugPrint('[USB] printData SENT OK');
      return true;
    } catch (e, s) {
      debugPrint('[USB] printData FAILED: $e\n$s');
      rethrow;
    }
  }

  /// Whether the USB device is currently PRESENT (enumerated on the bus). Unlike
  /// isConnected, this is true even before permission is granted — so we don't
  /// block the first print that must trigger the permission dialog. Returns false
  /// only when the device is truly gone (unplugged). Fail-open on any error so a
  /// check failure never blocks a legitimate print.
  Future<bool> isUsbPresent(DiscoveredPrinter device) async {
    try {
      final raw = await FlutterThermalPrinterPlatform.instance.startUsbScan();
      final list = (raw as List?) ?? const [];
      for (final d in list) {
        final m = Map<String, dynamic>.from(d as Map);
        if (m['vendorId']?.toString() == device.vendorId &&
            m['productId']?.toString() == device.productId) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true; // can't determine → allow the print attempt
    }
  }

  /// WiFi: raw TCP socket → dump bytes → close.
  Future<bool> sendViaWifi(List<int> bytes, String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 5));
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
      return true;
    } finally {
      await socket?.close();
    }
  }

  /// TCP connect test (no data sent).
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

  bool get isSupported => true;
}