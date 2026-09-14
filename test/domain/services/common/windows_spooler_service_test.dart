import 'package:flutter_test/flutter_test.dart';
import 'package:billberrylite/domain/services/common/windows_spooler/windows_spooler_service.dart';

/// The Windows spooler transport cannot be validated against hardware here, so
/// the writer is injected and every failure the Win32 API can report is
/// exercised through a fake. What these tests pin:
///
///  - the ESC/POS payload reaches the writer byte-for-byte (a mangled payload
///    would print garbage or skip the cut command),
///  - the queue name is passed through WHOLE — Windows names may contain a
///    colon, unlike the WiFi path's `ip:port`,
///  - every failure returns ok:false with a message, so callers fall back to
///    the PDF preview instead of reporting a bill as printed.

/// Records what the service handed down, and returns whatever it was primed
/// with. Hand-written because this repo has no mocking package.
class _FakeSpoolWriter {
  String? queueName;
  List<int>? bytes;
  String? docName;
  int callCount = 0;

  bool? sawVerifyDrained;

  SpoolResult result;
  Object? throwThis;

  _FakeSpoolWriter({SpoolResult? result, this.throwThis})
      : result = result ?? const SpoolResult.success();

  Future<SpoolResult> call(
    String queue,
    List<int> data,
    String doc, {
    bool verifyDrained = false,
  }) async {
    callCount++;
    queueName = queue;
    bytes = data;
    docName = doc;
    sawVerifyDrained = verifyDrained;
    if (throwThis != null) throw throwThis!;
    return result;
  }
}

void main() {
  // A miniature but realistic ticket: init, centre, text, feed, partial cut.
  final ticket = <int>[
    0x1B, 0x40,
    0x1B, 0x61, 0x01,
    0x48, 0x49,
    0x0A, 0x0A,
    0x1D, 0x56, 0x01,
  ];

  group('WindowsSpoolerService.send — success', () {
    test('passes the bytes through untouched', () async {
      final fake = _FakeSpoolWriter(
        result: const SpoolResult.success(bytesWritten: 12),
      );
      final service = WindowsSpoolerService(writer: fake.call);

      final result = await service.send(queueName: 'POS-80', bytes: ticket);

      expect(result.ok, isTrue);
      expect(fake.bytes, equals(ticket));
      // The cut command must survive — losing it is the whole reason RAW is
      // used instead of printing a PDF through the driver.
      expect(fake.bytes!.sublist(fake.bytes!.length - 3), [0x1D, 0x56, 0x01]);
    });

    test('passes a queue name containing a colon through whole', () async {
      // The WiFi path splits address on ':' to get ip/port. Doing that here
      // would address the wrong queue, or none at all.
      final fake = _FakeSpoolWriter();
      final service = WindowsSpoolerService(writer: fake.call);

      await service.send(queueName: r'Printer on SERVER:2', bytes: ticket);

      expect(fake.queueName, r'Printer on SERVER:2');
    });

    test('uses the supplied document name', () async {
      final fake = _FakeSpoolWriter();
      final service = WindowsSpoolerService(writer: fake.call);

      await service.send(
        queueName: 'POS-80',
        bytes: ticket,
        docName: 'KOT 12',
      );

      expect(fake.docName, 'KOT 12');
    });
  });

  group('Win32 error code mapping', () {
    test('printer-not-found codes all collapse to printerNotFound', () {
      expect(spoolErrorFromWin32(errorFileNotFound), SpoolError.printerNotFound);
      expect(spoolErrorFromWin32(errorInvalidPrinterName),
          SpoolError.printerNotFound);
      expect(spoolErrorFromWin32(errorPrinterDeleted),
          SpoolError.printerNotFound);
    });

    test('maps the remaining known codes', () {
      expect(spoolErrorFromWin32(errorAccessDenied), SpoolError.accessDenied);
      expect(spoolErrorFromWin32(errorInvalidHandle), SpoolError.invalidHandle);
      expect(spoolErrorFromWin32(errorNotReady), SpoolError.printerOffline);
    });

    test('an unrecognised code falls back rather than throwing', () {
      expect(spoolErrorFromWin32(999999), SpoolError.unknown);
      expect(spoolErrorFromWin32(0), SpoolError.unknown);
    });

    test('every error has a non-empty message', () {
      for (final e in SpoolError.values) {
        expect(spoolErrorMessage(e), isNotEmpty, reason: '$e has no message');
      }
    });

    test('SpoolResult.fromWin32 keeps the raw code for logs', () {
      final r = SpoolResult.fromWin32(errorAccessDenied);
      expect(r.ok, isFalse);
      expect(r.error, SpoolError.accessDenied);
      expect(r.win32Code, errorAccessDenied);
      expect(r.message, isNotEmpty);
    });
  });

  group('delivery verification flag', () {
    test('defaults to off, so ordinary bills are not delayed', () async {
      final fake = _FakeSpoolWriter();
      await WindowsSpoolerService(writer: fake.call)
          .send(queueName: 'POS-80', bytes: ticket);

      expect(fake.sawVerifyDrained, isFalse);
    });

    test('is forwarded when the caller asks to verify', () async {
      final fake = _FakeSpoolWriter();
      await WindowsSpoolerService(writer: fake.call).send(
        queueName: 'POS-80',
        bytes: ticket,
        verifyDrained: true,
      );

      expect(fake.sawVerifyDrained, isTrue);
    });
  });

  group('disconnected-printer failures', () {
    // The spooler ACCEPTS work for a printer that is switched off — it queues
    // it — and Windows still reports PRINTER_STATUS_NORMAL. Confirmed on a real
    // machine: two Test Print jobs sat unprinted while the app reported
    // success. These two errors are what turns that into a PDF fallback.
    test('a backed-up queue fails instead of piling on', () async {
      final fake = _FakeSpoolWriter(
        result: SpoolResult.failure(
          SpoolError.queueBacklogged,
          message: 'Printer not responding — 2 earlier prints are still waiting',
        ),
      );
      final r = await WindowsSpoolerService(writer: fake.call)
          .send(queueName: 'POS-80', bytes: ticket);

      expect(r.ok, isFalse);
      expect(r.error, SpoolError.queueBacklogged);
      expect(r.message, contains('still waiting'));
    });

    test('a job that never leaves the queue is not a successful print', () async {
      final fake = _FakeSpoolWriter(
        result: SpoolResult.failure(SpoolError.jobStuck, bytesWritten: 196),
      );
      final r = await WindowsSpoolerService(writer: fake.call).send(
        queueName: 'POS-80',
        bytes: ticket,
        verifyDrained: true,
      );

      expect(r.ok, isFalse);
      expect(r.error, SpoolError.jobStuck);
      // Bytes were accepted by the spooler — that is exactly the trap.
      expect(r.bytesWritten, 196);
      expect(r.message, isNotEmpty);
    });
  });

  group('failure paths', () {
    Future<SpoolResult> sendWith(SpoolResult primed) {
      final fake = _FakeSpoolWriter(result: primed);
      return WindowsSpoolerService(writer: fake.call)
          .send(queueName: 'POS-80', bytes: ticket);
    }

    test('printer not found', () async {
      final r = await sendWith(SpoolResult.fromWin32(errorInvalidPrinterName));
      expect(r.ok, isFalse);
      expect(r.error, SpoolError.printerNotFound);
      expect(r.message, isNotEmpty);
    });

    test('access denied', () async {
      final r = await sendWith(SpoolResult.fromWin32(errorAccessDenied));
      expect(r.ok, isFalse);
      expect(r.error, SpoolError.accessDenied);
    });

    test('printer offline', () async {
      final r = await sendWith(SpoolResult.fromWin32(errorNotReady));
      expect(r.ok, isFalse);
      expect(r.error, SpoolError.printerOffline);
    });

    test('a short write is a failure, not a success', () async {
      // The spooler can accept fewer bytes than offered without raising an
      // error. Reporting that as printed would show a half-bill as complete.
      final r = await sendWith(
        SpoolResult.failure(SpoolError.partialWrite, bytesWritten: 4),
      );
      expect(r.ok, isFalse);
      expect(r.error, SpoolError.partialWrite);
      expect(r.bytesWritten, 4);
    });

    test('a throwing writer is caught, not propagated', () async {
      // A crash here must degrade to the PDF fallback, never take out the sale.
      final fake = _FakeSpoolWriter(throwThis: StateError('handle closed'));
      final service = WindowsSpoolerService(writer: fake.call);

      final r = await service.send(queueName: 'POS-80', bytes: ticket);

      expect(r.ok, isFalse);
      expect(r.error, SpoolError.unknown);
      expect(r.message, contains('handle closed'));
    });
  });

  group('guards before the writer is reached', () {
    test('an empty queue name never reaches the writer', () async {
      final fake = _FakeSpoolWriter();
      final r = await WindowsSpoolerService(writer: fake.call)
          .send(queueName: '   ', bytes: ticket);

      expect(r.ok, isFalse);
      expect(r.error, SpoolError.printerNotFound);
      expect(fake.callCount, 0);
    });

    test('an empty payload never reaches the writer', () async {
      final fake = _FakeSpoolWriter();
      final r = await WindowsSpoolerService(writer: fake.call)
          .send(queueName: 'POS-80', bytes: const []);

      expect(r.ok, isFalse);
      expect(r.error, SpoolError.writeFailed);
      expect(fake.callCount, 0);
    });
  });

  group('isLikelyVirtualQueue', () {
    test('flags the queues Windows ships with', () {
      expect(isLikelyVirtualQueue('Microsoft XPS Document Writer'), isTrue);
      expect(isLikelyVirtualQueue('Microsoft Print to PDF'), isTrue);
      expect(isLikelyVirtualQueue('Fax'), isTrue);
      expect(isLikelyVirtualQueue('OneNote (Desktop)'), isTrue);
      expect(isLikelyVirtualQueue('Adobe PDF'), isTrue);
    });

    test('matches on the driver name too', () {
      expect(
        isLikelyVirtualQueue('Office Printer', 'Microsoft XPS Document Writer'),
        isTrue,
      );
    });

    // Ground truth from `Get-Printer` on a real Windows dev machine
    // (2026-09-14). Pinned because inventing queue names missed 'doPDF 11',
    // which installs under the 'novaPDF' driver and matched no keyword.
    test('classifies a real Windows queue list correctly', () {
      const virtual = <(String, String)>[
        ('OneNote (Desktop)', 'Send to Microsoft OneNote 16 Driver'),
        ('Microsoft XPS Document Writer', 'Microsoft XPS Document Writer v4'),
        ('Microsoft Print to PDF', 'Microsoft Print To PDF'),
        ('Fax', 'Microsoft Shared Fax Driver'),
        ('doPDF 11', 'novaPDF 11'),
      ];
      const physical = <(String, String)>[
        ('Essae PR-55', 'Essae PR-55'),
        ('80mm Series Printer', '80mm Series Printer'),
        ('80mm Series Printer (Copy 1)', '80mm Series Printer'),
      ];

      for (final (name, driver) in virtual) {
        expect(isLikelyVirtualQueue(name, driver), isTrue,
            reason: '"$name" should sort to the bottom');
      }
      for (final (name, driver) in physical) {
        expect(isLikelyVirtualQueue(name, driver), isFalse,
            reason: '"$name" is a real printer and must not be buried');
      }
    });

    test('does not flag plausible thermal printers', () {
      // A false positive buries a real printer at the bottom of the picker.
      expect(isLikelyVirtualQueue('POS-80'), isFalse);
      expect(isLikelyVirtualQueue('TM-T82'), isFalse);
      expect(isLikelyVirtualQueue('EPSON TM-T20III Receipt'), isFalse);
      expect(isLikelyVirtualQueue('XP-58 Thermal'), isFalse);
      expect(isLikelyVirtualQueue('Counter Printer', 'Generic / Text Only'),
          isFalse);
    });
  });
}
