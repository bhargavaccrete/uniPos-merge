import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M6a: the Retail dashboard shows the start-of-day backup prompt the way the
/// Restaurant home does — after its day/shift checks, from a post-frame
/// callback, through the shared prompt (which keeps its own plan, setting and
/// once-a-day guards).
void main() {
  String code(String path) => File(path)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('Retail dashboard: prompt after the shift check', () {
    final src = code('lib/presentation/screens/retail/home_screen.dart');
    final init = src.indexOf('void initState() {');
    final end = src.indexOf('Future<void> _startShiftIfNeeded() async {');
    expect(init, greaterThan(0));
    final body = src.substring(init, end);
    final check = body.indexOf('final shiftCheck = _startShiftIfNeeded();');
    final frame = body.indexOf('addPostFrameCallback');
    final wait = body.indexOf('await shiftCheck;');
    final prompt = body.indexOf('StartOfDayBackupPrompt.show(context)');
    expect(check, greaterThan(0), reason: 'the shift check still starts at once');
    expect(frame, greaterThan(check));
    expect(wait, greaterThan(frame));
    expect(prompt, greaterThan(wait), reason: 'prompt only after the check');
    expect(body, contains('if (mounted) await StartOfDayBackupPrompt.show'));
  });

  test('Restaurant home is unchanged', () {
    final src = code('lib/presentation/screens/restaurant/welcome_Admin.dart');
    final shift = src.indexOf('await _startShiftIfNeeded();');
    final prompt = src.indexOf('await StartOfDayBackupPrompt.show(context);');
    expect(shift, greaterThan(0));
    expect(prompt, greaterThan(shift));
  });
}
