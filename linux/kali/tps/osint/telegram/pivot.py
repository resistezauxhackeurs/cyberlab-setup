import collections
graph = collections.Counter()

for msg in client.iter_messages(ent, limit=5000):
    fwd = msg.fwd_from
    if fwd and fwd.from_id:
        try:
            src = client.get_entity(fwd.from_id)
            graph[(getattr(src,"username",None), src.id)] += 1
        except Exception:
            pass

for (uname, cid), n in graph.most_common(30):
    print(f"{n:4}  @{uname}  ({cid})")   # canaux sources les plus liés
