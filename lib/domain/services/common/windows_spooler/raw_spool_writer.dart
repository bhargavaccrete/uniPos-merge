/// Conditional export: picks the dart:io implementation on mobile/desktop, and
/// a no-op stub on web (where dart:ffi is unavailable).
///
/// `dart.library.io` is true on Android too, so this split alone does NOT
/// isolate Windows — the io implementation guards on `Platform.isWindows`
/// before touching any FFI.
library;

export 'raw_spool_writer_stub.dart'
    if (dart.library.io) 'raw_spool_writer_io.dart';
