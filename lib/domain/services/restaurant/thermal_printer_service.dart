/// Conditional export: picks the native implementation on mobile/desktop,
/// and a no-op stub on web (where dart:ffi / dart:io are unavailable).
export 'thermal_printer_service_stub.dart'
    if (dart.library.io) 'thermal_printer_service_native.dart';