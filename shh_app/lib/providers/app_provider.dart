import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final WebSocketService _webSocketService = WebSocketService();

  AuthUser? _currentUser;
  String? _authToken;
  bool _isLoading = false;
  String? _error;
  List<Conversation> _conversations = [];
  Map<String, List<Message>> _messages = {};
  bool _isWebSocketConnected = false;

  // Token expiration callback
  bool _tokenExpired = false;
  bool get tokenExpired => _tokenExpired;
  bool get isWebSocketConnected => _isWebSocketConnected;

  // Getters
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _authToken != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Conversation> get conversations => _conversations;

  List<Message> getMessages(String conversationId) {
    return _messages[conversationId] ?? [];
  }

  Future<void> initialize() async {
    _setLoading(true);
    try {
      _authToken = await _storageService.getAuthToken();
      _currentUser = await _storageService.getCurrentUser();

      if (_authToken != null) {
        _apiService.setAuthToken(_authToken!);
        await syncGroupsFromServer();
        await loadConversations();
        _connectWebSocket();
      }
    } catch (e) {
      _setError('Failed to initialize: $e');
    }
    _setLoading(false);
  }

  void _connectWebSocket() {
    if (_authToken == null) return;
    
    _webSocketService.onConnectionChanged = (connected) {
      _isWebSocketConnected = connected;
      notifyListeners();
    };
    
    _webSocketService.onNewPrivateMessage = (data) {
      debugPrint('New private message notification: $data');
      fetchMessages();
    };
    
    _webSocketService.onNewGroupMessage = (data) {
      debugPrint('New group message notification: $data');
      final groupId = data['group_id'];
      if (groupId != null) {
        fetchMessages();
      }
    };
    
    _webSocketService.onMessageAvailable = (data) {
      debugPrint('Message available notification: $data');
      fetchMessages();
    };
    
    _webSocketService.connect(_authToken!);
  }

  Future<bool> register({
    required String uniqueUsername,
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Generate cryptographic keys
      final rsaKeyPair = CryptoService.generateRSAKeyPair();
      final dhKeyPair = CryptoService.generateDHKeyPair();

      // Store private keys securely
      await _storageService.storeRSAPrivateKey(
        CryptoService.rsaPrivateKeyToPem(rsaKeyPair.privateKey),
      );
      await _storageService.storeDHPrivateKey(
        CryptoService.dhPrivateKeyToBase64(dhKeyPair.privateKey),
      );

      // Create registration request
      final request = RegisterRequest(
        uniqueUsername: uniqueUsername,
        username: username,
        password: password,
        rsaPublicKey: CryptoService.rsaPublicKeyToPem(rsaKeyPair.publicKey),
        dhPublicKey: CryptoService.dhPublicKeyToBase64(dhKeyPair.publicKey),
      );

      final result = await _apiService.register(request);

      if (result.isSuccess) {
        return await login(uniqueUsername: uniqueUsername, password: password);
      } else {
        _setError(result.error ?? 'Registration failed');
        return false;
      }
    } catch (e) {
      _setError('Registration error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({
    required String uniqueUsername,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final request = LoginRequest(
        uniqueUsername: uniqueUsername,
        password: password,
      );

      final result = await _apiService.login(request);

      if (result.isSuccess && result.data != null) {
        _authToken = result.data!.accessToken;
        _currentUser = result.data!.user;

        await _storageService.storeAuthToken(_authToken!);
        await _storageService.storeCurrentUser(_currentUser!);

        await syncGroupsFromServer();
        await loadConversations();
        _connectWebSocket();

        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Login failed');
        return false;
      }
    } catch (e) {
      _setError('Login error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _webSocketService.disconnect();
    _apiService.clearAuthToken();
    await _storageService.clearSecureStorage();

    _currentUser = null;
    _authToken = null;
    _conversations = [];
    _messages = {};
    _isWebSocketConnected = false;

    notifyListeners();
  }

  Future<void> resetApp() async {
    _setLoading(true);
    try {
      _webSocketService.disconnect();
      _apiService.clearAuthToken();
      await _storageService.clearAll();
      _currentUser = null;
      _authToken = null;
      _conversations = [];
      _messages = {};
      _tokenExpired = false;
      _isWebSocketConnected = false;

      notifyListeners();
    } catch (e) {
      _setError('Failed to reset app: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _handleTokenExpired() {
    _tokenExpired = true;
    _authToken = null;
    _apiService.clearAuthToken();
    notifyListeners();
  }

  Future<bool> reLogin(String password) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final request = LoginRequest(
        uniqueUsername: _currentUser!.uniqueUsername,
        password: password,
      );

      final result = await _apiService.login(request);

      if (result.isSuccess && result.data != null) {
        _authToken = result.data!.accessToken;
        _tokenExpired = false;
        await _storageService.storeAuthToken(_authToken!);

        notifyListeners();
        return true;
      } else {
        _setError(result.error ?? 'Re-login failed');
        return false;
      }
    } catch (e) {
      _setError('Re-login error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadConversations() async {
    try {
      _conversations = await _storageService.getConversations();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load conversations: $e');
    }
  }

  /// Sync groups from server to ensure user sees all groups they're a member of
  Future<void> syncGroupsFromServer() async {
    try {
      final result = await _apiService.getUserGroups();
      if (result.isTokenExpired) {
        _handleTokenExpired();
        return;
      }

      if (result.isSuccess && result.data != null) {
        for (final group in result.data!) {
          // Get group members to store locally
          final membersResult = await _apiService.getGroupMembers(group.id);
          List<String> memberUsernames = [];
          
          if (membersResult.isSuccess && membersResult.data != null) {
            memberUsernames = membersResult.data!
                .map((m) => m.uniqueUsername)
                .toList();
            
            // Cache member keys for encryption
            for (final member in membersResult.data!) {
              await _storageService.cacheUserKeys(User(
                id: member.id,
                uniqueUsername: member.uniqueUsername,
                username: member.username,
                rsaPublicKey: member.rsaPublicKey,
                dhPublicKey: member.dhPublicKey,
              ));
            }
          }

          // Create or update local conversation for this group
          await _storageService.getOrCreateConversation(
            group.id.toString(),
            group.name,
            ConversationType.group,
            members: memberUsernames,
          );
          
          // Join WebSocket room for this group
          _webSocketService.joinGroup(group.id);
        }
      }
    } catch (e) {
      debugPrint('Error syncing groups: $e');
    }
  }

  Future<Conversation?> startConversation(
    String recipientUniqueUsername,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _apiService.getUserKeys(recipientUniqueUsername);
      if (result.isTokenExpired) {
        _handleTokenExpired();
        return null;
      }

      if (!result.isSuccess || result.data == null) {
        _setError(result.error ?? 'User not found');
        return null;
      }

      final recipient = result.data!;
      await _storageService.cacheUserKeys(recipient);
      print("recipient dh key: ${recipient.dhPublicKey}");
      print("recipient rsa key: ${recipient.rsaPublicKey}");
      print("my dh key: ${await _storageService.getDHPrivateKey()}");
      if (recipient.dhPublicKey != null) {
        final myDHPrivateKey = await _storageService.getDHPrivateKey();
        if (myDHPrivateKey != null) {
          final sharedSecret = CryptoService.computeSharedSecret(
            CryptoService.dhPrivateKeyFromBase64(myDHPrivateKey),
            CryptoService.dhPublicKeyFromBase64(recipient.dhPublicKey!),
          );
          await _storageService.storeSharedSecret(
            recipientUniqueUsername,
            CryptoService.dhPublicKeyToBase64(
              BigInt.parse(
                sharedSecret
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(),
                radix: 16,
              ),
            ),
          );
        }
      }

      final conversation = await _storageService.getOrCreateConversation(
        recipientUniqueUsername,
        recipient.username,
        ConversationType.dm,
      );

      await loadConversations();
      return conversation;
    } catch (e) {
      _setError('Failed to start conversation: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Conversation?> createGroup(
    String groupName,
    List<String> memberIds,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final request = CreateGroupRequest(
        groupName: groupName,
        members: memberIds,
      );

      final result = await _apiService.createGroup(request);

      if (result.isTokenExpired) {
        _handleTokenExpired();
        return null;
      }

      if (result.isSuccess && result.data != null) {
        final groupId = result.data!;

        final conversation = await _storageService.getOrCreateConversation(
          groupId.toString(),
          groupName,
          ConversationType.group,
          members: memberIds,
        );

        await loadConversations();
        return conversation;
      } else {
        _setError(result.error ?? 'Failed to create group');
        return null;
      }
    } catch (e) {
      _setError('Failed to create group: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMessages(String conversationId) async {
    try {
      final messages = await _storageService.getMessages(conversationId);
      final list = messages.reversed.toList();

      for (var i = 0; i < list.length; i++) {
        final msg = list[i];
        if (msg.decryptedContent == null) {
          final decrypted = await _decryptMessage(msg);
          final updated = msg.copyWith(decryptedContent: decrypted);
          list[i] = updated;

          try {
            await _storageService.saveMessage(updated, conversationId);
          } catch (_) {}
        }
      }

      _messages[conversationId] = list;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load messages: $e');
    }
  }

  Future<bool> sendMessage(
    String conversationId,
    String content, {
    bool isGroup = false,
  }) async {
    if (_currentUser == null) return false;

    try {
      final rsaPrivateKeyPem = await _storageService.getRSAPrivateKey();
      final localId = const Uuid().v4();
      
      if (isGroup) {
        // For group messages, encrypt for each member individually (pairwise)
        return await _sendGroupMessagePairwise(
          conversationId,
          content,
          localId,
          rsaPrivateKeyPem,
        );
      } else {
        // For private messages, use existing logic
        return await _sendPrivateMessage(
          conversationId,
          content,
          localId,
          rsaPrivateKeyPem,
        );
      }
    } catch (e) {
      _setError('Failed to send message: $e');
      return false;
    }
  }

  Future<bool> _sendPrivateMessage(
    String conversationId,
    String content,
    String localId,
    String? rsaPrivateKeyPem,
  ) async {
    Uint8List? sharedSecret;
    final secretBase64 = await _storageService.getSharedSecret(conversationId);
    print("Retrieved shared secret base64: $secretBase64");
    if (secretBase64 != null) {
      sharedSecret = base64Decode(secretBase64);
    }

    sharedSecret ??= Uint8List.fromList(List.generate(32, (i) => i));

    final encrypted = CryptoService.encryptAESGCM(content, sharedSecret);

    String signature = '';
    if (rsaPrivateKeyPem != null) {
      final rsaPrivateKey = CryptoService.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
      signature = CryptoService.sign(encrypted.ciphertext, rsaPrivateKey);
    }

    final message = Message(
      localId: localId,
      senderId: _currentUser!.uniqueUsername,
      receiverId: conversationId,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      authTag: encrypted.authTag,
      signature: signature,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      decryptedContent: content,
    );
    await _storageService.saveMessage(message, conversationId);

    _messages[conversationId] = [
      ...(_messages[conversationId] ?? []),
      message,
    ];
    notifyListeners();

    final result = await _apiService.sendMessage(message);
    
    return await _handleSendResult(result, localId, conversationId, message);
  }

  Future<bool> _sendGroupMessagePairwise(
    String conversationId,
    String content,
    String localId,
    String? rsaPrivateKeyPem,
  ) async {
    final groupId = int.parse(conversationId);
    
    // Fetch group members with their public keys
    final membersResult = await _apiService.getGroupMembers(groupId);
    if (membersResult.isTokenExpired) {
      _handleTokenExpired();
      return false;
    }
    if (!membersResult.isSuccess || membersResult.data == null) {
      _setError(membersResult.error ?? 'Failed to get group members');
      return false;
    }

    final members = membersResult.data!;
    final encryptedCopies = <EncryptedMessageCopy>[];
    
    // Encrypt message for each member using their DH public key
    for (final member in members) {
      // Skip self
      if (member.uniqueUsername == _currentUser!.uniqueUsername) continue;
      
      try {
        // Get or compute shared secret with this member
        var secretBase64 = await _storageService.getSharedSecret(member.uniqueUsername);
        Uint8List sharedSecret;
        
        if (secretBase64 != null) {
          sharedSecret = base64Decode(secretBase64);
        } else if (member.dhPublicKey != null) {
          // Compute shared secret
          final myDHPrivateKey = await _storageService.getDHPrivateKey();
          if (myDHPrivateKey != null) {
            sharedSecret = CryptoService.computeSharedSecret(
              CryptoService.dhPrivateKeyFromBase64(myDHPrivateKey),
              CryptoService.dhPublicKeyFromBase64(member.dhPublicKey!),
            );
            await _storageService.storeSharedSecret(
              member.uniqueUsername,
              base64Encode(sharedSecret),
            );
          } else {
            sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
          }
        } else {
          sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        }

        // Encrypt message for this member
        final encrypted = CryptoService.encryptAESGCM(content, sharedSecret);

        String signature = '';
        if (rsaPrivateKeyPem != null) {
          final rsaPrivateKey = CryptoService.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
          signature = CryptoService.sign(encrypted.ciphertext, rsaPrivateKey);
        }

        encryptedCopies.add(EncryptedMessageCopy(
          recipientUsername: member.uniqueUsername,
          ciphertext: encrypted.ciphertext,
          nonce: encrypted.nonce,
          authTag: encrypted.authTag,
          signature: signature,
        ));
      } catch (e) {
        debugPrint('Failed to encrypt for member ${member.uniqueUsername}: $e');
      }
    }

    if (encryptedCopies.isEmpty) {
      _setError('Failed to encrypt message for any group member');
      return false;
    }

    // Save local copy of the message (with our own encryption for display)
    final mySecret = Uint8List.fromList(List.generate(32, (i) => i));
    final myEncrypted = CryptoService.encryptAESGCM(content, mySecret);
    
    final message = Message(
      localId: localId,
      senderId: _currentUser!.uniqueUsername,
      groupId: groupId,
      ciphertext: myEncrypted.ciphertext,
      nonce: myEncrypted.nonce,
      authTag: myEncrypted.authTag,
      signature: '',
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
      decryptedContent: content,
    );
    await _storageService.saveMessage(message, conversationId);

    _messages[conversationId] = [
      ...(_messages[conversationId] ?? []),
      message,
    ];
    notifyListeners();

    // Send to server
    final request = SendGroupMessageRequest(encryptedCopies: encryptedCopies);
    final result = await _apiService.sendGroupMessage(groupId, request);
    
    return await _handleSendResult(result, localId, conversationId, message);
  }

  Future<bool> _handleSendResult(
    ApiResult<void> result,
    String localId,
    String conversationId,
    Message message,
  ) async {
    if (result.isTokenExpired) {
      _handleTokenExpired();
      await _storageService.updateMessageStatus(localId, MessageStatus.failed);
      return false;
    }
    
    if (result.isSuccess) {
      await _storageService.updateMessageStatus(localId, MessageStatus.sent);
      final index = _messages[conversationId]!.indexWhere(
        (m) => m.localId == localId,
      );
      if (index != -1) {
        _messages[conversationId]![index] = message.copyWith(
          status: MessageStatus.sent,
        );
        notifyListeners();
      }
    } else {
      await _storageService.updateMessageStatus(localId, MessageStatus.failed);
    }

    await _storageService.updateLastActivity(conversationId, DateTime.now());
    await loadConversations();

    return result.isSuccess;
  }

  Future<void> fetchMessages() async {
    if (_currentUser == null) return;

    try {
      // Also sync groups in case user was added to a new group
      await syncGroupsFromServer();
      
      final result = await _apiService.getAllPendingMessages();
      if (result.isTokenExpired) {
        _handleTokenExpired();
        return;
      }

      if (result.isSuccess && result.data != null) {
        final privateMessageIds = <int>[];
        final groupCopyIds = <int>[];

        // Process private messages
        for (final message in result.data!.privateMessages) {
          final decryptedContent = await _decryptMessage(message);
          final decryptedMessage = message.copyWith(
            decryptedContent: decryptedContent,
          );
          final conversationId = message.senderId;

          await _storageService.saveMessage(decryptedMessage, conversationId);

          await _storageService.getOrCreateConversation(
            conversationId,
            message.senderId,
            ConversationType.dm,
          );

          if (message.id != null) {
            privateMessageIds.add(message.id!);
          }
        }
        
        // Process group messages
        for (final message in result.data!.groupMessages) {
          final groupId = message.groupId;
          if (groupId == null) continue;
          
          final conversationId = groupId.toString();
          final decryptedContent = await _decryptMessage(message);
          final decryptedMessage = message.copyWith(
            decryptedContent: decryptedContent,
          );

          await _storageService.saveMessage(decryptedMessage, conversationId);

          if (message.id != null) {
            groupCopyIds.add(message.id!);
          }
        }
        
        // Acknowledge messages
        if (privateMessageIds.isNotEmpty) {
          await _apiService.acknowledgeMessages(privateMessageIds);
        }
        if (groupCopyIds.isNotEmpty) {
          await _apiService.acknowledgeGroupMessages(groupCopyIds);
        }

        await loadConversations();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    }
  }

  Future<String> _decryptMessage(Message message) async {
    try {
      var secretBase64 = await _storageService.getSharedSecret(message.senderId);
      Uint8List sharedSecret;

      if (secretBase64 != null) {
        sharedSecret = base64Decode(secretBase64);
      } else {
        try {
          var cached = await _storageService.getCachedUserKeys(message.senderId);

          if (cached == null) {
            final keysResult = await _apiService.getUserKeys(message.senderId);
            if (keysResult.isTokenExpired) {
              _handleTokenExpired();
              return '[Decryption failed]';
            }
            if (keysResult.isSuccess && keysResult.data != null) {
              cached = keysResult.data!;
              await _storageService.cacheUserKeys(cached);
            }
          }

          if (cached != null && cached.dhPublicKey != null) {
            final myDHPrivateKey = await _storageService.getDHPrivateKey();
            if (myDHPrivateKey != null) {
              final secret = CryptoService.computeSharedSecret(
                CryptoService.dhPrivateKeyFromBase64(myDHPrivateKey),
                CryptoService.dhPublicKeyFromBase64(cached.dhPublicKey!),
              );

              secretBase64 = base64Encode(secret);
              await _storageService.storeSharedSecret(message.senderId, secretBase64);
              sharedSecret = secret;
            } else {
              sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
            }
          } else {
            sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
          }
        } catch (e) {
          sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
        }
      }
      print('Decrypting message with shared secret: $sharedSecret');
      print(
        "message info : ${message.ciphertext}, ${message.nonce}, ${message.authTag}",
      );
      final encrypted = EncryptedData(
        ciphertext: message.ciphertext,
        nonce: message.nonce,
        authTag: message.authTag,
      );

      return CryptoService.decryptAESGCM(encrypted, sharedSecret);
    } catch (e) {
      print('Decryption error: $e ');
      return '[Decryption failed]';
    }
  }


  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
