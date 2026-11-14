#!/usr/bin/env bash
# Export / restore APT, pip (python3 par défaut) et pipx sur Kali/Debian.
#
# Objectif du restore : réinstaller un maximum d'outils SANS s'arrêter à la
# première erreur. Un paquet APT renommé/retiré ou une version pip propre à
# Debian (introuvable sur PyPI) ne doit jamais faire échouer toute l'opération.
# Ce qui ne peut pas être restauré est listé dans un rapport final.
set -Eeuo pipefail
umask 077
ACTION="${1:-}"
ARCHIVE="${2:-}"
ASSUME_YES="${3:-}"      # --yes pour sauter la confirmation interactive
HOST="$(hostname -s 2>/dev/null || hostname)"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK=""
log(){ printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn(){ printf '[ATTENTION] %s\n' "$*" >&2; }
die(){ echo "[ERREUR] $*" >&2; exit 1; }
cleanup(){ [[ -z "$WORK" || ! -d "$WORK" ]] || rm -rf "$WORK"; }
trap cleanup EXIT

usage(){
cat <<EOF
Export :  sudo $0 export
Restore:  sudo $0 restore /chemin/kali-packages-HOST-DATE.tar.gz [--yes]

  --yes : ne pas demander de confirmation (mode non interactif).
EOF
}
[[ "$ACTION" == export || "$ACTION" == restore ]] || { usage; exit 2; }
[[ $EUID -eq 0 ]] || die "Lance le script avec sudo."
for c in tar python3 apt-get dpkg-query; do command -v "$c" >/dev/null || die "Commande manquante: $c"; done

# ---------------------------------------------------------------------------
# EXPORT
# ---------------------------------------------------------------------------
if [[ "$ACTION" == export ]]; then
  OUT="$PWD/kali-packages-${HOST}-${STAMP}.tar.gz"
  WORK="$(mktemp -d /tmp/kali-packages.XXXXXX)"
  mkdir -p "$WORK/apt" "$WORK/python" "$WORK/system"

  log "Inventaire APT"
  apt-mark showmanual | sort -u > "$WORK/apt/manual-packages.txt"
  dpkg-query -W -f='${binary:Package}\t${Version}\t${db:Status-Status}\n' \
    > "$WORK/apt/all-installed-packages.tsv" 2>/dev/null || true
  apt-cache policy > "$WORK/apt/apt-policy.txt" 2>&1 || true

  log "Inventaire pip"
  python3 --version > "$WORK/python/python-version.txt" 2>&1 || true
  python3 -m pip --version > "$WORK/python/pip-version.txt" 2>&1 || true
  # Dump complet (référence). Le restore ne s'appuie PAS dessus directement :
  # il le filtre, car un pip freeze système contient des versions Debian
  # (.dev, +dfsg, 0.0.0, GDAL @ file://...) absentes de PyPI.
  python3 -m pip freeze --all > "$WORK/python/pip-freeze.txt" 2>"$WORK/python/pip-freeze.err" || {
    : > "$WORK/python/pip-freeze.txt"
    echo "python3 -m pip freeze a échoué; voir ce fichier." >> "$WORK/python/pip-freeze.err"
  }

  log "Inventaire pipx"
  if command -v pipx >/dev/null 2>&1; then
    pipx list --json > "$WORK/python/pipx-list.json" 2>"$WORK/python/pipx-list.err" || true
    python3 - "$WORK/python/pipx-list.json" "$WORK/python/pipx-packages.txt" <<'PY'
import json, sys
try:
    data=json.load(open(sys.argv[1]))
    names=sorted((data.get("venvs") or {}).keys())
except Exception:
    names=[]
open(sys.argv[2],"w").write("".join(n+"\n" for n in names))
PY
  else
    : > "$WORK/python/pipx-packages.txt"
    echo "pipx non installé" > "$WORK/python/pipx-list.err"
  fi

  # Sources et clés APT archivées comme référence, pas réactivées au restore.
  for p in /etc/apt/sources.list /etc/apt/sources.list.d /etc/apt/keyrings; do
    [[ ! -e "$p" ]] || cp -a --parents "$p" "$WORK/system/"
  done
  {
    echo "Hostname: $HOST"
    date -Is
    cat /etc/os-release 2>/dev/null || true
    echo "Architecture: $(dpkg --print-architecture)"
    uname -a
  } > "$WORK/system/host-info.txt"

  cat > "$WORK/README.txt" <<'EOF'
APT:
- apt/manual-packages.txt : paquets marqués manuels par apt-mark.
- apt/all-installed-packages.tsv : inventaire complet et versions.
Python:
- python/pip-freeze.txt : paquets visibles via python3 -m pip freeze --all.
- python/pipx-packages.txt / pipx-list.json : applications pipx.
system:
- sources APT et keyrings archivés pour référence.

Le restore :
- installe les paquets APT manuels un par un en cas d'échec de lot
  (un paquet manquant n'interrompt plus toute l'opération) ;
- recrée les applications pipx par nom ;
- filtre pip-freeze.txt (supprime les versions Debian absentes de PyPI :
  .dev, +dfsg, +ds, +b, +svn, 0.0.0, @ file://, git+, -e) puis installe
  le reste dans /opt/kali-tools-venv, en tolérant les échecs ;
- écrit un rapport restore-report.txt listant ce qui n'a pas pu être installé.

Limites:
- pip ne concerne que l'interpréteur python3 par défaut, pas tous les venvs.
- pipx est réinstallé par nom, pas avec une garantie de versions identiques.
- Les dépôts tiers ne sont pas réactivés automatiquement : vérifier leur
  compatibilité et leur authenticité avant de les réutiliser.
- Les outils Git clonés, binaires compilés et configurations applicatives
  ne sont pas sauvegardés par ce script.
- Des paquets présents dans pip freeze peuvent dépendre de bibliothèques APT
  ou ne pas avoir de wheel pour la version de Python cible.
EOF
  log "Création de l'archive"
  tar -czpf "$OUT" -C "$WORK" .
  chmod 600 "$OUT"
  echo "Archive créée : $OUT"
  sha256sum "$OUT"
  exit 0
fi

# ---------------------------------------------------------------------------
# RESTORE
# ---------------------------------------------------------------------------
[[ -n "$ARCHIVE" && -f "$ARCHIVE" ]] || die "Indique une archive existante."
tar -tzf "$ARCHIVE" >/dev/null || die "Archive invalide."
WORK="$(mktemp -d /tmp/kali-restore.XXXXXX)"
tar -xzpf "$ARCHIVE" -C "$WORK"
APT_LIST="$WORK/apt/manual-packages.txt"
PIP_LIST="$WORK/python/pip-freeze.txt"
PIPX_LIST="$WORK/python/pipx-packages.txt"
REPORT="$WORK/restore-report.txt"
: > "$REPORT"
[[ -f "$APT_LIST" ]] || die "Liste APT absente."

# Rappel de contexte : version de Python d'origine vs cible.
SRC_PY="$(sed -n 's/^Python //p' "$WORK/python/python-version.txt" 2>/dev/null | head -1)"
DST_PY="$(python3 --version 2>&1 | sed 's/^Python //')"
if [[ -n "$SRC_PY" && "${SRC_PY%.*}" != "${DST_PY%.*}" ]]; then
  warn "Python d'origine ${SRC_PY} vs cible ${DST_PY} : des wheels pip peuvent manquer."
fi

echo "Cette opération installe des paquets et modifie l'environnement Python."
if [[ "$ASSUME_YES" != "--yes" ]]; then
  read -r -p "Tape RESTORE pour confirmer : " CONFIRM
  [[ "$CONFIRM" == RESTORE ]] || die "Annulé."
fi

# --- APT ---------------------------------------------------------------------
log "Mise à jour APT"
apt-get update || warn "apt-get update a renvoyé une erreur (dépôts tiers ?)."

log "Installation des paquets APT manuels"
mapfile -t PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$APT_LIST" | sort -u)
APT_FAILED=()
if ((${#PACKAGES[@]})); then
  # Tentative en lot (rapide). En cas d'échec, reprise paquet par paquet pour
  # n'écarter que ceux réellement indisponibles.
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"; then
    warn "Installation en lot incomplète, reprise paquet par paquet."
    for p in "${PACKAGES[@]}"; do
      if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$p"; then
        APT_FAILED+=("$p")
      fi
    done
  fi
fi
if ((${#APT_FAILED[@]})); then
  { echo "== Paquets APT non installés =="; printf '%s\n' "${APT_FAILED[@]}"; echo; } >> "$REPORT"
  warn "${#APT_FAILED[@]} paquet(s) APT non installé(s) (voir rapport)."
fi

# --- pipx --------------------------------------------------------------------
if [[ -s "$PIPX_LIST" ]]; then
  log "Restauration des applications pipx"
  command -v pipx >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y pipx || true
  if command -v pipx >/dev/null 2>&1; then
    PIPX_FAILED=()
    while IFS= read -r pkg; do
      [[ -n "$pkg" ]] || continue
      pipx install "$pkg" || PIPX_FAILED+=("$pkg")
    done < "$PIPX_LIST"
    if ((${#PIPX_FAILED[@]})); then
      { echo "== Applications pipx non installées =="; printf '%s\n' "${PIPX_FAILED[@]}"; echo; } >> "$REPORT"
      warn "${#PIPX_FAILED[@]} application(s) pipx en échec (voir rapport)."
    fi
  else
    warn "pipx indisponible : applications pipx ignorées."
    { echo "== pipx indisponible, applications ignorées =="; cat "$PIPX_LIST"; echo; } >> "$REPORT"
  fi
fi

# --- pip (venv isolé) --------------------------------------------------------
if [[ -s "$PIP_LIST" ]]; then
  log "Filtrage de pip-freeze (retrait des versions non installables depuis PyPI)"
  CLEAN="$WORK/python/pip-clean.txt"
  SKIPPED="$WORK/python/pip-skipped.txt"
  # Écarte : URLs/chemins locaux ( @ ...), file://, git+, éditables (-e),
  # et pins propres à Debian (.dev, +dfsg, +ds, +b<n>, +svn, +git, ==0.0.0).
  grep -Ev '^[[:space:]]*(#|$)' "$PIP_LIST" \
    | grep -E ' @ |file://|git\+|^-e|^-r|==[^[:space:]]*(\.dev|\+dfsg|\+ds|\+b[0-9]|\+svn|\+git|\+)|==0\.0\.0([[:space:]]|$)' \
    > "$SKIPPED" || true
  grep -Ev '^[[:space:]]*(#|$)' "$PIP_LIST" \
    | grep -Ev ' @ |file://|git\+|^-e|^-r|==[^[:space:]]*(\.dev|\+dfsg|\+ds|\+b[0-9]|\+svn|\+git|\+)|==0\.0\.0([[:space:]]|$)' \
    > "$CLEAN" || true

  if [[ -s "$SKIPPED" ]]; then
    { echo "== Lignes pip écartées (version Debian/locale absente de PyPI) =="; cat "$SKIPPED"; echo; } >> "$REPORT"
    warn "$(wc -l < "$SKIPPED") ligne(s) pip écartée(s) (voir rapport)."
  fi

  if [[ -s "$CLEAN" ]]; then
    log "Création du venv isolé /opt/kali-tools-venv"
    command -v python3 >/dev/null || die "python3 absent."
    if ! python3 -m venv /opt/kali-tools-venv 2>/dev/null; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv || true
      python3 -m venv /opt/kali-tools-venv || die "Impossible de créer le venv (python3-venv ?)."
    fi
    VPY="/opt/kali-tools-venv/bin/python"
    "$VPY" -m pip install --upgrade pip wheel setuptools || warn "Mise à niveau pip/wheel/setuptools incomplète."

    log "Installation pip (lot, puis paquet par paquet si échec)"
    if ! "$VPY" -m pip install -r "$CLEAN"; then
      warn "Installation groupée incomplète, reprise paquet par paquet (plus lent)."
      PIP_FAILED=()
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        "$VPY" -m pip install "$line" || PIP_FAILED+=("$line")
      done < "$CLEAN"
      if ((${#PIP_FAILED[@]})); then
        { echo "== Paquets pip non installés =="; printf '%s\n' "${PIP_FAILED[@]}"; echo; } >> "$REPORT"
        warn "${#PIP_FAILED[@]} paquet(s) pip en échec (voir rapport)."
      fi
    fi

    # Reprise des lignes écartées : la version Debian n'existe pas sur PyPI,
    # mais le paquet lui-même souvent oui. On réessaie SANS version figée
    # (impacket, neo4j, matplotlib, playwright...). On ne touche pas aux
    # références locales/VCS (GDAL @ file://, git+, -e), non installables.
    if [[ -s "$SKIPPED" ]]; then
      log "Reprise des paquets écartés, sans version figée"
      RETRY_OK=(); RETRY_KO=()
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
          *' @ '*|*file://*|git+*|-e*|-r*) continue ;;
        esac
        name="${line%%==*}"; name="${name%%[<>=!~;[ ]*}"
        [[ -n "$name" ]] || continue
        if "$VPY" -m pip install "$name"; then RETRY_OK+=("$name"); else RETRY_KO+=("$name"); fi
      done < "$SKIPPED"
      ((${#RETRY_OK[@]})) && { echo "== Paquets réinstallés sans version figée =="; printf '%s\n' "${RETRY_OK[@]}"; echo; } >> "$REPORT"
      ((${#RETRY_KO[@]})) && { echo "== Paquets écartés toujours en échec =="; printf '%s\n' "${RETRY_KO[@]}"; echo; } >> "$REPORT"
    fi

    echo "Activation du venv : source /opt/kali-tools-venv/bin/activate"
  else
    warn "Aucune ligne pip installable après filtrage."
  fi
fi

# --- Rapport -----------------------------------------------------------------
if [[ -s "$REPORT" ]]; then
  FINAL_REPORT="/root/kali-restore-report-${STAMP}.txt"
  cp -f "$REPORT" "$FINAL_REPORT" 2>/dev/null || {
    FINAL_REPORT="$PWD/kali-restore-report-${STAMP}.txt"
    cp -f "$REPORT" "$FINAL_REPORT"
  }
  log "Restauration terminée (certains éléments n'ont pas pu être restaurés)."
  echo "Rapport détaillé : $FINAL_REPORT"
else
  log "Restauration terminée, aucun élément en échec signalé."
fi
echo "Vérifie les versions et les paquets manquants avant usage en TP."
