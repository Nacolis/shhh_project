class AppConstants {
  static const String appName = 'SHHH';
  static const String appTagline = '// ENCRYPTED_COMMS_ONLY';
  
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';
  static const String privateKeyKey = 'private_key';
  static const String dhPrivateKeyKey = 'dh_private_key';
  
  static const int rsaKeySize = 2048;
  static const int dhKeySize = 2048;
  static const int aesKeySize = 256;
  
  static const double glitchIntensity = 0.03;
  static const int blinkInterval = 500;
}
