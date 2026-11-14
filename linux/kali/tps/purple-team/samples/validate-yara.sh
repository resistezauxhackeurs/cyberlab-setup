#!/usr/bin/env bash
# Chemin : tps/purple-team/samples/validate-yara.sh
# Fil rouge Purple Team - Active Directory
#
# Valide que chaque regle YARA detecte son sample, SANS faux positif sur un temoin benin.
# Usage :
#   cd tps/purple-team/samples
#   cp /bin/ls _benign_control.exe      # fabrique le temoin negatif
#   bash validate-yara.sh
#
# Samples attendus dans ce dossier : Advanced_IP_Scanner_2.5.4594.1.exe,
# PsExec.exe, PsExec64.exe, mimikatz.exe (64 bits).
#
# Sortie attendue : toutes les lignes OK, 0 FAIL, "Couverture validee."

set -u
RULES="rules"
G="\033[32m"; R="\033[31m"; Y="\033[33m"; N="\033[0m"
pass=0; fail=0

# check <regle.yar> <sample> <doit_matcher: yes|no>
check() {
  local rule="$RULES/$1" sample="$2" expect="$3"
  if [[ ! -f "$rule" ]];   then echo -e "${Y}SKIP${N} regle absente  : $rule";   return; fi
  if [[ ! -e "$sample" ]]; then echo -e "${Y}SKIP${N} sample absent  : $sample"; return; fi
  if yara "$rule" "$sample" 2>/dev/null | grep -q .; then hit=yes; else hit=no; fi
  if [[ "$hit" == "$expect" ]]; then
    echo -e "${G}OK  ${N} $1  vs  $(basename "$sample")  (attendu: $expect)"; ((pass++))
  else
    echo -e "${R}FAIL${N} $1  vs  $(basename "$sample")  (attendu: $expect, obtenu: $hit)"; ((fail++))
  fi
}

echo "=== Detection attendue (le sample DOIT matcher) ==="
check advanced_ip_scanner.yar  Advanced_IP_Scanner_2.5.4594.1.exe  yes
check psexec.yar               PsExec.exe                          yes
check psexec.yar               PsExec64.exe                        yes
# mimikatz : le binaire compile 64 bits, dans ce meme dossier (cas reel : l'attaquant lance l'exe)
check mimikatz.yar             mimikatz.exe                        yes

echo; echo "=== Controle negatif (le temoin NE DOIT PAS matcher) ==="
if [[ -e _benign_control.exe ]]; then
  for r in "$RULES"/*.yar; do
    [[ -f "$r" ]] || continue
    check "$(basename "$r")" _benign_control.exe no
  done
else
  echo -e "${Y}SKIP${N} temoin absent : cree-le avec  cp /bin/ls _benign_control.exe"
fi

echo; echo "---------------------------------------------"
echo -e "Resultat : ${G}${pass} OK${N} / ${R}${fail} FAIL${N}"
if [[ $fail -eq 0 ]]; then
  echo -e "${G}Couverture validee.${N}"; exit 0
else
  echo -e "${R}A corriger avant la session.${N}  Astuce : relance la regle fautive avec  yara -s rules/<regle>.yar <sample>  pour voir les chaines trouvees."; exit 1
fi
