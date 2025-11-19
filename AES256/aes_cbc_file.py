import sys # pour gérer les arguments en ligne de commande
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad 
import base64 # encoder les données binaire en texte

# Fixed key and IV
FIXED_KEY = b'fixedkey1234567890123456'  # 256-bit key (32 bytes)
FIXED_IV = b'fixediv012345678'  # 128-bit IV (16 bytes)

def encrypt(plaintext):
    cipher = AES.new(FIXED_KEY, AES.MODE_CBC, FIXED_IV)
    ciphertext = cipher.encrypt(pad(plaintext, AES.block_size))
    return base64.b64encode(ciphertext)

def decrypt(ciphertext):
    ciphertext = base64.b64decode(ciphertext)
    cipher = AES.new(FIXED_KEY, AES.MODE_CBC, FIXED_IV)
    plaintext = unpad(cipher.decrypt(ciphertext), AES.block_size)
    return plaintext

def main():
    if len(sys.argv) < 4:
        print("Usage: python aes_cbc_file.py <encrypt|decrypt> <input_file> <output_file>")
        sys.exit(1)

    action = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    try:
        with open(input_file, 'rb') as f:
            data = f.read()
    except FileNotFoundError:
        print(f"File {input_file} not found.")
        sys.exit(1)

    if action == "encrypt":
        encrypted_data = encrypt(data)
        with open(output_file, 'wb') as f:
            f.write(encrypted_data)
        print(f"Encrypted data written to {output_file}")
    elif action == "decrypt":
        decrypted_data = decrypt(data)
        with open(output_file, 'wb') as f:
            f.write(decrypted_data)
        print(f"Decrypted data written to {output_file}")
    else:
        print("Invalid action. Use 'encrypt' or 'decrypt'.")
        sys.exit(1)

if __name__ == "__main__":
    main()
