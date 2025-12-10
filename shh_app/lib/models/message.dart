class Message {
  final int? id;
  final String? localId;
  final String senderId;
  final String? receiverId;
  final int? groupId;
  final String ciphertext;
  final String nonce;
  final String authTag;
  final String signature;
  final DateTime timestamp;
  final MessageStatus status;
  final String? decryptedContent;

  Message({
    this.id,
    this.localId,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.ciphertext,
    required this.nonce,
    required this.authTag,
    required this.signature,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.decryptedContent,
  });

  bool get isGroupMessage => groupId != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    print("message created at : ${json['timestamp']}");
    return Message(
      id: json['id'] as int?,
      localId: json['local_id'] as String?,
      senderId: json['sender'] as String,
      receiverId: json['receiver'] as String?,
      groupId: json['group_id'] as int?,
      ciphertext: json['ciphertext'] as String,
      nonce: json['nonce'] as String,
      authTag: json['auth_tag'] as String,
      signature: json['signature'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String).toLocal()
          : DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      decryptedContent: json['decrypted_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_id': localId,
      'sender': senderId,
      'receiver': receiverId,
      'group_id': groupId,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'auth_tag': authTag,
      'signature': signature,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'decrypted_content': decryptedContent,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'receiver_username': receiverId,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'auth_tag': authTag,
      'signature': signature,
    };
  }

  Map<String, dynamic> toGroupApiJson() {
    return {
      'ciphertext': ciphertext,
      'nonce': nonce,
      'auth_tag': authTag,
      'signature': signature,
    };
  }

  Message copyWith({
    int? id,
    String? localId,
    String? senderId,
    String? receiverId,
    int? groupId,
    String? ciphertext,
    String? nonce,
    String? authTag,
    String? signature,
    DateTime? timestamp,
    MessageStatus? status,
    String? decryptedContent,
  }) {
    return Message(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      authTag: authTag ?? this.authTag,
      signature: signature ?? this.signature,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      decryptedContent: decryptedContent ?? this.decryptedContent,
    );
  }
}

enum MessageStatus { pending, sent, delivered, read, failed }
