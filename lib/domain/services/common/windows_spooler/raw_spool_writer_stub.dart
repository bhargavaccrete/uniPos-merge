import 'spool_result.dart';

/// Web stub — the Windows print spooler is unreachable without dart:ffi.
Future<SpoolResult> platformRawSpoolWrite(
  String queueName,
  List<int> bytes,
  String docName, {
  bool verifyDrained = false,
}) async =>
    SpoolResult.failure(SpoolError.notSupported);
