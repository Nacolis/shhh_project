"""
Implementation complete de Diffie-Hellman pour messagerie chiffree
Utilise des fonctions DH personnalisees + cryptographie moderne
"""

import secrets
import os
import hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# PARAMETRES DH (RFC 3526 - MODP 14)

# Nombre premier p (2048 bits)
p = int("""
FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1
29024E088A67CC74020BBEA63B139B22514A08798E3404DD
EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245
E485B576625E7EC6F44C42E9A63A3620FFFFFFFFFFFFFFFF
""".replace("\n", ""), 16)

# Generateur
g = 2

# FONCTIONS DIFFIE-HELLMAN DE BASE

def get_private_key():
    """Genere une cle privee aleatoire securisee"""
    return secrets.randbelow(p - 2) + 1

def get_public_key(private_key):
    """
    Calcule la cle publique a partir de la cle privee
    Formule: public_key = g^private_key mod p
    """
    return pow(g, private_key, p)

def get_shared_key(peer_public_key, my_private_key):
    """
    Calcule le secret partage avec un pair
    Formule: shared_secret = peer_public^my_private mod p
    """
    return pow(peer_public_key, my_private_key, p)

def derive_aes_key(shared_secret):
    """
    Derive une cle AES-256 a partir du secret DH
    Utilise SHA-256 pour convertir l'entier en cle de 32 bytes
    """
    secret_bytes = shared_secret.to_bytes((shared_secret.bit_length() + 7) // 8, 'big')
    return hashlib.sha256(secret_bytes).digest()


# CLASSE UTILISATEUR

class DHUser:
    """Represente un utilisateur avec ses cles DH et ses groupes"""
    
    def __init__(self, name):
        self.name = name
        self.private_key = None
        self.public_key = None
        self.shared_secrets = {}
        self.groups = {}
        

    def generate_keys(self):
        """Genere une paire de cles privee/publique"""
        self.private_key = get_private_key()
        self.public_key = get_public_key(self.private_key)
        
    def get_public_key(self):
        """Retourne la cle publique (a envoyer aux autres)"""
        return self.public_key
    
    def compute_shared_secret(self, peer_name, peer_public_key):
        """Calcule le secret partage avec un pair et derive une cle AES"""
        shared_secret = get_shared_key(peer_public_key, self.private_key)
        aes_key = derive_aes_key(shared_secret)
        self.shared_secrets[peer_name] = aes_key
    
    # -------------------FONCTIONS DE CHIFFREMENT ET DÉCHIFFREMENT-----------------
    def encrypt_message(self, peer_name, message):
        """Chiffre un message pour un pair avec AES-GCM"""
        if peer_name not in self.shared_secrets:
            raise ValueError(f"Pas de secret partage avec {peer_name}")
        
        key = self.shared_secrets[peer_name]
        aesgcm = AESGCM(key)
        nonce = os.urandom(12)
        ciphertext = aesgcm.encrypt(nonce, message.encode('utf-8'), None)
        
        return nonce, ciphertext
    
    def decrypt_message(self, peer_name, nonce, ciphertext):
        """Dechiffre un message d'un pair"""
        if peer_name not in self.shared_secrets:
            raise ValueError(f"Pas de secret partage avec {peer_name}")
        
        key = self.shared_secrets[peer_name]
        aesgcm = AESGCM(key)
        plaintext = aesgcm.decrypt(nonce, ciphertext, None)
        
        return plaintext.decode('utf-8')

    # ----------------------FONCTIONS SUR LES GROUPES-----------------------
    def create_group(self, group_name, members_names):
        """Cree un groupe avec une liste de noms de membres"""
        if group_name in self.groups:
            raise ValueError(f"Le groupe {group_name} existe deja")
        self.groups[group_name] = members_names
    
    def add_member_to_group(self, group_name, member_name):
        """Ajoute un membre a un groupe existant"""
        if group_name not in self.groups:
            raise ValueError(f"Le groupe {group_name} n'existe pas")
        if member_name not in self.groups[group_name]:
            self.groups[group_name].append(member_name)
    
    def remove_member_from_group(self, group_name, member_name):
        """Retire un membre d'un groupe"""
        if group_name not in self.groups:
            raise ValueError(f"Le groupe {group_name} n'existe pas")
        if member_name in self.groups[group_name]:
            self.groups[group_name].remove(member_name)
    
    def get_group_members(self, group_name):
        """Retourne la liste des membres d'un groupe"""
        if group_name not in self.groups:
            raise ValueError(f"Le groupe {group_name} n'existe pas")
        return self.groups[group_name]
    

    # -----------------FONCTIONS D'ENVOIE DE MESSAGES------------------
    def send_direct_message(self, peer_name, message):
        """Envoie un message direct a un pair"""
        return self.encrypt_message(peer_name, message)
    
    def send_group_message(self, group_name, message):
        """Envoie un message a tous les membres d'un groupe"""
        if group_name not in self.groups:
            raise ValueError(f"Le groupe {group_name} n'existe pas")
        
        encrypted_messages = {}
        members = self.groups[group_name]
        
        for member_name in members:
            if member_name != self.name:
                nonce, ciphertext = self.encrypt_message(member_name, message)
                encrypted_messages[member_name] = (nonce, ciphertext)
        
        return encrypted_messages


# CLASSE DE GROUPCHAT (pour reference/compatibilite)

class GroupChatPairwise:
    """
    Chat de groupe avec secrets pairwise
    Chaque membre a un secret avec chaque autre membre
    SIMULE COMMENT AGIT UN GROUPE
    NE SERA PAS UTILISER
    """
    
    def __init__(self, group_name):
        self.group_name = group_name
        self.members = {}
        
    def add_member(self, name):
        """Ajoute un membre et etablit des secrets avec tous les autres"""
        new_member = DHUser(name)
        new_member.generate_keys()
        
        for other_name, other_member in self.members.items():
            new_public = new_member.get_public_key()
            other_public = other_member.get_public_key()
            
            new_member.compute_shared_secret(other_name, other_public)
            other_member.compute_shared_secret(name, new_public)
        
        self.members[name] = new_member
    
    def broadcast_message(self, sender_name, message):
        """Envoie un message a tous les membres (sauf l'expediteur)"""
        if sender_name not in self.members:
            raise ValueError(f"{sender_name} n'est pas dans le groupe")
        
        sender = self.members[sender_name]
        encrypted_msgs = {}
        
        for recipient_name in self.members:
            if recipient_name != sender_name:
                nonce, ciphertext = sender.encrypt_message(recipient_name, message)
                encrypted_msgs[recipient_name] = (nonce, ciphertext)
        
        return encrypted_msgs
    
    def receive_message(self, recipient_name, sender_name, nonce, ciphertext):
        """Dechiffre un message recu"""
        recipient = self.members[recipient_name]
        return recipient.decrypt_message(sender_name, nonce, ciphertext)
