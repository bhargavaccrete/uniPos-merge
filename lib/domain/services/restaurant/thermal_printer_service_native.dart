import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

import 'thermal_printer_service_stub.dart' show DiscoveredPrinter;
export 'thermal_printer_service_stub.dart' show DiscoveredPrinter;

// ── Helpers to convert between package Printer and our DiscoveredPrinter ──

DiscoveredPrinter _toDiscovered(Printer p) => DiscoveredPrinter(
      name: p.name,
      address: p.address,
      vendorId: p.vendorId,
      connectionType: p.connectionType == ConnectionType.USB ? 'USB' : 'BLE',
    );

Printer _toPackagePrinter(DiscoveredPrinter d) => Printer(
      name: d.name,
      address: d.address,
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
    final printer = _toPackagePrinter(device);
    await _instance.connect(printer);
    await _instance.printData(printer, bytes, longData: true);
    return true;
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