#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../common/base.sh"

require_debian_family
. /etc/os-release
case "${ID:-}" in
  debian|ubuntu) ;;
  *) echo "[!] Ce rôle est prévu pour Debian/Ubuntu. Détecté : ${PRETTY_NAME:-inconnue}" >&2; exit 1 ;;
esac

log "Préparation de la base Debian/Ubuntu"
apt_install_list "$HERE/packages.apt"
log "Base Debian/Ubuntu terminée. Ajoute ici les étapes spécifiques à tes TP."
