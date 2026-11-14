#!/usr/bin/env bash
# boite-a-outils/preparer.sh [domaine]
# Verifie les outils, teste la presence d'un wildcard DNS, rappelle le cadre.
set -uo pipefail
# Les binaires Go (subfinder, dnsx, httpx, github-subdomains...) vivent dans
# ~/go/bin (GOPATH/bin). On les rend visibles meme si le PATH permanent du
# shell ne les inclut pas encore (sinon : faux "manquant" alors qu'ils sont la).
command -v go >/dev/null 2>&1 && export PATH="$PATH:$(go env GOPATH)/bin"
[ -d "$HOME/go/bin" ] && export PATH="$PATH:$HOME/go/bin"
DOM="${1:-}"
echo "== Outils =="
for t in subfinder dnsx alterx naabu httpx katana gau puredns github-subdomains jq curl dig; do
  if command -v "$t" >/dev/null; then echo "  [OK] $t"; else echo "  [--] $t manquant"; fi
done
echo "== Cles d'API subfinder (optionnelles, personnelles) =="
f="$HOME/.config/subfinder/provider-config.yaml"
if [ -f "$f" ]; then
  echo "  [OK] $f present (vos cles a vous)"
else
  echo "  [i] pas de cles : normal, le TP tourne sans (crt.sh + certspotter portent le passif)."
  echo "      Pour plus de sources, ajoutez VOS propres cles gratuites dans $f."
fi
echo "== Token GitHub (source github-subdomains) =="
if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "  [OK] GITHUB_TOKEN defini"
else
  echo "  [--] GITHUB_TOKEN absent : la source GitHub sera sautee (export GITHUB_TOKEN=ghp_...)"
fi
echo "== Wordlist de sous-domaines =="
HERE="$(cd "$(dirname "$0")" && pwd)"
WLFILE="$HERE/wordlists/sous-domaines.txt"
if [ -f "$WLFILE" ]; then
  n="$(grep -vc '^#' "$WLFILE")"
  if [ "$n" -gt 1000 ]; then
    echo "  [OK] $n entrees"
  else
    echo "  [!] seulement $n entrees (liste starter) : peu de resultats au bruteforce."
    echo "      cp /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \"$WLFILE\""
    echo "      ...ou relancez ./installer-outils.sh (il tente de recuperer SecLists)."
  fi
else
  echo "  [--] $WLFILE introuvable"
fi
echo "== Resolveurs DNS =="
RESFILE="$HERE/wordlists/resolvers.txt"
TRUSTED="$HERE/wordlists/resolvers-trusted.txt"
if [ -f "$RESFILE" ]; then
  echo "  [OK] publics (bruteforce) : $(grep -vc '^#' "$RESFILE") resolveurs"
else
  echo "  [!] publics absents : relancez ./installer-outils.sh. Sans grosse liste,"
  echo "      le bruteforce a grande echelle throttle et rate des domaines (faux negatifs)."
fi
if [ -f "$TRUSTED" ]; then
  echo "  [OK] confiance (validation) : $(grep -vc '^#' "$TRUSTED") resolveurs"
else
  echo "  [--] $TRUSTED introuvable"
fi
if [ -n "$DOM" ]; then
  echo "== Test wildcard sur $DOM =="
  r="zzz$RANDOM$RANDOM.$DOM"
  if command -v dig >/dev/null; then
    if dig +short "$r" | grep -q .; then
      echo "  [!] WILDCARD : $r resout. Le bruteforce DOIT filtrer (puredns / dnsx -wd)."
    else echo "  [OK] pas de wildcard evident."; fi
  fi
fi
echo "== Rappel : n'auditez qu'un perimetre autorise. =="
