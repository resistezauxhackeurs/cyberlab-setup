#!/usr/bin/env python3
# code/profileur.py
"""
Profileur passif de canal Telegram — TP1 « Découverte et profilage de canal ».

Objectif pédagogique : profiler un canal PUBLIC depuis l'extérieur, sans jamais
le rejoindre ni se connecter à un compte. On interroge uniquement la surface
web publique « web preview » servie par Telegram à l'adresse :

    https://t.me/s/<canal>

C'est la même page que celle qu'un navigateur affiche à un visiteur anonyme.
Le script en extrait :
  - le titre affiché et le @username,
  - le nombre d'abonnés,
  - la description,
  - les compteurs (photos / vidéos / liens / fichiers) quand ils sont exposés,
  - la date du plus ancien et du plus récent post visible,
  - les CANAUX LIÉS : reposts (« forwarded from ») et mentions t.me dans les posts,
  - les VUES par post -> médiane et RATIO vues/abonnés (détecteur d'audience gonflée),
  - les LIENS SORTANTS classés : domaines externes, TLD, bots, invitations privées,
  - la HEATMAP HORAIRE (heures UTC de publication) -> fenêtre active, indice de fuseau,
  - la CADENCE (posts par jour) et le SCRIPT DOMINANT (latin / cyrillique / arabe...).

Aucune dépendance externe : bibliothèque standard uniquement.
Option --proxy pour router la requête (ex. Tor : socks5h://127.0.0.1:9050
via un proxy HTTP local, ou un proxy HTTP classique) — voir le README.

Usage :
    python3 profileur.py durov
    python3 profileur.py https://t.me/s/durov --json data/durov.json
    python3 profileur.py durov --pages 10 --md data/durov.md
    python3 profileur.py durov --proxy http://127.0.0.1:8118
"""

import argparse
import json
import re
import statistics
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from html.parser import HTMLParser
from html import unescape
from urllib.parse import urlsplit

UA = ("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) "
      "Gecko/20100101 Firefox/128.0")

BASE = "https://t.me/s/"

# Hôtes Telegram (les liens vers ces domaines pointent DANS l'écosystème,
# pas vers de l'infra externe).
HOTES_TELEGRAM = {"t.me", "telegram.me", "telegram.dog", "telegram.org"}

# Premiers segments de t.me qui ne sont PAS des canaux (pages de service).
# Sans ce garde-fou, « t.me/joinchat/... » serait pris pour un canal « joinchat ».
SEGMENTS_RESERVES = {
    "s", "share", "joinchat", "addstickers", "addemoji", "addlist",
    "proxy", "socks", "iv", "login", "confirmphone", "setlanguage",
    "bg", "msg", "c", "contact",
}


# --------------------------------------------------------------------------- #
# Récupération réseau                                                          #
# --------------------------------------------------------------------------- #
def _opener(proxy: str | None):
    """Construit un opener urllib, éventuellement derrière un proxy HTTP."""
    handlers = []
    if proxy:
        handlers.append(urllib.request.ProxyHandler({"http": proxy, "https": proxy}))
    else:
        # ProxyHandler vide = on ignore les variables d'env http_proxy
        handlers.append(urllib.request.ProxyHandler({}))
    return urllib.request.build_opener(*handlers)


def fetch(url: str, proxy: str | None = None, timeout: int = 20) -> str:
    """GET brut d'une page. Lève une exception réseau en cas d'échec."""
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Accept-Language": "en,fr;q=0.8"})
    opener = _opener(proxy)
    with opener.open(req, timeout=timeout) as resp:
        raw = resp.read()
    # Telegram renvoie de l'UTF-8. errors=replace pour ne jamais planter.
    return raw.decode("utf-8", errors="replace")


# --------------------------------------------------------------------------- #
# Extraction — on privilégie des regex ciblées sur des classes CSS stables    #
# du web preview. Un mini parseur HTML sert de repli pour le texte des posts. #
# --------------------------------------------------------------------------- #
class _TextStripper(HTMLParser):
    """Réduit un fragment HTML à son texte brut (pour le corps d'un post)."""
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)

    def text(self):
        return unescape("".join(self.parts)).strip()


def _strip_html(fragment: str) -> str:
    p = _TextStripper()
    p.feed(fragment)
    return re.sub(r"\s+", " ", p.text()).strip()


def _first(pattern: str, html: str, flags=re.S) -> str | None:
    m = re.search(pattern, html, flags)
    return m.group(1).strip() if m else None


def parse_header(html: str) -> dict:
    """Extrait les métadonnées d'en-tête du canal depuis la page web preview."""
    info = {}

    # Titre affiché
    title = _first(r'<div class="tgme_channel_info_header_title"[^>]*>\s*'
                   r'<span[^>]*>(.*?)</span>', html)
    if not title:
        # repli : balise <meta property="og:title">
        title = _first(r'<meta property="og:title" content="([^"]*)"', html)
    info["titre"] = _strip_html(title) if title else None

    # @username (issu du lien canonique / og:url) — on saute un éventuel « s/ »
    uname = _first(r'<meta property="og:url" content="https://t\.me/(?:s/)?([^"/?]+)', html)
    info["username"] = uname

    # Description
    desc = _first(r'<div class="tgme_channel_info_description"[^>]*>(.*?)</div>', html)
    if not desc:
        desc = _first(r'<meta property="og:description" content="([^"]*)"', html)
    info["description"] = _strip_html(desc) if desc else None

    # Compteurs : chaque bloc = <span class="counter_value">N</span>
    #                            <span class="counter_type">subscribers</span>
    counters = {}
    for value, ctype in re.findall(
            r'<span class="counter_value">([^<]+)</span>\s*'
            r'<span class="counter_type">([^<]+)</span>', html):
        counters[ctype.strip().lower()] = value.strip()
    info["compteurs"] = counters
    info["abonnes_txt"] = counters.get("subscribers")
    info["abonnes"] = _to_int(counters.get("subscribers"))

    # Badge « vérifié »
    info["verifie"] = 'tgme_channel_info_header_verified' in html \
        or 'verified-icon' in html

    return info


def _to_int(txt: str | None) -> int | None:
    """'12.3K' -> 12300 ; '1 234' -> 1234 ; '2M' -> 2000000."""
    if not txt:
        return None
    t = txt.replace("\u202f", "").replace("\xa0", "").replace(" ", "").upper()
    m = re.match(r"^([\d.,]+)([KMB]?)$", t)
    if not m:
        return None
    num = float(m.group(1).replace(",", "."))
    mult = {"": 1, "K": 1_000, "M": 1_000_000, "B": 1_000_000_000}[m.group(2)]
    return int(num * mult)


def _classer_liens(hrefs: list[str], username: str):
    """Range les URLs d'un post par nature.

    Retourne (canaux, externes, bots, invites) où :
      - canaux   : set des @canaux Telegram publics cités (hors le canal lui-même) ;
      - externes : liste des DOMAINES non-Telegram (avec doublons, pour compter) ;
      - bots     : set des bots (@…bot) ;
      - invites  : liste des liens d'invitation privés (t.me/+… ou /joinchat/…).

    On classe sur la structure de l'URL (host + premier segment de chemin),
    pas sur le texte affiché : c'est ce qui résiste aux redesigns de Telegram.
    """
    canaux, bots, invites, externes = set(), set(), [], []
    for h in hrefs:
        try:
            parts = urlsplit(h)
        except ValueError:
            continue
        host = parts.netloc.lower()
        if host.startswith("www."):
            host = host[4:]

        if host in HOTES_TELEGRAM:
            seg = parts.path.lstrip("/").split("/")[0]
            if not seg:
                continue
            if seg.startswith("+") or seg.lower() == "joinchat":
                invites.append(h)
            elif seg.lower().endswith("bot"):
                bots.add(seg)
            elif (re.match(r"^[A-Za-z0-9_]{4,32}$", seg)
                    and seg.lower() not in SEGMENTS_RESERVES
                    and seg.lower() != username.lower()):
                canaux.add(seg)
        elif host:  # tout hôte non-Telegram = infrastructure externe
            externes.append(host)
    return canaux, externes, bots, invites


def parse_posts(html: str, username: str) -> list[dict]:
    """Découpe la page en posts et extrait date, texte, vues, forward, liens."""
    posts = []
    # Chaque post = <div class="tgme_widget_message ..."> ... </div> jusqu'au
    # prochain widget_message. On segmente sur ce marqueur.
    blocks = re.split(r'(?=<div class="tgme_widget_message[ "])', html)
    for b in blocks:
        if 'tgme_widget_message_text' not in b and 'message_date' not in b:
            continue
        post = {}

        # Date ISO (attribut datetime de la balise <time>)
        post["date"] = _first(r'<time[^>]*datetime="([^"]+)"', b)

        # Vues (footer du post) : chaîne humaine « 12.4K » -> entier
        vues_txt = _first(r'class="tgme_widget_message_views"[^>]*>([^<]+)</span>', b)
        post["vues_txt"] = vues_txt
        post["vues"] = _to_int(vues_txt)

        # Forward : canal source d'un repost
        fwd = _first(r'tgme_widget_message_forwarded_from_name"[^>]*>(.*?)</a>', b)
        fwd_url = _first(r'tgme_widget_message_forwarded_from_name"\s+href="'
                         r'https://t\.me/([^"/?]+)', b)
        if fwd:
            post["forward_from"] = _strip_html(fwd)
            post["forward_username"] = fwd_url

        # Texte du post
        body = _first(r'<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>', b)
        post["texte"] = _strip_html(body) if body else ""

        # Liens sortants : on ratisse TOUS les href du bloc du post (texte +
        # aperçu de lien), puis on les classe. Le self-link vers le post et le
        # forward pointent vers le canal lui-même : filtrés par _classer_liens.
        hrefs = re.findall(r'href="(https?://[^"]+)"', b)
        canaux, externes, bots, invites = _classer_liens(hrefs, username)
        post["canaux"] = canaux
        post["externes"] = externes
        post["bots"] = bots
        post["invites"] = invites

        posts.append(post)
    return posts


# --------------------------------------------------------------------------- #
# Heuristiques d'analyse                                                       #
# --------------------------------------------------------------------------- #
def _script_dominant(textes: list[str]) -> str | None:
    """Devine le script d'écriture majoritaire (indice de langue / origine).

    Compte des plages Unicode simples. Volontairement grossier : c'est un
    indice de pivot, pas une détection de langue fiable.
    """
    blob = " ".join(textes)
    scores = {
        "latin":      len(re.findall(r"[A-Za-zÀ-ÿ]", blob)),
        "cyrillique": len(re.findall(r"[\u0400-\u04FF]", blob)),
        "arabe":      len(re.findall(r"[\u0600-\u06FF]", blob)),
        "grec":       len(re.findall(r"[\u0370-\u03FF]", blob)),
        "han":        len(re.findall(r"[\u4E00-\u9FFF]", blob)),
    }
    total = sum(scores.values())
    if total == 0:
        return None
    script, n = max(scores.items(), key=lambda kv: kv[1])
    part = round(100 * n / total)
    return f"{script} (~{part}%)"


def _heatmap_horaire(posts: list[dict]) -> dict:
    """Distribution des heures UTC de publication + fenêtre de 3h la plus dense."""
    heures = Counter()
    for p in posts:
        d = p.get("date")
        if not d:
            continue
        try:
            dt = datetime.fromisoformat(d).astimezone(timezone.utc)
        except ValueError:
            continue
        heures[dt.hour] += 1
    if not heures:
        return {}
    # Fenêtre glissante de 3 heures la plus active (indice grossier de fuseau).
    meilleure_h, meilleur_score = 0, -1
    for h in range(24):
        s = heures[h] + heures[(h + 1) % 24] + heures[(h + 2) % 24]
        if s > meilleur_score:
            meilleure_h, meilleur_score = h, s
    return {
        "par_heure_utc": {h: heures.get(h, 0) for h in range(24)},
        "fenetre_active_utc": f"{meilleure_h:02d}h-{(meilleure_h + 3) % 24:02d}h",
        "posts_dans_la_fenetre": meilleur_score,
    }


def _cadence_par_jour(plus_ancien: str | None, plus_recent: str | None,
                      n_posts: int) -> float | None:
    """Posts par jour sur l'intervalle observé (grossier : dépend des pages lues)."""
    if not (plus_ancien and plus_recent) or n_posts == 0:
        return None
    try:
        a = datetime.fromisoformat(plus_ancien)
        r = datetime.fromisoformat(plus_recent)
    except ValueError:
        return None
    jours = max((r - a).total_seconds() / 86400, 1 / 24)  # plancher : 1 heure
    return round(n_posts / jours, 2)


# --------------------------------------------------------------------------- #
# Agrégation — le « profil » du canal                                         #
# --------------------------------------------------------------------------- #
def build_profile(username: str, pages_html: list[str]) -> dict:
    header = parse_header(pages_html[0])

    all_posts = []
    for h in pages_html:
        all_posts.extend(parse_posts(h, username))

    # Canaux liés : forwards + mentions, agrégés et comptés
    liens = Counter()      # nb de posts où chaque canal apparaît (1 max/post)
    forwards = Counter()   # nb de reposts « forwarded from » par canal source
    domaines = Counter()   # domaines externes, avec doublons -> volume
    bots = Counter()       # bots cités
    invites_total = 0
    for p in all_posts:
        vus = set()  # canaux distincts vus dans CE post (dé-doublonnage par post)
        fu = p.get("forward_username")
        if fu and fu.lower() != username.lower():
            forwards[fu] += 1
            vus.add(fu)
        for c in p.get("canaux", ()):
            vus.add(c)
        for c in vus:
            liens[c] += 1
        for d in p.get("externes", ()):
            domaines[d] += 1
        for bpost in p.get("bots", ()):
            bots[bpost] += 1
        invites_total += len(p.get("invites", ()))

    # TLD agrégés à partir des domaines (dernier label du host)
    tld = Counter()
    for d, n in domaines.items():
        tld[d.rsplit(".", 1)[-1]] += n

    # Bornes de dates observées
    dates = sorted(p["date"] for p in all_posts if p.get("date"))
    plus_ancien = dates[0] if dates else None
    plus_recent = dates[-1] if dates else None

    # Vues : médiane sur les posts qui l'exposent + ratio vues/abonnés
    vues_list = [p["vues"] for p in all_posts if p.get("vues") is not None]
    vues_mediane = int(statistics.median(vues_list)) if vues_list else None
    abonnes = header.get("abonnes")
    ratio_vues_abonnes = (round(vues_mediane / abonnes, 3)
                          if vues_mediane and abonnes else None)

    profile = {
        "cible": username,
        "url_source": f"{BASE}{username}",
        "collecte_le": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "titre": header.get("titre"),
        "username": header.get("username") or username,
        "verifie": header.get("verifie"),
        "abonnes": abonnes,
        "abonnes_txt": header.get("abonnes_txt"),
        "description": header.get("description"),
        "compteurs": header.get("compteurs"),
        "posts_analyses": len(all_posts),
        "plus_ancien_post_visible": plus_ancien,
        "plus_recent_post_visible": plus_recent,
        "cadence_posts_par_jour": _cadence_par_jour(plus_ancien, plus_recent,
                                                    len(all_posts)),
        "script_dominant": _script_dominant([p.get("texte", "") for p in all_posts]),
        "vues_mediane": vues_mediane,
        "ratio_vues_abonnes": ratio_vues_abonnes,
        "heatmap_horaire": _heatmap_horaire(all_posts),
        "canaux_lies": [
            {"canal": c, "occurrences": n} for c, n in liens.most_common()
        ],
        "reposts_depuis": [
            {"canal": c, "occurrences": n} for c, n in forwards.most_common()
        ],
        "domaines_externes": [
            {"domaine": d, "occurrences": n} for d, n in domaines.most_common()
        ],
        "tld_externes": [
            {"tld": t, "occurrences": n} for t, n in tld.most_common()
        ],
        "bots_cites": [
            {"bot": b, "occurrences": n} for b, n in bots.most_common()
        ],
        "invitations_privees": invites_total,
    }
    return profile


# --------------------------------------------------------------------------- #
# Pagination du web preview                                                    #
# --------------------------------------------------------------------------- #
def _oldest_message_id(html: str) -> int | None:
    """Récupère le plus petit id de message présent sur la page (pour paginer)."""
    ids = [int(x) for x in re.findall(r'data-post="[^/]+/(\d+)"', html)]
    return min(ids) if ids else None


def collect_pages(username: str, pages: int, proxy: str | None,
                  pause: float = 1.0) -> list[str]:
    """Récupère jusqu'à `pages` pages en remontant l'historique via ?before=."""
    out = []
    url = f"{BASE}{username}"
    for i in range(pages):
        html = fetch(url, proxy=proxy)
        out.append(html)
        oldest = _oldest_message_id(html)
        if oldest is None or oldest <= 1:
            break
        url = f"{BASE}{username}?before={oldest}"
        if i < pages - 1:
            time.sleep(pause)  # politesse / OPSEC : pas de rafale
    return out


# --------------------------------------------------------------------------- #
# Rendu Markdown (fiche de profil lisible)                                     #
# --------------------------------------------------------------------------- #
def to_markdown(p: dict) -> str:
    L = []
    L.append(f"# Profil de canal : {p.get('titre') or p['cible']}")
    L.append("")
    L.append(f"- **Cible** : `{p['cible']}`")
    L.append(f"- **Source** : {p['url_source']}")
    L.append(f"- **Collecté le** : {p['collecte_le']}")
    L.append(f"- **@username** : `{p.get('username')}`"
             + ("  (verifie)" if p.get("verifie") else ""))
    ab = p.get("abonnes")
    L.append(f"- **Abonnés** : {p.get('abonnes_txt') or '-'}"
             + (f" (~ {ab:,})".replace(",", " ") if ab else ""))
    L.append(f"- **Posts analysés** : {p.get('posts_analyses')}")
    L.append(f"- **Post le plus ancien visible** : {p.get('plus_ancien_post_visible') or '-'}")
    L.append(f"- **Post le plus récent visible** : {p.get('plus_recent_post_visible') or '-'}")
    if p.get("cadence_posts_par_jour") is not None:
        L.append(f"- **Cadence** : ~{p['cadence_posts_par_jour']} post(s)/jour")
    if p.get("script_dominant"):
        L.append(f"- **Script dominant** : {p['script_dominant']}")
    if p.get("compteurs"):
        cc = ", ".join(f"{k} : {v}" for k, v in p["compteurs"].items())
        L.append(f"- **Compteurs** : {cc}")
    L.append("")

    # Signaux d'audience
    L.append("## Audience (vues)")
    if p.get("vues_mediane") is not None:
        L.append(f"- **Vues médianes / post** : {p['vues_mediane']:,}".replace(",", " "))
        if p.get("ratio_vues_abonnes") is not None:
            r = p["ratio_vues_abonnes"]
            note = ("faible (audience peu active ?)" if r < 0.1
                    else "forte reprise" if r > 1 else "normal")
            L.append(f"- **Ratio vues/abonnés** : {r} — {note}")
    else:
        L.append("_Aucune vue exposée sur les pages collectées._")
    L.append("")

    # Rythme
    hm = p.get("heatmap_horaire") or {}
    L.append("## Rythme de publication (UTC)")
    if hm:
        L.append(f"- **Fenêtre la plus active** : {hm.get('fenetre_active_utc')} "
                 f"({hm.get('posts_dans_la_fenetre')} posts)")
        barres = hm.get("par_heure_utc", {})
        vmax = max(barres.values()) if barres else 0
        for h in range(24):
            n = barres.get(h, 0)
            blocs = "#" * round(8 * n / vmax) if vmax else ""
            L.append(f"    {h:02d}h | {blocs} {n}")
    else:
        L.append("_Pas de dates exploitables._")
    L.append("")

    L.append("## Description")
    L.append(p.get("description") or "_(vide ou non exposée)_")
    L.append("")

    L.append("## Canaux liés (mentions + reposts)")
    if p.get("canaux_lies"):
        for c in p["canaux_lies"]:
            L.append(f"- `{c['canal']}` — {c['occurrences']} occurrence(s) "
                     f"→ https://t.me/{c['canal']}")
    else:
        L.append("_Aucun canal lié détecté sur les pages collectées._")
    L.append("")

    L.append("## Reposts (« forwarded from »)")
    if p.get("reposts_depuis"):
        for c in p["reposts_depuis"]:
            L.append(f"- `{c['canal']}` — {c['occurrences']} repost(s)")
    else:
        L.append("_Aucun repost détecté._")
    L.append("")

    L.append("## Infrastructure sortante")
    if p.get("domaines_externes"):
        L.append("**Domaines externes :**")
        for d in p["domaines_externes"]:
            L.append(f"- `{d['domaine']}` — {d['occurrences']} lien(s)")
        if p.get("tld_externes"):
            tl = ", ".join(f"{t['tld']} ({t['occurrences']})" for t in p["tld_externes"])
            L.append(f"\n**TLD :** {tl}")
    else:
        L.append("_Aucun lien externe détecté._")
    if p.get("bots_cites"):
        L.append("\n**Bots cités :** "
                 + ", ".join(f"@{b['bot']} ({b['occurrences']})" for b in p["bots_cites"]))
    if p.get("invitations_privees"):
        L.append(f"\n**Invitations privées (t.me/+… ou joinchat) :** "
                 f"{p['invitations_privees']} — pivot vers du canal fermé.")
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #
def normalize_target(arg: str) -> str:
    """Accepte 'durov', '@durov', 't.me/durov', 'https://t.me/s/durov'."""
    a = arg.strip().lstrip("@")
    a = re.sub(r"^https?://", "", a)
    a = re.sub(r"^t\.me/(s/)?", "", a)
    a = a.split("/")[0].split("?")[0]
    return a


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Profilage passif d'un canal Telegram public (web preview).")
    ap.add_argument("canal", help="username, @username, ou URL t.me")
    ap.add_argument("--pages", type=int, default=1,
                    help="nombre de pages d'historique à remonter (défaut : 1)")
    ap.add_argument("--proxy", default=None,
                    help="proxy HTTP (ex. http://127.0.0.1:8118 pour Tor via privoxy)")
    ap.add_argument("--json", metavar="FICHIER", help="écrit le profil en JSON")
    ap.add_argument("--md", metavar="FICHIER", help="écrit la fiche en Markdown")
    ap.add_argument("--pause", type=float, default=1.0,
                    help="pause entre pages en secondes (défaut : 1.0)")
    args = ap.parse_args(argv)

    target = normalize_target(args.canal)
    if not re.match(r"^[A-Za-z0-9_]{4,32}$", target):
        print(f"[!] Nom de canal invalide : {target!r}", file=sys.stderr)
        return 2

    print(f"[*] Cible          : {target}")
    print(f"[*] Source         : {BASE}{target}")
    print(f"[*] Pages           : {args.pages}"
          + (f"  | proxy : {args.proxy}" if args.proxy else ""))

    try:
        pages_html = collect_pages(target, args.pages, args.proxy, args.pause)
    except urllib.error.HTTPError as e:
        print(f"[!] HTTP {e.code} — canal privé, inexistant, ou preview désactivée.",
              file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"[!] Erreur réseau : {e.reason}", file=sys.stderr)
        return 1

    if not pages_html or 'tgme_channel_info' not in pages_html[0] \
            and 'tgme_widget_message' not in pages_html[0]:
        print("[!] Page reçue mais aucun contenu de canal détecté.\n"
              "    Le canal n'a peut-être pas activé le web preview public.",
              file=sys.stderr)
        # on continue quand même : parse_header renverra des champs vides

    profile = build_profile(target, pages_html)

    # Affichage console
    print()
    print(f"    Titre     : {profile.get('titre')}")
    print(f"    Abonnés   : {profile.get('abonnes_txt')} "
          f"({profile.get('abonnes')})")
    print(f"    Posts     : {profile.get('posts_analyses')}"
          + (f"  (~{profile['cadence_posts_par_jour']}/j)"
             if profile.get("cadence_posts_par_jour") else ""))
    if profile.get("vues_mediane") is not None:
        r = profile.get("ratio_vues_abonnes")
        print(f"    Vues méd. : {profile['vues_mediane']}"
              + (f"  | ratio vues/abo : {r}" if r is not None else ""))
    if profile.get("script_dominant"):
        print(f"    Langue    : {profile['script_dominant']}")
    hm = profile.get("heatmap_horaire") or {}
    if hm:
        print(f"    Actif     : {hm.get('fenetre_active_utc')} UTC "
              f"({hm.get('posts_dans_la_fenetre')} posts)")
    print(f"    + ancien  : {profile.get('plus_ancien_post_visible')}")
    print(f"    Liés      : {len(profile.get('canaux_lies', []))} canal(aux)")
    for c in profile.get("canaux_lies", [])[:10]:
        print(f"                - {c['canal']} ({c['occurrences']})")
    if profile.get("domaines_externes"):
        print(f"    Domaines  : {len(profile['domaines_externes'])} externe(s)")
        for d in profile["domaines_externes"][:10]:
            print(f"                - {d['domaine']} ({d['occurrences']})")
    if profile.get("bots_cites"):
        print("    Bots      : "
              + ", ".join(f"@{b['bot']}" for b in profile["bots_cites"][:10]))
    if profile.get("invitations_privees"):
        print(f"    Invites   : {profile['invitations_privees']} lien(s) privé(s)")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(profile, f, ensure_ascii=False, indent=2)
        print(f"\n[+] JSON écrit : {args.json}")
    if args.md:
        with open(args.md, "w", encoding="utf-8") as f:
            f.write(to_markdown(profile))
        print(f"[+] Markdown écrit : {args.md}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
