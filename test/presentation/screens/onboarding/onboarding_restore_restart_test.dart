import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/unified_backup_service.dart';
import 'package:billberrylite/presentation/screens/onboarding/existingUserRestoreScreen.dart';

/// WF-6 (Option R): an onboarding restore ends like every other restore —
/// the existing restart prompt — and never continues into licensing or the
/// dashboard with the in-memory settings of the empty install.
void main() {
  test('after a successful onboarding restore the app restarts (the existing '
      'restore prompt)', () {
    expect(
      identical(onboardingRestoreFinished,
          UnifiedBackupService.promptRestartAfterRestore),
      isTrue,
    );
  });

  test('the restore path has no in-session continuation', () {
    final src = File(
            'lib/presentation/screens/onboarding/existingUserRestoreScreen.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final start = src.indexOf('Future<void> _restoreData() async {');
    final end = src.indexOf('Future<void> _activateLicense()');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final body = src.substring(start, end);

    final success = body.indexOf('if (!success) {');
    final restart = body.indexOf('await onboardingRestoreFinished();');
    expect(success, greaterThan(0));
    expect(restart, greaterThan(success),
        reason: 'a successful import ends in the restart prompt');
    for (final staleContinuation in [
      '_nextStep()',
      'AppConfig.init()',
      'HiveInit.initializeBusinessBoxes()',
      'registerBusinessDependencies(',
      '_goToDashboard()',
      'pushReplacement',
    ]) {
      expect(body.contains(staleContinuation), isFalse,
          reason: '$staleContinuation would continue on stale in-memory state');
    }
  });
}
