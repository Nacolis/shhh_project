class ApiConstants {
  static const bool isDevelopment = false;
  
  static String get baseUrl => isDevelopment 
      ? 'http://localhost:5500/api'
      : 'https://shh.univ-edt.fr/api';
  
  static String get socketIOUrl => isDevelopment
      ? 'http://localhost:5500'
      : 'https://shh.univ-edt.fr';
  
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  
  static String get messages => '$baseUrl/messages';
  static String get messagesAck => '$baseUrl/messages/ack';
  static String get pendingMessages => '$baseUrl/messages/pending';
  static String get groupMessagesAck => '$baseUrl/messages/group/ack';
  
  static String get groups => '$baseUrl/groups';
  static String group(int groupId) => '$baseUrl/groups/$groupId';
  static String groupMessages(int groupId) => '$baseUrl/groups/$groupId/messages';
  static String groupMembers(int groupId) => '$baseUrl/groups/$groupId/members';
  static String groupMember(int groupId, String uniqueUsername) => '$baseUrl/groups/$groupId/members/$uniqueUsername';
  static String groupLeave(int groupId) => '$baseUrl/groups/$groupId/leave';
  
  static String conversation(String uniqueUsername) => '$baseUrl/conversations/$uniqueUsername';

  static String userKeys(String uniqueUsername) => '$baseUrl/users/$uniqueUsername/keys';
}
