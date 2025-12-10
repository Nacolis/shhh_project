class User {
  final int id;
  final String uniqueUsername;
  final String username;
  final String? rsaPublicKey;
  final String? dhPublicKey;

  User({
    required this.id,
    required this.uniqueUsername,
    required this.username,
    this.rsaPublicKey,
    this.dhPublicKey,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      uniqueUsername: json['unique_username'] as String,
      username: json['username'] as String,
      rsaPublicKey: json['rsa_public_key'] as String?,
      dhPublicKey: json['dh_public_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unique_username': uniqueUsername,
      'username': username,
      'rsa_public_key': rsaPublicKey,
      'dh_public_key': dhPublicKey,
    };
  }

  User copyWith({
    int? id,
    String? uniqueUsername,
    String? username,
    String? rsaPublicKey,
    String? dhPublicKey,
  }) {
    return User(
      id: id ?? this.id,
      uniqueUsername: uniqueUsername ?? this.uniqueUsername,
      username: username ?? this.username,
      rsaPublicKey: rsaPublicKey ?? this.rsaPublicKey,
      dhPublicKey: dhPublicKey ?? this.dhPublicKey,
    );
  }
}
