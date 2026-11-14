for u in client.iter_participants(ent, aggressive=True):
    print(u.id, u.username, u.first_name, u.phone)  # phone quasi toujours None
