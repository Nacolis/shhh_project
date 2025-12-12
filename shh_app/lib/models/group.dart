class Group {
  final int id;
  final String name;
  final List<String> members;
  final int? memberCount;
  final DateTime? createdAt;

  Group({
    required this.id,
    required this.name,
    required this.members,
    this.memberCount,
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int? ?? json['group_id'] as int,
      name: json['name'] as String? ?? json['group_name'] as String,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      memberCount: json['member_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'members': members,
      'member_count': memberCount,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class CreateGroupRequest {
  final String groupName;
  final List<String> members;

  CreateGroupRequest({required this.groupName, required this.members});

  Map<String, dynamic> toJson() {
    return {'group_name': groupName, 'members': members};
  }
}

/// Encrypted copy of a message for a specific recipient (pairwise encryption)
class EncryptedMessageCopy {
  final String recipientUsername;
  final String ciphertext;
  final String nonce;
  final String authTag;
  final String signature;

  EncryptedMessageCopy({
    required this.recipientUsername,
    required this.ciphertext,
    required this.nonce,
    required this.authTag,
    required this.signature,
  });

  Map<String, dynamic> toJson() {
    return {
      'recipient_username': recipientUsername,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'auth_tag': authTag,
      'signature': signature,
    };
  }
}

/// Request to send a group message with pairwise encrypted copies
class SendGroupMessageRequest {
  final List<EncryptedMessageCopy> encryptedCopies;

  SendGroupMessageRequest({required this.encryptedCopies});

  Map<String, dynamic> toJson() {
    return {
      'encrypted_copies': encryptedCopies.map((e) => e.toJson()).toList(),
    };
  }
}

/// Group member with their public keys
class GroupMember {
  final int id;
  final String uniqueUsername;
  final String username;
  final String? rsaPublicKey;
  final String? dhPublicKey;

  GroupMember({
    required this.id,
    required this.uniqueUsername,
    required this.username,
    this.rsaPublicKey,
    this.dhPublicKey,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as int,
      uniqueUsername: json['unique_username'] as String,
      username: json['username'] as String,
      rsaPublicKey: json['rsa_public_key'] as String?,
      dhPublicKey: json['dh_public_key'] as String?,
    );
  }
}
