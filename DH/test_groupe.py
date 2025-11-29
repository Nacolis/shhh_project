"""
Test de chat de groupe avec Alice, Bob et Mohamed
Gestion cote client (chaque utilisateur gere ses propres groupes)
"""

from dh_python_implementation import DHUser

def test_group_chat():
    print("\n" + "="*70)
    print("TEST : CHAT DE GROUPE ALICE - BOB - MOHAMED")
    print("="*70 + "\n")
    
    # Etape 1: Creation des utilisateurs
    print("Etape 1: Creation des utilisateurs")
    print("-"*70)
    alice = DHUser("Alice")
    bob = DHUser("Bob")
    mohamed = DHUser("Mohamed")
    
    alice.generate_keys()
    bob.generate_keys()
    mohamed.generate_keys()
    
    print(f"Alice - Cle publique: {alice.public_key}")
    print(f"Bob - Cle publique: {bob.public_key}")
    print(f"Mohamed - Cle publique: {mohamed.public_key}\n")
    
    # Etape 2: Etablissement des secrets pairwise
    print("Etape 2: Etablissement des secrets entre tous les membres")
    print("-"*70)
    
    # Alice <-> Bob
    alice.compute_shared_secret("Bob", bob.get_public_key())
    bob.compute_shared_secret("Alice", alice.get_public_key())
    print("Secret etabli entre Alice et Bob")
    
    # Alice <-> Mohamed
    alice.compute_shared_secret("Mohamed", mohamed.get_public_key())
    mohamed.compute_shared_secret("Alice", alice.get_public_key())
    print("Secret etabli entre Alice et Mohamed")
    
    # Bob <-> Mohamed
    bob.compute_shared_secret("Mohamed", mohamed.get_public_key())
    mohamed.compute_shared_secret("Bob", bob.get_public_key())
    print("Secret etabli entre Bob et Mohamed\n")
    
    # Etape 3: Creation des groupes cote client
    print("Etape 3: Creation du groupe 'Projet Python'")
    print("-"*70)
    
    # Chaque utilisateur cree le groupe localement avec la meme liste
    group_name = "Projet Python"
    members = ["Alice", "Bob", "Mohamed"]
    
    alice.create_group(group_name, ["Bob", "Mohamed"])
    bob.create_group(group_name, ["Alice", "Mohamed"])
    mohamed.create_group(group_name, ["Alice", "Bob"])
    
    print(f"Groupe '{group_name}' cree par tous les membres")
    print(f"Membres d'Alice: {alice.get_group_members(group_name)}")
    print(f"Membres de Bob: {bob.get_group_members(group_name)}")
    print(f"Membres de Mohamed: {mohamed.get_group_members(group_name)}\n")
    
    # Etape 4: Alice envoie un message au groupe
    print("Etape 4: Alice envoie un message au groupe")
    print("-"*70)
    
    message1 = "Bonjour a tous! Reunion demain a 10h."
    print(f"Alice diffuse: '{message1}'\n")
    
    encrypted_msgs = alice.send_group_message(group_name, message1)
    print(f"Messages chiffres crees: {len(encrypted_msgs)}\n")
    
    # Bob recoit et dechiffre
    nonce_bob, cipher_bob = encrypted_msgs["Bob"]
    decrypted_bob = bob.decrypt_message("Alice", nonce_bob, cipher_bob)
    print(f"Bob recoit: '{decrypted_bob}'")
    
    # Mohamed recoit et dechiffre
    nonce_mohamed, cipher_mohamed = encrypted_msgs["Mohamed"]
    decrypted_mohamed = mohamed.decrypt_message("Alice", nonce_mohamed, cipher_mohamed)
    print(f"Mohamed recoit: '{decrypted_mohamed}'\n")
    
    # Etape 5: Bob repond au groupe
    print("Etape 5: Bob repond au groupe")
    print("-"*70)
    
    message2 = "OK pour moi! Merci Alice."
    print(f"Bob diffuse: '{message2}'\n")
    
    encrypted_msgs2 = bob.send_group_message(group_name, message2)
    
    # Alice recoit
    nonce_alice, cipher_alice = encrypted_msgs2["Alice"]
    decrypted_alice = alice.decrypt_message("Bob", nonce_alice, cipher_alice)
    print(f"Alice recoit: '{decrypted_alice}'")
    
    # Mohamed recoit
    nonce_mohamed2, cipher_mohamed2 = encrypted_msgs2["Mohamed"]
    decrypted_mohamed2 = mohamed.decrypt_message("Bob", nonce_mohamed2, cipher_mohamed2)
    print(f"Mohamed recoit: '{decrypted_mohamed2}'\n")
    
    # Etape 6: Mohamed repond au groupe
    print("Etape 6: Mohamed repond au groupe")
    print("-"*70)
    
    message3 = "Parfait! Je serai la."
    print(f"Mohamed diffuse: '{message3}'\n")
    
    encrypted_msgs3 = mohamed.send_group_message(group_name, message3)
    
    # Alice recoit
    nonce_alice2, cipher_alice2 = encrypted_msgs3["Alice"]
    decrypted_alice2 = alice.decrypt_message("Mohamed", nonce_alice2, cipher_alice2)
    print(f"Alice recoit: '{decrypted_alice2}'")
    
    # Bob recoit
    nonce_bob2, cipher_bob2 = encrypted_msgs3["Bob"]
    decrypted_bob2 = bob.decrypt_message("Mohamed", nonce_bob2, cipher_bob2)
    print(f"Bob recoit: '{decrypted_bob2}'\n")
    
    # Etape 7: Conversation complete dans le groupe
    print("Etape 7: Suite de la conversation de groupe")
    print("-"*70)
    
    group_conversation = [
        (alice, "Quelqu'un a des questions?"),
        (bob, "Oui, quelle salle?"),
        (alice, "Salle de conference A"),
        (mohamed, "Merci! A demain alors!"),
        (bob, "A demain!"),
    ]
    
    users_dict = {"Alice": alice, "Bob": bob, "Mohamed": mohamed}
    
    for sender, msg in group_conversation:
        print(f"\n{sender.name} diffuse: '{msg}'")
        encrypted = sender.send_group_message(group_name, msg)
        
        # Tous les autres membres recoivent
        for recipient_name, (nonce, cipher) in encrypted.items():
            recipient = users_dict[recipient_name]
            decrypted = recipient.decrypt_message(sender.name, nonce, cipher)
            print(f"  {recipient_name} recoit: '{decrypted}'")
    
    
    # Etape 8: Test d'ajout d'un membre
    print("Etape 8: Test d'ajout d'un nouveau membre")
    print("-"*70)
    
    # Alice ajoute un nouveau membre localement
    alice.add_member_to_group(group_name, "Sophie")
    print("Alice ajoute Sophie au groupe")
    print(f"Nouveaux membres pour Alice: {alice.get_group_members(group_name)}\n")
    
    # CHOSES A RAJOUTER:
    # - Une invitations synchroniseras le dictionnaire de contacts du receveur
    #   avec celui de l'envoyeur en rajoutant respectivement par la suite
    #   L'envoyeur chez le receveur et le receveur à l'envoyeur de l'invitation.


if __name__ == "__main__":
    test_group_chat()
