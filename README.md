# 🔒 Shhh Project - End-to-End Encrypted Messaging

**Groupe B**: Coquard-Morel Lou-Ann, Hamri Mathis, Massenya Theo, Houngbedji Dylan-Thomas, Roy Nicolas

Une application pour communiquer de manière anonyme et sécurisée avec chiffrement de bout en bout.

## 🌐 Live Environments

- **Production**: https://shh.univ-edt.fr

## 💻 Technologies

### Backend
- **Framework**: Python 3.11 / Flask
- **Database**: MariaDB
- **WSGI Server**: Gunicorn
- **Web Server**: Nginx
- **SSL/TLS**: Let's Encrypt

### Frontend
- **Framework**: Dart / Flutter

### DevOps
- **CI/CD**: GitLab CI/CD
- **Deployment**: Automated (test) & Manual approval (production)
- **Monitoring**: Custom scripts

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

# Fonctionnalités:

## Groupe
- Minimum de 3 personnes pour créer un groupe.
- Minimum de 1 personne dans un groupe pour éviter sa suppression.
- Une personne rejoignant le groupe n'auras pas les messages antérieurs à son arrivée.
- pour l'instant pas de limite d'utilisateurs dans un groupe

## Contact/Amis
- Envoie de demande d'ami par le username de la personne.
- (Bonus) Génération de QR code pour ajouter un.e ami.e

## Identification
- Username (unique et modifiable) 
- mot de passe
- Identifiant (unique et non modifiable)

## Message
- Textuel 
- Image
- Audio (Bonus) 



# Déploiement sur VPS avec GitLab CI/CD
## 1. VPS Preparation
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker $USER
```

## 2. GitLab CI/CD Configuration
Variables stoquées dans **Settings > CI/CD > Variables**:
| Variable | Description | Example |
|----------|-------------|---------|
| `SSH_HOST` | Adresse ip du serveur | `159.65.124.188` |
| `SSH_USER` | SSH username | ...|
| `SSH_PRIVATE_KEY` | Clé privée SSH | ...|
| `ENV_FILE` | Content of the `.env` file |  |

```env
FLASK_ENV=production
SECRET_KEY=change-this-to-a-secure-random-string
JWT_SECRET_KEY=change-this-to-another-secure-random-string

MYSQL_ROOT_PASSWORD=secure_root_password
MYSQL_DATABASE=shhh_db
MYSQL_USER=shhh_user
MYSQL_PASSWORD=secure_db_password
```

## 3. Setup SSL 
1. Pousser le code sur la branche `main`. (pipeline CI/CD s'exécute, peut échouer au début vu que les certificats manquent)
2. SSH dans le VPS.
3. Lancer le script d'initialisation:
```bash
cd ~/shhh_project
chmod +x deployment/init-letsencrypt.sh
sudo ./deployment/init-letsencrypt.sh
```

## 4. Pour la db
Les tables se créent automatiquement au premier déploiement. Depuis les models SQLAlchemy.

## 5. Déploiement automatique
Une fois le setup une première fois, chaque push sur la branche `main` va:
- Construire les images Docker
- Pousser les images sur le VPS
- Redémarrer les conteneurs avec les nouvelles images

# Pour faire tourner en local (dev)

```bash
docker-compose -f docker-compose.dev.yml up --build
```


