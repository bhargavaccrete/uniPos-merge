import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

final List<WebSocketChannel> clients = [];

void handleSocket(WebSocketChannel channel) {
  clients.add(channel);
  print('✅ WebSocket client connected. Total clients: ${clients.length}');

  channel.stream.listen(
    (message) {
      // Handle incoming messages from KDS if needed
      print('📨 Received message from client: $message');
    },
    onDone: () {
      clients.remove(channel);
      print('❌ WebSocket client disconnected. Total clients: ${clients.length}');
    },
    onError: (error) {
      print('⚠️ WebSocket error: $error');
      clients.remove(channel);
    },
  );
}

void broadcastEvent(Map<String, dynamic> event) {
  if (clients.isEmpty) {
    print('ℹ️ No WebSocket clients connected. Event not broadcast: ${event['type']}');
    return;
  }

  final msg = jsonEncode(event);
  print('📢 Broadcasting to ${clients.length} client(s): ${event['type']}');

  for (final client in clients) {
    try {
      client.sink.add(msg);
    } catch (e) {
      print('⚠️ Failed to send to client: $e');
    }
  }
}
