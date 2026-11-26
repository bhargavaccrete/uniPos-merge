import 'dart:async';

import 'package:flutter/foundation.dart';

/// AND-34: in release builds the app writes nothing to the device log
/// (logcat) — licence requests and replies, OTPs, tokens and stack traces
/// included. Debug and profile builds keep every log line.

/// Drops every `debugPrint` when [release] is true.
void silenceDebugPrintInRelease({bool release = kReleaseMode}) {
  if (release) debugPrint = _dropDebugPrint;
}

void _dropDebugPrint(String? message, {int? wrapWidth}) {}

/// Zone rules that drop every `print` when [release] is true. Run the whole
/// app (error handlers included) inside a zone with these rules.
ZoneSpecification releaseLogZone({bool release = kReleaseMode}) =>
    ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!release) parent.print(zone, line);
      },
    );
