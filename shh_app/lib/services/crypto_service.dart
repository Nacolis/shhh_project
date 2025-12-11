import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart' as crypto;
import '../core/secure/rsa.dart' as custom_rsa;

/// Service de cryptographie pour le chiffrement de bout en bout, la gestion des clés, et les signatures numériques.
class CryptoService {
  static final _random = Random.secure();

  /// Génère une paire de clés RSA pour la signature et le chiffrement
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair() {
    // Utilise l'implémentation RSA personnalisée depuis rsa.dart
    return custom_rsa.genRsaKeypair(2048);
  }

  /// Convertit une clé publique RSA au format PEM
  static String rsaPublicKeyToPem(RSAPublicKey publicKey) {
    final bytes = _encodeRSAPublicKey(publicKey);
    final base64 = base64Encode(bytes);
    return '-----BEGIN PUBLIC KEY-----\n${_chunked(base64, 64)}\n-----END PUBLIC KEY-----';
  }

  /// Convertit une clé privée RSA au format PEM
  static String rsaPrivateKeyToPem(RSAPrivateKey privateKey) {
    final bytes = _encodeRSAPrivateKey(privateKey);
    final base64 = base64Encode(bytes);
    return '-----BEGIN RSA PRIVATE KEY-----\n${_chunked(base64, 64)}\n-----END RSA PRIVATE KEY-----';
  }

  /// Analyse une clé publique RSA à partir du format PEM
  static RSAPublicKey rsaPublicKeyFromPem(String pem) {
    final lines = pem.split('\n')
      .where((line) => !line.startsWith('-----'))
      .join('');
    final bytes = base64Decode(lines);
    return _decodeRSAPublicKey(bytes);
  }

  /// Analyse une clé privée RSA à partir du format PEM
  static RSAPrivateKey rsaPrivateKeyFromPem(String pem) {
    final lines = pem.split('\n')
      .where((line) => !line.startsWith('-----'))
      .join('');
    final bytes = base64Decode(lines);
    return _decodeRSAPrivateKey(bytes);
  }

//Diffie Hellman (Échange de clés Diffie-Hellman)
  
  // RFC 3526 Groupe 14 (MODP 2048-bit)
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

  /// Génère une paire de clés DH (retourne les clés privée et publique en tant que BigInt)
  static DHKeyPair generateDHKeyPair() {
    // Génère une clé privée aléatoire (x) entre 2 et p-2
    final privateKey = _generateRandomBigInt(_dhP - BigInt.two);
    // Calcule la clé publique: y = g^x mod p
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

  /// Exporte la clé publique DH en base64
  static String dhPublicKeyToBase64(BigInt publicKey) {
    return base64Encode(_bigIntToBytes(publicKey));
  }

  /// Importe la clé publique DH à partir de base64
  static BigInt dhPublicKeyFromBase64(String base64Key) {
    return _bytesToBigInt(base64Decode(base64Key));
  }

  /// Exporte la clé privée DH en base64
  static String dhPrivateKeyToBase64(BigInt privateKey) {
    return base64Encode(_bigIntToBytes(privateKey));
  }

  /// Importe la clé privée DH à partir de base64
  static BigInt dhPrivateKeyFromBase64(String base64Key) {
    return _bytesToBigInt(base64Decode(base64Key));
  }

  /// Calcule le secret partagé en utilisant DH
  static Uint8List computeSharedSecret(BigInt privateKey, BigInt otherPublicKey) {
    // s = (y_other ^ x_self) mod p
    final sharedSecret = otherPublicKey.modPow(privateKey, _dhP);
    
    // Dérive une clé 256-bit du secret partagé en utilisant SHA-256
    final secretBytes = _bigIntToBytes(sharedSecret);
    final hash = crypto.sha256.convert(secretBytes);
    return Uint8List.fromList(hash.bytes);
  }

  //AES

  /// Encrypte un message avec AES-GCM
  static EncryptedData encryptAESGCM(String plaintext, Uint8List key) {
    final iv = encrypt.IV.fromSecureRandom(12); // 96-bit nonce for GCM
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    
    // La bibliothèque encrypt ajoute la balise d'authentification 16-byte au texte chiffré
    // Nous devons les séparer pour un stockage/transmission approprié
    final fullBytes = encrypted.bytes;
    final ciphertextBytes = fullBytes.sublist(0, fullBytes.length - 16);
    final authTagBytes = fullBytes.sublist(fullBytes.length - 16);
    
    return EncryptedData(
      ciphertext: base64Encode(ciphertextBytes),
      nonce: iv.base64,
      authTag: base64Encode(authTagBytes),
    );
  }

  /// Déchiffre un message avec AES-GCM
  static String decryptAESGCM(EncryptedData data, Uint8List key) {
    final iv = encrypt.IV.fromBase64(data.nonce);
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm));
    
    // Reconstruit le texte chiffré combiné + balise d'authentification attendu par la bibliothèque
    final ciphertextBytes = base64Decode(data.ciphertext);
    final authTagBytes = base64Decode(data.authTag);
    final combined = Uint8List.fromList([...ciphertextBytes, ...authTagBytes]);
    
    return encrypter.decrypt(encrypt.Encrypted(combined), iv: iv);
  }

  //RSA - Signature numérique

  /// Signe des données avec la clé privée RSA (implémentation personnalisée)
  static String sign(String data, RSAPrivateKey privateKey) {
    final result = custom_rsa.rsaSign(data, privateKey);
    final BigInt sig = result['signature'] as BigInt;
    // Conversion BigInt -> bytes -> base64
    final sigBytes = _bigIntToBytes(sig);
    return base64Encode(sigBytes);
  }

  /// Vérifie la signature avec la clé publique RSA (implémentation personnalisée)
  static bool verify(String data, String signatureBase64, RSAPublicKey publicKey) {
    try {
      final sigBytes = base64Decode(signatureBase64);
      final sigBigInt = _bytesToBigInt(Uint8List.fromList(sigBytes));
      return custom_rsa.rsaVerify(data, sigBigInt, publicKey);
    } catch (_) {
      return false;
    }
  }

  // méthodes d'assistance

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

  // Codage/décodage ASN.1 pour les clés RSA (simplifié)
  static Uint8List _encodeRSAPublicKey(RSAPublicKey key) {
    final modulus = _bigIntToBytes(key.modulus!);
    final exponent = _bigIntToBytes(key.exponent!);
    
    // Codage simple : concaténation préfixée par la longueur
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

/// Conteneur pour les données chiffrées
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

/// Conteneur pour la paire de clés DH
class DHKeyPair {
  final BigInt privateKey;
  final BigInt publicKey;

  DHKeyPair({required this.privateKey, required this.publicKey});
}
