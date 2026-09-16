import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billberrylite/core/constants/hive_box_names.dart';
import 'package:billberrylite/core/constants/hive_type_ids.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/data/repositories/restaurant/printer_repository.dart';
import 'package:billberrylite/domain/services/common/windows_spooler/windows_spooler_service.dart';
import 'package:billberrylite/domain/services/restaurant/thermal_printer_service.dart';
import 'package:billberrylite/domain/store/restaurant/printer_store.dart';

/// The two Windows transports must stay strictly separated:
///
///   'windows'     → RAW ESC/POS through the spooler
///   'windows_pdf' → rendered receipt PDF, NEVER raw bytes
///
/// The second rule is the important one. A PDF writer accepts ESC/POS, throws
/// it away and reports success, so a RAW send there silently loses a bill —
/// that is the defect these tests pin shut.
class _RecordingSpoolWriter {
  int callCount = 0;
  String? lastQueueName;
  List<int>? lastBytes;

  Future<SpoolResult> call(
    String queue,
    List<int> data,
    String doc, {
    bool verifyDrained = false,
  }) async {
    callCount++;
    lastQueueName = queue;
    lastBytes = data;
    return const SpoolResult.success();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PrinterStore store;
  late _RecordingSpoolWriter spoolWriter;

  final ticket = <int>[0x1B, 0x40, 0x48, 0x49, 0x1D, 0x56, 0x01];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('printer_routing_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(HiveTypeIds.savedPrinter)) {
      Hive.registerAdapter(SavedPrinterModelAdapter());
    }
    await Hive.openBox<SavedPrinterModel>(HiveBoxNames.restaurantPrinters);
    SharedPreferences.setMockInitialValues({});

    spoolWriter = _RecordingSpoolWriter();
    store = PrinterStore(
      PrinterRepository(),
      ThermalPrinterService(),
      windowsSpooler: WindowsSpoolerService(writer: spoolWriter.call),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  SavedPrinterModel printer(String type, {String address = 'POS-80'}) =>
      SavedPrinterModel(
        id: 'p1',
        name: 'Counter',
        type: type,
        address: address,
        paperSize: 80,
        role: 'receipt',
      );

  group("type 'windows' → RAW spooler path", () {
    test('reaches the spooler and reports success', () async {
      final ok = await store.sendBytes(ticket, printer('windows'));

      expect(ok, isTrue);
      expect(spoolWriter.callCount, 1);
      expect(spoolWriter.lastBytes, equals(ticket));
    });

    test('passes a queue name containing a colon through whole', () async {
      await store.sendBytes(
        ticket,
        printer('windows', address: r'Printer on SERVER:2'),
      );

      // Splitting on ':' the way the WiFi path does would address a queue that
      // does not exist.
      expect(spoolWriter.lastQueueName, r'Printer on SERVER:2');
    });
  });

  group("type 'windows_pdf' → never the RAW spooler", () {
    test('does not invoke the spooler at all', () async {
      final ok = await store.sendBytes(ticket, printer('windows_pdf'));

      expect(ok, isFalse, reason: 'caller must fall back, not report success');
      expect(spoolWriter.callCount, 0,
          reason: 'ESC/POS must never reach a PDF writer');
    });

    test('sets a message so the caller can explain the fallback', () async {
      await store.sendBytes(ticket, printer('windows_pdf'));

      expect(store.errorMessage, isNotNull);
      expect(store.errorMessage, contains('PDF'));
    });

    test('holds even when delivery verification is requested', () async {
      // testPrint asks for verification; that must not open a RAW route.
      final ok = await store.sendBytes(
        ticket,
        printer('windows_pdf'),
        verifyDelivery: true,
      );

      expect(ok, isFalse);
      expect(spoolWriter.callCount, 0);
    });
  });

  group('the two Windows types are disjoint', () {
    test('a windows printer is not a windows_pdf printer', () {
      final raw = printer('windows');
      expect(raw.isWindows, isTrue);
      expect(raw.isWindowsPdf, isFalse);
    });

    test('a windows_pdf printer is not a windows printer', () {
      // If this ever overlapped, the RAW branch in sendBytes would capture PDF
      // printers before the guard could reject them.
      final pdf = printer('windows_pdf');
      expect(pdf.isWindowsPdf, isTrue);
      expect(pdf.isWindows, isFalse);
    });

    test('saveWindowsPrinter records the chosen mode, not a guessed one',
        () async {
      await store.saveWindowsPrinter(
        name: 'doPDF 11',
        queueName: 'doPDF 11',
        asPdfPrinter: true,
      );
      await store.saveWindowsPrinter(
        name: 'doPDF 11 as thermal',
        queueName: 'doPDF 11',
        asPdfPrinter: false,
      );

      final saved = store.savedPrinters;
      // Same queue name, opposite types — proving the type comes from the
      // explicit choice and never from the printer's name.
      expect(saved.firstWhere((p) => p.name == 'doPDF 11').type, 'windows_pdf');
      expect(
        saved.firstWhere((p) => p.name == 'doPDF 11 as thermal').type,
        'windows',
      );
    });

    test('windowsPrinters lists both Windows transports', () async {
      await store.saveWindowsPrinter(
          name: 'Thermal', queueName: 'POS-80', asPdfPrinter: false);
      await store.saveWindowsPrinter(
          name: 'Writer', queueName: 'doPDF 11', asPdfPrinter: true);

      expect(store.windowsPrinters.length, 2);
    });
  });
}
