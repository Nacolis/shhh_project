"""
Test de chat direct entre Alice et Bob
"""

from dh_python_implementation import DHUser

def test_direct_chat():
    print("\n" + "="*70)
    print("TEST : CHAT DIRECT ALICE <-> BOB")
    print("="*70 + "\n")
    
    # Etape 1: Creation des utilisateurs
    print("Etape 1: Creation des utilisateurs")
    print("-"*70)
    alice = DHUser("Alice")
    bob = DHUser("Bob")
    
    alice.generate_keys()
    bob.generate_keys()
    
    print(f"Alice - Cle privee: {alice.private_key}")
    print(f"Alice - Cle publique: {alice.public_key}\n")
    print(f"Bob - Cle privee: {bob.private_key}")
    print(f"Bob - Cle publique: {bob.public_key}\n")
    
    # Etape 2: Echange des cles publiques
    print("Etape 2: Echange des cles publiques")
    print("-"*70)
    alice_public = alice.get_public_key()
    bob_public = bob.get_public_key()
    
    print(f"Alice envoie sa cle publique a Bob: {alice_public}")
    print(f"Bob envoie sa cle publique a Alice: {bob_public}\n")
    
    # Etape 3: Calcul des secrets partages
    print("Etape 3: Calcul des secrets partages")
    print("-"*70)
    alice.compute_shared_secret("Bob", bob_public)
    bob.compute_shared_secret("Alice", alice_public)
    
    print("Alice a calcule le secret partage avec Bob")
    print("Bob a calcule le secret partage avec Alice\n")
    
    # Verification que les secrets sont identiques
    alice_secret = alice.shared_secrets["Bob"]
    bob_secret = bob.shared_secrets["Alice"]
    
    if alice_secret == bob_secret:
        print("Verification: Les secrets partages sont IDENTIQUES")
        print(f"Secret (hex): {alice_secret.hex()[:32]}...\n")
    else:
        print("ERREUR: Les secrets ne correspondent pas!\n")
    
    # Etape 4: Alice envoie un message a Bob
    print("Etape 4: Messagerie chiffree")
    print("-"*70)
    
    message1 = "Salut Bob! Comment vas-tu?"
    print(f"Alice envoie: '{message1}'")
    
    nonce1, ciphertext1 = alice.send_direct_message("Bob", message1)
    print(f"Nonce: {nonce1.hex()}")
    print(f"Message chiffre: {ciphertext1.hex()}\n")
    
    decrypted1 = bob.decrypt_message("Alice", nonce1, ciphertext1)
    print(f"Bob recoit et dechiffre: '{decrypted1}'\n")
    
    # Etape 5: Bob repond a Alice
    message2 = "Tres bien merci Alice! Et toi?"
    print(f"Bob repond: '{message2}'")
    
    nonce2, ciphertext2 = bob.send_direct_message("Alice", message2)
    print(f"Nonce: {nonce2.hex()}")
    print(f"Message chiffre: {ciphertext2.hex()}\n")
    
    decrypted2 = alice.decrypt_message("Bob", nonce2, ciphertext2)
    print(f"Alice recoit et dechiffre: '{decrypted2}'\n")
    
    # Etape 6: Conversation complete
    print("Etape 5: Suite de la conversation")
    print("-"*70)
    
    conversation = [
        ("Alice", "Bob", "On se voit ce soir?"),
        ("Bob", "Alice", "Oui, a quelle heure?"),
        ("Alice", "Bob", "20h au restaurant habituel?"),
        ("Bob", "Alice", "Parfait! A ce soir!"),
    ]
    
    for sender_name, receiver_name, msg in conversation:
        if sender_name == "Alice":
            sender = alice
            receiver = bob
        else:
            sender = bob
            receiver = alice
        
        print(f"{sender_name} -> {receiver_name}: '{msg}'")
        nonce, ciphertext = sender.send_direct_message(receiver_name, msg)
        decrypted = receiver.decrypt_message(sender_name, nonce, ciphertext)
        print(f"  Recu et dechiffre: '{decrypted}'\n")

if __name__ == "__main__":
    test_direct_chat()
