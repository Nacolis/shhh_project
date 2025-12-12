import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../core/constants/api_constants.dart';

/// Callback types for WebSocket events
typedef OnMessageCallback = void Function(Map<String, dynamic> data);
typedef OnConnectionCallback = void Function(bool connected);

/// WebSocket service for real-time messaging
class WebSocketService {
  WebSocketChannel? _channel;
  String? _authToken;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  
  // Event callbacks
  OnMessageCallback? onNewPrivateMessage;
  OnMessageCallback? onNewGroupMessage;
  OnMessageCallback? onMessageAvailable;
  OnConnectionCallback? onConnectionChanged;
  
  bool get isConnected => _isConnected;
  
  /// Connect to the WebSocket server
  Future<void> connect(String authToken) async {
    _authToken = authToken;
    _shouldReconnect = true;
    await _establishConnection();
  }
  
  Future<void> _establishConnection() async {
    if (_authToken == null) return;
    
    try {
      final wsUrl = ApiConstants.websocketUrl;
      final uri = Uri.parse('$wsUrl?token=$_authToken');
      
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      onConnectionChanged?.call(true);
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
      debugPrint('WebSocket connected to $wsUrl');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
      _scheduleReconnect();
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final eventType = data['type'] as String? ?? data.keys.first;
      
      debugPrint('WebSocket received: $eventType');
      
      switch (eventType) {
        case 'connected':
          debugPrint('WebSocket authenticated successfully');
          break;
        case 'new_private_message':
          onNewPrivateMessage?.call(data);
          break;
        case 'new_group_message':
          onNewGroupMessage?.call(data);
          break;
        case 'message_available':
          onMessageAvailable?.call(data);
          break;
        case 'pong':
          // Server responded to ping
          break;
        default:
          debugPrint('Unknown WebSocket event: $eventType');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }
  
  void _handleError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }
  
  void _handleDisconnect() {
    debugPrint('WebSocket disconnected');
    _isConnected = false;
    _pingTimer?.cancel();
    onConnectionChanged?.call(false);
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached');
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay * (_reconnectAttempts + 1), () {
      _reconnectAttempts++;
      debugPrint('Attempting to reconnect (attempt $_reconnectAttempts)');
      _establishConnection();
    });
  }
  
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        send({'type': 'ping'});
      }
    });
  }
  
  /// Send a message through the WebSocket
  void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }
  
  /// Join a group room to receive group messages
  void joinGroup(int groupId) {
    send({'type': 'join_group', 'group_id': groupId});
  }
  
  /// Leave a group room
  void leaveGroup(int groupId) {
    send({'type': 'leave_group', 'group_id': groupId});
  }
  
  /// Disconnect from the WebSocket server
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _isConnected = false;
    onConnectionChanged?.call(false);
    debugPrint('WebSocket disconnected manually');
  }
  
  /// Dispose of the service
  void dispose() {
    disconnect();
    onNewPrivateMessage = null;
    onNewGroupMessage = null;
    onMessageAvailable = null;
    onConnectionChanged = null;
  }
}
