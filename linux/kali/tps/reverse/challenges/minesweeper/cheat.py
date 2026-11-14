import os

# Dump memory
cmd = "del mine.dmp"
os.system(cmd)
cmd = "procdump -ma minesam.exe mine"
os.system(cmd)

# Find gameboard

mark ='\x10\x10\x10\x0F\x0F\x0F\x0F\x0F'

nread = 8
boardfound = 0
gameboard = []

with open("D:\\tmp\\mine.dmp", "rb") as f:
  line = f.read(8)

  while (boardfound == 0):
    c = f.read(1)
    if c == "":
      print "File ended, but gameboard not found!"
      exit()
    line = line[1:] + c
    nread += 1
    if nread % 0x100000 == 0:
      print "Looking at byte", hex(nread), nread
    if line == mark:
      print "Gameboard found at ", hex(nread)
      boardfound = 1
  for i in range(4):
    gameboard.append('\x10')
  for i in range(500):
    gameboard.append(f.read(1))

# Print Gameboard

l = len(gameboard)
m = 32 # items per line

for i in range(0, l-m, m):
  line = ""
  for j in range(m):
    g = gameboard[i+j]
    # print i, j, ord(g)
    if g == '\x10':
      c = "-"
    elif g == '\x0f':
      c = " "
    elif g == '\x8f':
      c = "*"
    elif g == '\x00':
      c = " "
    else:
      c = chr( ord(g) - 16 )
    line += c
  print line