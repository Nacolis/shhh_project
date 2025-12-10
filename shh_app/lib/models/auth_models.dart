class AuthResponse {
  final String accessToken;
  final String message;
  final AuthUser user;

  AuthResponse({
    required this.accessToken,
    required this.message,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      message: json['message'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthUser {
  final int id;
  final String uniqueUsername;
  final String username;
  final String? rsaPublicKey;
  final String? dhPublicKey;

  AuthUser({
    required this.id,
    required this.uniqueUsername,
    required this.username,
    this.rsaPublicKey,
    this.dhPublicKey,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
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
}

class RegisterRequest {
  final String uniqueUsername;
  final String username;
  final String password;
  final String rsaPublicKey;
  final String dhPublicKey;

  RegisterRequest({
    required this.uniqueUsername,
    required this.username,
    required this.password,
    required this.rsaPublicKey,
    required this.dhPublicKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'unique_username': uniqueUsername,
      'username': username,
      'password': password,
      'rsa_public_key': rsaPublicKey,
      'dh_public_key': dhPublicKey,
    };
  }
}

class LoginRequest {
  final String uniqueUsername;
  final String password;

  LoginRequest({required this.uniqueUsername, required this.password});

  Map<String, dynamic> toJson() {
    return {'unique_username': uniqueUsername, 'password': password};
  }
}
