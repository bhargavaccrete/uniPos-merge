/// Value types for the Windows print-spooler transport.
///
/// Pure Dart on purpose: the FFI lives in `raw_spool_writer_io.dart`, so these
/// types (and their tests) never load `win32`.
library;

/// Why a spool write failed. Maps from Win32 error codes.
enum SpoolError {
  notSupported,
  printerNotFound,
  accessDenied,
  invalidHandle,
  printerOffline,
  writeFailed,
  partialWrite,

  /// The queue already held unprinted jobs, so it is not draining — the device
  /// is almost certainly off or unplugged. Windows cannot tell us directly: a
  /// disconnected USB thermal printer still reports `PRINTER_STATUS_NORMAL`
  /// with `WorkOffline` unset, because the spooler is designed to hold work
  /// until the device reappears. A backed-up queue is the only honest signal.
  queueBacklogged,

  /// The job was accepted but had not left the queue when we checked, so it
  /// did not reach paper.
  jobStuck,

  unknown,
}

// Win32 error codes, declared here so the pure layer never imports win32.
// Values from winerror.h.
const int errorFileNotFound = 2;
const int errorAccessDenied = 5;
const int errorInvalidHandle = 6;
const int errorNotReady = 21;
const int errorInvalidPrinterName = 1801;
const int errorPrinterDeleted = 1905;

SpoolError spoolErrorFromWin32(int code) {
  switch (code) {
    case errorFileNotFound:
    case errorInvalidPrinterName:
    case errorPrinterDeleted:
      return SpoolError.printerNotFound;
    case errorAccessDenied:
      return SpoolError.accessDenied;
    case errorInvalidHandle:
      return SpoolError.invalidHandle;
    case errorNotReady:
      return SpoolError.printerOffline;
    default:
      return SpoolError.unknown;
  }
}

/// Short, counter-facing text. Matches the terse style already used for the USB
/// path ('Printer not available'), which callers surface as a warning before
/// falling back to the PDF preview.
String spoolErrorMessage(SpoolError error) {
  switch (error) {
    case SpoolError.notSupported:
      return 'Windows printing is not available on this platform';
    case SpoolError.printerNotFound:
      return 'Printer not found in Windows';
    case SpoolError.accessDenied:
      return 'Access denied to printer';
    case SpoolError.invalidHandle:
      return 'Printer connection lost';
    case SpoolError.printerOffline:
      return 'Printer not available';
    case SpoolError.writeFailed:
      return 'Failed to send data to printer';
    case SpoolError.partialWrite:
      return 'Print job was cut short';
    case SpoolError.queueBacklogged:
      return 'Printer not responding — earlier prints are still waiting';
    case SpoolError.jobStuck:
      return 'Printer did not print — check power, cable and paper';
    case SpoolError.unknown:
      return 'Print failed';
  }
}

/// Outcome of one spool write.
class SpoolResult {
  final bool ok;
  final SpoolError? error;
  final String message;

  /// Raw `GetLastError()` value when the failure came from the API. For logs —
  /// never shown to the user.
  final int? win32Code;
  final int bytesWritten;

  const SpoolResult.success({this.bytesWritten = 0})
      : ok = true,
        error = null,
        message = '',
        win32Code = null;

  SpoolResult.failure(
    SpoolError this.error, {
    String? message,
    this.win32Code,
    this.bytesWritten = 0,
  })  : ok = false,
        message = message ?? spoolErrorMessage(error);

  /// Build a failure straight from a `GetLastError()` value.
  factory SpoolResult.fromWin32(int code, {int bytesWritten = 0}) =>
      SpoolResult.failure(
        spoolErrorFromWin32(code),
        win32Code: code,
        bytesWritten: bytesWritten,
      );

  @override
  String toString() => ok
      ? 'SpoolResult.ok(bytesWritten: $bytesWritten)'
      : 'SpoolResult.fail($error, win32: $win32Code, "$message")';
}

/// Queue names that are almost certainly not a physical printer. Windows lists
/// these alongside real devices, and a cashier picking one gets a silent file
/// instead of paper. They are deprioritised in the picker, never hidden — a
/// real printer could carry an odd name.
const List<String> _virtualQueueKeywords = [
  'xps document writer',
  'microsoft print to pdf',
  'print to pdf',
  'onenote',
  'fax',
  'adobe pdf',
  'cutepdf',
  'pdfcreator',
  'document writer',
  // Third-party PDF writers. 'dopdf' installs under the 'novaPDF' driver, so
  // both spellings are needed — matching on a bare 'pdf' would be too broad and
  // could bury a real printer whose model name contains it.
  'dopdf',
  'novapdf',
  'pdf24',
  'foxit',
];

bool isLikelyVirtualQueue(String name, [String? driver]) {
  final haystack = '$name ${driver ?? ''}'.toLowerCase();
  return _virtualQueueKeywords.any(haystack.contains);
}
