import json, hashlib, datetime, os
from telethon import TelegramClient

def sha256(path):
    h = hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda: f.read(8192), b""): h.update(b)
    return h.hexdigest()

client = TelegramClient("enquete_persona1", api_id, api_hash); client.start()
target, outdir = "nom_du_canal", "dump_media"; os.makedirs(outdir, exist_ok=True)
rows = []

for m in client.iter_messages(target):
    rec = {
        "id": m.id, "date_utc": m.date.isoformat(),
        "sender_id": getattr(m.sender_id,"__int__",lambda:m.sender_id)(),
        "text": m.raw_text,
        "fwd_from": str(m.fwd_from.from_id) if m.fwd_from else None,
        "reply_to": m.reply_to_msg_id, "views": m.views, "media_sha256": None,
    }
    if m.media:
        p = client.download_media(m, file=outdir)
        if p: rec["media_sha256"] = sha256(p); rec["media_file"] = os.path.basename(p)
    rows.append(rec)

manifest = {
    "target": target, "collected_at_utc": datetime.datetime.utcnow().isoformat(),
    "analyst": "persona1", "message_count": len(rows),
}
with open("dump.json","w",encoding="utf-8") as f:
    json.dump({"manifest":manifest, "messages":rows}, f, ensure_ascii=False, indent=2)
print("dump.json sha256:", sha256("dump.json"))   # sceller le hash dans le journal
