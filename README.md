# CyberLab Setup

Dépôt de bootstrap portable pour préparer des VM Linux et Windows, quel que soit l'hébergeur ou l'hyperviseur (AWS, OVH, Hetzner, Proxmox, VMware, poste local, client...).

## Principe

- Un dépôt Git, une branche principale.
- Un point d'entrée par OS : `setup.sh` pour Linux et `setup.ps1` pour Windows.
- Un rôle explicite : `kali`, `debian`, `windows-server`, `windows-client`, `windows-ad`.
- Des scripts séparés et relançables autant que possible.
- Les scripts de migration/export restent distincts des scripts de préparation d'une VM neuve.

## Linux

```bash
git clone https://github.com/resistezauxhackeurs/cyberlab-setup
cd cyberlab-setup
sudo ./setup.sh kali
# ou : sudo ./setup.sh debian
```

Afficher l'aide :

```bash
./setup.sh --help
```

## Windows (PowerShell administrateur)

```powershell
git clone https://github.com/TON_ORGA/cyberlab-setup.git
cd cyberlab-setup
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1 windows-server
# ou : .\setup.ps1 windows-client
# ou : .\setup.ps1 windows-ad
```

`windows-ad` est volontairement un squelette : l'installation d'AD DS et la promotion en contrôleur de domaine nécessitent des paramètres propres au TP (nom de domaine, IP/DNS, mot de passe DSRM, etc.). Ne pas automatiser ces choix avec des valeurs par défaut.

## Migration d'une Kali existante

Le script `linux/kali/migration/kali-package-migrate.sh` exporte l'inventaire APT, pip et pipx dans une archive `kali-packages-*.tar.gz`, et sait la restaurer. L'archive de référence est versionnée dans ce dossier, donc disponible juste après un clone :

```bash
git clone https://github.com/resistezauxhackeurs/cyberlab-setup
cd cyberlab-setup
sudo linux/kali/migration/kali-package-migrate.sh restore \
  linux/kali/migration/kali-packages-kali-20261103-045627.tar.gz
# mode non interactif : ajouter --yes en 3e argument
```

La restauration est tolérante aux échecs (reprise APT paquet par paquet, filtrage des versions pip propres à Debian absentes de PyPI avec reprise sans version figée) et écrit un rapport `kali-restore-report-<date>.txt` listant ce qui n'a pas pu être installé. Détails et export : voir `linux/kali/migration/README.md`.

**Important :** migration d'une machine existante et préparation d'une VM propre sont deux opérations différentes. Une restauration complète peut réinstaller des outils ou versions qui ne sont pas souhaitables dans tous les TP. Utilise-la explicitement, après vérification de l'archive et de la compatibilité de la version Kali.

Le précédent script de migration Docker/Nginx est également à conserver séparément : `docker-nginx-migrate.sh` (Nginx, certificats, conteneurs, volumes, Compose, services et cron). Il n'est pas appelé automatiquement par `setup.sh`.

## Personnalisation

- Linux : `linux/<role>/packages.apt` et `linux/<role>/install.sh`
- Windows : `windows/<role>/install.ps1`
- Outils communs : `common/`
- Configurations : `configs/`

Les listes fournies sont des exemples minimaux/commentés. Complète-les avec les outils réellement nécessaires à tes TP.

## Bonnes pratiques

- Tester chaque rôle sur un snapshot/une VM jetable avant de l'utiliser chez un client.
- Épingler les versions importantes et documenter les dépôts tiers.
- Ne jamais committer de secrets, clés privées, tokens, mots de passe ou fichiers `.env`.
- Ne pas lancer aveuglément un script récupéré depuis une branche non vérifiée.
- Conserver les logs et faire échouer le script lorsqu'une étape critique échoue.
- Les scripts doivent être idempotents : une deuxième exécution ne doit pas dégrader la machine.
"# cyberlab-setup" 
