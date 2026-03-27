/// Platform-agnostic model representing a discovered printer device.
/// Replaces the `Printer` type from flutter_thermal_printer so that
/// web code never touches dart:ffi.
class DiscoveredPrinter {
  final String? name;
  final String? address;
  final String? vendorId;
  final String connectionType; // 'BLE' or 'USB'

  DiscoveredPrinter({
    this.name,
    this.address,
    this.vendorId,
    this.connectionType = 'BLE',
  });
}

/// Web stub — thermal printing is not available on web.
/// All discovery/print methods return gracefully with "not supported".
class ThermalPrinterService {
  Stream<List<DiscoveredPrinter>> get devicesStream =>
      Stream.value([]);

  Future<void> startBleScan() async {}
  Future<void> startUsbScan() async {}
  void stopScan() {}

  Future<void> connect(DiscoveredPrinter device) async {}
  Future<void> disconnect(DiscoveredPrinter device) async {}

  Future<bool> printData(DiscoveredPrinter device, List<int> bytes) async {
    return false;
  }

  /// WiFi printing via raw TCP socket — not available on web.
  Future<bool> sendViaWifi(List<int> bytes, String ip, int port) async {
    return false;
  }

  /// TCP connection test — not available on web.
  Future<bool> testWifiConnection(String ip, int port) async {
    return false;
  }

  bool get isSupported => false;
}