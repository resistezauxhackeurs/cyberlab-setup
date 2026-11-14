#!/usr/bin/env bash
# boite-a-outils/installer-outils.sh
# Installe TOUTE la chaine d'enumeration de perimetre + dependances :
#   apt      : git, build-essential, curl, jq, dnsutils, chromium (captures)
#   massdns  : compile depuis les sources (requis par puredns)
#   Go       : subfinder, dnsx, alterx, naabu, httpx, katana, gau, puredns,
#              github-subdomains (source GitHub, token perso)
# Idempotent : saute ce qui est deja present. A lancer sur Kali/Debian.
set -uo pipefail

log(){ echo -e "\n[*] $*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ------------------------------------------------------------ 1. paquets apt
log "Paquets systeme (apt)"
if have apt-get; then
  $SUDO apt-get update -qq || true
  $SUDO apt-get install -y \
    git build-essential curl wget jq dnsutils libpcap-dev ca-certificates || true
  # chromium pour les captures d'ecran httpx (nom de paquet variable)
  $SUDO apt-get install -y chromium 2>/dev/null \
    || $SUDO apt-get install -y chromium-browser 2>/dev/null \
    || echo "  [!] chromium non installe : httpx -screenshot ne fonctionnera pas (optionnel)."
else
  echo "  [!] apt introuvable : installez git, build-essential, curl, jq, dnsutils, libpcap-dev a la main."
fi

# ------------------------------------------------------------ 2. Go
log "Go"
if have go; then
  echo "  [OK] $(go version)"
else
  echo "  [!] Go absent. Installation via apt (golang-go)..."
  $SUDO apt-get install -y golang-go 2>/dev/null || true
  have go || { echo "  [X] Go toujours absent. Installez-le (https://go.dev/dl/) puis relancez."; exit 1; }
fi
export PATH="$PATH:$(go env GOPATH)/bin"
GOBIN="$(go env GOPATH)/bin"

# ------------------------------------------------------------ 3. massdns (pour puredns)
log "massdns (requis par puredns)"
if have massdns; then
  echo "  [OK] massdns present"
else
  tmp="$(mktemp -d)"
  if git clone --depth 1 https://github.com/blechschmidt/massdns.git "$tmp/massdns" 2>/dev/null \
     && make -C "$tmp/massdns" >/dev/null 2>&1; then
    $SUDO cp "$tmp/massdns/bin/massdns" /usr/local/bin/ && echo "  [OK] massdns compile et installe"
  else
    echo "  [!] echec compilation massdns : puredns fonctionnera en mode degrade."
  fi
  rm -rf "$tmp"
fi

# ------------------------------------------------------------ 4. binaires Go
log "Outils Go (subfinder, dnsx, alterx, naabu, httpx, katana, gau, puredns, github-subdomains)"
install_go(){
  local name="$1" pkg="$2"
  if have "$name"; then echo "  [OK] $name"; else
    echo "  ... $name"
    go install -v "$pkg@latest" >/dev/null 2>&1 && echo "  [OK] $name installe" \
      || echo "  [X] echec $name ($pkg)"
  fi
}
install_go subfinder github.com/projectdiscovery/subfinder/v2/cmd/subfinder
install_go dnsx      github.com/projectdiscovery/dnsx/cmd/dnsx
install_go alterx    github.com/projectdiscovery/alterx/cmd/alterx
install_go naabu     github.com/projectdiscovery/naabu/v2/cmd/naabu
install_go httpx     github.com/projectdiscovery/httpx/cmd/httpx
install_go katana    github.com/projectdiscovery/katana/cmd/katana
install_go gau       github.com/lc/gau/v2/cmd/gau
install_go puredns   github.com/d3mondev/puredns/v2
install_go github-subdomains github.com/gwen001/github-subdomains

# ------------------------------------------------------ 4b. wordlist sous-domaines
# Le bundle est livre avec SecLists top-110000. Si la wordlist presente est plus
# petite, on la remplace par SecLists (Kali local ou telechargement).
log "Wordlist de sous-domaines (bruteforce)"
WLDIR="$(cd "$(dirname "$0")" && pwd)/wordlists"
WLFILE="$WLDIR/sous-domaines.txt"
mkdir -p "$WLDIR"
SECLISTS_KALI="/usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt"
SECLISTS_URL="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-110000.txt"
cur=0; [ -f "$WLFILE" ] && cur="$(grep -vc '^#' "$WLFILE" 2>/dev/null || echo 0)"
if [ "$cur" -gt 10000 ]; then
  echo "  [OK] wordlist deja consequente ($cur entrees), on n'y touche pas"
elif [ -f "$SECLISTS_KALI" ]; then
  cp "$SECLISTS_KALI" "$WLFILE" && echo "  [OK] SecLists (Kali) -> $WLFILE ($(wc -l < "$WLFILE") entrees)"
elif curl -fsSL "$SECLISTS_URL" -o "$WLFILE.tmp" 2>/dev/null && [ -s "$WLFILE.tmp" ]; then
  mv "$WLFILE.tmp" "$WLFILE" && echo "  [OK] SecLists telecharge -> $WLFILE ($(wc -l < "$WLFILE") entrees)"
else
  rm -f "$WLFILE.tmp" 2>/dev/null
  echo "  [!] SecLists indisponible : la wordlist actuelle ($cur entrees) est conservee."
  echo "      Pour du volume : cp /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt \"$WLFILE\""
fi

# ------------------------------------------------------ 4c. resolveurs DNS publics
# Grosse liste publique VALIDEE (trickest, MAJ quotidienne) pour la phase de
# bruteforce (-r). La validation finale se fait sur resolvers-trusted.txt (livre).
# Peu de resolveurs a grande echelle => throttling => faux negatifs.
log "Resolveurs DNS publics (bruteforce)"
RESFILE="$WLDIR/resolvers.txt"
TRUSTED="$WLDIR/resolvers-trusted.txt"
RESOLVERS_URL="https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt"
if curl -fsSL "$RESOLVERS_URL" -o "$RESFILE.tmp" 2>/dev/null && [ -s "$RESFILE.tmp" ]; then
  mv "$RESFILE.tmp" "$RESFILE" && echo "  [OK] resolveurs publics -> $RESFILE ($(grep -vc '^#' "$RESFILE") resolveurs)"
else
  rm -f "$RESFILE.tmp" 2>/dev/null
  [ -f "$TRUSTED" ] && cp "$TRUSTED" "$RESFILE"
  echo "  [!] Liste trickest indisponible : repli sur les resolveurs de confiance ($(grep -vc '^#' "$RESFILE" 2>/dev/null || echo 0))."
  echo "      A grande echelle => faux negatifs. Recuperez : $RESOLVERS_URL"
fi

# ------------------------------------------------------------ 5. PATH & cles
log "Finalisation"
case ":$PATH:" in
  *":$GOBIN:"*) : ;;
  *) echo "  [!] Ajoutez a votre shell :  export PATH=\"\$PATH:$GOBIN\"" ;;
esac
echo "  [i] Cles d'API subfinder : OPTIONNELLES et PERSONNELLES."
echo "      Le TP tourne sans aucune cle (crt.sh + certspotter portent le passif)."
echo "      Pour plus de sources, creez VOS PROPRES comptes gratuits (VirusTotal,"
echo "      Chaos/ProjectDiscovery, Shodan, Censys, Netlas) et renseignez-les dans"
echo "      ~/.config/subfinder/provider-config.yaml"
echo "      Ne collez JAMAIS la cle d'un tiers : une cle partagee finit par fuiter."
echo "  [i] Source GitHub (github-subdomains) : exportez VOTRE token perso, gratuit,"
echo "      aucun scope requis :   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx"

# ------------------------------------------------------------ 6. recap
log "Verification"
ok=0; ko=0
for t in subfinder dnsx alterx naabu httpx katana gau puredns github-subdomains massdns jq curl dig; do
  if have "$t"; then echo "  [OK] $t"; ok=$((ok+1)); else echo "  [--] $t"; ko=$((ko+1)); fi
done
echo
echo "Termine : $ok presents / $ko manquants."
[ "$ko" -gt 0 ] && echo "Relancez ce script ou installez les manquants a la main."
