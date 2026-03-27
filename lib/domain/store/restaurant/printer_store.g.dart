// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PrinterStore on _PrinterStore, Store {
  Computed<bool>? _$hasDefaultKotPrinterComputed;

  @override
  bool get hasDefaultKotPrinter => (_$hasDefaultKotPrinterComputed ??=
          Computed<bool>(() => super.hasDefaultKotPrinter,
              name: '_PrinterStore.hasDefaultKotPrinter'))
      .value;
  Computed<bool>? _$hasDefaultReceiptPrinterComputed;

  @override
  bool get hasDefaultReceiptPrinter => (_$hasDefaultReceiptPrinterComputed ??=
          Computed<bool>(() => super.hasDefaultReceiptPrinter,
              name: '_PrinterStore.hasDefaultReceiptPrinter'))
      .value;
  Computed<List<SavedPrinterModel>>? _$bluetoothPrintersComputed;

  @override
  List<SavedPrinterModel> get bluetoothPrinters =>
      (_$bluetoothPrintersComputed ??= Computed<List<SavedPrinterModel>>(
              () => super.bluetoothPrinters,
              name: '_PrinterStore.bluetoothPrinters'))
          .value;
  Computed<List<SavedPrinterModel>>? _$wifiPrintersComputed;

  @override
  List<SavedPrinterModel> get wifiPrinters => (_$wifiPrintersComputed ??=
          Computed<List<SavedPrinterModel>>(() => super.wifiPrinters,
              name: '_PrinterStore.wifiPrinters'))
      .value;

  late final _$savedPrintersAtom =
      Atom(name: '_PrinterStore.savedPrinters', context: context);

  @override
  ObservableList<SavedPrinterModel> get savedPrinters {
    _$savedPrintersAtom.reportRead();
    return super.savedPrinters;
  }

  @override
  set savedPrinters(ObservableList<SavedPrinterModel> value) {
    _$savedPrintersAtom.reportWrite(value, super.savedPrinters, () {
      super.savedPrinters = value;
    });
  }

  late final _$defaultKotPrinterAtom =
      Atom(name: '_PrinterStore.defaultKotPrinter', context: context);

  @override
  SavedPrinterModel? get defaultKotPrinter {
    _$defaultKotPrinterAtom.reportRead();
    return super.defaultKotPrinter;
  }

  @override
  set defaultKotPrinter(SavedPrinterModel? value) {
    _$defaultKotPrinterAtom.reportWrite(value, super.defaultKotPrinter, () {
      super.defaultKotPrinter = value;
    });
  }

  late final _$defaultReceiptPrinterAtom =
      Atom(name: '_PrinterStore.defaultReceiptPrinter', context: context);

  @override
  SavedPrinterModel? get defaultReceiptPrinter {
    _$defaultReceiptPrinterAtom.reportRead();
    return super.defaultReceiptPrinter;
  }

  @override
  set defaultReceiptPrinter(SavedPrinterModel? value) {
    _$defaultReceiptPrinterAtom.reportWrite(value, super.defaultReceiptPrinter,
        () {
      super.defaultReceiptPrinter = value;
    });
  }

  late final _$discoveredDevicesAtom =
      Atom(name: '_PrinterStore.discoveredDevices', context: context);

  @override
  ObservableList<DiscoveredPrinter> get discoveredDevices {
    _$discoveredDevicesAtom.reportRead();
    return super.discoveredDevices;
  }

  @override
  set discoveredDevices(ObservableList<DiscoveredPrinter> value) {
    _$discoveredDevicesAtom.reportWrite(value, super.discoveredDevices, () {
      super.discoveredDevices = value;
    });
  }

  late final _$isScanningAtom =
      Atom(name: '_PrinterStore.isScanning', context: context);

  @override
  bool get isScanning {
    _$isScanningAtom.reportRead();
    return super.isScanning;
  }

  @override
  set isScanning(bool value) {
    _$isScanningAtom.reportWrite(value, super.isScanning, () {
      super.isScanning = value;
    });
  }

  late final _$isConnectingAtom =
      Atom(name: '_PrinterStore.isConnecting', context: context);

  @override
  bool get isConnecting {
    _$isConnectingAtom.reportRead();
    return super.isConnecting;
  }

  @override
  set isConnecting(bool value) {
    _$isConnectingAtom.reportWrite(value, super.isConnecting, () {
      super.isConnecting = value;
    });
  }

  late final _$connectionStatusAtom =
      Atom(name: '_PrinterStore.connectionStatus', context: context);

  @override
  String get connectionStatus {
    _$connectionStatusAtom.reportRead();
    return super.connectionStatus;
  }

  @override
  set connectionStatus(String value) {
    _$connectionStatusAtom.reportWrite(value, super.connectionStatus, () {
      super.connectionStatus = value;
    });
  }

  late final _$errorMessageAtom =
      Atom(name: '_PrinterStore.errorMessage', context: context);

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$isPrintingAtom =
      Atom(name: '_PrinterStore.isPrinting', context: context);

  @override
  bool get isPrinting {
    _$isPrintingAtom.reportRead();
    return super.isPrinting;
  }

  @override
  set isPrinting(bool value) {
    _$isPrintingAtom.reportWrite(value, super.isPrinting, () {
      super.isPrinting = value;
    });
  }

  late final _$loadSavedPrintersAsyncAction =
      AsyncAction('_PrinterStore.loadSavedPrinters', context: context);

  @override
  Future<void> loadSavedPrinters() {
    return _$loadSavedPrintersAsyncAction.run(() => super.loadSavedPrinters());
  }

  late final _$savePrinterAsyncAction =
      AsyncAction('_PrinterStore.savePrinter', context: context);

  @override
  Future<void> savePrinter(SavedPrinterModel printer) {
    return _$savePrinterAsyncAction.run(() => super.savePrinter(printer));
  }

  late final _$deletePrinterAsyncAction =
      AsyncAction('_PrinterStore.deletePrinter', context: context);

  @override
  Future<void> deletePrinter(String id) {
    return _$deletePrinterAsyncAction.run(() => super.deletePrinter(id));
  }

  late final _$setDefaultForRoleAsyncAction =
      AsyncAction('_PrinterStore.setDefaultForRole', context: context);

  @override
  Future<void> setDefaultForRole(String printerId, String role) {
    return _$setDefaultForRoleAsyncAction
        .run(() => super.setDefaultForRole(printerId, role));
  }

  late final _$addWifiPrinterAsyncAction =
      AsyncAction('_PrinterStore.addWifiPrinter', context: context);

  @override
  Future<void> addWifiPrinter(
      {required String name,
      required String ip,
      int port = 9100,
      int paperSize = 80,
      String role = 'both'}) {
    return _$addWifiPrinterAsyncAction.run(() => super.addWifiPrinter(
        name: name, ip: ip, port: port, paperSize: paperSize, role: role));
  }

  late final _$testWifiConnectionAsyncAction =
      AsyncAction('_PrinterStore.testWifiConnection', context: context);

  @override
  Future<bool> testWifiConnection(String ip, int port) {
    return _$testWifiConnectionAsyncAction
        .run(() => super.testWifiConnection(ip, port));
  }

  late final _$startBluetoothScanAsyncAction =
      AsyncAction('_PrinterStore.startBluetoothScan', context: context);

  @override
  Future<void> startBluetoothScan() {
    return _$startBluetoothScanAsyncAction
        .run(() => super.startBluetoothScan());
  }

  late final _$startUsbScanAsyncAction =
      AsyncAction('_PrinterStore.startUsbScan', context: context);

  @override
  Future<void> startUsbScan() {
    return _$startUsbScanAsyncAction.run(() => super.startUsbScan());
  }

  late final _$saveUsbPrinterAsyncAction =
      AsyncAction('_PrinterStore.saveUsbPrinter', context: context);

  @override
  Future<void> saveUsbPrinter(
      {required DiscoveredPrinter device,
      required String name,
      int paperSize = 80,
      String role = 'both'}) {
    return _$saveUsbPrinterAsyncAction.run(() => super.saveUsbPrinter(
        device: device, name: name, paperSize: paperSize, role: role));
  }

  late final _$saveBluetoothPrinterAsyncAction =
      AsyncAction('_PrinterStore.saveBluetoothPrinter', context: context);

  @override
  Future<void> saveBluetoothPrinter(
      {required DiscoveredPrinter device,
      required String name,
      int paperSize = 80,
      String role = 'both'}) {
    return _$saveBluetoothPrinterAsyncAction.run(() => super
        .saveBluetoothPrinter(
            device: device, name: name, paperSize: paperSize, role: role));
  }

  late final _$sendBytesAsyncAction =
      AsyncAction('_PrinterStore.sendBytes', context: context);

  @override
  Future<bool> sendBytes(List<int> bytes, SavedPrinterModel printer) {
    return _$sendBytesAsyncAction.run(() => super.sendBytes(bytes, printer));
  }

  late final _$testPrintAsyncAction =
      AsyncAction('_PrinterStore.testPrint', context: context);

  @override
  Future<bool> testPrint(SavedPrinterModel printer) {
    return _$testPrintAsyncAction.run(() => super.testPrint(printer));
  }

  late final _$_PrinterStoreActionController =
      ActionController(name: '_PrinterStore', context: context);

  @override
  void stopScan() {
    final _$actionInfo = _$_PrinterStoreActionController.startAction(
        name: '_PrinterStore.stopScan');
    try {
      return super.stopScan();
    } finally {
      _$_PrinterStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
savedPrinters: ${savedPrinters},
defaultKotPrinter: ${defaultKotPrinter},
defaultReceiptPrinter: ${defaultReceiptPrinter},
discoveredDevices: ${discoveredDevices},
isScanning: ${isScanning},
isConnecting: ${isConnecting},
connectionStatus: ${connectionStatus},
errorMessage: ${errorMessage},
isPrinting: ${isPrinting},
hasDefaultKotPrinter: ${hasDefaultKotPrinter},
hasDefaultReceiptPrinter: ${hasDefaultReceiptPrinter},
bluetoothPrinters: ${bluetoothPrinters},
wifiPrinters: ${wifiPrinters}
    ''';
  }
}
