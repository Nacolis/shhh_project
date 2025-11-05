## source: https://ssojet.com/encryption-decryption/aes-256-in-python/

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from os import urandom
import base64

def encrypt_data(key: bytes, plaintext: str) -> str:
    # Generate a random initialization vector
    iv = urandom(16)
    
    # Create a Cipher object
    cipher = Cipher(algorithms.AES(key), modes.CFB(iv), backend=default_backend())
    encryptor = cipher.encryptor()
    
    # Encrypt the plaintext
    ciphertext = encryptor.update(plaintext.encode()) + encryptor.finalize()
    
    # Return the IV and ciphertext as a base64 encoded string
    return base64.b64encode(iv + ciphertext).decode('utf-8')
# Example usage
key = urandom(32)  # Generate a random 256-bit key
plaintext = "Hello, World!"
encrypted_data = encrypt_data(key, plaintext)
print("Encrypted:", encrypted_data)


def decrypt_data(key: bytes, encrypted_data: str) -> str:
    # Decode the base64 encoded data
    encrypted_data_bytes = base64.b64decode(encrypted_data)
    
    # Extract the IV and ciphertext
    iv = encrypted_data_bytes[:16]
    ciphertext = encrypted_data_bytes[16:]
    
    # Create a Cipher object
    cipher = Cipher(algorithms.AES(key), modes.CFB(iv), backend=default_backend())
    decryptor = cipher.decryptor()
    
    # Decrypt the ciphertext
    decrypted_data = decryptor.update(ciphertext) + decryptor.finalize()
    
    return decrypted_data.decode('utf-8')
# Example usage
decrypted_data = decrypt_data(key, encrypted_data)
print("Decrypted:", decrypted_data)