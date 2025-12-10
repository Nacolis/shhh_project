import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  AuthUser? _currentUser;
  String? _authToken;
  bool _isLoading = false;
  String? _error;
  List<Conversation> _conversations = [];
  Map<String, List<Message>> _messages = {};

  // Token expiration callback
  bool _tokenExpired = false;
  bool get tokenExpired => _tokenExpired;

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
        await loadConversations();
      }
    } catch (e) {
      _setError('Failed to initialize: $e');
    }
    _setLoading(false);
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

        await loadConversations();

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
    _apiService.clearAuthToken();
    await _storageService.clearSecureStorage();

    _currentUser = null;
    _authToken = null;
    _conversations = [];
    _messages = {};

    notifyListeners();
  }

  Future<void> resetApp() async {
    _setLoading(true);
    try {
      _apiService.clearAuthToken();
      await _storageService.clearAll();
      _currentUser = null;
      _authToken = null;
      _conversations = [];
      _messages = {};
      _tokenExpired = false;

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
      Uint8List? sharedSecret;

      if (!isGroup) {
        final secretBase64 = await _storageService.getSharedSecret(
          conversationId,
        );
        print("Retrieved shared secret base64: $secretBase64");
        if (secretBase64 != null) {
          sharedSecret = base64Decode(secretBase64);
        }
      }

      sharedSecret ??= Uint8List.fromList(List.generate(32, (i) => i));

      final encrypted = CryptoService.encryptAESGCM(content, sharedSecret);


      final rsaPrivateKeyPem = await _storageService.getRSAPrivateKey();
      String signature = '';
      if (rsaPrivateKeyPem != null) {
        final rsaPrivateKey = CryptoService.rsaPrivateKeyFromPem(
          rsaPrivateKeyPem,
        );
        signature = CryptoService.sign(encrypted.ciphertext, rsaPrivateKey);
      }

      final localId = const Uuid().v4();
      final message = Message(
        localId: localId,
        senderId: _currentUser!.uniqueUsername,
        receiverId: isGroup ? null : conversationId,
        groupId: isGroup ? int.tryParse(conversationId) : null,
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

      ApiResult<void> result;
      if (isGroup) {
        result = await _apiService.sendGroupMessage(
          int.parse(conversationId),
          message,
        );
      } else {
        result = await _apiService.sendMessage(message);
      }
      if (result.isTokenExpired) {
        _handleTokenExpired();
        await _storageService.updateMessageStatus(
          localId,
          MessageStatus.failed,
        );
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
        await _storageService.updateMessageStatus(
          localId,
          MessageStatus.failed,
        );
      }

      await _storageService.updateLastActivity(conversationId, DateTime.now());
      await loadConversations();

      return result.isSuccess;
    } catch (e) {
      _setError('Failed to send message: $e');
      return false;
    }
  }

  Future<void> fetchMessages() async {
    if (_currentUser == null) return;

    try {
      final result = await _apiService.getPendingMessages();
      if (result.isTokenExpired) {
        _handleTokenExpired();
        return;
      }

      if (result.isSuccess && result.data != null) {
        final messageIds = <int>[];

        for (final message in result.data!) {
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
            messageIds.add(message.id!);
          }
        }
        if (messageIds.isNotEmpty) {
          await _apiService.acknowledgeMessages(messageIds);
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
