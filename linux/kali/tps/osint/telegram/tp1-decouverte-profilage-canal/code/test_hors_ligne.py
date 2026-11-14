#!/usr/bin/env python3
# code/test_hors_ligne.py
"""
Test hors ligne du profileur — ne fait AUCUN appel réseau.

Il rejoue une page web preview enregistrée (exemples/fixture_page1.html) dans
la logique de parsing, et vérifie que les champs clés sont bien extraits.
Utile pour valider l'installation quand la séance n'a pas encore d'accès à t.me,
ou pour comprendre ce que le parseur sait faire.

    python3 test_hors_ligne.py
"""
import os
import sys

import profileur as P

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "exemples", "fixture_page1.html")


def main() -> int:
    with open(FIXTURE, encoding="utf-8") as f:
        html = f.read()

    prof = P.build_profile("canaltest", [html])

    def dom(nom):
        return any(d["domaine"] == nom for d in prof["domaines_externes"])

    def bot(nom):
        return any(b["bot"] == nom for b in prof["bots_cites"])

    verifs = {
        # --- base (déjà couvert en v1) ---
        "titre extrait":            prof["titre"] == "Test Canal OSINT",
        "username propre":          prof["username"] == "canaltest",
        "abonnés parsés (12.3K)":   prof["abonnes"] == 12300,
        "compteur photos":          prof["compteurs"].get("photos") == "842",
        "3 posts analysés":         prof["posts_analyses"] == 3,
        "post le + ancien":         prof["plus_ancien_post_visible"].startswith("2024-03-10"),
        "post le + récent":         prof["plus_recent_post_visible"].startswith("2024-03-12"),
        "sourceA en tête des liés": prof["canaux_lies"][0]["canal"] == "sourceA",
        "sourceA vu sur 3 posts":   prof["canaux_lies"][0]["occurrences"] == 3,
        "2 reposts depuis sourceA": prof["reposts_depuis"][0]["occurrences"] == 2,

        # --- enrichissements v2 ---
        "vues médianes = 2100":     prof["vues_mediane"] == 2100,
        "ratio vues/abonnés":       prof["ratio_vues_abonnes"] == round(2100 / 12300, 3),
        "domaine externe capté":    dom("leak-example.top"),
        "TLD .top agrégé":          any(t["tld"] == "top" for t in prof["tld_externes"]),
        "bot @collectbot capté":    bot("collectbot"),
        "1 invitation privée":      prof["invitations_privees"] == 1,
        "collectbot ≠ canal lié":   all(c["canal"] != "collectbot" for c in prof["canaux_lies"]),
        "self-link canal filtré":   all(c["canal"] != "canaltest" for c in prof["canaux_lies"]),
        "script dominant latin":    (prof["script_dominant"] or "").startswith("latin"),
        "fenêtre active 08h UTC":   prof["heatmap_horaire"]["fenetre_active_utc"].startswith("08h"),
        "cadence calculée":         prof["cadence_posts_par_jour"] is not None,
    }

    ok = True
    for libelle, resultat in verifs.items():
        etat = "OK  " if resultat else "ECHEC"
        if not resultat:
            ok = False
        print(f"  [{etat}] {libelle}")

    print()
    if ok:
        print("Tous les tests passent. Le parsing est fonctionnel.")
        return 0
    print("Au moins un test échoue — vérifier profileur.py ou la fixture.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
