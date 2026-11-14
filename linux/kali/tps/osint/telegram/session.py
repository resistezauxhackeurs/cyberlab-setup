# Session d'enquête - fichier .session à protéger comme un secret
from telethon import TelegramClient

api_id   = 123456
api_hash = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

client = TelegramClient("enquete_persona1", api_id, api_hash)
client.start()   # 1re fois : demande le numéro + code
