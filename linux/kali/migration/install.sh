#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/base.sh
source "$HERE/../common/base.sh"

require_debian_family
. /etc/os-release
if [[ "${ID:-}" != "kali" ]]; then
  echo "[!] Ce rôle est prévu pour Kali. Distribution détectée : ${PRETTY_NAME:-inconnue}" >&2
  echo "    Pour Debian/Ubuntu, utilise le rôle debian." >&2
  exit 1
fi

log "Préparation de la base Kali"
apt_install_list "$HERE/packages.apt"

cp msf_vulnserver.rb /usr/share/metasploit-framework/modules/exploits/windows/misc/msf_vulnserver.rb

log "Base Kali terminée. Ajoute ici les étapes spécifiques à tes TP."
log "Le script de migration d'une Kali existante n'est volontairement pas lancé automatiquement."
