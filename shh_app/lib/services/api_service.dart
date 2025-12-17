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

  String? get authToken => _authToken;

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
      print("response text  : ${response.body}");

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

  Future<ApiResult<List<Group>>> getUserGroups() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.groups),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final groups = data.map((e) => Group.fromJson(e)).toList();
        return ApiResult.success(groups);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        return ApiResult.failure('Failed to fetch groups');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<List<GroupMember>>> getGroupMembers(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.groupMembers(groupId)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final members = data.map((e) => GroupMember.fromJson(e)).toList();
        return ApiResult.success(members);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 403) {
        return ApiResult.failure('Not a member of this group');
      } else {
        return ApiResult.failure('Failed to fetch group members');
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

  Future<ApiResult<void>> sendGroupMessage(
    int groupId,
    SendGroupMessageRequest request,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groupMessages(groupId)),
        headers: _headers,
        body: jsonEncode(request.toJson()),
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

  Future<ApiResult<PendingMessagesResponse>> getAllPendingMessages() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.pendingMessages),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult.success(PendingMessagesResponse.fromJson(data));
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        return ApiResult.failure('Failed to fetch pending messages');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<void>> acknowledgeGroupMessages(List<int> copyIds) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groupMessagesAck),
        headers: _headers,
        body: jsonEncode({'copy_ids': copyIds}),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else {
        return ApiResult.failure('Failed to acknowledge group messages');
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

  // ==================== Group Management ====================

  Future<ApiResult<void>> deleteGroup(int groupId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.group(groupId)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 403) {
        return ApiResult.failure('Only admin can delete the group');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('Group not found');
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['error'] ?? 'Failed to delete group');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<GroupMember>> addGroupMember(int groupId, String uniqueUsername) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groupMembers(groupId)),
        headers: _headers,
        body: jsonEncode({'unique_username': uniqueUsername}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResult.success(GroupMember.fromJson(data['member']));
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 403) {
        return ApiResult.failure('Only admin can add members');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('User not found');
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['error'] ?? 'Failed to add member');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<void>> removeGroupMember(int groupId, String uniqueUsername) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.groupMember(groupId, uniqueUsername)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 403) {
        return ApiResult.failure('Only admin can remove members');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('User not found');
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['error'] ?? 'Failed to remove member');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  Future<ApiResult<void>> leaveGroup(int groupId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.groupLeave(groupId)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['error'] ?? 'Cannot leave group');
      } else if (response.statusCode == 404) {
        return ApiResult.failure('Not a member of this group');
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['error'] ?? 'Failed to leave group');
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  // ==================== Conversation Management ====================

  Future<ApiResult<void>> deleteConversation(String uniqueUsername) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.conversation(uniqueUsername)),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else if (response.statusCode == 401) {
        return ApiResult.tokenExpired();
      } else if (response.statusCode == 404) {
        return ApiResult.failure('User not found');
      } else {
        final error = jsonDecode(response.body);
        return ApiResult.failure(error['error'] ?? 'Failed to delete conversation');
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
