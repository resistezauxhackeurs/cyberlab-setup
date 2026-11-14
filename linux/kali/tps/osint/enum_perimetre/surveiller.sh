#!/usr/bin/env bash
# boite-a-outils/surveiller.sh [ANCIEN_DIR] [NOUVEAU_DIR]
# Monitoring de perimetre : compare deux passages de perimetre.sh et sort
# les diffs utiles. Sans argument, prend les deux dossiers out-* les plus recents.
#
# Diffs produits (dans NOUVEAU_DIR/DIFF.md) :
#   + nouveaux sous-domaines        + sous-domaines disparus
#   + nouveaux services HTTP        + nouveaux Tier 0  (le signal important)
#   + Tier 0 disparus
#
# Usage :
#   ./perimetre.sh -d corp.fr        # passage 1 (semaine derniere)
#   ...                              # puis, plus tard :
#   ./perimetre.sh -d corp.fr        # passage 2
#   ./surveiller.sh                  # compare les deux derniers automatiquement
set -uo pipefail
SEUIL_BRUIT="${SEUIL_BRUIT:-200}"   # au-dela, on suspecte un wildcard / changement d'infra

OLD="${1:-}"; NEW="${2:-}"
if [ -z "$OLD" ] || [ -z "$NEW" ]; then
  # deux dossiers out-* les plus recents (par date de modif)
  mapfile -t dirs < <(ls -1dt out-*/ 2>/dev/null | sed 's#/$##')
  [ "${#dirs[@]}" -ge 2 ] || { echo "Il faut au moins deux dossiers out-* (lancez perimetre.sh deux fois), ou passez ANCIEN NOUVEAU."; exit 1; }
  NEW="${dirs[0]}"; OLD="${dirs[1]}"
fi
[ -d "$OLD" ] && [ -d "$NEW" ] || { echo "Dossiers introuvables : $OLD / $NEW"; exit 1; }
echo "[*] Comparaison : $OLD  ->  $NEW"

# diff d'un fichier present dans les deux dossiers ; $3 = sens (new|gone)
delta(){
  local f="$1" sens="$2"
  local a="$OLD/$f" b="$NEW/$f"
  [ -f "$a" ] || a=/dev/null
  [ -f "$b" ] || b=/dev/null
  if [ "$sens" = "new" ]; then
    comm -13 <(sort -u "$a") <(sort -u "$b")     # dans NEW, pas dans OLD
  else
    comm -23 <(sort -u "$a") <(sort -u "$b")     # dans OLD, pas dans NEW
  fi
}

OUT="$NEW/DIFF.md"
{
  echo "# Diff de perimetre  -  $(date '+%F %T')"
  echo
  echo "Ancien : \`$OLD\`  ->  Nouveau : \`$NEW\`"
} > "$OUT"

section(){   # titre, fichier, sens, prefixe
  local titre="$1" f="$2" sens="$3" pre="$4"
  local lines; lines="$(delta "$f" "$sens")"
  local n; n="$(printf '%s\n' "$lines" | grep -c . || true)"
  {
    echo
    echo "## $titre : $n"
    [ "$n" -gt 0 ] && printf '%s\n' "$lines" | sed "s/^/- $pre /"
  } >> "$OUT"
  echo "$n"
}

n_new_sub=$(section "Nouveaux sous-domaines" "subs_all.txt" new "+")
n_gone_sub=$(section "Sous-domaines disparus" "subs_all.txt" gone "-")
n_new_http=$(section "Nouveaux services HTTP" "http_urls.txt" new "+")
n_new_t0=$(section "Nouveaux Tier 0 (a regarder vite)" "tier0.txt" new "!")
n_gone_t0=$(section "Tier 0 disparus" "tier0.txt" gone "-")

# seuil de bruit
if [ "${n_new_sub:-0}" -gt "$SEUIL_BRUIT" ]; then
  {
    echo
    echo "## Alerte bruit"
    echo "- $n_new_sub nouveaux sous-domaines d'un coup (> $SEUIL_BRUIT) : suspectez un wildcard nouvellement actif ou un changement d'infra, pas une vraie expansion. Verifiez avant de traiter."
  } >> "$OUT"
fi

echo
echo "== Resume =="
echo "  sous-domaines : +$n_new_sub / -$n_gone_sub"
echo "  services HTTP : +$n_new_http"
echo "  Tier 0        : +$n_new_t0 / -$n_gone_t0"
[ "${n_new_t0:-0}" -gt 0 ] && echo "  >> $n_new_t0 nouvelle(s) cible(s) prioritaire(s) : voir $OUT"
echo
echo "[OK] Diff ecrit : $OUT"
