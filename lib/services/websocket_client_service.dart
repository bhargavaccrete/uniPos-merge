import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client service for UniPOS to receive real-time updates from server
class WebSocketClientService {
  static final WebSocketClientService _instance = WebSocketClientService._internal();
  factory WebSocketClientService() => _instance;
  WebSocketClientService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isEnabled = false;

  Stream<Map<String, dynamic>> get messageStream =>
      _messageController?.stream ?? const Stream.empty();

  bool get isConnected => _channel != null;
  bool get isEnabled => _isEnabled;

  /// Start the WebSocket client service
  Future<void> start() async {
    if (_isEnabled) {
      print('⚠️ WebSocket client already started');
      return;
    }

    _isEnabled = true;
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
    await _connect();
  }

  /// Stop the WebSocket client service
  void stop() {
    _isEnabled = false;
    _disconnect();
  }

  Future<void> _connect() async {
    if (_isConnecting || !_isEnabled) return;
    _isConnecting = true;

    try {
      // Connect to local server WebSocket
      const wsUrl = 'ws://localhost:9090/ws';
      print('🔌 UniPOS connecting to WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            print('📨 UniPOS received WebSocket message: ${data['type']}');
            _messageController?.add(data);
          } catch (e) {
            print('⚠️ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('⚠️ UniPOS WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('🔌 UniPOS WebSocket connection closed');
          _handleDisconnect();
        },
      );

      _isConnecting = false;
      print('✅ UniPOS WebSocket connected successfully');
    } catch (e) {
      print('❌ UniPOS WebSocket connection error: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _channel = null;

    // Attempt to reconnect after 5 seconds if still enabled
    if (_isEnabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        print('🔄 UniPOS attempting to reconnect WebSocket...');
        _connect();
      });
    }
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _messageController?.close();
    _messageController = null;
    _isConnecting = false;
  }

  void dispose() {
    stop();
  }
}
