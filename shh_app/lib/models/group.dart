class Group {
  final int id;
  final String name;
  final List<String> members;
  final DateTime? createdAt;

  Group({
    required this.id,
    required this.name,
    required this.members,
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
