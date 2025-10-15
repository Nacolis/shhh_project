# shhh Project - Groupe B

## Overview

Une application pour communiquer de manière anonyme et sécurisée. 

## Technologies Utilisées
- Backend : Python / Flask

- Frontend : Dart / Flutter

- Base de données : Mariadb

- Peut être conteneurisé avec Docker ???

## Protocoles et Algorithmes

| **Fonction / Objectif** | **Protocole ou Algorithme** | **Rôle dans le système** | **Commentaires / Implémentation** |
|---------------------------|------------------------------|----------------------------|----------------------------------|
| **Échange de clé** | **Diffie–Hellman (DH)** | Permet à deux utilisateurs d’établir une clé secrète commune sans jamais la transmettre. | Chaque client génère un secret (a, b), calcule `A = g^a mod p`, `B = g^b mod p`, et déduit la clé partagée `K = B^a mod p = A^b mod p`. |
| **Chiffrement symétrique** | **AES-256 (mode GCM ou CBC)** | Sert à chiffrer et déchiffrer les messages avec la clé partagée issue du DH. | Rapide et sûr. GCM ajoute une authentification (intégrité du message). Nécessite une clé de 256 bits et un IV/nonce. |
| **Signature / Authentification** | **RSA (ou ECDSA)** | Permet de signer un message ou un hash pour prouver l’identité de l’expéditeur. | Chaque utilisateur a une paire (clé privée / publique). La clé publique est publiée sur le serveur. |
| **Hachage / Dérivation de clé** | **SHA-256** | Sert à dériver la clé AES à partir du secret Diffie–Hellman ou à vérifier l’intégrité des données. ||
| **Transport sécurisé** | **HTTPS (TLS)** | Chiffre la communication entre client et serveur. | Utiliser un certificat (auto-signé en dev, Let's Encrypt en prod). |
| **Stockage des clés publiques** | **Serveur Flask (API REST)** | Permet de récupérer les clés publiques RSA et DH des utilisateurs. | Le serveur ne stocke **jamais les clés privées**. |
| **Chiffrement de groupe (optionnel)** | **Clé symétrique partagée** | Une clé AES unique est distribuée à tous les membres du groupe via leurs clés RSA. | Permet à tous les membres de chiffrer/déchiffrer avec la même clé. |




