import 'message.dart';

class Conversation {
  final String id;
  final ConversationType type;
  final String name;
  final String? avatarUrl;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime? lastActivityAt;
  final List<String>? members;

  Conversation({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastActivityAt,
    this.members,
  });

  bool get isGroup => type == ConversationType.group;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      type: ConversationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConversationType.dm,
      ),
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.parse(json['last_activity_at'] as String)
          : null,
      members: (json['members'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'avatar_url': avatarUrl,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'members': members,
    };
  }

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? name,
    String? avatarUrl,
    Message? lastMessage,
    int? unreadCount,
    DateTime? lastActivityAt,
    List<String>? members,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      members: members ?? this.members,
    );
  }
}

enum ConversationType { dm, group }
