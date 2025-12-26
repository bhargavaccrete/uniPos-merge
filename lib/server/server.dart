import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'router.dart';
import 'websocket.dart';

bool _serverStarted = false;

Future<void> startServer() async {
  if (_serverStarted) {
    print('⚠️ Server already running, skipping start');
    return;
  }

  _serverStarted = true;

  final router = createRouter();

  // Create a handler that routes WebSocket vs HTTP requests
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) {
        // Handle WebSocket upgrade requests
        if (request.url.path == 'ws') {
          print('🔌 WebSocket connection request from ${request.url}');
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

  print('🌐 Server running on port ${server.port}');
  print('🔌 WebSocket available at ws://localhost:${server.port}/ws');
}

