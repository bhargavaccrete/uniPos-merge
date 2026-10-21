import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import '../core/plan/plan_enforcement.dart';
import '../core/plan/entitlement_keys.dart';
import 'router.dart';
import 'websocket.dart';

bool _serverStarted = false;

/// Licensing gate for the embedded server. KDS and Captain are independently
/// licensable: /kds/* requires the `kds` module, /captain/* requires `captain`.
/// Path-based so it works regardless of handler signatures (route params).
Middleware entitlementGate() {
  return (Handler handler) {
    return (Request request) {
      final path = request.url.path; // shelf path has no leading slash
      if (path == 'kds' || path.startsWith('kds/')) {
        if (!PlanEnforce.allows(EntKeys.kds)) {
          return Response.forbidden(
              '{"error":"feature_not_licensed","feature":"kds"}',
              headers: {'Content-Type': 'application/json'});
        }
      } else if (path == 'captain' || path.startsWith('captain/')) {
        if (!PlanEnforce.allows(EntKeys.captain)) {
          return Response.forbidden(
              '{"error":"feature_not_licensed","feature":"captain"}',
              headers: {'Content-Type': 'application/json'});
        }
      }
      return handler(request);
    };
  };
}

/// CORS middleware to allow web browser connections
Middleware corsHeaders() {
  return (Handler handler) {
    return (Request request) async {
      // Handle preflight requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization, Access-Control-Request-Private-Network',
          'Access-Control-Allow-Private-Network': 'true',
          'Access-Control-Max-Age': '86400',
        });
      }

      // Add CORS headers to all responses
      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
        'Access-Control-Allow-Private-Network': 'true',
      });
    };
  };
}

Future<void> startServer() async {

  if (_serverStarted) {
    return;
  }

  _serverStarted = true;

  final router = createRouter();

  // Create a handler that routes WebSocket vs HTTP requests
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(entitlementGate())
      .addMiddleware(logRequests())
      .addHandler((Request request) {
        // Handle WebSocket upgrade requests
        if (request.url.path == 'ws') {
          final wsHandler = webSocketHandler(handleSocket);
          return wsHandler(request);
        }

        // Handle regular HTTP requests
        return router(request);
      });

  final server = await serve(
    handler,
    InternetAddress.anyIPv4,
    9090,
  );

}

