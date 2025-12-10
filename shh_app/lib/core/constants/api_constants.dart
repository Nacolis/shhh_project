class ApiConstants {
  static const bool isDevelopment = false;
  
  static String get baseUrl => isDevelopment 
      ? 'http://localhost:5500/api'
      : 'https://shh.univ-edt.fr/api';
  
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  
  static String get messages => '$baseUrl/messages';
  static String get messagesAck => '$baseUrl/messages/ack';
  
  static String get groups => '$baseUrl/groups';
  static String groupMessages(int groupId) => '$baseUrl/groups/$groupId/messages';
  

  static String userKeys(String uniqueUsername) => '$baseUrl/users/$uniqueUsername/keys';
}
