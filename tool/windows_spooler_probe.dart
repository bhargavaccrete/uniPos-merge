// ignore_for_file: avoid_print — this is a CLI probe; print IS its output.
//
// No-hardware validation of the Windows spooler FFI path.
//
//   dart run tool/windows_spooler_probe.dart
//
// Spools NO print job. It opens and closes real queue handles, and drives the
// real production writer only against queue names that do not exist, so the
// failure path is exercised end to end without paper.
//
// This exists because `platformRawSpoolWrite` cannot be reached from
// `flutter test` (the Dart VM has no plugin registrant, and the FFI needs a
// real Windows spooler). Keep it runnable — when a physical printer arrives,
// it is the quickest way to confirm the queue is reachable before printing.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'package:billberrylite/domain/services/common/windows_spooler/raw_spool_writer_io.dart';
import 'package:billberrylite/domain/services/common/windows_spooler/spool_result.dart';

/// Opens and immediately closes a queue handle. Proves the binding, the UTF-16
/// marshalling of the queue name, and the handle lifecycle — without StartDoc,
/// so nothing is ever queued.
({bool ok, int code}) probeOpenClose(String queueName) {
  final handle = calloc<IntPtr>();
  final namePtr = queueName.toNativeUtf16();
  try {
    if (OpenPrinter(namePtr, handle, nullptr) == 0) {
      return (ok: false, code: GetLastError());
    }
    ClosePrinter(handle.value);
    return (ok: true, code: 0);
  } finally {
    calloc.free(handle);
    calloc.free(namePtr);
  }
}

Future<void> main(List<String> args) async {
  if (!Platform.isWindows) {
    stderr.writeln('Windows only.');
    exitCode = 1;
    return;
  }

  // Queue names may be passed as args; otherwise probe a safe default set.
  final queues = args.isNotEmpty
      ? args
      : const ['Microsoft Print to PDF', 'Fax'];

  print('=== 1. OpenPrinter/ClosePrinter against real queues (no job) ===');
  for (final q in queues) {
    final r = probeOpenClose(q);
    print(r.ok
        ? '  OK      "$q"'
        : '  FAIL    "$q" -> win32 ${r.code} (${spoolErrorFromWin32(r.code)})');
  }

  print('\n=== 2. Production writer vs a queue that does not exist ===');
  final missing = await platformRawSpoolWrite(
    'No Such Printer 12345',
    const [0x1B, 0x40],
    'Probe',
  );
  print('  ok      : ${missing.ok}          (expected false)');
  print('  error   : ${missing.error}   (expected printerNotFound)');
  print('  win32   : ${missing.win32Code}           (expected 1801)');
  print('  message : "${missing.message}"');

  print('\n=== 2b. Raw OpenPrinter diagnostics ===');
  for (final bogus in ['No Such Printer 12345', r'Printer on SERVER:2']) {
    final handle = calloc<IntPtr>();
    final namePtr = bogus.toNativeUtf16();
    final rc = OpenPrinter(namePtr, handle, nullptr);
    final err = GetLastError();
    print('  "$bogus" -> OpenPrinter rc=$rc lastError=$err');
    if (rc != 0) ClosePrinter(handle.value);
    calloc.free(handle);
    calloc.free(namePtr);
  }

  // Only runs with --try-write, because on a HEALTHY queue it really does
  // spool a job. On a backed-up queue the pre-flight check bails first, which
  // is exactly what this verifies.
  if (args.contains('--try-write')) {
    final target = queues.first;
    print('\n=== 2c. Real write against "$target" ===');
    final r = await platformRawSpoolWrite(
      target,
      const [0x1B, 0x40],
      'Probe backlog check',
    );
    print('  ok      : ${r.ok}');
    print('  error   : ${r.error}');
    print('  message : "${r.message}"');
    print('  -> queueBacklogged means the pre-flight caught a stalled printer');
    print('     and NO new job was added.');
  }

  print('\n=== 3. A queue name containing a colon is not split ===');
  final colon = await platformRawSpoolWrite(
    r'Printer on SERVER:2',
    const [0x1B, 0x40],
    'Probe',
  );
  print('  ok      : ${colon.ok}          (expected false)');
  print('  error   : ${colon.error}   (the point: it tried the WHOLE name,');
  print('                                   not a truncated "Printer on SERVER")');
}
