import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'spool_result.dart';

bool _lastErrorWarm = false;

/// Force `GetLastError`'s lazy FFI binding to resolve BEFORE any call whose
/// error we care about.
///
/// `package:win32` binds each function through a top-level `final` that runs
/// `DynamicLibrary.open` + `lookupFunction` on first use. If that resolution
/// happens *after* a failing `OpenPrinter`, the `LoadLibrary`/`GetProcAddress`
/// it performs resets the thread's last-error to 0 — so the first spooler
/// failure in a process reported `unknown` / "Print failed" instead of the real
/// 1801 / "Printer not found in Windows". Verified on a real machine via
/// `tool/windows_spooler_probe.dart`; every later call was already correct.
void _warmUpLastError() {
  if (_lastErrorWarm) return;
  GetLastError();
  _lastErrorWarm = true;
}

/// Jobs currently sitting in this queue (`PRINTER_INFO_2.cJobs`).
///
/// Returns 0 when the query itself fails — an unreadable queue must not block
/// printing, since the write below will report its own error anyway.
int _pendingJobCount(int handle) {
  final needed = calloc<Uint32>();
  try {
    // First call sizes the buffer; it is expected to "fail" with
    // ERROR_INSUFFICIENT_BUFFER.
    GetPrinter(handle, 2, nullptr, 0, needed);
    if (needed.value == 0) return 0;

    final buffer = calloc<Uint8>(needed.value);
    try {
      if (GetPrinter(handle, 2, buffer, needed.value, needed) == 0) return 0;
      return buffer.cast<PRINTER_INFO_2>().ref.cJobs;
    } finally {
      calloc.free(buffer);
    }
  } catch (_) {
    return 0;
  } finally {
    calloc.free(needed);
  }
}

/// True once [jobId] has left the queue.
///
/// `GetJob` failing is the success signal: the spooler deletes a job record
/// once it has been delivered, so "job not found" means it reached the device.
/// A disconnected printer keeps the record indefinitely — and reports
/// `PRINTER_STATUS_NORMAL` while doing so, which is why polling the job is the
/// only reliable check.
Future<bool> _waitForJobToDrain(
  int handle,
  int jobId, {
  Duration timeout = const Duration(milliseconds: 2000),
  Duration interval = const Duration(milliseconds: 150),
}) async {
  final deadline = DateTime.now().add(timeout);
  final needed = calloc<Uint32>();
  try {
    while (DateTime.now().isBefore(deadline)) {
      needed.value = 0;
      GetJob(handle, jobId, 1, nullptr, 0, needed);
      if (needed.value == 0) return true; // record gone → delivered
      await Future<void>.delayed(interval);
    }
    return false;
  } catch (_) {
    // Never let the check itself fail a print that the spooler accepted.
    return true;
  } finally {
    calloc.free(needed);
  }
}

/// Sends [bytes] to the Windows print queue [queueName] as a RAW spool job.
///
/// `pDatatype: 'RAW'` is the whole trick — it tells the spooler not to hand the
/// data to the printer driver for rendering, but to pipe it to the port
/// verbatim. That keeps the ESC/POS payload (cut command included) intact,
/// while Windows still handles the port, whether the printer is attached over
/// USB, Bluetooth SPP or the network.
///
/// This file is compiled on Android and Linux too (`dart.library.io` is true
/// there), so the platform guard below is what actually keeps the FFI
/// Windows-only. `win32` resolves its DLL lazily, so merely importing it on
/// another platform is harmless as long as nothing is called.
Future<SpoolResult> platformRawSpoolWrite(
  String queueName,
  List<int> bytes,
  String docName, {
  bool verifyDrained = false,
}) async {
  if (!Platform.isWindows) {
    return SpoolResult.failure(SpoolError.notSupported);
  }
  _warmUpLastError();

  final printerHandle = calloc<IntPtr>();
  final queueNamePtr = queueName.toNativeUtf16();
  final docNamePtr = docName.toNativeUtf16();
  final datatypePtr = 'RAW'.toNativeUtf16();
  final docInfo = calloc<DOC_INFO_1>();
  final buffer = calloc<Uint8>(bytes.length);
  final bytesWritten = calloc<Uint32>();

  var opened = false;
  var docStarted = false;
  var pageStarted = false;

  try {
    if (OpenPrinter(queueNamePtr, printerHandle, nullptr) == 0) {
      return SpoolResult.fromWin32(GetLastError());
    }
    opened = true;
    final handle = printerHandle.value;

    // Pre-flight: a queue that already holds jobs is not draining, so this one
    // would only pile on. Free (no latency) and it makes every print after the
    // first failure fall back to the PDF instead of reporting a false success.
    final pending = _pendingJobCount(handle);
    if (pending > 0) {
      return SpoolResult.failure(
        SpoolError.queueBacklogged,
        message: pending == 1
            ? 'Printer not responding — 1 earlier print is still waiting'
            : 'Printer not responding — $pending earlier prints are still waiting',
      );
    }

    docInfo.ref
      ..pDocName = docNamePtr
      ..pOutputFile = nullptr
      ..pDatatype = datatypePtr;

    // StartDocPrinter returns the spooler's job id, which is what the drain
    // check below polls.
    final jobId = StartDocPrinter(handle, 1, docInfo);
    if (jobId == 0) {
      return SpoolResult.fromWin32(GetLastError());
    }
    docStarted = true;

    if (StartPagePrinter(handle) == 0) {
      return SpoolResult.fromWin32(GetLastError());
    }
    pageStarted = true;

    buffer.asTypedList(bytes.length).setAll(0, bytes);

    if (WritePrinter(handle, buffer, bytes.length, bytesWritten) == 0) {
      return SpoolResult.fromWin32(
        GetLastError(),
        bytesWritten: bytesWritten.value,
      );
    }

    // The spooler can accept fewer bytes than offered without reporting an
    // error. Treat a short write as a failure so the caller falls back to the
    // PDF instead of showing a half-printed bill as successful.
    if (bytesWritten.value != bytes.length) {
      return SpoolResult.failure(
        SpoolError.partialWrite,
        bytesWritten: bytesWritten.value,
      );
    }

    if (!verifyDrained) {
      return SpoolResult.success(bytesWritten: bytesWritten.value);
    }

    // Close the document NOW so the spooler can hand it to the port; polling a
    // job that is still open would always look pending. The finally block skips
    // what has already been closed.
    EndPagePrinter(handle);
    pageStarted = false;
    EndDocPrinter(handle);
    docStarted = false;

    final drained = await _waitForJobToDrain(handle, jobId);
    return drained
        ? SpoolResult.success(bytesWritten: bytesWritten.value)
        : SpoolResult.failure(
            SpoolError.jobStuck,
            bytesWritten: bytesWritten.value,
          );
  } catch (e) {
    // Deliberately no Flutter import here: keeping this file pure Dart + win32
    // lets a plain `dart run` harness exercise the real FFI path off-device.
    // PrinterStore logs the failure under [WIN-SPOOL].
    return SpoolResult.failure(SpoolError.unknown, message: '$e');
  } finally {
    if (opened) {
      if (pageStarted) EndPagePrinter(printerHandle.value);
      if (docStarted) EndDocPrinter(printerHandle.value);
      ClosePrinter(printerHandle.value);
    }
    calloc.free(printerHandle);
    calloc.free(queueNamePtr);
    calloc.free(docNamePtr);
    calloc.free(datatypePtr);
    calloc.free(docInfo);
    calloc.free(buffer);
    calloc.free(bytesWritten);
  }
}
