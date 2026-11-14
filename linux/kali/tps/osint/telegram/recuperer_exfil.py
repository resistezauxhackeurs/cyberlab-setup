# Rapatrier les preuves dans SON chat, sans altérer la source
MY_CHAT = 111111111          # votre chat_id de collecte
OP_CHAT = -1001234567890     # chat de l'opérateur (via getUpdates)

requests.get(f"{API}/forwardMessage", params={
    "chat_id": MY_CHAT, "from_chat_id": OP_CHAT, "message_id": 42})

# Télécharger un fichier exfiltré
fid  = "BQACAgQAAx..."
path = requests.get(f"{API}/getFile", params={"file_id":fid}).json()["result"]["file_path"]
data = requests.get(f"https://api.telegram.org/file/bot{TOKEN}/{path}").content
