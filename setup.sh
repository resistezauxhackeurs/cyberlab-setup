#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROLE="${1:-}"

usage() {
  cat <<'EOF'
Usage: sudo ./setup.sh <role>

Rôles Linux :
  kali
  debian

Exemples :
  sudo ./setup.sh kali
  sudo ./setup.sh debian
EOF
}

if [[ -z "$ROLE" || "$ROLE" == "--help" || "$ROLE" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "[!] Lance ce script avec sudo/root." >&2
  exit 1
fi

case "$ROLE" in
  kali|debian)
    SCRIPT="$ROOT_DIR/linux/$ROLE/install.sh"
    ;;
  *)
    echo "[!] Rôle Linux inconnu : $ROLE" >&2
    usage
    exit 2
    ;;
esac

if [[ ! -x "$SCRIPT" ]]; then
  chmod +x "$SCRIPT"
fi

exec "$SCRIPT"
