import 'raw_spool_writer.dart';
import 'spool_result.dart';

export 'spool_result.dart';

/// Windows print-spooler transport.
///
/// `flutter_thermal_printer`'s Windows plugin is a stub (only
/// `getPlatformVersion` is implemented), so Bluetooth and USB thermal printing
/// are dead there. The spooler is the way around it: once a printer is
/// installed in Windows — over USB, Bluetooth SPP or the network — it becomes a
/// print queue, and a RAW write to that queue reaches the device without driver
/// rendering. One transport covers all three physical connections.
///
/// Receipt building and rasterization are untouched; this sits at the same
/// level as `_sendViaWifi` / `_sendViaUsb` in `PrinterStore`.

/// Writes [bytes] to the Windows print queue [queueName] as a RAW job.
typedef RawSpoolWriter = Future<SpoolResult> Function(
  String queueName,
  List<int> bytes,
  String docName, {
  bool verifyDrained,
});

class WindowsSpoolerService {
  final RawSpoolWriter _write;

  /// [writer] defaults to the real FFI implementation. Tests pass a fake —
  /// that injection is what makes every failure path reachable without a
  /// printer attached.
  WindowsSpoolerService({RawSpoolWriter? writer})
      : _write = writer ?? platformRawSpoolWrite;

  /// Send raw ESC/POS [bytes] to the Windows queue [queueName].
  ///
  /// [queueName] is passed through whole. Windows queue names can contain a
  /// colon ('Printer on SERVER:2'), so it must never be split the way the WiFi
  /// path splits `ip:port`.
  ///
  /// [verifyDrained] waits (up to ~2s) for the job to actually leave the queue
  /// before reporting success. The spooler accepts work for a printer that is
  /// switched off — it queues it — so without this a disconnected printer looks
  /// like a successful print. Reserved for **Test Print**, where staff are
  /// deliberately checking the printer; bills stay instant and rely on the
  /// backlog pre-flight instead.
  Future<SpoolResult> send({
    required String queueName,
    required List<int> bytes,
    String docName = 'Receipt',
    bool verifyDrained = false,
  }) async {
    if (queueName.trim().isEmpty) {
      return SpoolResult.failure(SpoolError.printerNotFound);
    }
    if (bytes.isEmpty) {
      return SpoolResult.failure(
        SpoolError.writeFailed,
        message: 'Nothing to print',
      );
    }
    try {
      return await _write(queueName, bytes, docName,
          verifyDrained: verifyDrained);
    } catch (e) {
      return SpoolResult.failure(SpoolError.unknown, message: '$e');
    }
  }
}
