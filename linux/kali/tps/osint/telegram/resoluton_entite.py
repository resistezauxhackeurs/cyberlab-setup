from telethon.tl.functions.channels import GetFullChannelRequest

ent  = client.get_entity("nom_du_canal")        # username, lien ou ID
full = client(GetFullChannelRequest(ent))
print(ent.id, ent.title, full.full_chat.participants_count)
print(full.full_chat.about)                        # description = riche en IOC
