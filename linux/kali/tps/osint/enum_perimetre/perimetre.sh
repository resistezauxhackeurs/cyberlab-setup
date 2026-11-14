#!/usr/bin/env bash
# boite-a-outils/perimetre.sh
# Enumeration d'un gros perimetre externe, de la decouverte a la priorisation
# en 3 tiers. NE FAIT PAS de recherche de vulnerabilites : on s'arrete au
# classement. Mise en pratique du support "Auditer un gros perimetre".
#
# Chaine : passif -> actif -> resolution -> catalogue HTTP -> collecte d'URL -> tiers
# Degradation gracieuse : chaque outil absent est signale et l'etape est sautee.
#
# Usage :
#   ./perimetre.sh -d client.fr
#   ./perimetre.sh -s seeds.txt -o out/ -r resolvers.txt
#   ./perimetre.sh -d client.fr --no-active        # passif seul (aucun paquet envoye)
#   ./perimetre.sh -d client.fr --no-url           # sans collecte d'URL
#
# Options :
#   -d DOMAINE     un domaine racine (repetez -d pour plusieurs)
#   -s FICHIER     fichier de seeds (un domaine racine par ligne)
#   -o DOSSIER     dossier de sortie          (defaut : out-<domaine>-<date>)
#   -w FICHIER     wordlist de sous-domaines  (defaut : wordlists/sous-domaines.txt)
#   -r FICHIER     resolveurs publics (bruteforce)      (defaut : wordlists/resolvers.txt)
#   -t FICHIER     resolveurs de confiance (validation) (defaut : wordlists/resolvers-trusted.txt)
#   --no-active    passif uniquement (pas de bruteforce ni de sonde)
#   --no-url       ne pas collecter les URL (katana/gau)
#   --perms        activer les permutations (alterx) : lent, DESACTIVE par defaut (TP)
#   -y             sauter la confirmation d'autorisation (perimetre a vous)
set -uo pipefail
# Les binaires Go (subfinder, dnsx, puredns, github-subdomains...) vivent dans
# ~/go/bin (GOPATH/bin). On les rend visibles meme si le PATH permanent du shell
# ne les inclut pas encore (sinon les etapes seraient sautees a tort).
command -v go >/dev/null 2>&1 && export PATH="$PATH:$(go env GOPATH)/bin"
[ -d "$HOME/go/bin" ] && export PATH="$PATH:$HOME/go/bin"
HERE="$(cd "$(dirname "$0")" && pwd)"
SEEDS_INLINE=(); SEEDS_FILE=""; OUT=""; ACTIVE=1; DOURL=1; YES=0; PERMS=0
WL="$HERE/wordlists/sous-domaines.txt"
RES="$HERE/wordlists/resolvers.txt"
REST="$HERE/wordlists/resolvers-trusted.txt"

while [ $# -gt 0 ]; do case "$1" in
  -d) SEEDS_INLINE+=("$2"); shift 2;;
  -s) SEEDS_FILE="$2"; shift 2;;
  -o) OUT="$2"; shift 2;;
  -w) WL="$2"; shift 2;;
  -r) RES="$2"; shift 2;;
  -t) REST="$2"; shift 2;;
  --no-active) ACTIVE=0; shift;;
  --no-url) DOURL=0; shift;;
  --perms) PERMS=1; shift;;
  -y) YES=1; shift;;
  -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  *) echo "option inconnue : $1 (-h pour l'aide)"; exit 1;;
esac; done

# --- construction de la liste de seeds ---
SEEDS_TMP="$(mktemp)"
[ -n "$SEEDS_FILE" ] && cat "$SEEDS_FILE" >> "$SEEDS_TMP"
for d in "${SEEDS_INLINE[@]:-}"; do [ -n "$d" ] && echo "$d" >> "$SEEDS_TMP"; done
sort -u "$SEEDS_TMP" -o "$SEEDS_TMP"
[ -s "$SEEDS_TMP" ] || { echo "Erreur : aucun domaine (-d ou -s). -h pour l'aide."; exit 1; }
FIRST="$(head -1 "$SEEDS_TMP")"
[ -z "$OUT" ] && OUT="out-${FIRST}-$(date +%Y%m%d-%H%M)"
mkdir -p "$OUT"
cp "$SEEDS_TMP" "$OUT/seeds.txt"; rm -f "$SEEDS_TMP"

# --- garde-fou legal ---
if [ "$YES" -ne 1 ]; then
  echo "!! Vous allez enumerer : $(paste -sd' ' "$OUT/seeds.txt")"
  echo "!! N'auditez QUE un perimetre qui vous appartient ou pour lequel vous avez une autorisation ecrite."
  read -r -p "Confirmez-vous cette autorisation ? (oui/non) " a
  [ "$a" = "oui" ] || { echo "Abandon."; exit 1; }
fi

have(){ command -v "$1" >/dev/null 2>&1; }
step(){ echo -e "\n=== $* ==="; }
# Resolveurs : grosse liste publique (-r) pour cracher au bruteforce ; petite liste
# fiable (--resolvers-trusted) pour valider et filtrer les faux positifs.
# Repli : si la liste publique manque, on retombe sur la liste de confiance.
[ -f "$RES" ] || { [ -f "$REST" ] && RES="$REST"; }
RESARG=();     [ -f "$RES" ]  && RESARG=(-r "$RES")
TRUSTEDARG=(); [ -f "$REST" ] && TRUSTEDARG=(--resolvers-trusted "$REST")
# dnsx (resolution/validation) : resolveurs fiables de preference, pour la precision.
if [ -f "$REST" ]; then DNSXRES=(-r "$REST"); else DNSXRES=("${RESARG[@]}"); fi

# Kali installe un binaire "httpx" qui est le CLIENT HTTP Python, pas le httpx de
# ProjectDiscovery (souvent nomme "httpx-toolkit"). On selectionne le bon : seul le
# httpx de PD accepte l'option "-version" et renvoie 0.
pick_httpx(){
  local c
  for c in "$HOME/go/bin/httpx" httpx-toolkit httpx; do
    command -v "$c" >/dev/null 2>&1 || continue
    "$c" -version >/dev/null 2>&1 && { echo "$c"; return 0; }
  done
  return 1
}
HTTPX="$(pick_httpx || true)"

# ============================================================ 1. PASSIF
step "1/6  Decouverte passive (aucun paquet envoye a la cible)"
: > "$OUT/subs_passive.txt"
# subfinder : sources publiques ; les sources a cle sont ignorees si non configurees
if have subfinder; then
  subfinder -dL "$OUT/seeds.txt" -all -silent >> "$OUT/subs_passive.txt" 2>/dev/null || true
else echo "  [--] subfinder absent (installer-outils.sh)"; fi
# Certificate Transparency, sans aucune cle
if have jq; then
  # crt.sh (le plus rentable)
  while read -r dom; do
    curl -s "https://crt.sh/?q=%25.${dom}&output=json" 2>/dev/null \
      | jq -r '.[].name_value' 2>/dev/null \
      | tr 'A-Z' 'a-z' | sed 's/^\*\.//' ;
  done < "$OUT/seeds.txt" >> "$OUT/subs_passive.txt" || true
  # certspotter : 2e source CT (filet quand crt.sh est en rade ; debit limite sans cle)
  while read -r dom; do
    curl -s "https://api.certspotter.com/v1/issuances?domain=${dom}&include_subdomains=true&expand=dns_names" 2>/dev/null \
      | jq -r '.[].dns_names[]?' 2>/dev/null \
      | tr 'A-Z' 'a-z' | sed 's/^\*\.//' ;
  done < "$OUT/seeds.txt" >> "$OUT/subs_passive.txt" || true
else echo "  [--] jq absent : sources crt.sh / certspotter sautees"; fi
# GitHub (code + commits) : source unique. Token PERSO de l'operateur, jamais partage.
if have github-subdomains && [ -n "${GITHUB_TOKEN:-}" ]; then
  while read -r dom; do
    github-subdomains -d "$dom" -t "$GITHUB_TOKEN" 2>/dev/null \
      | tr 'A-Z' 'a-z' | sed 's/^\*\.//' ;
  done < "$OUT/seeds.txt" >> "$OUT/subs_passive.txt" || true
elif have github-subdomains; then
  echo "  [--] github-subdomains present mais GITHUB_TOKEN absent : source GitHub sautee (export GITHUB_TOKEN=...)"
fi
sort -u "$OUT/subs_passive.txt" -o "$OUT/subs_passive.txt"
echo "  -> passif : $(wc -l < "$OUT/subs_passive.txt") sous-domaines"

# ============================================================ 2. ACTIF
cp "$OUT/subs_passive.txt" "$OUT/subs_all.txt"
if [ "$ACTIVE" -eq 1 ]; then
  step "2/6  Decouverte active (bruteforce ; permutations si --perms)"
  # test wildcard sur le premier domaine
  rnd="zzz$RANDOM$RANDOM.$FIRST"
  if have dnsx; then
    if echo "$rnd" | dnsx -silent "${DNSXRES[@]}" 2>/dev/null | grep -q .; then
      echo "  [!] WILDCARD detecte sur $FIRST : le bruteforce sera filtre (dnsx -wd)."
    fi
  fi
  if have puredns && [ "${#RESARG[@]}" -gt 0 ]; then
    puredns bruteforce "$WL" "$FIRST" "${RESARG[@]}" "${TRUSTEDARG[@]}" -q --write "$OUT/brute.txt" 2>/dev/null || true
  elif have dnsx; then
    sed "s/$/.$FIRST/" "$WL" | dnsx -silent "${DNSXRES[@]}" -wd "$FIRST" > "$OUT/brute.txt" 2>/dev/null || true
  else echo "  [--] ni puredns ni dnsx : bruteforce saute"; : > "$OUT/brute.txt"; fi
  [ -f "$OUT/brute.txt" ] && cat "$OUT/brute.txt" >> "$OUT/subs_all.txt"
  # permutations
  if [ "$PERMS" -eq 1 ] && have alterx; then
    # -enrich derive des mots des hotes trouves : sur un gros perimetre la combinatoire
    # explose (millions de perms). On plafonne (PERMS_MAX, defaut 100000) pour borner
    # le temps de resolution. head ferme le flux -> alterx s'arrete tot.
    alterx -l "$OUT/subs_all.txt" -enrich -silent 2>/dev/null \
      | head -n "${PERMS_MAX:-100000}" > "$OUT/perms.txt" || true
    np=$(wc -l < "$OUT/perms.txt" 2>/dev/null || echo 0)
    [ "$np" -ge "${PERMS_MAX:-100000}" ] && echo "  [!] permutations plafonnees a ${PERMS_MAX:-100000} (ajustez PERMS_MAX si besoin)."
    if have dnsx && [ -s "$OUT/perms.txt" ]; then
      dnsx -l "$OUT/perms.txt" -silent "${DNSXRES[@]}" -wd "$FIRST" >> "$OUT/subs_all.txt" 2>/dev/null || true
    fi
  elif [ "$PERMS" -ne 1 ]; then
    echo "  [i] permutations desactivees (--perms pour les activer ; lent sur gros perimetre)"
  fi
  sort -u "$OUT/subs_all.txt" -o "$OUT/subs_all.txt"
  echo "  -> total apres actif : $(wc -l < "$OUT/subs_all.txt") sous-domaines"
else
  step "2/6  Decouverte active DESACTIVEE (--no-active)"
fi

# ============================================================ 3. RESOLUTION
step "3/6  Resolution & normalisation"
LIVE="$OUT/live_hosts.txt"; : > "$LIVE"
# puredns resout ET filtre les wildcards nativement. Bien plus fiable que dnsx -wd
# qui, sur un domaine a wildcard (frequent sur les gros orgs), peut tout eliminer (0 hote).
if have puredns && [ "${#RESARG[@]}" -gt 0 ]; then
  puredns resolve "$OUT/subs_all.txt" "${RESARG[@]}" "${TRUSTEDARG[@]}" -q --write "$LIVE" 2>/dev/null || true
elif have dnsx; then
  dnsx -l "$OUT/subs_all.txt" "${DNSXRES[@]}" -silent 2>/dev/null | sort -u > "$LIVE" || true
else
  # repli portable : getent
  while read -r h; do getent hosts "$h" >/dev/null 2>&1 && echo "$h"; done < "$OUT/subs_all.txt" | sort -u > "$LIVE"
fi
sort -u "$LIVE" -o "$LIVE" 2>/dev/null || true
echo "  -> hotes qui resolvent : $(wc -l < "$LIVE" 2>/dev/null || echo 0)"

# ============================================================ 4. HTTP
step "4/6  Sonde HTTP & catalogue"
HJSON="$OUT/http.jsonl"; HURLS="$OUT/http_urls.txt"; : > "$HJSON"; : > "$HURLS"
if [ ! -s "$LIVE" ]; then
  echo "  [--] aucun hote resolu : sonde HTTP sautee"
elif [ -n "$HTTPX" ]; then
  "$HTTPX" -l "$LIVE" -sc -title -td -web-server -ip -cname -cdn -location -favicon \
        -follow-redirects -threads 50 -rl 150 -timeout 8 -silent \
        -json -o "$HJSON" 2>/dev/null || true
  if have jq && [ -s "$HJSON" ]; then jq -r '.url' "$HJSON" 2>/dev/null | sort -u > "$HURLS"; fi
else
  echo "  [--] httpx (ProjectDiscovery) introuvable : catalogue reduit (curl). Sur Kali : httpx-toolkit"
  while read -r h; do
    for s in https http; do
      code=$(curl -sk -o /dev/null -w '%{http_code}' -m 8 "$s://$h/" 2>/dev/null || echo 000)
      [ "$code" != "000" ] && echo "$s://$h" >> "$HURLS"
    done
  done < "$LIVE"; sort -u "$HURLS" -o "$HURLS"
fi
echo "  -> services HTTP : $(wc -l < "$HURLS" 2>/dev/null || echo 0)"

# ============================================================ 5. COLLECTE URL
if [ "$DOURL" -eq 1 ]; then
  step "5/6  Collecte d'URL (crawl + archives)"
  : > "$OUT/urls_all.txt"
  if have katana && [ -s "$HURLS" ]; then
    katana -list "$HURLS" -d 2 -jc -c 12 -rl 60 -silent 2>/dev/null >> "$OUT/urls_all.txt" || true
  else echo "  [--] katana absent ou pas d'URL : crawl saute"; fi
  if have gau; then
    while read -r dom; do gau --subs "$dom" --threads 5 2>/dev/null; done < "$OUT/seeds.txt" >> "$OUT/urls_all.txt" || true
  else echo "  [--] gau absent : archives sautees"; fi
  sort -u "$OUT/urls_all.txt" -o "$OUT/urls_all.txt"
  echo "  -> URL collectees : $(wc -l < "$OUT/urls_all.txt")"
else
  step "5/6  Collecte d'URL DESACTIVEE (--no-url)"; : > "$OUT/urls_all.txt"
fi

# ============================================================ 6. PRIORISATION EN TIERS
step "6/6  Priorisation en 3 tiers"
T0="$OUT/tier0.txt"; T1="$OUT/tier1.txt"; T2="$OUT/tier2.txt"
: > "$T0"; : > "$T1"; : > "$T2"
NAMES='login|sign in|admin|portal|connexion|dashboard|console|manager'
NAMEURL='//(vpn|admin|jenkins|gitlab|owa|citrix|mail|remote|portal|sso|api|dev|test|old|legacy|staging)\.'
if have jq && [ -s "$HJSON" ]; then
  # Tier 0 : login/admin OU nom evocateur, ET pas derriere un CDN
  jq -r --arg n "$NAMES" --arg u "$NAMEURL" '
    select(.cdn != true and .cdn_name == null)
    | select( ((.title // "") | test($n;"i")) or (.url | test($u;"i")) )
    | .url' "$HJSON" 2>/dev/null | sort -u > "$T0"
  # Tier 2 : derriere CDN, redirige ailleurs, ou page parquee
  jq -r 'select(.cdn == true or .cdn_name != null or (.location // "") != "") | .url' \
    "$HJSON" 2>/dev/null | sort -u > "$T2"
  # Tier 1 : le reste des URL vivantes
  comm -23 <(sort -u "$HURLS") <(cat "$T0" "$T2" | sort -u) > "$T1"
else
  echo "  [--] jq/httpx indisponibles : priorisation heuristique sur les URL"
  grep -Ei "$NAMEURL" "$HURLS" 2>/dev/null | sort -u > "$T0" || true
  comm -23 <(sort -u "$HURLS" 2>/dev/null) <(sort -u "$T0") > "$T1" 2>/dev/null || true
fi
echo "  -> Tier 0 : $(wc -l < "$T0") | Tier 1 : $(wc -l < "$T1") | Tier 2 : $(wc -l < "$T2")"

# ============================================================ INVENTAIRE
{
  echo "# Inventaire de perimetre  -  $(date '+%F %T')"
  echo
  echo "Perimetre : $(paste -sd', ' "$OUT/seeds.txt")"
  echo
  echo "## Entonnoir"
  echo "- sous-domaines collectes : $(wc -l < "$OUT/subs_all.txt")"
  echo "- hotes qui resolvent     : $(wc -l < "$LIVE")"
  echo "- services HTTP           : $(wc -l < "$HURLS" 2>/dev/null || echo 0)"
  echo "- URL collectees          : $(wc -l < "$OUT/urls_all.txt")"
  echo
  echo "## Priorisation"
  echo "- Tier 0 (prioritaire) : $(wc -l < "$T0")"
  echo "- Tier 1 (metier)      : $(wc -l < "$T1")"
  echo "- Tier 2 (vitrine/CDN) : $(wc -l < "$T2")"
  echo
  echo "## Tier 0 - a revoir en premier"
  sed 's/^/- /' "$T0" 2>/dev/null | head -50
} > "$OUT/INVENTAIRE.md"
echo
echo "[OK] Termine. Inventaire : $OUT/INVENTAIRE.md"
echo "     Fichiers de sortie dans : $OUT/"
