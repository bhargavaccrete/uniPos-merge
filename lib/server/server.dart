import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'router.dart';
import 'websocket.dart';

bool _serverStarted = false;

/// CORS middleware to allow web browser connections
Middleware corsHeaders() {
  return (Handler handler) {
    return (Request request) async {
      // Handle preflight requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
          'Access-Control-Max-Age': '86400',
        });
      }

      // Add CORS headers to all responses
      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
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

