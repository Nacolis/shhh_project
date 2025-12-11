import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

// Génération des clés RSA
AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> genRsaKeypair(int bits) {
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
      SecureRandom('Fortuna')
        ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => 0))))
    ));
  final pair = keyGen.generateKeyPair();
  final pub = pair.publicKey as RSAPublicKey;
  final priv = pair.privateKey as RSAPrivateKey;
  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(pub, priv);
}

// Chiffrement/déchiffrement RSA
BigInt rsa(BigInt m, RSAPublicKey k) {
  return m.modPow(k.exponent!, k.modulus!);
}
BigInt rsaDecrypt(BigInt c, RSAPrivateKey k) {
  return c.modPow(k.exponent!, k.modulus!);
}

// Fonction de hachage SHA-256
BigInt h(BigInt n) {
  final bytes = n.toRadixString(16).padLeft((n.bitLength + 7) ~/ 8 * 2, '0');
  final hash = sha256.convert(hex.decode(bytes));
  return BigInt.parse(hash.toString(), radix: 16);
}

// Signature RSA
Map<String, dynamic> rsaSign(String m, RSAPrivateKey kPrivee) {
  final mInt = BigInt.parse(hex.encode(utf8.encode(m)), radix: 16);
  final hInt = h(mInt);
  final sign = hInt.modPow(kPrivee.exponent!, kPrivee.modulus!);
  return {'message': m, 'signature': sign};
}

// Vérification RSA
bool rsaVerify(String m, BigInt sign, RSAPublicKey kPublique) {
  final mInt = BigInt.parse(hex.encode(utf8.encode(m)), radix: 16);
  final hInt = h(mInt);
  final v = sign.modPow(kPublique.exponent!, kPublique.modulus!);
  return v == hInt;
}

// Test simple de la génération, signature et vérification RSA
void main() {
  final keyPair = genRsaKeypair(1024);
  final pub = keyPair.publicKey as RSAPublicKey;
  final priv = keyPair.privateKey as RSAPrivateKey;

  final message = "Hello RSA!";
  final signResult = rsaSign(message, priv);
  final signature = signResult['signature'] as BigInt;

  final isValid = rsaVerify(message, signature, pub);
  print("Signature valide ? $isValid"); // Doit afficher true

  final isValidFalse = rsaVerify("autre message", signature, pub);
  print("Signature valide sur autre message ? $isValidFalse"); // Doit afficher false
}


