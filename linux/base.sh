#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

require_debian_family() {
  if [[ ! -r /etc/os-release ]]; then
    echo "Impossible d'identifier la distribution (/etc/os-release absent)." >&2
    exit 1
  fi
  . /etc/os-release
  case "${ID:-}" in
    kali|debian|ubuntu) ;;
    *) echo "Distribution non prise en charge par ce script : ${PRETTY_NAME:-inconnue}" >&2; exit 1 ;;
  esac
}

apt_install_list() {
  local list_file="$1"
  [[ -f "$list_file" ]] || { log "Pas de liste APT : $list_file"; return 0; }
  mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$list_file" | sed 's/[[:space:]]*#.*$//' | awk 'NF')
  ((${#packages[@]})) || { log "Aucun paquet dans $list_file"; return 0; }
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}
