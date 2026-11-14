import re, sqlite3, hashlib
from telethon import TelegramClient, events

WATCH = ["canal_leaks_1", "canal_leaks_2", -1001234567890]
KEYWORDS = re.compile(r"(mondomaine\.fr|MaMarque|combolist|stealer)", re.I)

db = sqlite3.connect("veille.db")
db.execute("CREATE TABLE IF NOT EXISTS hits(h TEXT PRIMARY KEY, chan TEXT, mid INT, date TEXT, txt TEXT)")

client = TelegramClient("veille_persona", api_id, api_hash)

@client.on(events.NewMessage(chats=WATCH))
async def handler(ev):
    txt = ev.raw_text or ""
    if not KEYWORDS.search(txt): return
    h = hashlib.sha256((str(ev.chat_id)+txt).encode()).hexdigest()
    try:
        db.execute("INSERT INTO hits VALUES(?,?,?,?,?)",
                   (h, str(ev.chat_id), ev.id, ev.date.isoformat(), txt[:2000]))
        db.commit()
        alerte(ev.chat_id, ev.id, txt)   # webhook / mail
    except sqlite3.IntegrityError:
        pass   # déjà vu (dédup)

def alerte(chan, mid, txt):
    print(f"[HIT] {chan}/{mid} :: {txt[:120]}")

client.start(); client.run_until_disconnected()
