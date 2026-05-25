import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

final List<WebSocketChannel> clients = [];

void handleSocket(WebSocketChannel channel) {
  clients.add(channel);

  channel.stream.listen(
    (message) {
      // Handle incoming messages from KDS if needed
    },
    onDone: () {
      clients.remove(channel);
    },
    onError: (error) {
      clients.remove(channel);
    },
  );
}

void broadcastEvent(Map<String, dynamic> event) {
  if (clients.isEmpty) {
    return;
  }

  final msg = jsonEncode(event);

  for (final client in clients) {
    try {
      client.sink.add(msg);
    } catch (e) {
    }
  }
}
