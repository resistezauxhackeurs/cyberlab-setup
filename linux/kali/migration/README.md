# Migration Kali existante

Export / restauration des paquets APT, des applications pipx et des librairies
pip d'une Kali, via `kali-package-migrate.sh`. Export et restauration sont
volontairement séparés du provisioning d'une VM neuve (`setup.sh`).

## Restauration depuis un clone du dépôt

L'archive de référence (`kali-packages-*.tar.gz`) est versionnée dans ce
dossier : elle est donc présente juste après un `git clone`.

```bash
git clone https://github.com/TON_ORGA/cyberlab-setup.git
cd cyberlab-setup
sudo linux/kali/migration/kali-package-migrate.sh restore \
  linux/kali/migration/kali-packages-kali-20261103-045627.tar.gz
```

Ajouter `--yes` en 3e argument pour un mode non interactif (sans la
confirmation `RESTORE`).

## Export d'une Kali

```bash
sudo linux/kali/migration/kali-package-migrate.sh export
# -> produit kali-packages-<hôte>-<date>.tar.gz dans le dossier courant
```

Pour qu'une nouvelle archive soit livrée avec le dépôt, la placer dans ce
dossier (`linux/kali/migration/`) et la committer : le `.gitignore` y fait une
exception, alors que les archives générées ailleurs restent ignorées.

## Ce que fait la restauration (et ne fait pas)

La restauration est **tolérante aux échecs** : elle n'abandonne plus au premier
paquet manquant et consigne ce qui n'a pas pu être installé dans un rapport
`kali-restore-report-<date>.txt` (dans `/root`).

- **APT** : installe les paquets marqués manuels. En cas d'échec du lot, reprise
  paquet par paquet pour n'écarter que ceux réellement indisponibles.
- **pipx** : réinstalle les applications par nom (versions non garanties).
- **pip** : crée un venv isolé `/opt/kali-tools-venv`, filtre `pip-freeze.txt`
  pour retirer les versions propres à Debian absentes de PyPI (`.dev`, `+dfsg`,
  `+ds`, `+b`, `+svn`, `0.0.0`, `@ file://`, `git+`, `-e`), installe le reste,
  puis **réessaie les lignes écartées sans version figée** (impacket, neo4j,
  matplotlib, playwright…). Activation : `source /opt/kali-tools-venv/bin/activate`.

Limites :

- Le pip freeze source vient du Python système ; il est donc normal que des
  paquets Debian purs (`python-apt`, `PyGObject`, `zenmap`, `pcapy`, GDAL…)
  restent non installables dans le venv : ils figureront au rapport.
- Si la version de Python cible diffère de la source, certains wheels peuvent
  manquer (compilation requise, éventuellement des `-dev` APT).
- Outils Git clonés, binaires compilés et configurations applicatives ne sont
  pas sauvegardés par ce script.
- Les dépôts tiers ne sont pas réactivés : vérifier compatibilité et
  authenticité avant réutilisation.

**Important :** migration d'une machine existante et préparation d'une VM propre
sont deux opérations différentes. Lancer la restauration explicitement, après
vérification de l'archive et de la compatibilité de la version de Kali.
