import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/auto_backup_service.dart';

/// The start-of-day prompt rule: asked, never automatic. Off → nothing;
/// today done → nothing; under 7 days → skippable; 7+ days since the last
/// backup (or since the prompt was switched on, when never backed up) →
/// required. A fresh install is never "7 days overdue" on day one.
void main() {
  final now = DateTime(2026, 11, 24, 12, 40);
  DailyBackupPrompt rule(String? last, {bool enabled = true, String? since}) =>
      AutoBackupService.promptFor(
          enabled: enabled, lastBackupDate: last, since: since, now: now);

  test('setting off: no prompt, however old the last backup', () {
    expect(rule(null, enabled: false), DailyBackupPrompt.none);
    expect(rule('2026-10-01', enabled: false), DailyBackupPrompt.none);
  });

  test('backed up today: no prompt', () {
    expect(rule('2026-11-24'), DailyBackupPrompt.none);
  });

  test('1–6 days: Backup Now or Skip Today', () {
    for (final d in ['2026-11-23', '2026-11-20', '2026-11-18']) {
      expect(rule(d), DailyBackupPrompt.optional, reason: d);
    }
  });

  test('a backup late last night still counts as 1 day, not 0', () {
    expect(
        AutoBackupService.promptFor(
            enabled: true,
            lastBackupDate: '2026-11-23',
            now: DateTime(2026, 11, 24, 0, 5)),
        DailyBackupPrompt.optional);
  });

  test('7 days or more: required (no Skip)', () {
    expect(rule('2026-11-17'), DailyBackupPrompt.required);
    expect(rule('2026-09-01'), DailyBackupPrompt.required);
    expect(AutoBackupService.requiredAfterDays, 7);
  });

  test('fresh install (never backed up): asked, skippable — not "7 days"', () {
    expect(rule(null), DailyBackupPrompt.optional);
    expect(rule(null, since: '2026-11-24'), DailyBackupPrompt.optional,
        reason: 'switched on today');
    expect(rule('not a date', since: '2026-11-20'), DailyBackupPrompt.optional);
  });

  test('never backed up, switched on 7+ days ago: required', () {
    expect(rule(null, since: '2026-11-17'), DailyBackupPrompt.required);
    expect(rule(null, since: '2026-11-18'), DailyBackupPrompt.optional);
  });

  test('switching on again gives 7 days from that day, even after an old '
      'backup', () {
    expect(rule('2026-10-01', since: '2026-11-22'), DailyBackupPrompt.optional);
    expect(rule('2026-10-01', since: '2026-11-10'), DailyBackupPrompt.required);
  });

  test('clock set back (last backup "in the future"): asked, skippable', () {
    expect(rule('2026-11-30'), DailyBackupPrompt.optional);
  });

  test('across a month and year boundary', () {
    expect(
        AutoBackupService.promptFor(
            enabled: true,
            lastBackupDate: '2026-12-26',
            now: DateTime(2027, 1, 2)),
        DailyBackupPrompt.required); // 7 days
    expect(
        AutoBackupService.promptFor(
            enabled: true,
            lastBackupDate: '2026-12-27',
            now: DateTime(2027, 1, 2)),
        DailyBackupPrompt.optional); // 6 days
  });
}
