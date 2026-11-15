import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import 'package:billberrylite/server/router.dart';

/// Batch 3.2b P6 — the unused `POST /orders` route is gone; every route the
/// Captain and KDS apps call still reaches its handler.
void main() {
  final router = createRouter();

  /// shelf_router's own answer when no route matches.
  Future<bool> unrouted(String method, String path) async {
    final Response res;
    try {
      res = await router.call(
          Request(method, Uri.parse('http://localhost$path'), body: '{}'));
    } catch (_) {
      // A handler ran (and failed without the app's stores): routed.
      return false;
    }
    return res.statusCode == 404 &&
        await res.readAsString() == 'Route not found';
  }

  test('POST /orders is no longer routed', () async {
    expect(await unrouted('POST', '/orders'), isTrue);
  });

  test('health answers', () async {
    final res =
        await router.call(Request('GET', Uri.parse('http://localhost/health')));
    expect(res.statusCode, 200);
  });

  for (final (method, path) in [
    // Captain app (unipos_captain)
    ('POST', '/captain/auth'),
    ('GET', '/captain/menu'),
    ('GET', '/captain/tables'),
    ('POST', '/captain/send-order'),
    ('GET', '/captain/active-orders'),
    ('PUT', '/captain/orders/o1/status'),
    ('PUT', '/captain/orders/o1/modify'),
    // KDS app (kds_app)
    ('GET', '/kds/orders'),
    ('PUT', '/kds/orders/o1/status'),
    ('PUT', '/kds/orders/o1/kot/1/status'),
  ]) {
    test('$method $path is still routed', () async {
      expect(await unrouted(method, path), isFalse);
    });
  }
}
