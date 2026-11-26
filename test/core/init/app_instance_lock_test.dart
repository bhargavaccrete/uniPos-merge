import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:billberrylite/core/init/app_instance_lock.dart';

/// M4-PERSIST: one running copy of the app per data folder on desktop. A
/// lock left by a closed or crashed copy never blocks a start.
void main() {
  late Directory dir;
  String lockPath() => p.join(dir.path, AppInstanceLock.fileName);

  /// The SDK's real dart executable (on Windows `dart` on PATH is a .bat
  /// wrapper; killing a shell would not kill the process holding the lock).
  /// The test runner lives in `<flutter>/bin/cache/artifacts/...`.
  String? dartExecutable() {
    var d = File(Platform.resolvedExecutable).parent;
    while (p.basename(d.path) != 'cache' && d.parent.path != d.path) {
      d = d.parent;
    }
    final exe = File(p.join(d.path, 'dart-sdk', 'bin',
        Platform.isWindows ? 'dart.exe' : 'dart'));
    return exe.existsSync() ? exe.path : null;
  }

  /// Another process holding the instance lock, as a second app copy would.
  Future<Process> otherCopyHoldingLock() async {
    final script = File(p.join(dir.path, 'holder.dart'))
      ..writeAsStringSync('''
import 'dart:io';
Future<void> main(List<String> args) async {
  final raf = await File(args[0]).open(mode: FileMode.append);
  await raf.lock(FileLock.exclusive);
  stdout.writeln('locked');
  await stdin.first;
}
''');
    final proc =
        await Process.start(dartExecutable()!, [script.path, lockPath()]);
    await proc.stdout
        .transform(utf8.decoder)
        .firstWhere((l) => l.contains('locked'))
        .timeout(const Duration(seconds: 60));
    return proc;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('instance_lock_');
  });

  tearDown(() async {
    await AppInstanceLock.releaseForTesting();
    for (var i = 0; dir.existsSync(); i++) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        if (i > 100) rethrow;
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test('applies on desktop only', () {
    expect(AppInstanceLock.appliesToThisPlatform,
        Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  });

  test('first copy takes the lock', () async {
    await AppInstanceLock.acquire(dir.path);
    expect(AppInstanceLock.isHeld, isTrue);
    expect(File(lockPath()).existsSync(), isTrue);
  });

  test('a lock FILE left behind by a closed copy does not block a start',
      () async {
    File(lockPath()).writeAsStringSync('');
    await AppInstanceLock.acquire(dir.path);
    expect(AppInstanceLock.isHeld, isTrue);
  });

  test('a lock held through another handle refuses the start', () async {
    final holder = await File(lockPath()).open(mode: FileMode.append);
    await holder.lock(FileLock.exclusive);
    try {
      await expectLater(
        AppInstanceLock.acquire(dir.path),
        throwsA(isA<AppAlreadyRunningException>().having(
            (e) => e.toString(), 'message', contains('already running'))),
      );
      expect(AppInstanceLock.isHeld, isFalse);
    } finally {
      await holder.unlock();
      await holder.close();
    }
    await AppInstanceLock.acquire(dir.path);
    expect(AppInstanceLock.isHeld, isTrue, reason: 'retry after it closed');
  }, skip: Platform.isWindows ? false : 'same-process lock conflict is Windows-only');

  test('another running copy refuses the start; once that copy is killed '
      '(stale lock), the start succeeds', () async {
    final other = await otherCopyHoldingLock();
    try {
      await expectLater(AppInstanceLock.acquire(dir.path),
          throwsA(isA<AppAlreadyRunningException>()));
      expect(AppInstanceLock.isHeld, isFalse);
    } finally {
      // The dart launcher can run the script in a child process: end the
      // whole tree, as a crash of the real app would.
      if (Platform.isWindows) {
        Process.runSync('taskkill', ['/F', '/T', '/PID', '${other.pid}']);
      }
      other.kill(ProcessSignal.sigkill);
      await other.exitCode;
    }
    expect(File(lockPath()).existsSync(), isTrue,
        reason: 'the crashed copy left its lock file behind');
    // The OS frees the lock once the dead process is fully torn down.
    for (var i = 0;; i++) {
      try {
        await AppInstanceLock.acquire(dir.path);
        break;
      } on AppAlreadyRunningException {
        if (i >= 50) rethrow;
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    expect(AppInstanceLock.isHeld, isTrue);
  }, skip: dartExecutable() != null ? false : 'Flutter SDK dart not found',
      timeout: const Timeout(Duration(minutes: 2)));
}
