import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:billberrylite/domain/services/common/firebase_messaging_service.dart';

/// AND-24: push setup never depends on the network. Listeners are wired
/// before the token is fetched, a failed or slow token never breaks or
/// blocks setup, and the token still arrives when it can.
void main() {
  late List<String> ran;
  String? token;

  Future<void> setUp0({
    Future<String?> Function()? fetchToken,
    Future<void> Function()? prepare,
    Future<void> Function()? initial,
  }) =>
      FirebaseMessagingService.runSetup(
        prepare: prepare ?? () async => ran.add('prepare'),
        listen: () => ran.add('listen'),
        fetchToken: fetchToken ?? () async => 'tok-1',
        onToken: (t) => token = t,
        handleInitialMessage: initial ?? () async => ran.add('initial'),
      );

  setUp(() {
    ran = [];
    token = null;
  });

  test('listeners are wired before the token is fetched', () async {
    await setUp0(fetchToken: () async {
      ran.add('token');
      return 'tok-1';
    });
    await Future<void>.delayed(Duration.zero);
    expect(ran.indexOf('listen'), lessThan(ran.indexOf('token')));
    expect(token, 'tok-1');
  });

  test('offline: the token fails, listeners are still wired, nothing throws',
      () async {
    await setUp0(fetchToken: () async => throw Exception('SERVICE_NOT_AVAILABLE'));
    await Future<void>.delayed(Duration.zero);
    expect(ran, containsAll(['prepare', 'listen', 'initial']));
    expect(token, isNull);
  });

  test('a token that never arrives does not block setup', () async {
    final never = Completer<String?>();
    await setUp0(fetchToken: () => never.future)
        .timeout(const Duration(seconds: 2));
    expect(ran, containsAll(['listen', 'initial']));
  });

  test('a failed preparation step still wires the listeners', () async {
    await setUp0(prepare: () async => throw StateError('permission'));
    expect(ran, contains('listen'));
  });

  test('a failed initial-message read does not throw', () async {
    await setUp0(initial: () async => throw StateError('no message'));
    expect(ran, contains('listen'));
  });
}
