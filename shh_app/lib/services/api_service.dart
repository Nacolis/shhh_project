import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/models.dart';

class ApiService {
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<ApiResult<AuthResponse>> register(RegisterRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        return ApiResult.success(
          AuthResponse(
            accessToken: '',
            message: 'User registered successfully',
            user: AuthUser.fromJson(jsonDecode(response.body)['user']),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(data);
        _authToken = authResponse.accessToken;
        return ApiResult.success(authResponse);
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<List<Message>>> getPendingMessages() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.messages),
        headers: _headers,
      );
      print("response status: ${response.statusCode}");
      print("response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((e) => Message.fromJson(e)).toList();
        return ApiResult.success(messages);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        return ApiResult.failure('Failed to fetch messages');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<void>> sendMessage(Message message) async {
    try {
      print(jsonEncode(message.toApiJson()));
      final response = await http.post(
        Uri.parse(ApiConstants.messages),
        headers: _headers,
        body: jsonEncode(message.toApiJson()),
      );
      print(response.body);

      if (response.statusCode == 201) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<void>> acknowledgeMessages(List<int> messageIds) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.messagesAck),
        headers: _headers,
        body: jsonEncode({'message_ids': messageIds}),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        return ApiResult.failure('Failed to acknowledge messages');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<int>> createGroup(CreateGroupRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groups),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResult.success(data['group_id'] as int);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['message'] ?? 'Failed to create group');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<List<Message>>> getGroupMessages(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.groupMessages(groupId)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((e) => Message.fromJson(e)).toList();
        return ApiResult.success(messages);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        return ApiResult.failure('Failed to fetch group messages');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<void>> sendGroupMessage(int groupId, Message message) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groupMessages(groupId)),
        headers: _headers,
        body: jsonEncode(message.toGroupApiJson()),
      );

      if (response.statusCode == 201) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<User>> getUserKeys(String uniqueUsername) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.userKeys(uniqueUsername)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(User.fromJson(data));
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 404) {
        return ApiResult.failure('User not found');
      } else {
        return ApiResult.failure('Failed to fetch user keys');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }
}

class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final bool isTokenExpired;

  ApiResult._({
    this.data,
    this.error,
    required this.isSuccess,
    this.isTokenExpired = false,
  });

  factory ApiResult.success(T? data) =>
      ApiResult._(data: data, isSuccess: true);
  factory ApiResult.failure(String error) =>
      ApiResult._(error: error, isSuccess: false);
  factory ApiResult.tokenExpired() => ApiResult._(
    error: 'Token expired',
    isSuccess: false,
    isTokenExpired: true,
  );
}
