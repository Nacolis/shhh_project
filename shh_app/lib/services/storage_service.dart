import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';


class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  Database? _database;

  

  
  Future<void> storeAuthToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  
  Future<void> storeCurrentUser(AuthUser user) async {
    await _secureStorage.write(key: 'current_user', value: jsonEncode(user.toJson()));
  }

  
  Future<AuthUser?> getCurrentUser() async {
    final data = await _secureStorage.read(key: 'current_user');
    if (data == null) return null;
    return AuthUser.fromJson(jsonDecode(data));
  }

  
  Future<void> storeRSAPrivateKey(String privateKeyPem) async {
    await _secureStorage.write(key: 'rsa_private_key', value: privateKeyPem);
  }

  
  Future<String?> getRSAPrivateKey() async {
    return await _secureStorage.read(key: 'rsa_private_key');
  }

  
  Future<void> storeDHPrivateKey(String privateKey) async {
    await _secureStorage.write(key: 'dh_private_key', value: privateKey);
  }

  
  Future<String?> getDHPrivateKey() async {
    return await _secureStorage.read(key: 'dh_private_key');
  }

  
  Future<void> storeSharedSecret(String recipientId, String secret) async {
    await _secureStorage.write(key: 'shared_secret_$recipientId', value: secret);
  }

  
  Future<String?> getSharedSecret(String recipientId) async {
    return await _secureStorage.read(key: 'shared_secret_$recipientId');
  }

  Future<void> deleteSharedSecret(String recipientId) async {
    await _secureStorage.delete(key: 'shared_secret_$recipientId');
  }

  
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/shhh_messages.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        local_id TEXT UNIQUE,
        sender_id TEXT NOT NULL,
        receiver_id TEXT,
        group_id INTEGER,
        ciphertext TEXT NOT NULL,
        nonce TEXT NOT NULL,
        auth_tag TEXT NOT NULL,
        signature TEXT NOT NULL,
        decrypted_content TEXT,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        conversation_id TEXT NOT NULL
      )
    ''');

    
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        avatar_url TEXT,
        last_message_id INTEGER,
        unread_count INTEGER DEFAULT 0,
        last_activity_at TEXT,
        members TEXT
      )
    ''');

    
    await db.execute('''
      CREATE TABLE user_keys (
        unique_username TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        rsa_public_key TEXT,
        dh_public_key TEXT,
        cached_at TEXT NOT NULL
      )
    ''');

    
    await db.execute('CREATE INDEX idx_messages_conversation ON messages(conversation_id)');
    await db.execute('CREATE INDEX idx_messages_timestamp ON messages(timestamp)');
  }

  

  
  Future<int> saveMessage(Message message, String conversationId) async {
    final db = await database;
    return db.insert('messages', {
      'server_id': message.id,
      'local_id': message.localId,
      'sender_id': message.senderId,
      'receiver_id': message.receiverId,
      'group_id': message.groupId,
      'ciphertext': message.ciphertext,
      'nonce': message.nonce,
      'auth_tag': message.authTag,
      'signature': message.signature,
      'decrypted_content': message.decryptedContent,
      'timestamp': message.timestamp.toIso8601String(),
      'status': message.status.name,
      'conversation_id': conversationId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  
  Future<List<Message>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final results = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    
    return results.map((row) => Message(
      id: row['server_id'] as int?,
      localId: row['local_id'] as String?,
      senderId: row['sender_id'] as String,
      receiverId: row['receiver_id'] as String?,
      groupId: row['group_id'] as int?,
      ciphertext: row['ciphertext'] as String,
      nonce: row['nonce'] as String,
      authTag: row['auth_tag'] as String,
      signature: row['signature'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      status: MessageStatus.values.firstWhere((e) => e.name == row['status']),
      decryptedContent: row['decrypted_content'] as String?,
    )).toList();
  }

  
  Future<void> updateMessageStatus(String localId, MessageStatus status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status.name},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  

  
  Future<void> saveConversation(Conversation conversation) async {
    final db = await database;
    await db.insert('conversations', {
      'id': conversation.id,
      'type': conversation.type.name,
      'name': conversation.name,
      'avatar_url': conversation.avatarUrl,
      'unread_count': conversation.unreadCount,
      'last_activity_at': conversation.lastActivityAt?.toIso8601String(),
      'members': conversation.members != null ? jsonEncode(conversation.members) : null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  
  Future<List<Conversation>> getConversations() async {
    final db = await database;
    final results = await db.query(
      'conversations',
      orderBy: 'last_activity_at DESC',
    );
    
    return results.map((row) => Conversation(
      id: row['id'] as String,
      type: ConversationType.values.firstWhere((e) => e.name == row['type']),
      name: row['name'] as String,
      avatarUrl: row['avatar_url'] as String?,
      unreadCount: row['unread_count'] as int? ?? 0,
      lastActivityAt: row['last_activity_at'] != null 
          ? DateTime.parse(row['last_activity_at'] as String)
          : null,
      members: row['members'] != null 
          ? List<String>.from(jsonDecode(row['members'] as String))
          : null,
    )).toList();
  }

  
  Future<Conversation> getOrCreateConversation(String id, String name, ConversationType type, {List<String>? members}) async {
    final db = await database;
    final results = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (results.isEmpty) {
      final conversation = Conversation(
        id: id,
        name: name,
        type: type,
        lastActivityAt: DateTime.now(),
        members: members,
      );
      await saveConversation(conversation);
      return conversation;
    }
    
    final row = results.first;
    return Conversation(
      id: row['id'] as String,
      type: ConversationType.values.firstWhere((e) => e.name == row['type']),
      name: row['name'] as String,
      avatarUrl: row['avatar_url'] as String?,
      unreadCount: row['unread_count'] as int? ?? 0,
      lastActivityAt: row['last_activity_at'] != null 
          ? DateTime.parse(row['last_activity_at'] as String)
          : null,
      members: row['members'] != null 
          ? List<String>.from(jsonDecode(row['members'] as String))
          : null,
    );
  }

  
  Future<void> updateUnreadCount(String conversationId, int count) async {
    final db = await database;
    await db.update(
      'conversations',
      {'unread_count': count},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  
  Future<void> updateLastActivity(String conversationId, DateTime time) async {
    final db = await database;
    await db.update(
      'conversations',
      {'last_activity_at': time.toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  

  
  Future<void> cacheUserKeys(User user) async {
    final db = await database;
    await db.insert('user_keys', {
      'unique_username': user.uniqueUsername,
      'username': user.username,
      'rsa_public_key': user.rsaPublicKey,
      'dh_public_key': user.dhPublicKey,
      'cached_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  
  Future<User?> getCachedUserKeys(String uniqueUsername) async {
    final db = await database;
    final results = await db.query(
      'user_keys',
      where: 'unique_username = ?',
      whereArgs: [uniqueUsername],
    );
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    return User(
      id: 0, 
      uniqueUsername: row['unique_username'] as String,
      username: row['username'] as String,
      rsaPublicKey: row['rsa_public_key'] as String?,
      dhPublicKey: row['dh_public_key'] as String?,
    );
  }

  
  Future<void> clearAll() async {
    await clearSecureStorage();
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
    await db.delete('user_keys');
  }


  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    await deleteSharedSecret(conversationId);
  }

  Future<void> updateConversationMembers(String conversationId, List<String> members) async {
    final db = await database;
    await db.update(
      'conversations',
      {'members': jsonEncode(members)},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }
}
