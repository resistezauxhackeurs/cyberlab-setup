#!/usr/bin/env python3
# code/telethon_lecture.py
"""
ANNEXE AVANCÉE (semi-actif) — lecture d'un canal public via l'API MTProto.

⚠ CETTE ÉTAPE SORT DU PROFILAGE 100 % PASSIF DU TP.
Contrairement à `profileur.py` (qui ne fait que lire la page web publique),
ce script se connecte à Telegram avec un COMPTE. Même sans rejoindre le canal,
tu es authentifié : tu laisses une empreinte côté Telegram.

RÈGLES NON NÉGOCIABLES pour ce script :
  1. COMPTE JETABLE uniquement (numéro dédié, jamais ton compte perso).
  2. On LIT des canaux PUBLICS. On ne rejoint rien, on n'écrit rien.
  3. On NE liste PAS les membres (pas de get_participants) : c'est de la donnée
     personnelle (RGPD), hors périmètre pédagogique, et souvent réservé aux admins.
  4. Réseau dédié (VPN/Tor) si la cible est sensible.

Ce que le script fait, et rien de plus :
  - résout chaque canal public par son @username (sans le rejoindre) ;
  - lit ses métadonnées : titre, abonnés (participants_count), description ;
  - lit les N derniers messages : date, vues, source de repost, extrait de texte ;
  - repère le plus ancien message accessible (borne d'ancienneté plus fiable
    que le web preview, qui ne montre que les posts récents).

Prérequis :
  pip install telethon
  Identifiants API depuis https://my.telegram.org  (API development tools).
  On les passe par variables d'environnement (ne JAMAIS les coder en dur) :
      export TG_API_ID=123456
      export TG_API_HASH=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Usage :
    python3 telethon_lecture.py brutsecurity echocloudlink sourcebyte
    python3 telethon_lecture.py --limit 50 --json ../data/telethon.json brutsecurity
    python3 telethon_lecture.py --graines exemples/canal-graine.txt
"""

import argparse
import asyncio
import json
import os
import sys
from datetime import timezone

try:
    from telethon import TelegramClient
    from telethon.tl.functions.channels import GetFullChannelRequest
    from telethon.errors import (UsernameNotOccupiedError, UsernameInvalidError,
                                 ChannelPrivateError, FloodWaitError)
except ImportError:
    print("[!] Telethon n'est pas installé.  ->  pip install telethon",
          file=sys.stderr)
    sys.exit(3)


def _extrait(txt: str | None, n: int = 90) -> str:
    """Réduit un texte de message à une ligne courte pour l'affichage."""
    if not txt:
        return ""
    t = " ".join(txt.split())
    return t if len(t) <= n else t[: n - 1] + "…"


def _source_repost(msg) -> str | None:
    """Nom/username du canal d'origine d'un repost, si disponible.

    On reste défensif : selon les cas, Telethon expose le forward de façons
    différentes, et l'origine peut être masquée par l'auteur.
    """
    fwd = getattr(msg, "forward", None)
    if not fwd:
        return None
    chat = getattr(fwd, "chat", None)
    if chat is not None:
        return getattr(chat, "username", None) or getattr(chat, "title", None)
    return None


async def profil_canal(client, username: str, limit: int) -> dict:
    """Lit un canal public (métadonnées + derniers messages) SANS le rejoindre."""
    resultat = {"cible": username}

    entity = await client.get_entity(username)      # résout sans rejoindre
    full = await client(GetFullChannelRequest(entity))
    fc = full.full_chat

    resultat.update({
        "titre": getattr(entity, "title", None),
        "username": getattr(entity, "username", None),
        "abonnes": getattr(fc, "participants_count", None),
        "description": getattr(fc, "about", None),
        # entity.date = date connue de l'entité (approx. de l'ancienneté).
        "date_entite": (entity.date.astimezone(timezone.utc).isoformat()
                        if getattr(entity, "date", None) else None),
    })

    # Derniers messages (du plus récent au plus ancien).
    messages, vues = [], []
    async for msg in client.iter_messages(entity, limit=limit):
        v = getattr(msg, "views", None)
        if v is not None:
            vues.append(v)
        messages.append({
            "id": msg.id,
            "date": msg.date.astimezone(timezone.utc).isoformat() if msg.date else None,
            "vues": v,
            "repost_de": _source_repost(msg),
            "extrait": _extrait(getattr(msg, "message", None)),
        })
    resultat["messages"] = messages
    resultat["vues_max_vue"] = max(vues) if vues else None

    # Plus ancien message accessible (borne d'ancienneté) : une lecture inverse.
    plus_vieux = None
    async for msg in client.iter_messages(entity, limit=1, reverse=True):
        plus_vieux = msg.date.astimezone(timezone.utc).isoformat() if msg.date else None
    resultat["plus_ancien_message"] = plus_vieux

    return resultat


def _afficher(r: dict) -> None:
    print(f"\n=== {r.get('titre') or r['cible']}  (@{r.get('username')}) ===")
    print(f"    Abonnés          : {r.get('abonnes')}")
    print(f"    Date entité (UTC): {r.get('date_entite')}")
    print(f"    + ancien message : {r.get('plus_ancien_message')}")
    if r.get("vues_max_vue") is not None:
        print(f"    Vues max (récent): {r['vues_max_vue']}")
    desc = _extrait(r.get("description"), 120)
    if desc:
        print(f"    Description      : {desc}")
    reposts = [m["repost_de"] for m in r.get("messages", []) if m.get("repost_de")]
    if reposts:
        uniq = sorted(set(reposts))
        print(f"    Reposte depuis   : {', '.join(uniq[:10])}")
    print(f"    Messages lus     : {len(r.get('messages', []))}")


def _charger_graines(chemin: str) -> list[str]:
    graines = []
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            ligne = ligne.strip()
            if ligne and not ligne.startswith("#"):
                graines.append(ligne.lstrip("@"))
    return graines


async def run(canaux: list[str], limit: int, sortie_json: str | None) -> int:
    api_id = os.environ.get("TG_API_ID")
    api_hash = os.environ.get("TG_API_HASH")
    if not (api_id and api_hash):
        print("[!] Définis TG_API_ID et TG_API_HASH (voir https://my.telegram.org).",
              file=sys.stderr)
        return 2

    profils = []
    # « burner_session » : fichier de session du COMPTE JETABLE, jamais partagé.
    async with TelegramClient("burner_session", int(api_id), api_hash) as client:
        for u in canaux:
            try:
                r = await profil_canal(client, u, limit)
                _afficher(r)
                profils.append(r)
            except (UsernameNotOccupiedError, UsernameInvalidError):
                print(f"\n[!] @{u} : username inexistant ou invalide.", file=sys.stderr)
            except ChannelPrivateError:
                print(f"\n[!] @{u} : canal privé ou inaccessible sans y être membre.",
                      file=sys.stderr)
            except FloodWaitError as e:
                print(f"\n[!] Rate limit Telegram : patiente {e.seconds}s puis relance.",
                      file=sys.stderr)
                break
            except Exception as e:  # défensif : la cible peut réagir de mille façons
                print(f"\n[!] @{u} : erreur inattendue ({type(e).__name__}: {e}).",
                      file=sys.stderr)

    if sortie_json:
        with open(sortie_json, "w", encoding="utf-8") as f:
            json.dump(profils, f, ensure_ascii=False, indent=2)
        print(f"\n[+] JSON écrit : {sortie_json}")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description="Lecture de canaux publics via Telethon (compte jetable, sans rejoindre).")
    ap.add_argument("canaux", nargs="*", help="usernames de canaux publics")
    ap.add_argument("--graines", metavar="FICHIER",
                    help="lit les usernames depuis un fichier (un par ligne)")
    ap.add_argument("--limit", type=int, default=30,
                    help="nombre de messages récents à lire par canal (défaut : 30)")
    ap.add_argument("--json", metavar="FICHIER", help="écrit tous les profils en JSON")
    args = ap.parse_args(argv)

    canaux = list(args.canaux)
    if args.graines:
        canaux += _charger_graines(args.graines)
    canaux = [c.lstrip("@") for c in dict.fromkeys(canaux)]  # dé-doublonne, garde l'ordre
    if not canaux:
        ap.error("aucun canal fourni (positionnel ou --graines).")

    try:
        return asyncio.run(run(canaux, args.limit, args.json))
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
