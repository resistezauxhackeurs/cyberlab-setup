global _start
section .text
_start:
	mov eax, 3 ; sys_write
	mov ebx, 1 ; stdout
	mov ecx, fichier
	mov edx, 13
	int 0x80
	mov eax, 1 ; sys_exit
	xor ebx, ebx
	int 0x80
section .data
	fichier: db "/etc/passwd", 10