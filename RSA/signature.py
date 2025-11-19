import Crypto.Util.number as crypto
import hashlib

def gen_rsa_keypair(bits):
    s = bits // 2
    p = crypto.getPrime(s)
    q = crypto.getPrime(s)
    n = p * q
    phi_n = (p - 1) * (q - 1)
    e = 65537 
    assert(phi_n % e != 0)
    d = crypto.inverse(e, phi_n)
    return (e, n), (d, n)


def rsa(m, k):
    return pow(m, k[0], k[1])

def h(n): 
    nbites = n.to_bytes((n.bit_length() + 7) // 8, 'big')
    n = hashlib.sha256(nbites).digest()
    return int.from_bytes(n, 'big')


def rsa_sign(m, k_privee):
    m_int = int.from_bytes(m.encode('utf-8'), 'big') 
    h_int = h(m_int) 
    sign = pow(h_int, k_privee[0], k_privee[1]) 
    
    return(m, sign)


def rsa_verify(m, sign, k_publique):
    m_int = int.from_bytes(m.encode('utf-8'), 'big')
    h_int = h(m_int)
    v = pow(sign, k_publique[0],k_publique[1])
    
    if v != h_int:
        return False
    else:
        return True





print("Test RSA - Génération des clés")

# 1. Génération des clés RSA
cle_publique, cle_privee = gen_rsa_keypair(512)
print(f"Clé publique (e, n): {cle_publique}")
print(f"Clé privée (d, n): {cle_privee}")
print()

print(" Test RSA - Chiffrement/Déchiffrement")

# 2. Test de la fonction rsa de base
m = 42
print(f"Test fonction rsa() avec m={m}")
chiffre = rsa(m, cle_publique)
dechiffre = rsa(chiffre, cle_privee)
print(f"m={m} -> chiffré={chiffre} -> déchiffré={dechiffre}")
print(f"Résultat correct: {m == dechiffre}")
print()

print(" Test fonction de hachage")

# 3. Test de la fonction de hachage
nombre = 123456789
hash_result = h(nombre)
print(f"h({nombre}) = {hash_result}")
print(f"Taille du hash: {hash_result.bit_length()} bits")
print()

print(" Test RSA - Signature/Vérification ")

# 4. Test de la signature et vérification
message_a_signer = "Document important"
print(f"Message à signer: '{message_a_signer}'")

# Signature
message_signe, signature = rsa_sign(message_a_signer, cle_privee)
print(f"Message signé: '{message_signe}'")
print(f"Signature: {signature}")

# Vérification avec le bon message
verification_ok = rsa_verify(message_a_signer, signature, cle_publique)
print(f"Vérification signature (message correct): {verification_ok}")

# Test avec un message modifié
message_modifie = "Document important modifié"
verification_fausse = rsa_verify(message_modifie, signature, cle_publique)
print(f"Vérification signature (message modifié): {verification_fausse}")
print()


