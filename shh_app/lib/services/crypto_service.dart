import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;

/// Cryptography service for E2E encryption
class CryptoService {
  static final _random = Random.secure();
  
  static FortunaRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seeds = List<int>.generate(32, (_) => _random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  // ==================== RSA KEY GENERATION ====================

  /// Generate RSA key pair for signing and encryption
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _getSecureRandom(),
      ));
    
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  /// Convert RSA public key to PEM format
  static String rsaPublicKeyToPem(RSAPublicKey publicKey) {
    final bytes = _encodeRSAPublicKey(publicKey);
    final base64 = base64Encode(bytes);
    return '-----BEGIN PUBLIC KEY-----\n${_chunked(base64, 64)}\n-----END PUBLIC KEY-----';
  }

  /// Convert RSA private key to PEM format
  static String rsaPrivateKeyToPem(RSAPrivateKey privateKey) {
    final bytes = _encodeRSAPrivateKey(privateKey);
    final base64 = base64Encode(bytes);
    return '-----BEGIN RSA PRIVATE KEY-----\n${_chunked(base64, 64)}\n-----END RSA PRIVATE KEY-----';
  }

  /// Parse RSA public key from PEM
  static RSAPublicKey rsaPublicKeyFromPem(String pem) {
    final lines = pem.split('\n')
      .where((line) => !line.startsWith('-----'))
      .join('');
    final bytes = base64Decode(lines);
    return _decodeRSAPublicKey(bytes);
  }

  /// Parse RSA private key from PEM
  static RSAPrivateKey rsaPrivateKeyFromPem(String pem) {
    final lines = pem.split('\n')
      .where((line) => !line.startsWith('-----'))
      .join('');
    final bytes = base64Decode(lines);
    return _decodeRSAPrivateKey(bytes);
  }

  // ==================== DIFFIE-HELLMAN (Custom Implementation) ====================
  
  // RFC 3526 Group 14 (2048-bit MODP)
  static final BigInt _dhP = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
    '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
    '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05'
    '98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB'
    '9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718'
    '3995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF',
    radix: 16,
  );
  static final BigInt _dhG = BigInt.from(2);

  /// Generate DH key pair (returns private key and public key as BigInt)
  static DHKeyPair generateDHKeyPair() {
    // Generate random private key (x) between 2 and p-2
    final privateKey = _generateRandomBigInt(_dhP - BigInt.two);
    // Compute public key: y = g^x mod p
    final publicKey = _dhG.modPow(privateKey, _dhP);
    
    return DHKeyPair(privateKey: privateKey, publicKey: publicKey);
  }

  static BigInt _generateRandomBigInt(BigInt max) {
    final bytes = (max.bitLength + 7) ~/ 8;
    BigInt result;
    do {
      final randomBytes = List<int>.generate(bytes, (_) => _random.nextInt(256));
      result = _bytesToBigInt(Uint8List.fromList(randomBytes));
    } while (result >= max || result < BigInt.two);
    return result;
  }

  /// Export DH public key as base64
  static String dhPublicKeyToBase64(BigInt publicKey) {
    return base64Encode(_bigIntToBytes(publicKey));
  }

  /// Import DH public key from base64
  static BigInt dhPublicKeyFromBase64(String base64Key) {
    return _bytesToBigInt(base64Decode(base64Key));
  }

  /// Export DH private key as base64
  static String dhPrivateKeyToBase64(BigInt privateKey) {
    return base64Encode(_bigIntToBytes(privateKey));
  }

  /// Import DH private key from base64
  static BigInt dhPrivateKeyFromBase64(String base64Key) {
    return _bytesToBigInt(base64Decode(base64Key));
  }

  /// Compute shared secret using DH
  static Uint8List computeSharedSecret(BigInt privateKey, BigInt otherPublicKey) {
    // s = (y_other ^ x_self) mod p
    final sharedSecret = otherPublicKey.modPow(privateKey, _dhP);
    
    // Derive 256-bit key from shared secret using SHA-256
    final secretBytes = _bigIntToBytes(sharedSecret);
    final hash = crypto.sha256.convert(secretBytes);
    return Uint8List.fromList(hash.bytes);
  }

  // ==================== AES-GCM ENCRYPTION ====================

  /// Encrypt message with AES-GCM
  static EncryptedData encryptAESGCM(String plaintext, Uint8List key) {
    final iv = encrypt.IV.fromSecureRandom(12); // 96-bit nonce for GCM
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    
    // The encrypt library appends the 16-byte auth tag to the ciphertext
    // We need to separate them for proper storage/transmission
    final fullBytes = encrypted.bytes;
    final ciphertextBytes = fullBytes.sublist(0, fullBytes.length - 16);
    final authTagBytes = fullBytes.sublist(fullBytes.length - 16);
    
    return EncryptedData(
      ciphertext: base64Encode(ciphertextBytes),
      nonce: iv.base64,
      authTag: base64Encode(authTagBytes),
    );
  }

  /// Decrypt message with AES-GCM
  static String decryptAESGCM(EncryptedData data, Uint8List key) {
    final iv = encrypt.IV.fromBase64(data.nonce);
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm));
    
    // Reconstruct the combined ciphertext + authTag that the library expects
    final ciphertextBytes = base64Decode(data.ciphertext);
    final authTagBytes = base64Decode(data.authTag);
    final combined = Uint8List.fromList([...ciphertextBytes, ...authTagBytes]);
    
    return encrypter.decrypt(encrypt.Encrypted(combined), iv: iv);
  }

  // ==================== RSA SIGNING ====================

  /// Sign data with RSA private key
  static String sign(String data, RSAPrivateKey privateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    
    final signature = signer.generateSignature(Uint8List.fromList(utf8.encode(data)));
    return base64Encode(signature.bytes);
  }

  /// Verify signature with RSA public key
  static bool verify(String data, String signatureBase64, RSAPublicKey publicKey) {
    try {
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      
      final signature = RSASignature(base64Decode(signatureBase64));
      return signer.verifySignature(Uint8List.fromList(utf8.encode(data)), signature);
    } catch (e) {
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  static String _chunked(String str, int chunkSize) {
    final chunks = <String>[];
    for (var i = 0; i < str.length; i += chunkSize) {
      chunks.add(str.substring(i, i + chunkSize > str.length ? str.length : i + chunkSize));
    }
    return chunks.join('\n');
  }

  static Uint8List _bigIntToBytes(BigInt number) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  // ASN.1 encoding/decoding for RSA keys (simplified)
  static Uint8List _encodeRSAPublicKey(RSAPublicKey key) {
    final modulus = _bigIntToBytes(key.modulus!);
    final exponent = _bigIntToBytes(key.exponent!);
    
    // Simple encoding: length-prefixed concatenation
    final buffer = BytesBuilder();
    buffer.addByte(modulus.length >> 8);
    buffer.addByte(modulus.length & 0xFF);
    buffer.add(modulus);
    buffer.addByte(exponent.length >> 8);
    buffer.addByte(exponent.length & 0xFF);
    buffer.add(exponent);
    
    return buffer.toBytes();
  }

  static RSAPublicKey _decodeRSAPublicKey(Uint8List bytes) {
    var offset = 0;
    
    final modulusLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final modulusBytes = bytes.sublist(offset, offset + modulusLen);
    offset += modulusLen;
    
    final exponentLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final exponentBytes = bytes.sublist(offset, offset + exponentLen);
    
    final modulus = _bytesToBigInt(modulusBytes);
    final exponent = _bytesToBigInt(exponentBytes);
    
    return RSAPublicKey(modulus, exponent);
  }

  static Uint8List _encodeRSAPrivateKey(RSAPrivateKey key) {
    final modulus = _bigIntToBytes(key.modulus!);
    final exponent = _bigIntToBytes(key.exponent!);
    final p = _bigIntToBytes(key.p!);
    final q = _bigIntToBytes(key.q!);
    
    final buffer = BytesBuilder();
    buffer.addByte(modulus.length >> 8);
    buffer.addByte(modulus.length & 0xFF);
    buffer.add(modulus);
    buffer.addByte(exponent.length >> 8);
    buffer.addByte(exponent.length & 0xFF);
    buffer.add(exponent);
    buffer.addByte(p.length >> 8);
    buffer.addByte(p.length & 0xFF);
    buffer.add(p);
    buffer.addByte(q.length >> 8);
    buffer.addByte(q.length & 0xFF);
    buffer.add(q);
    
    return buffer.toBytes();
  }

  static RSAPrivateKey _decodeRSAPrivateKey(Uint8List bytes) {
    var offset = 0;
    
    final modulusLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final modulusBytes = bytes.sublist(offset, offset + modulusLen);
    offset += modulusLen;
    
    final exponentLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final exponentBytes = bytes.sublist(offset, offset + exponentLen);
    offset += exponentLen;
    
    final pLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final pBytes = bytes.sublist(offset, offset + pLen);
    offset += pLen;
    
    final qLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    final qBytes = bytes.sublist(offset, offset + qLen);
    
    final modulus = _bytesToBigInt(modulusBytes);
    final exponent = _bytesToBigInt(exponentBytes);
    final p = _bytesToBigInt(pBytes);
    final q = _bytesToBigInt(qBytes);
    
    return RSAPrivateKey(modulus, exponent, p, q);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }
}

/// Container for encrypted data
class EncryptedData {
  final String ciphertext;
  final String nonce;
  final String authTag;

  EncryptedData({
    required this.ciphertext,
    required this.nonce,
    required this.authTag,
  });
}

/// Container for DH key pair
class DHKeyPair {
  final BigInt privateKey;
  final BigInt publicKey;

  DHKeyPair({required this.privateKey, required this.publicKey});
}
