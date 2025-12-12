import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/api_constants.dart';

/// Callback types for WebSocket events
typedef OnMessageCallback = void Function(Map<String, dynamic> data);
typedef OnConnectionCallback = void Function(bool connected);

/// WebSocket service for real-time messaging using Socket.IO
class WebSocketService {
  IO.Socket? _socket;
  String? _authToken;
  bool _isConnected = false;
  
  // Event callbacks
  OnMessageCallback? onNewPrivateMessage;
  OnMessageCallback? onNewGroupMessage;
  OnMessageCallback? onMessageAvailable;
  OnConnectionCallback? onConnectionChanged;
  
  bool get isConnected => _isConnected;
  
  /// Connect to the Socket.IO server
  Future<void> connect(String authToken) async {
    _authToken = authToken;
    _establishConnection();
  }
  
  void _establishConnection() {
    if (_authToken == null) return;
    
    try {
      final wsUrl = ApiConstants.socketIOUrl;
      
      _socket = IO.io(wsUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'query': {'token': _authToken},
        'extraHeaders': {'Authorization': 'Bearer $_authToken'},
      });
      
      _socket!.onConnect((_) {
        debugPrint('Socket.IO connected');
        _isConnected = true;
        onConnectionChanged?.call(true);
      });
      
      _socket!.onDisconnect((_) {
        debugPrint('Socket.IO disconnected');
        _isConnected = false;
        onConnectionChanged?.call(false);
      });
      
      _socket!.onConnectError((error) {
        debugPrint('Socket.IO connection error: $error');
        _isConnected = false;
        onConnectionChanged?.call(false);
      });
      
      _socket!.onError((error) {
        debugPrint('Socket.IO error: $error');
      });
      
      // Listen for events
      _socket!.on('connected', (data) {
        debugPrint('Socket.IO authenticated: $data');
      });
      
      _socket!.on('new_private_message', (data) {
        debugPrint('New private message: $data');
        if (data is Map<String, dynamic>) {
          onNewPrivateMessage?.call(data);
        } else {
          onNewPrivateMessage?.call({'data': data});
        }
      });
      
      _socket!.on('new_group_message', (data) {
        debugPrint('New group message: $data');
        if (data is Map<String, dynamic>) {
          onNewGroupMessage?.call(data);
        } else {
          onNewGroupMessage?.call({'data': data});
        }
      });
      
      _socket!.on('message_available', (data) {
        debugPrint('Message available: $data');
        if (data is Map<String, dynamic>) {
          onMessageAvailable?.call(data);
        } else {
          onMessageAvailable?.call({'data': data});
        }
      });
      
      _socket!.connect();
      
      debugPrint('Socket.IO connecting to $wsUrl');
    } catch (e) {
      debugPrint('Socket.IO connection error: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
    }
  }
  
  /// Join a group room to receive group messages
  void joinGroup(int groupId) {
    _socket?.emit('join_group', {'group_id': groupId});
  }
  
  /// Leave a group room
  void leaveGroup(int groupId) {
    _socket?.emit('leave_group', {'group_id': groupId});
  }
  
  /// Disconnect from the Socket.IO server
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    onConnectionChanged?.call(false);
    debugPrint('Socket.IO disconnected manually');
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
