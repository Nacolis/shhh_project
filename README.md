# shhh Project - Groupe B

Coquard-Morel Lou-Ann
Hamri Mathis
Massenya Theo
Houngbedji Dylan-Thomas
Roy Nicolas

## Overview

Une application pour communiquer de manière anonyme et sécurisée. 

## Technologies Utilisées
- Backend : Python / Flask

- Frontend : Dart / Flutter

- Base de données : Mariadb

- Peut être conteneurisé avec Docker ???

## Algorithmes

| **Fonction / Objectif** | **Protocole ou Algorithme** | **Rôle dans le système** | **Commentaires / Implémentation** |
|---------------------------|------------------------------|----------------------------|----------------------------------|
| **Échange de clé** | **Diffie–Hellman (DH)** | Permet à deux utilisateurs d’établir une clé secrète commune sans jamais la transmettre. | Chaque client génère un secret (a, b), calcule `A = g^a mod p`, `B = g^b mod p`, et déduit la clé partagée `K = B^a mod p = A^b mod p`. |
| **Chiffrement symétrique** | **AES-256 (mode GCM ou CBC)** | Sert à chiffrer et déchiffrer les messages avec la clé partagée issue du DH. | Rapide et sûr. GCM ajoute une authentification (intégrité du message). Nécessite une clé de 256 bits et un IV/nonce. |
| **Signature / Authentification** | **RSA (ou ECDSA)** | Permet de signer un message ou un hash pour prouver l’identité de l’expéditeur. | Chaque utilisateur a une paire (clé privée / publique). La clé publique est publiée sur le serveur. |
| **Hachage / Dérivation de clé** | **SHA-256** | Sert à dériver la clé AES à partir du secret Diffie–Hellman ou à vérifier l’intégrité des données. ||
| **Transport sécurisé** | **HTTPS (TLS)** | Chiffre la communication entre client et serveur. | Utiliser un certificat (auto-signé en dev, Let's Encrypt en prod). |
| **Stockage des clés publiques** | **Serveur Flask (API REST)** | Permet de récupérer les clés publiques RSA et DH des utilisateurs. | Le serveur ne stocke **jamais les clés privées**. |
| **Chiffrement de groupe (optionnel)** | **Clé symétrique partagée** | Une clé AES unique est distribuée à tous les membres du groupe via leurs clés RSA. | Permet à tous les membres de chiffrer/déchiffrer avec la même clé. |



# Protocole

## Étape 1 — Inscription et génération des clés

À l'installation ou à la première connexion, chaque client effectue :
1. Génération d'une paire RSA :
   - `RSA_priv` : clé privée (stockée localement, jamais envoyée)
   - `RSA_pub` : clé publique (envoyée au serveur)
2. Génération d'une clé Diffie–Hellman locale (secret aléatoire `a`) et calcul de la clé publique DH : `A = g^a mod p`.

---

## Étape 1-2 — Paramètres publics

Le serveur publie les paramètres DH partagés par tous les utilisateurs :
- `p` : grand nombre premier
- `g` : générateur

---

## Étape 3 — Échange de clés Diffie–Hellman

Quand Alice veut démarrer une conversation avec Bob :
1. Alice récupère la clé DH publique de Bob depuis le serveur
2. Alice calcule la clé partagée locale : `K = B^a mod p`.
3. Bob calcule de son côté `K = A^b mod p`.
4. La clé K n'est jamais transmise. On en dérive la clé AES via SHA-256 :

---

## Étape 4 — Échange de messages chiffrés (AES-256-GCM)

Quand Alice envoie un message à Bob :
1. Chiffrement avec AES-256-GCM ou autre en utilisant `aes_key` dérivée.
2. Signature du ciphertext avec la clé privée RSA d'Alice.
3. Envoi au serveur d'un message

Remarques :
- Apparemment, il faudrait signer le haché du ciphertext||nonce||tag plutôt que le ciphertext seul.

---

## Étape 5 — Vérification et déchiffrement côté récepteur

Quand Bob reçoit un message :
1. Récupère la clé publique RSA d'Alice depuis le serveur.
2. Vérifie la signature RSA sur `ciphertext||nonce||tag`.
3. Si la signature est valide, utilise `aes_key` (dérivée de la session DH) pour déchiffrer le ciphertext.
4. Si la décryption et l'authentification GCM réussissent, afficher le texte clair.


---
### Comment utiliser git pour le projet

"git pull" pour être à jour sur les modifications du projet.
"git add --all" pour ajouter ses modifs.
"git commit -m "description du commit" "pour soumettre le projet modifié.
"git push" pour envoyer le projet après avoir add et commit (obligatoire).

## 
